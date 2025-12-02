# Location Features & Map View

## Overview

The Manage Favorites page now includes advanced location features:

1. **Map View** - Visual representation of all exit nodes on an interactive map
2. **Location Grouping** - Exit nodes in the same city are grouped together
3. **Round-Robin Support** - Favorite a location group to rotate through all servers

---

## Data Available

From Tailscale's API, each exit node includes rich location data:

```swift
struct Location: Codable {
    let country: String?          // e.g., "United States"
    let countryCode: String?      // e.g., "US"
    let city: String?             // e.g., "New York"
    let cityCode: String?         // e.g., "NYC"
    let latitude: Double?         // 40.7128
    let longitude: Double?        // -74.0060
    let priority: Int?
}
```

---

## Features

### 1. Map View

Toggle between List and Map views using the segmented control at the top.

**Map View displays:**
- All exit node locations with pins
- Number badge for locations with multiple servers
- Server icon for single-server locations
- Location name labels
- Realistic 3D terrain

### 2. Location Grouping

Exit nodes are automatically grouped by `cityCode` and `countryCode`.

**Example:**
- `US-NYC` → Groups all New York servers together
- `UK-LON` → Groups all London servers together

### 3. Round-Robin Favorites

When adding a location with multiple servers, you have two options:

#### Option A: Add Location Group (Blue Building Icon)
- Favorites the entire location
- Each time you select it, cycles to the next server
- Shows `(3)` badge indicating 3 servers in rotation
- Icon: 🏢 (building.2)

#### Option B: Add Single Server (Green Plus Icon)
- Favorites just one specific server
- Always connects to that server
- Icon: ➕ (plus.circle.fill)

---

## User Interface

### List View

```
Current Favorites (2/3)
┌────────────────────────────────┐
│ 🏢 New York, USA (3)           │ ← Location group
│    3 servers • Round-robin     │
│ ⭐ lon-server-1 (London, UK)   │ ← Single server
└────────────────────────────────┘

Add Favorite
┌────────────────────────────────┐
│ San Francisco, USA             │
│ 2 servers available       🏢 ➕│ ← Both buttons
│   > (expand to see servers)    │
└────────────────────────────────┘
```

### Map View

Shows all exit nodes on an interactive MapKit map with:
- Pins at lat/long coordinates
- Number badges for multi-server locations
- City/country labels
- Realistic elevation

---

## How Round-Robin Works

When you favorite a location group and click it:

1. First click → Connects to Server 1
2. Second click → Connects to Server 2
3. Third click → Connects to Server 3
4. Fourth click → Back to Server 1 (cycles)

The `FavoriteExitNode` model tracks:
- `nodeIDs: [String]` - All server IDs in the group
- `currentNodeIndex: Int` - Current position in rotation

---

## Technical Implementation

### Updated Models

**ExitNode** now stores full `Location` object:
```swift
struct ExitNode {
    let location: Location?  // Full location data
    
    var locationKey: String? {
        // Returns "US-NYC" for grouping
        return "\(countryCode)-\(cityCode)"
    }
}
```

**FavoriteExitNode** supports groups:
```swift
@Model class FavoriteExitNode {
    var isLocationGroup: Bool
    var locationKey: String?
    var nodeIDs: [String]        // All servers in group
    var currentNodeIndex: Int    // For round-robin
    
    func getNextNodeID() -> String {
        // Cycles through nodeIDs array
    }
}
```

### New View Components

- **ManageFavoritesView** - Main container with map/list toggle
- **ListView** - List of grouped locations
- **MapView** - Interactive map with annotations
- **LocationGroup** - Groups nodes by city/country
- **LocationGroupRow** - Shows location with add buttons

---

## Menu Bar Integration

The menu bar now shows:

```
Turn Off Exit Node              ⌘0
──────────────────────────────────
🏢 New York, USA (3)            ⌘1  ← Shows badge
✓  lon-server-1                 ⌘2  ← Shows checkmark
○  Paris, France                ⌘3
──────────────────────────────────
Manage Favorites…               ⌘,
──────────────────────────────────
Quit                            ⌘Q
```

---

## Future Enhancements

Potential improvements:

1. **Smart Selection** - Choose least-loaded server in a group
2. **Performance Metrics** - Show latency for each server
3. **Custom Rotation Order** - Reorder servers in a group
4. **Geofencing** - Auto-switch based on user's location
5. **Favorites Sync** - Share favorites across devices

---

## Migration

Existing favorites are automatically compatible:
- Old favorites work as single-server favorites
- `isLocationGroup` defaults to `false`
- `nodeIDs` defaults to single-element array
- No data loss on upgrade
