//
//  TailscaleLocalAPI.swift
//  ExitNoder
//
//  Communicates with Tailscale's local API server
//

import Foundation
import Network

/// Handles communication with Tailscale's local API
class TailscaleLocalAPI {
    
    // Tailscale's local API listens on localhost:41641
    private let apiURL = "http://localhost:41641"
    private let session: URLSession
    
    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        self.session = URLSession(configuration: config)
    }
    
    // MARK: - API Methods
    
    /// Get the current Tailscale status
    func getStatus() async throws -> TailscaleStatus {
        let url = URL(string: "\(apiURL)/localapi/v0/status")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw TailscaleAPIError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw TailscaleAPIError.httpError(statusCode: httpResponse.statusCode)
        }
        
        let decoder = JSONDecoder()
        return try decoder.decode(TailscaleStatus.self, from: data)
    }
    
    /// Set the exit node
    func setExitNode(nodeID: String?) async throws {
        let url = URL(string: "\(apiURL)/localapi/v0/prefs")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Create the preferences update
        let prefs: [String: Any] = [
            "ExitNodeID": nodeID ?? ""
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: prefs)
        
        let (_, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw TailscaleAPIError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw TailscaleAPIError.httpError(statusCode: httpResponse.statusCode)
        }
    }
}

// MARK: - Data Models

struct TailscaleStatus: Codable {
    let version: String?
    let backendState: String?
    let self: SelfNode?
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
        case self = "Self"
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

struct Location: Codable {
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
    case httpError(statusCode: Int)
    case notRunning
    case connectionFailed
    
    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from Tailscale"
        case .httpError(let code):
            return "HTTP error \(code) from Tailscale"
        case .notRunning:
            return "Tailscale is not running"
        case .connectionFailed:
            return "Failed to connect to Tailscale. Please ensure Tailscale is running."
        }
    }
}
