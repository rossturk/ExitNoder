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
    let name: String
    let location: String?
    
    var displayName: String {
        if let location = location {
            return "\(name) (\(location))"
        }
        return name
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
        print("🔵 loadExitNodes() called")
        isLoading = true
        errorMessage = nil
        
        do {
            print("🔵 Fetching status from Tailscale Local API...")
            let status = try await api.getStatus()
            
            // Extract exit nodes
            let nodes = extractExitNodes(from: status)
            availableExitNodes = nodes
            print("🔵 Found \(nodes.count) exit nodes")
            
            // Get current exit node
            currentExitNode = status.exitNodeID
            print("🔵 Current exit node: \(currentExitNode ?? "none")")
        } catch let error as TailscaleAPIError {
            print("🔵 Tailscale API error: \(error)")
            errorMessage = error.localizedDescription
        } catch {
            print("🔵 Error loading exit nodes: \(error)")
            errorMessage = "Failed to connect to Tailscale. Please ensure Tailscale is running and accessible."
        }
        
        isLoading = false
        print("🔵 loadExitNodes() finished")
    }
    
    func setExitNode(_ nodeID: String?) async {
        print("🟢 setExitNode() called with nodeID: \(nodeID ?? "nil")")
        isLoading = true
        errorMessage = nil
        
        do {
            print("🟢 Setting exit node via Local API...")
            try await api.setExitNode(nodeID: nodeID)
            
            // Refresh status to get the updated exit node
            let status = try await api.getStatus()
            currentExitNode = status.exitNodeID
            
            print("🟢 Successfully set exit node. Current: \(currentExitNode ?? "none")")
        } catch let error as TailscaleAPIError {
            print("🟢 Tailscale API error: \(error)")
            errorMessage = error.localizedDescription
        } catch {
            print("🟢 Error setting exit node: \(error)")
            errorMessage = "Failed to set exit node. Please ensure Tailscale is running."
        }
        
        isLoading = false
        print("🟢 setExitNode() finished")
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
                  let hostName = peer.hostName else {
                continue
            }
            
            let locationString = peer.location?.displayString
            
            nodes.append(ExitNode(
                id: id,
                name: hostName,
                location: locationString
            ))
        }
        
        return nodes.sorted { $0.name < $1.name }
    }
}
