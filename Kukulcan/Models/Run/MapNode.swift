import Foundation
import CoreGraphics

enum NodeType: String, Codable, CaseIterable {
    case combat
    case elite
    case shop
    case campfire
    case event
    case boss

    var title: String {
        switch self {
        case .combat: return "Combat"
        case .elite: return "Élite"
        case .shop: return "Shop"
        case .campfire: return "Campfire"
        case .event: return "Événement"
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
        case .boss: return "crown.fill"
        }
    }
}

struct MapNode: Identifiable, Codable, Hashable {
    let id: UUID
    let type: NodeType
    let x: CGFloat
    let y: CGFloat
    let nextNodeIDs: [UUID]
    var isUnlocked: Bool
    var isCompleted: Bool
}
