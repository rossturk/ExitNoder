//
//  Item.swift
//  ExitNodeSwitcher
//
//  Created by Ross Turk on 12/1/25.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
