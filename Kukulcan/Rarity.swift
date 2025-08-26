import SwiftUI

extension Rarity {
    var title: String {
        switch self {
        case .common:     return "Commun"
        case .rare:       return "Rare"
        case .epic:       return "Épique"
        case .legendary:  return "Légendaire"
        }
    }

    var colors: [Color] {
        switch self {
        case .common:     return [.gray.opacity(0.7), .gray.opacity(0.4)]
        case .rare:       return [.blue, .teal]
        case .epic:       return [.purple, .pink]
        case .legendary:  return [.orange, .yellow]
        }
    }

    var glow: Color {
        switch self {
        case .common:     return .gray.opacity(0.5)
        case .rare:       return .blue.opacity(0.6)
        case .epic:       return .purple.opacity(0.6)
        case .legendary:  return .orange.opacity(0.8)
        }
    }
}

