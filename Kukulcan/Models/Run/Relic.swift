import Foundation

enum RelicID: String, Codable, Hashable {
    case pakalFuneraryMask
    case sacredCodex
    case palenqueRoyalJade
    case tzolkinCalendar
    case quetzalFeather
    case ceremonialDrum
    case jadeSerpent
    case obsidianOffering
    case sunStone
}

struct Relic: Identifiable, Codable, Hashable {
    let id: UUID
    let relicID: RelicID
    let name: String
    let description: String
    let effect: String
    let rarity: Rarity
    let image: String

    init(
        id: UUID = UUID(),
        relicID: RelicID,
        name: String,
        description: String,
        effect: String,
        rarity: Rarity,
        image: String
    ) {
        self.id = id
        self.relicID = relicID
        self.name = name
        self.description = description
        self.effect = effect
        self.rarity = rarity
        self.image = image
    }
}
