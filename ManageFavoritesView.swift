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
    
    // Separate Mullvad locations from user's own tailnet nodes
    private var mullvadLocations: [LocationGroup] {
        groupedNodes.filter { $0.isMullvadLocation }
    }
    
    private var tailnetNodes: [ExitNode] {
        tailscaleService.availableExitNodes.filter { node in
            // Nodes without location data or non-Mullvad locations are user's own
            node.location == nil || !groupedNodes.contains(where: { $0.nodes.contains(node) && $0.isMullvadLocation })
        }
    }
    
    var body: some View {
        NavigationStack {
            FavoritesListView(
                favorites: favorites,
                mullvadLocations: mullvadLocations,
                tailnetNodes: tailnetNodes,
                onAddFavoriteGroup: addFavoriteGroup,
                onAddFavoriteNode: addFavoriteNode,
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
        
        withAnimation(nil) {
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
            try? modelContext.save()
        }
    }
    
    private func addFavoriteNode(_ node: ExitNode) {
        guard favorites.count < 15 else { return }
        
        withAnimation(nil) {
            let newFavorite = FavoriteExitNode(
                name: node.displayName,
                nodeID: node.id,
                hostname: node.dnsName,
                order: favorites.count,
                isLocationGroup: false,
                locationKey: node.locationKey,
                nodeIDs: [node.id]
            )
            modelContext.insert(newFavorite)
            try? modelContext.save()
        }
    }
    
    private func deleteFavorite(_ favorite: FavoriteExitNode) {
        withAnimation(nil) {
            modelContext.delete(favorite)
            
            // Reorder remaining favorites
            let remaining = favorites.filter { $0.id != favorite.id }
            for (index, fav) in remaining.enumerated() {
                fav.order = index
            }
            try? modelContext.save()
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
    
    /// Check if this is a Mullvad location (has valid coordinates and location data)
    var isMullvadLocation: Bool {
        location.latitude != nil && location.longitude != nil
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

struct CountryGroup: Identifiable {
    let id: String
    let country: String
    let locations: [LocationGroup]
    
    init(country: String, locations: [LocationGroup]) {
        self.id = country
        self.country = country
        self.locations = locations
    }
}

struct FavoritesListView: View {
    let favorites: [FavoriteExitNode]
    let mullvadLocations: [LocationGroup]
    let tailnetNodes: [ExitNode]
    let onAddFavoriteGroup: (LocationGroup) -> Void
    let onAddFavoriteNode: (ExitNode) -> Void
    let onDeleteFavorite: ((FavoriteExitNode) -> Void)?
    
    @State private var expandedCountries: Set<String> = []
    
    // Group Mullvad locations by country
    private var mullvadByCountry: [CountryGroup] {
        let grouped = Dictionary(grouping: mullvadLocations) { $0.countryCode }
        return grouped.map { CountryGroup(country: $0.key, locations: $0.value.sorted { $0.displayName < $1.displayName }) }
            .sorted { $0.country < $1.country }
    }
    
    // Check if a location is already favorited
    private func isLocationFavorited(_ group: LocationGroup) -> Bool {
        favorites.contains(where: { $0.locationKey == group.locationKey })
    }
    
    // Check if a node is already favorited
    private func isNodeFavorited(_ node: ExitNode) -> Bool {
        favorites.contains(where: { $0.nodeID == node.id })
    }
    
    // Get the favorite for a location group
    private func getFavorite(for group: LocationGroup) -> FavoriteExitNode? {
        favorites.first(where: { $0.locationKey == group.locationKey })
    }
    
    // Get the favorite for a node
    private func getFavorite(for node: ExitNode) -> FavoriteExitNode? {
        favorites.first(where: { $0.nodeID == node.id })
    }
    
    private var favoriteCount: Int {
        favorites.count
    }
    
    // Convert country code to flag emoji
    private func countryFlag(for countryCode: String) -> String {
        let base: UInt32 = 127397
        var emoji = ""
        for scalar in countryCode.uppercased().unicodeScalars {
            if let scalarValue = UnicodeScalar(base + scalar.value) {
                emoji.append(String(scalarValue))
            }
        }
        return emoji
    }
    
    var body: some View {
        List {
            // Your Tailnet Section (at the top)
            if !tailnetNodes.isEmpty {
                Section {
                    ForEach(tailnetNodes) { node in
                        NodeRow(
                            node: node,
                            isFavorited: isNodeFavorited(node),
                            favoriteCount: favoriteCount,
                            onAdd: {
                                onAddFavoriteNode(node)
                            },
                            onRemove: {
                                if let favorite = getFavorite(for: node) {
                                    onDeleteFavorite?(favorite)
                                }
                            }
                        )
                    }
                } header: {
                    Text("Your Tailnet")
                }
            }
            
            // Mullvad Countries List
            if !mullvadLocations.isEmpty {
                Section {
                    ForEach(mullvadByCountry) { countryGroup in
                        if countryGroup.locations.count == 1 {
                            // Single location - show directly without disclosure group
                            if let location = countryGroup.locations.first {
                                LocationRow(
                                    location: location,
                                    isFavorited: isLocationFavorited(location),
                                    favoriteCount: favoriteCount,
                                    onAdd: {
                                        onAddFavoriteGroup(location)
                                    },
                                    onRemove: {
                                        if let favorite = getFavorite(for: location) {
                                            onDeleteFavorite?(favorite)
                                        }
                                    }
                                )
                            }
                        } else {
                            // Multiple locations - use disclosure group with manual state
                            DisclosureGroup(
                                isExpanded: Binding(
                                    get: { expandedCountries.contains(countryGroup.id) },
                                    set: { isExpanded in
                                        if isExpanded {
                                            expandedCountries.insert(countryGroup.id)
                                        } else {
                                            expandedCountries.remove(countryGroup.id)
                                        }
                                    }
                                )
                            ) {
                                ForEach(countryGroup.locations) { location in
                                    LocationRow(
                                        location: location,
                                        isFavorited: isLocationFavorited(location),
                                        favoriteCount: favoriteCount,
                                        onAdd: {
                                            onAddFavoriteGroup(location)
                                        },
                                        onRemove: {
                                            if let favorite = getFavorite(for: location) {
                                                onDeleteFavorite?(favorite)
                                            }
                                        }
                                    )
                                }
                            } label: {
                                HStack {
                                    Text(countryFlag(for: countryGroup.country))
                                    Text(countryGroup.country)
                                        .font(.headline)
                                    Spacer()
                                    Text("\(countryGroup.locations.count) \(countryGroup.locations.count == 1 ? "city" : "cities")")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                } header: {
                    Text("Mullvad VPN")
                }
            }
        }
        .listStyle(.inset)
        .transaction { transaction in
            transaction.animation = nil
        }
    }
}

// MARK: - Location Row

struct LocationRow: View {
    let location: LocationGroup
    let isFavorited: Bool
    let favoriteCount: Int
    let onAdd: () -> Void
    let onRemove: () -> Void
    
    // Convert country code to flag emoji
    private var countryFlag: String {
        let base: UInt32 = 127397
        var emoji = ""
        for scalar in location.countryCode.uppercased().unicodeScalars {
            if let scalarValue = UnicodeScalar(base + scalar.value) {
                emoji.append(String(scalarValue))
            }
        }
        return emoji
    }
    
    // Format location name to show just the city
    private var formattedLocationName: String {
        // Use the city name from the location if available
        if let city = location.location.city {
            return city
        }
        
        // Otherwise parse from displayName (typically "City, Country")
        let components = location.displayName.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        if let cityName = components.first {
            return cityName
        }
        
        return location.displayName
    }
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(countryFlag)
                        .font(.body)
                    Text(formattedLocationName)
                        .font(.body)
                }
                
                HStack(spacing: 4) {
                    Image(systemName: location.hasMultipleNodes ? "server.rack" : "server.rack")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    
                    Text("\(location.nodes.count) server\(location.nodes.count == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
            
            if isFavorited {
                Button(action: onRemove) {
                    Image(systemName: "star.fill")
                        .foregroundStyle(.yellow)
                }
                .buttonStyle(.plain)
                .help("Remove from favorites")
            } else {
                Button(action: onAdd) {
                    Image(systemName: "star")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .disabled(favoriteCount >= 15)
                .help(favoriteCount >= 15 ? "Maximum 15 favorites reached" : "Add to favorites")
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Node Row

struct NodeRow: View {
    let node: ExitNode
    let isFavorited: Bool
    let favoriteCount: Int
    let onAdd: () -> Void
    let onRemove: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(node.name)
                    .font(.body)
                
                HStack(spacing: 4) {
                    Image(systemName: "server.rack")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    
                    Text(node.dnsName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
            
            if isFavorited {
                Button(action: onRemove) {
                    Image(systemName: "star.fill")
                        .foregroundStyle(.yellow)
                }
                .buttonStyle(.plain)
                .help("Remove from favorites")
            } else {
                Button(action: onAdd) {
                    Image(systemName: "star")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .disabled(favoriteCount >= 15)
                .help(favoriteCount >= 15 ? "Maximum 15 favorites reached" : "Add to favorites")
            }
        }
        .padding(.vertical, 4)
    }
}

