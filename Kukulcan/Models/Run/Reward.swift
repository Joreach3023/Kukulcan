import Foundation

enum Reward: Identifiable, Codable, Hashable {
    case card(Card)
    case gold(Int)
    case heal(Int)

    var id: String {
        switch self {
        case .card(let card):
            return "card-\(card.id.uuidString)"
        case .gold(let amount):
            return "gold-\(amount)"
        case .heal(let amount):
            return "heal-\(amount)"
        }
    }

    var title: String {
        switch self {
        case .card(let card):
            return "Ajouter \(card.name)"
        case .gold(let amount):
            return "+\(amount) or"
        case .heal(let amount):
            return "Soigner \(amount) HP"
        }
    }

    private enum CodingKeys: String, CodingKey {
        case kind
        case card
        case amount
    }

    private enum Kind: String, Codable {
        case card
        case gold
        case heal
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try container.decode(Kind.self, forKey: .kind)
        switch kind {
        case .card:
            self = .card(try container.decode(Card.self, forKey: .card))
        case .gold:
            self = .gold(try container.decode(Int.self, forKey: .amount))
        case .heal:
            self = .heal(try container.decode(Int.self, forKey: .amount))
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .card(let card):
            try container.encode(Kind.card, forKey: .kind)
            try container.encode(card, forKey: .card)
        case .gold(let amount):
            try container.encode(Kind.gold, forKey: .kind)
            try container.encode(amount, forKey: .amount)
        case .heal(let amount):
            try container.encode(Kind.heal, forKey: .kind)
            try container.encode(amount, forKey: .amount)
        }
    }
}
