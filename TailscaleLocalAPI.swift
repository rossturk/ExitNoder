//
//  TailscaleLocalAPI.swift
//  ExitNoder
//
//  Communicates with Tailscale via local API
//

import Foundation
import os.log

private let logger = Logger(subsystem: "us.rtrk.ExitNoder", category: "TailscaleAPI")

/// Handles communication with Tailscale via local API
class TailscaleLocalAPI {

    private let tailscaleDir = "/Library/Tailscale"

    init() {}

    // MARK: - API Methods

    /// Get the current Tailscale status
    func getStatus() async throws -> TailscaleStatus {
        let data = try await sendRequest(method: "GET", path: "/localapi/v0/status")
        let decoder = JSONDecoder()
        return try decoder.decode(TailscaleStatus.self, from: data)
    }

    /// Set the exit node
    /// - Parameters:
    ///   - nodeID: The node ID to set as exit node, or nil to disable
    ///   - nodeName: Unused, kept for API compatibility
    func setExitNode(nodeID: String?, nodeName: String? = nil) async throws {
        var body: [String: Any] = [:]
        if let nodeID = nodeID {
            body["id"] = nodeID
        }

        let bodyData = try JSONSerialization.data(withJSONObject: body)
        _ = try await sendRequest(method: "POST", path: "/localapi/v0/exit-node", body: bodyData)
    }

    // MARK: - Local API Communication

    private struct LocalAPICredentials {
        let port: Int
        let password: String
    }

    private func getLocalAPICredentials() throws -> LocalAPICredentials {
        let fileManager = FileManager.default
        let portFilePath = "\(tailscaleDir)/ipnport"

        // Read the symlink target (which is the port number)
        // Note: fileExists returns false for "broken" symlinks, so we try to read directly
        let portString: String
        do {
            portString = try fileManager.destinationOfSymbolicLink(atPath: portFilePath)
            logger.info("Read port from symlink: \(portString)")
        } catch {
            logger.error("Failed to read symlink at \(portFilePath): \(error.localizedDescription)")
            throw TailscaleAPIError.notRunning
        }

        guard let port = Int(portString) else {
            logger.error("Port string is not a valid integer: \(portString)")
            throw TailscaleAPIError.invalidResponse
        }

        // Read the sameuserproof password
        let passwordFilePath = "\(tailscaleDir)/sameuserproof-\(port)"
        logger.info("Reading password from: \(passwordFilePath)")

        guard let passwordData = fileManager.contents(atPath: passwordFilePath) else {
            logger.error("Failed to read password file (nil data). Check file permissions.")
            throw TailscaleAPIError.notRunning
        }

        guard let password = String(data: passwordData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) else {
            logger.error("Failed to decode password as UTF-8")
            throw TailscaleAPIError.notRunning
        }

        logger.info("Successfully read credentials for port \(port)")
        return LocalAPICredentials(port: port, password: password)
    }

    private func sendRequest(method: String, path: String, body: Data? = nil) async throws -> Data {
        let credentials = try getLocalAPICredentials()

        guard let url = URL(string: "http://127.0.0.1:\(credentials.port)\(path)") else {
            throw TailscaleAPIError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 10

        // Add Basic Auth header (empty username, password from sameuserproof)
        let authString = ":\(credentials.password)"
        if let authData = authString.data(using: .utf8) {
            let base64Auth = authData.base64EncodedString()
            request.setValue("Basic \(base64Auth)", forHTTPHeaderField: "Authorization")
        }

        if let body = body {
            request.httpBody = body
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw TailscaleAPIError.invalidResponse
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                logger.error("HTTP error: \(httpResponse.statusCode)")
                throw TailscaleAPIError.connectionFailed
            }

            return data
        } catch let error as TailscaleAPIError {
            throw error
        } catch let urlError as URLError {
            logger.error("URL error: \(urlError.localizedDescription)")
            throw TailscaleAPIError.connectionFailed
        } catch {
            logger.error("Unexpected error: \(error.localizedDescription)")
            throw TailscaleAPIError.connectionFailed
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
            return "Tailscale is not running. Please ensure the standalone version is installed and running."
        case .connectionFailed:
            return "Failed to connect to Tailscale"
        case .commandFailed(let message):
            return "Tailscale command failed: \(message)"
        }
    }
}
