// Types essentiels pour les tests (version allégée des règles du jeu).
// L'enum `Element` est volontairement isolée afin d'éviter les dépendances
// à SwiftUI/Combine lors de la compilation des tests sur Linux.

enum Element: String, Codable, CaseIterable {
    case fire, water, plant
}
