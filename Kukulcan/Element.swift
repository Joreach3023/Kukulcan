// SwiftUI n'est pas disponible sur toutes les plateformes (ex.: Linux).
// On ne l'importe que lorsqu'il est présent afin que le code compile partout.
#if canImport(SwiftUI)
import SwiftUI
#endif

// ⚠️ NE redéclare PAS l'enum ici.
// L'enum Element (fire, water, plant) existe déjà dans Rules.swift.
// On ajoute seulement des helpers.

extension Element {
    /// Pierre-feuille-ciseaux élémentaire
    func beats(_ other: Element) -> Bool {
        switch (self, other) {
        case (.fire, .plant), (.plant, .water), (.water, .fire): return true
        default: return false
        }
    }

    /// Icône SF Symbol pratique pour l'UI
    var sfSymbol: String {
        switch self {
        case .fire:  return "flame.fill"
        case .water: return "drop.fill"
        case .plant: return "leaf.fill"
        }
    }

    #if canImport(SwiftUI)
    /// Couleur associée
    var color: Color {
        switch self {
        case .fire:  return .orange
        case .water: return .blue
        case .plant: return .green
        }
    }
    #endif

    /// Nom lisible
    var title: String {
        switch self {
        case .fire:  return "Feu"
        case .water: return "Eau"
        case .plant: return "Plante"
        }
    }
}

