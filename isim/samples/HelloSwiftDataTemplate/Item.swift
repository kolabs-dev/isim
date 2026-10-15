// The model of Xcode's SwiftData app template.
import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date

    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}

/// a second model for the fetch checks (predicate, sort, offset, limit)
@Model
final class Score {
    var player: String
    var points: Int
    init(player: String, points: Int) { self.player = player; self.points = points }
}
