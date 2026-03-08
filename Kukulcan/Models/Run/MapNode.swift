import Foundation

enum NodeType: String, Codable, CaseIterable {
    case combat
    case elite
    case shop
    case campfire
    case event
    case treasure
    case boss

    var title: String {
        switch self {
        case .combat: return "Combat"
        case .elite: return "Élite"
        case .shop: return "Shop"
        case .campfire: return "Campfire"
        case .event: return "Événement"
        case .treasure: return "Trésor"
        case .boss: return "Boss"
        }
    }

    var systemImage: String {
        switch self {
        case .combat: return "sword.fill"
        case .elite: return "skull.fill"
        case .shop: return "bag.fill"
        case .campfire: return "flame.fill"
        case .event: return "questionmark.circle.fill"
        case .treasure: return "gift.fill"
        case .boss: return "crown.fill"
        }
    }
}

struct MapNode: Identifiable, Codable, Hashable {
    let id: UUID
    let row: Int
    let column: Int
    let type: NodeType
    let nextNodeIDs: [UUID]
    var isUnlocked: Bool
    var isCompleted: Bool
}

struct MapGraph: Codable {
    let nodes: [MapNode]
    let startNodeIDs: [UUID]
    let bossNodeID: UUID
}
