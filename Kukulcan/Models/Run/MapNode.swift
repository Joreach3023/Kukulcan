import Foundation

enum MapNodeType: String, Codable, CaseIterable {
    case combat
    case campfire
    case shop
    case event
    case boss

    var title: String {
        switch self {
        case .combat: return "Combat"
        case .campfire: return "Campfire"
        case .shop: return "Shop"
        case .event: return "Event"
        case .boss: return "Boss"
        }
    }

    var systemImage: String {
        switch self {
        case .combat: return "flame.fill"
        case .campfire: return "cross.case.fill"
        case .shop: return "bag.fill"
        case .event: return "sparkles"
        case .boss: return "crown.fill"
        }
    }
}

struct MapNode: Identifiable, Codable, Hashable {
    let id: UUID
    let index: Int
    let type: MapNodeType
    var isVisited: Bool

    init(id: UUID = UUID(), index: Int, type: MapNodeType, isVisited: Bool = false) {
        self.id = id
        self.index = index
        self.type = type
        self.isVisited = isVisited
    }
}
