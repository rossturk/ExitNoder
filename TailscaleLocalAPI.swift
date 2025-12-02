//
//  TailscaleLocalAPI.swift
//  ExitNodeSwitcher
//
//  Communicates with Tailscale via the Local API or CLI
//

import Foundation

/// Handles communication with Tailscale via Local API or CLI
class TailscaleLocalAPI {
    
    // Local API endpoint
    private let localAPIURL = "http://localhost:41112/localapi/v0"
    
    // Possible paths for Tailscale CLI (fallback)
    private static let possibleTailscalePaths = [
        "/Applications/Tailscale.app/Contents/MacOS/Tailscale",  // Mac App Store version
        "/usr/local/bin/tailscale",                               // Homebrew or manual install
        "/opt/homebrew/bin/tailscale"                             // Apple Silicon Homebrew
    ]
    
    private let tailscalePath: String
    private var useHTTPAPI = true  // Try HTTP first, fall back to CLI if it fails
    
    init() {
        // Find the first valid Tailscale executable (for fallback)
        let fileManager = FileManager.default
        
        if let validPath = Self.possibleTailscalePaths.first(where: { path in
            fileManager.fileExists(atPath: path) && fileManager.isExecutableFile(atPath: path)
        }) {
            self.tailscalePath = validPath
        } else {
            // Default to the Mac App Store version path
            self.tailscalePath = Self.possibleTailscalePaths[0]
        }
    }
    
    // MARK: - API Methods
    
    /// Get the current Tailscale status
    func getStatus() async throws -> TailscaleStatus {
        // Try HTTP API first
        if useHTTPAPI {
            do {
                return try await getStatusViaHTTP()
            } catch {
                useHTTPAPI = false
            }
        }
        
        // Fall back to CLI
        return try await getStatusViaCLI()
    }
    
    private func getStatusViaHTTP() async throws -> TailscaleStatus {
        guard let url = URL(string: "\(localAPIURL)/status") else {
            throw TailscaleAPIError.invalidResponse
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw TailscaleAPIError.connectionFailed
        }
                
        let decoder = JSONDecoder()
        return try decoder.decode(TailscaleStatus.self, from: data)
    }
    
    private func getStatusViaCLI() async throws -> TailscaleStatus {
        let output = try await runTailscaleCommand(["status", "--json"])
                
        let decoder = JSONDecoder()
        guard let data = output.data(using: .utf8) else {
            throw TailscaleAPIError.invalidResponse
        }
        
        do {
            return try decoder.decode(TailscaleStatus.self, from: data)
        } catch {
            print("🔧 JSON Decoding failed. First 500 chars:")
            print(String(output.prefix(500)))
            throw error
        }
    }
    
    /// Set the exit node
    /// - Parameters:
    ///   - nodeID: The node ID (used for HTTP API)
    ///   - nodeName: The node's hostname or DNS name (used for CLI fallback)
    func setExitNode(nodeID: String?, nodeName: String? = nil) async throws {
        // Try HTTP API first
        if useHTTPAPI {
            do {
                try await setExitNodeViaHTTP(nodeID: nodeID)
                return
            } catch {
                useHTTPAPI = false
            }
        }
        
        // Fall back to CLI - use nodeName if provided, otherwise try nodeID
        let identifier = nodeName ?? nodeID
        try await setExitNodeViaCLI(identifier: identifier)
    }
    
    private func setExitNodeViaHTTP(nodeID: String?) async throws {
        guard let url = URL(string: "\(localAPIURL)/exit-node") else {
            throw TailscaleAPIError.invalidResponse
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = nodeID != nil ? ["id": nodeID!] : [:]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw TailscaleAPIError.commandFailed(message: "HTTP API returned error")
        }
    }
    
    private func setExitNodeViaCLI(identifier: String?) async throws {
        if let identifier = identifier, !identifier.isEmpty {
            // Set a specific exit node using hostname or DNS name
            _ = try await runTailscaleCommand(["set", "--exit-node", identifier])
        } else {
            // Disable exit node
            _ = try await runTailscaleCommand(["set", "--exit-node="])
        }
    }
    
    // MARK: - Private Helper
    
