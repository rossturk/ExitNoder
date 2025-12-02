//
//  ManageFavoritesView.swift
//  ExitNoder
//
//  Created by Ross Turk on 12/2/25.
//

import SwiftUI
import SwiftData
import MapKit

struct ManageFavoritesView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(TailscaleService.self) private var tailscaleService
    @Query(sort: \FavoriteExitNode.order) private var favorites: [FavoriteExitNode]
    
    // Group exit nodes by location
    private var groupedNodes: [LocationGroup] {
        var groups: [String: LocationGroup] = [:]
        
        for node in tailscaleService.availableExitNodes {
            if let locationKey = node.locationKey,
               let location = node.location,
               let cityCode = location.cityCode,
               let countryCode = location.countryCode {
                
                if groups[locationKey] == nil {
                    groups[locationKey] = LocationGroup(
                        cityCode: cityCode,
                        countryCode: countryCode,
                        displayName: location.displayString ?? locationKey,
                        location: location,
                        nodes: []
                    )
                }
                groups[locationKey]?.nodes.append(node)
            }
        }
        
        return groups.values.sorted { $0.displayName < $1.displayName }
    }
    
    var body: some View {
        NavigationStack {
            FavoritesMapView(
                favorites: favorites,
                groupedNodes: groupedNodes,
                onAddFavoriteGroup: addFavoriteGroup,
                onDeleteFavorite: deleteFavorite
            )
            .navigationTitle("ExitNoder Locations")
            .frame(minWidth: 500, minHeight: 600)
        }
        .task {
            await tailscaleService.loadExitNodes()
        }
    }
    
    private func addFavoriteGroup(_ group: LocationGroup) {
        guard favorites.count < 15 else { return }
        
        let newFavorite = FavoriteExitNode(
            name: group.displayName,
            nodeID: group.nodes.first?.id ?? "",
            hostname: group.nodes.first?.dnsName,
            order: favorites.count,
            isLocationGroup: group.hasMultipleNodes,
            locationKey: "\(group.countryCode)-\(group.cityCode)",
            nodeIDs: group.nodes.map { $0.id }
        )
        modelContext.insert(newFavorite)
    }
    
    private func deleteFavorite(_ favorite: FavoriteExitNode) {
        modelContext.delete(favorite)
        
        // Reorder remaining favorites
        let remaining = favorites.filter { $0.id != favorite.id }
        for (index, fav) in remaining.enumerated() {
            fav.order = index
        }
    }
}

// MARK: - Location Group Model

struct LocationGroup: Identifiable, Hashable {
    let id = UUID()
    let cityCode: String
    let countryCode: String
    let displayName: String
    let location: Location
    var nodes: [ExitNode]
    
    var hasMultipleNodes: Bool {
        nodes.count > 1
    }
    
    var locationKey: String {
        "\(countryCode)-\(cityCode)"
    }
    
    // Implement Hashable manually
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: LocationGroup, rhs: LocationGroup) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Map View

struct FavoritesMapView: View {
    let favorites: [FavoriteExitNode]
    let groupedNodes: [LocationGroup]
    let onAddFavoriteGroup: (LocationGroup) -> Void
    let onDeleteFavorite: ((FavoriteExitNode) -> Void)?
    
    @State private var position: MapCameraPosition = .automatic
    @State private var selectedGroup: LocationGroup?
    
    // Check if a location is already favorited
    private func isLocationFavorited(_ group: LocationGroup) -> Bool {
        favorites.contains(where: { $0.locationKey == group.locationKey })
    }
    
    // Get the favorite for a location group
    private func getFavorite(for group: LocationGroup) -> FavoriteExitNode? {
        favorites.first(where: { $0.locationKey == group.locationKey })
    }
    
    // Get the favorite count (for display)
    private var favoriteCount: Int {
        favorites.count
    }
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            Map(position: $position, selection: $selectedGroup) {
                ForEach(groupedNodes) { group in
                    if let lat = group.location.latitude,
                       let lon = group.location.longitude {
                        
                        Annotation(group.displayName, coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon)) {
                            Button(action: {
                                selectedGroup = group
                            }) {
                                VStack(spacing: 4) {
                                    ZStack {
                                        Circle()
                                            .fill(isLocationFavorited(group) ? Color.yellow : Color.blue)
                                            .frame(width: 36, height: 36)
                                        
                                        if group.hasMultipleNodes {
                                            Text("\(group.nodes.count)")
                                                .font(.caption)
                                                .fontWeight(.bold)
                                                .foregroundStyle(.white)
                                        } else {
                                            Image(systemName: "server.rack")
                                                .foregroundStyle(.white)
                                                .font(.caption)
                                        }
                                    }
                                    .shadow(radius: 4)
                                    
                                    Text(group.displayName)
                                        .font(.caption2)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 4))
                                }
                            }
                            .buttonStyle(.plain)
                            .tag(group)
                        }
                    }
                }
            }
            .mapStyle(.standard(elevation: .realistic))
            
            // Info panel when location is selected
            if let group = selectedGroup {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(group.displayName)
                                .font(.headline)
                            Text("\(group.nodes.count) server\(group.nodes.count == 1 ? "" : "s")")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        Spacer()
                        
                        Button(action: {
                            selectedGroup = nil
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                    
                    if isLocationFavorited(group) {
                        HStack {
                            Image(systemName: "star.fill")
                                .foregroundStyle(.yellow)
                            Text("In favorites")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            
                            Spacer()
                        }
                        
                        Button(action: {
                            if let favorite = getFavorite(for: group) {
                                onDeleteFavorite?(favorite)
                                selectedGroup = nil
                            }
                        }) {
                            Label("Remove from Favorites", systemImage: "trash")
                                .font(.subheadline)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.red, in: RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(.plain)
                    } else if favoriteCount >= 15 {
                        Text("Maximum 15 favorites reached")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Button(action: {
                            onAddFavoriteGroup(group)
                            selectedGroup = nil
                        }) {
                            Label("Add to Favorites", systemImage: "star.fill")
                                .font(.subheadline)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.blue, in: RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(.plain)
                        
                        if group.hasMultipleNodes {
                            Text("Round-robin across all servers")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding()
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                .shadow(radius: 8)
                .padding()
            }
        }
    }
}

