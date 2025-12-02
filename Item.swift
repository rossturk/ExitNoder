//
//  Item.swift
//  ExitNoder
//
//  Created by Ross Turk on 12/1/25.
//

import Foundation
import SwiftData

@Model
final class FavoriteExitNode {
    var name: String  // Display name (e.g., "hostname (City, Country)" or location group)
    var nodeID: String  // Internal Tailscale ID (for HTTP API) - or group key for location groups
    var hostname: String?  // DNS name (for CLI fallback) - optional for migration
    var order: Int
    var isLocationGroup: Bool  // True if this is a location group with multiple nodes
    var locationKey: String?  // Key for location grouping (e.g., "US-NYC")
    var nodeIDs: [String]  // Array of node IDs for location groups
    var currentNodeIndex: Int  // Index for round-robin rotation
    
    init(name: String, nodeID: String, hostname: String? = nil, order: Int = 0, isLocationGroup: Bool = false, locationKey: String? = nil, nodeIDs: [String] = [], currentNodeIndex: Int = 0) {
        self.name = name
        self.nodeID = nodeID
        self.hostname = hostname
        self.order = order
        self.isLocationGroup = isLocationGroup
        self.locationKey = locationKey
        self.nodeIDs = nodeIDs.isEmpty ? [nodeID] : nodeIDs
        self.currentNodeIndex = currentNodeIndex
    }
    
    /// Returns the DNS name for CLI usage, falling back to nodeID if not set
    var hostnameOrFallback: String {
        return hostname ?? nodeID
    }
    
    /// Get the next node ID for round-robin (if this is a location group)
    func getNextNodeID() -> String {
        guard isLocationGroup, !nodeIDs.isEmpty else {
            return nodeID
        }
        
        let nextID = nodeIDs[currentNodeIndex]
        currentNodeIndex = (currentNodeIndex + 1) % nodeIDs.count
        return nextID
    }
}