    private func runTailscaleCommand(_ args: [String]) async throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: tailscalePath)
        process.arguments = args
        
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        
        // Set environment to ensure proper execution
        var environment = ProcessInfo.processInfo.environment
        environment["PATH"] = "/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
        process.environment = environment
                
        // Check if the executable exists before trying to run it
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: tailscalePath) else {
            print("🔧 ERROR: Executable not found")
            throw TailscaleAPIError.commandFailed(message: "Tailscale executable not found at \(tailscalePath). Please ensure Tailscale is installed.")
        }
        
        // Check if executable is actually executable
        guard fileManager.isExecutableFile(atPath: tailscalePath) else {
            print("🔧 ERROR: File is not executable")
            throw TailscaleAPIError.commandFailed(message: "Tailscale file is not executable at \(tailscalePath)")
        }
        
        // Read output asynchronously to prevent pipe buffer overflow
        let outputData = NSMutableData()
        let errorData = NSMutableData()
        
        outputPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if !data.isEmpty {
                outputData.append(data)
            }
        }
        
        errorPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if !data.isEmpty {
                errorData.append(data)
            }
        }
        
        try process.run()
        
        // Wait for process to complete (this is async-safe in the background)
        return try await withCheckedThrowingContinuation { continuation in
            process.terminationHandler = { process in
                // Stop reading from pipes
                outputPipe.fileHandleForReading.readabilityHandler = nil
                errorPipe.fileHandleForReading.readabilityHandler = nil
                
                // Read any remaining data
                let remainingOutput = outputPipe.fileHandleForReading.readDataToEndOfFile()
                let remainingError = errorPipe.fileHandleForReading.readDataToEndOfFile()
                
                outputData.append(remainingOutput)
                errorData.append(remainingError)
                
                let output = String(data: outputData as Data, encoding: .utf8) ?? ""
                let errorOutput = String(data: errorData as Data, encoding: .utf8) ?? ""
                                
                if process.terminationStatus == 0 {
                    continuation.resume(returning: output)
                } else {
                    let message = errorOutput.isEmpty ? "Command failed with status \(process.terminationStatus)" : errorOutput
                    print("🔧 ERROR: \(message)")
                    continuation.resume(throwing: TailscaleAPIError.commandFailed(message: message))
                }
            }
        }
    }
}

// MARK: - Data Models

struct TailscaleStatus: Codable {
    let version: String?
    let backendState: String?
    let selfNode: SelfNode?
    let peer: [String: PeerNode]?
    let currentTailnet: CurrentTailnet?
    let user: [String: User]?
    
    // The ID of the current exit node (if any)
    var exitNodeID: String? {
        return peer?.values.first(where: { $0.exitNode == true })?.id
    }
    
    enum CodingKeys: String, CodingKey {
        case version = "Version"
        case backendState = "BackendState"
        case selfNode = "Self"
        case peer = "Peer"
        case currentTailnet = "CurrentTailnet"
        case user = "User"
    }
}

struct SelfNode: Codable {
    let id: String?
    let hostName: String?
    let dnsName: String?
    
    enum CodingKeys: String, CodingKey {
        case id = "ID"
        case hostName = "HostName"
        case dnsName = "DNSName"
    }
}

struct PeerNode: Codable {
    let id: String?
    let publicKey: String?
    let hostName: String?
    let dnsName: String?
    let os: String?
    let online: Bool?
    let exitNode: Bool?
    let exitNodeOption: Bool?
    let location: Location?
    
    enum CodingKeys: String, CodingKey {
        case id = "ID"
        case publicKey = "PublicKey"
        case hostName = "HostName"
        case dnsName = "DNSName"
        case os = "OS"
        case online = "Online"
        case exitNode = "ExitNode"
        case exitNodeOption = "ExitNodeOption"
        case location = "Location"
    }
}

struct Location: Codable, Hashable, Equatable {
    let country: String?
    let countryCode: String?
    let city: String?
    let cityCode: String?
    let latitude: Double?
    let longitude: Double?
    let priority: Int?
    
    var displayString: String? {
        if let city = city, let country = country {
            return "\(city), \(country)"
        } else if let country = country {
            return country
        }
        return nil
    }
    
    enum CodingKeys: String, CodingKey {
        case country = "Country"
        case countryCode = "CountryCode"
        case city = "City"
        case cityCode = "CityCode"
        case latitude = "Latitude"
        case longitude = "Longitude"
        case priority = "Priority"
    }
}

struct CurrentTailnet: Codable {
    let name: String?
    let magicDNSSuffix: String?
    
    enum CodingKeys: String, CodingKey {
        case name = "Name"
        case magicDNSSuffix = "MagicDNSSuffix"
    }
}

struct User: Codable {
    let id: Int?
    let loginName: String?
    let displayName: String?
    
    enum CodingKeys: String, CodingKey {
        case id = "ID"
        case loginName = "LoginName"
        case displayName = "DisplayName"
    }
}

// MARK: - Errors

enum TailscaleAPIError: LocalizedError {
    case invalidResponse
    case notRunning
    case connectionFailed
    case commandFailed(message: String)
    
    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from Tailscale"
        case .notRunning:
            return "Tailscale is not running"
        case .connectionFailed:
            return "Failed to connect to Tailscale. Please ensure Tailscale is running."
        case .commandFailed(let message):
            return "Tailscale command failed: \(message)"
        }
    }
}
