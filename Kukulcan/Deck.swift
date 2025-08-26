import Foundation

struct Deck: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var name: String
    var cards: [Card]

    /// Validate deck composition according to game rules.
    /// - Returns: `true` if the deck does not exceed copy limits.
    /// A deck may contain up to three copies of the same card,
    /// except for cards of type `.god` which are limited to one copy.
    func isValid() -> Bool {
        var counts: [String: Int] = [:]
        for c in cards {
            counts[c.name, default: 0] += 1
            let limit = c.type == .god ? 1 : 3
            if counts[c.name, default: 0] > limit { return false }
        }
        return true
    }
}

