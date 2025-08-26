import Foundation

struct Deck: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var name: String
    var cards: [Card]
}

