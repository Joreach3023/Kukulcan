//
//  Item.swift
//  Kukulcan
//
//  Created by Jonathan Labbe on 2025-08-24.
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
