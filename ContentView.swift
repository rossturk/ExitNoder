//
//  ContentView.swift
//  ExitNoder
//
//  Created by Ross Turk on 12/1/25.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(TailscaleService.self) private var tailscaleService
    @Environment(\.openWindow) private var openWindow
    @Query(sort: \FavoriteExitNode.order) private var favorites: [FavoriteExitNode]
    
    var body: some View {
        VStack(spacing: 0) {
            // Error message if present
            if let errorMessage = tailscaleService.errorMessage {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Connection Error", systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                        .font(.headline)
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.orange.opacity(0.1))
                
                Divider()
            }
            
            // Turn Off Exit Node
            Button {
                Task { @MainActor in
                    await tailscaleService.setExitNode(nil)
                }
            } label: {
                HStack {
                    Label("Disable Exit Nodes", systemImage: "xmark.circle")
                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .keyboardShortcut("0", modifiers: .command)
            .disabled(tailscaleService.currentExitNode == nil)
            
            Divider()
                        
            // Favorites Section
            if !favorites.isEmpty {
                ForEach(Array(favorites.enumerated()), id: \.element.id) { index, favorite in
                    favoriteButton(for: favorite, at: index)
                }
                
                Divider()
            }

            // Settings
            Button {
                Task {
                    await tailscaleService.loadExitNodes()
                }
                openWindow(id: "manage-favorites")
            } label: {
                HStack {
                    Label("Favorites…", systemImage: "star")
                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .keyboardShortcut(",", modifiers: .command)
            
            Divider()
            
            // Quit
            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                HStack {
                    Text("Quit")
                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .keyboardShortcut("q", modifiers: .command)
        }
        .frame(width: 280)
        .task {
            await tailscaleService.loadExitNodes()
        }
    }
    
    // Extract favorite button to prevent menu index issues
    @ViewBuilder
    private func favoriteButton(for favorite: FavoriteExitNode, at index: Int) -> some View {
        Button {
            Task { @MainActor in
                // Check if this favorite is currently active
                let isActive = favorite.isLocationGroup 
                    ? favorite.nodeIDs.contains(tailscaleService.currentExitNode ?? "")
                    : tailscaleService.currentExitNode == favorite.nodeID
                
                if isActive {
                    // If already active, disable exit nodes
                    await tailscaleService.setExitNode(nil)
                } else {
                    // If not active, activate it
                    if favorite.isLocationGroup {
                        // Round-robin: get next node in the group
                        let nextNodeID = favorite.getNextNodeID()
                        
                        // Find the corresponding node to get its hostname
                        if let node = tailscaleService.availableExitNodes.first(where: { $0.id == nextNodeID }) {
                            await tailscaleService.setExitNode(nextNodeID, nodeName: node.dnsName)
                        } else {
                            await tailscaleService.setExitNode(nextNodeID, nodeName: nil)
                        }
                    } else {
                        // Single node: use as before
                        await tailscaleService.setExitNode(favorite.nodeID, nodeName: favorite.hostnameOrFallback)
                    }
                }
            }
        } label: {
            HStack {
                // Status icon if this is the current exit node
                let isActive = favorite.isLocationGroup 
                    ? favorite.nodeIDs.contains(tailscaleService.currentExitNode ?? "")
                    : tailscaleService.currentExitNode == favorite.nodeID
                
                if isActive {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                } else {
                    Image(systemName: favorite.isLocationGroup ? "building.2" : "circle")
                        .foregroundStyle(.secondary)
                }
                
                Text(favorite.name)
                
                if favorite.isLocationGroup {
                    Text("(\(favorite.nodeIDs.count))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .keyboardShortcut(KeyEquivalent(Character("\(index + 1)")), modifiers: .command)
    }
}

#Preview {
    ContentView()
        .environment(TailscaleService())
        .modelContainer(for: FavoriteExitNode.self, inMemory: true)
}
