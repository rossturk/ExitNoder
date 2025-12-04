//
//  TailscaleService.swift
//  ExitNoder
//
//  Created by Ross Turk on 12/1/25.
//

import Foundation
import Observation

struct ExitNode: Identifiable, Hashable {
    let id: String
    let name: String  // Short hostname for display
    let dnsName: String  // Full DNS name for CLI
    let location: Location?  // Full location object with coordinates
    
    var displayName: String {
        if let locationString = location?.displayString {
            return "\(name) (\(locationString))"
        }
        return name
    }
    
    var locationKey: String? {
        guard let location = location,
              let cityCode = location.cityCode,
              let countryCode = location.countryCode else {
            return nil
        }
        return "\(countryCode)-\(cityCode)"
    }
}

@MainActor
@Observable
class TailscaleService {
    var availableExitNodes: [ExitNode] = []
    var currentExitNode: String? = nil
    var isLoading = false
    var errorMessage: String? = nil
    
    private let api = TailscaleLocalAPI()
    
    func loadExitNodes() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let status = try await api.getStatus()
            
            // Extract exit nodes
            let nodes = extractExitNodes(from: status)
            availableExitNodes = nodes
            
            // Get current exit node
            currentExitNode = status.exitNodeID
        } catch let error as TailscaleAPIError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = "Failed to connect to Tailscale. Please ensure the standalone version is installed and running."
        }
        
        isLoading = false
    }
    
    func setExitNode(_ nodeID: String?, nodeName: String? = nil) async {
        isLoading = true
        errorMessage = nil
        
        do {
            try await api.setExitNode(nodeID: nodeID, nodeName: nodeName)
            
            // Refresh status to get the updated exit node
            let status = try await api.getStatus()
            currentExitNode = status.exitNodeID
        } catch let error as TailscaleAPIError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = "Failed to set exit node. Please ensure the standalone version of Tailscale is installed and running."
        }
        
        isLoading = false
    }
    
    // MARK: - Private Helpers
    
    private func extractExitNodes(from status: TailscaleStatus) -> [ExitNode] {
        guard let peers = status.peer else {
            return []
        }
        
        var nodes: [ExitNode] = []
        
        for (_, peer) in peers {
            // Only include nodes that are available as exit nodes
            guard let exitNodeOption = peer.exitNodeOption,
                  exitNodeOption,
                  let id = peer.id,
                  let hostName = peer.hostName,
                  let dnsName = peer.dnsName else {
                continue
            }
            
            nodes.append(ExitNode(
                id: id,
                name: hostName,
                dnsName: dnsName,
                location: peer.location
            ))
        }
        
        return nodes.sorted { $0.name < $1.name }
    }
}
