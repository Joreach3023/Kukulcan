// SwiftUI n'est pas disponible sur toutes les plateformes (ex.: Linux).
// On ne l'importe que lorsqu'il est présent afin que le code compile partout.
#if canImport(SwiftUI)
import SwiftUI
#endif

// ⚠️ NE redéclare PAS l'enum ici.
// L'enum Element existe déjà dans Rules.swift.
// On ajoute seulement des helpers.

extension Element {
    /// Icône SF Symbol pratique pour l'UI
    var sfSymbol: String { "leaf.fill" }

    #if canImport(SwiftUI)
    /// Couleur associée
    var color: Color { .green }
    #endif

    /// Nom lisible
    var title: String { "Plante" }
}

