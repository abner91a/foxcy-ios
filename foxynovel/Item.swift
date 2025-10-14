//
//  Item.swift
//  foxynovel
//
//  Created by Abner on 13/10/25.
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
