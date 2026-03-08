import Foundation

struct RunCardInstance: Identifiable, Codable, Hashable {
    let id: UUID
    var card: Card
    var isUpgraded: Bool

    init(id: UUID = UUID(), card: Card, isUpgraded: Bool = false) {
        self.id = id
        self.card = card
        self.isUpgraded = isUpgraded
    }
}
