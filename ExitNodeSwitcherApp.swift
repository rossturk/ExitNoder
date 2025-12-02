//
//  ExitNodeSwitcherApp.swift
//  ExitNodeSwitcher
//
//  Created by Ross Turk on 12/1/25.
//

import SwiftUI
import SwiftData

@main
struct ExitNodeSwitcherApp: App {
    @State private var tailscaleService = TailscaleService()
    @State private var hasUpdatedHostnames = false
    
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            FavoriteExitNode.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()
    
    /// Development helper: Clear all favorites from the store
    private func clearAllFavorites() {
        let context = sharedModelContainer.mainContext
        
        do {
            let descriptor = FetchDescriptor<FavoriteExitNode>()
            let favorites = try context.fetch(descriptor)
            
            for favorite in favorites {
                context.delete(favorite)
            }
            
            try context.save()
            print("✅ All favorites cleared")
        } catch {
            print("❌ Error clearing favorites: \(error)")
        }
    }

    var body: some Scene {
        MenuBarExtra("Tailscale Exit Node", systemImage: "arrow.triangle.swap") {
            ContentView()
                .environment(tailscaleService)
                .task {
                    // One-time hostname update on first menu open
                    if !hasUpdatedHostnames {
                        await updateFavoritesWithHostnames()
                        hasUpdatedHostnames = true
                    }
                }
        }
        .modelContainer(sharedModelContainer)
                
        Window("Manage Favorites", id: "manage-favorites") {
            ManageFavoritesView()
                .environment(tailscaleService)
                .modelContainer(sharedModelContainer)
                .onAppear {
                    // Make window float on top
                    if let window = NSApplication.shared.windows.first(where: { $0.title == "Manage Favorites" }) {
                        window.level = .floating
                    }
                }
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 500, height: 600)
    }
    
    /// Updates old favorites that don't have hostnames set
    private func updateFavoritesWithHostnames() async {
        let context = sharedModelContainer.mainContext
        
        do {
            let descriptor = FetchDescriptor<FavoriteExitNode>()
            let favorites = try context.fetch(descriptor)
            
            // Check if any favorites are missing hostnames
            let needsUpdate = favorites.contains { $0.hostname == nil }
            
            guard needsUpdate else {
                return
            }
            
            // Load current exit nodes to get hostnames
            await tailscaleService.loadExitNodes()
            
            for favorite in favorites where favorite.hostname == nil {
                // Find matching node by ID
                if let node = tailscaleService.availableExitNodes.first(where: { $0.id == favorite.nodeID }) {
                    favorite.hostname = node.dnsName  // Use dnsName for CLI
                }
            }
            
            try context.save()
            
        } catch {
            print("⚠️ Error updating favorites: \(error)")
        }
    }
}
