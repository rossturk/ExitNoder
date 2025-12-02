//
//  ManageFavoritesView.swift
//  ExitNodeSwitcher
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
    
    @State private var showMap = false
    
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
            VStack(spacing: 0) {
                // Toggle between list and map view
                Picker("View Mode", selection: $showMap) {
                    Label("List", systemImage: "list.bullet").tag(false)
                    Label("Map", systemImage: "map").tag(true)
                }
                .pickerStyle(.segmented)
                .padding()
                
                if showMap {
                    FavoritesMapView(
                        favorites: favorites,
                        groupedNodes: groupedNodes,
                        onAddFavoriteGroup: addFavoriteGroup
                    )
                } else {
                    FavoritesListView(
                        favorites: favorites,
                        groupedNodes: groupedNodes,
                        isLoading: tailscaleService.isLoading,
                        onAddFavoriteGroup: addFavoriteGroup,
                        onDeleteFavorite: deleteFavorite
                    )
                }
            }
            .navigationTitle("Manage Favorites")
            .frame(minWidth: 500, minHeight: 600)
        }
        .task {
            await tailscaleService.loadExitNodes()
        }
    }
    
    private func addFavoriteGroup(_ group: LocationGroup) {
        guard favorites.count < 3 else { return }
        
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

// MARK: - List View

struct FavoritesListView: View {
    let favorites: [FavoriteExitNode]
    let groupedNodes: [LocationGroup]
    let isLoading: Bool
    let onAddFavoriteGroup: (LocationGroup) -> Void
    let onDeleteFavorite: (FavoriteExitNode) -> Void
    
    var body: some View {
        List {
            Section {
                if favorites.isEmpty {
                    Text("No favorites yet. Add up to 3 locations as favorites.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(favorites) { favorite in
                        HStack {
                            Image(systemName: favorite.isLocationGroup ? "building.2.fill" : "star.fill")
                                .foregroundStyle(.yellow)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(favorite.name)
                                
                                if favorite.isLocationGroup {
                                    Text("\(favorite.nodeIDs.count) servers • Round-robin")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            
                            Spacer()
                            Button(action: {
                                onDeleteFavorite(favorite)
                            }) {
                                Image(systemName: "trash")
                                    .foregroundStyle(.red)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            } header: {
                Text("Current Favorites (\(favorites.count)/3)")
            }
            
            if favorites.count < 3 {
                Section("Available Locations") {
                    if isLoading {
                        HStack {
                            ProgressView()
                            Text("Loading exit nodes...")
                        }
                    } else {
                        // Show all locations (grouped)
                        ForEach(groupedNodes) { group in
                            LocationGroupRow(
                                group: group,
                                isFavorited: favorites.contains(where: { $0.locationKey == group.locationKey }),
                                onAddGroup: onAddFavoriteGroup
                            )
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Map View

struct FavoritesMapView: View {
    let favorites: [FavoriteExitNode]
    let groupedNodes: [LocationGroup]
    let onAddFavoriteGroup: (LocationGroup) -> Void
    
    @State private var position: MapCameraPosition = .automatic
    @State private var selectedGroup: LocationGroup?
    
    // Check if a location is already favorited
    private func isLocationFavorited(_ group: LocationGroup) -> Bool {
        favorites.contains(where: { $0.locationKey == group.locationKey })
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
                            Text("Already in favorites")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } else if favoriteCount >= 3 {
                        Text("Maximum 3 favorites reached")
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

// MARK: - Location Group Row

struct LocationGroupRow: View {
    let group: LocationGroup
    let isFavorited: Bool
    let onAddGroup: (LocationGroup) -> Void
    
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(group.displayName)
                            .font(.headline)
                        
                        if isFavorited {
                            Image(systemName: "star.fill")
                                .font(.caption)
                                .foregroundStyle(.yellow)
                        }
                    }
                    
                    Text("\(group.nodes.count) server\(group.nodes.count == 1 ? "" : "s")\(group.hasMultipleNodes ? " • Round-robin" : "")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                // Expand/collapse button
                Button(action: {
                    isExpanded.toggle()
                }) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                
                // Add button (disabled if already favorited)
                Button(action: {
                    onAddGroup(group)
                }) {
                    HStack(spacing: 4) {
                        if group.hasMultipleNodes {
                            Image(systemName: "building.2")
                        }
                        Image(systemName: "plus.circle.fill")
                    }
                    .foregroundStyle(isFavorited ? .gray : .blue)
                }
                .buttonStyle(.plain)
                .disabled(isFavorited)
                .help(isFavorited ? "Already in favorites" : (group.hasMultipleNodes ? "Add location with round-robin" : "Add single server"))
            }
            
            // Show individual nodes when expanded
            if isExpanded {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(group.nodes) { node in
                        HStack(spacing: 8) {
                            Image(systemName: "circle.fill")
                                .font(.system(size: 6))
                                .foregroundStyle(.secondary)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(node.name)
                                    .font(.subheadline)
                                
                                if let location = node.location {
                                    if let city = location.city, let country = location.country {
                                        Text("\(city), \(country)")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                            
                            Spacer()
                        }
                        .padding(.leading, 20)
                        .padding(.vertical, 2)
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding(.vertical, 4)
    }
}
