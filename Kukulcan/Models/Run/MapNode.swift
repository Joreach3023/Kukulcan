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
    var isDisabled: Bool

    private enum CodingKeys: String, CodingKey {
        case id, row, column, type, nextNodeIDs, isUnlocked, isCompleted, isDisabled
    }

    init(
        id: UUID,
        row: Int,
        column: Int,
        type: NodeType,
        nextNodeIDs: [UUID],
        isUnlocked: Bool,
        isCompleted: Bool,
        isDisabled: Bool = false
    ) {
        self.id = id
        self.row = row
        self.column = column
        self.type = type
        self.nextNodeIDs = nextNodeIDs
        self.isUnlocked = isUnlocked
        self.isCompleted = isCompleted
        self.isDisabled = isDisabled
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        row = try container.decode(Int.self, forKey: .row)
        column = try container.decode(Int.self, forKey: .column)
        type = try container.decode(NodeType.self, forKey: .type)
        nextNodeIDs = try container.decode([UUID].self, forKey: .nextNodeIDs)
        isUnlocked = try container.decode(Bool.self, forKey: .isUnlocked)
        isCompleted = try container.decode(Bool.self, forKey: .isCompleted)
        isDisabled = try container.decodeIfPresent(Bool.self, forKey: .isDisabled) ?? false
    }
}

struct MapGraph: Codable {
    let nodes: [MapNode]
    let startNodeIDs: [UUID]
    let bossNodeID: UUID
}
