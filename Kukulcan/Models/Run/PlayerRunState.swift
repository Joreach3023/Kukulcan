import Foundation

struct PlayerRunState: Codable {
    var maxHP: Int
    var currentHP: Int
    var gold: Int
    var deck: [RunCardInstance]
    var relics: [Relic]

    init(maxHP: Int = 30, currentHP: Int = 30, gold: Int = 0, deck: [RunCardInstance] = [], relics: [Relic] = []) {
        self.maxHP = maxHP
        self.currentHP = currentHP
        self.gold = gold
        self.deck = deck
        self.relics = relics
    }
}
