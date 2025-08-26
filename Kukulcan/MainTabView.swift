import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var collection: CollectionStore

    var body: some View {
        TabView {
            PacksView()
                .tabItem { Label("Accueil", systemImage: "house.fill") }

            CollectionView()
                .tabItem { Label("Collection", systemImage: "square.grid.2x2.fill") }

            if collection.ownedPlayable.count >= 10 {
                CombatView(
                    engine: GameEngine(
                        p1: PlayerState(name: "Toi", deck: collection.ownedPlayable),
                        p2: PlayerState(name: "IA", deck: StarterFactory.randomDeck())
                    )
                )
                .tabItem { Label("Combats", systemImage: "gamecontroller.fill") }
            } else {
                Text("Tu as besoin d'au moins 10 cartes pour combattre.")
                    .padding()
                    .tabItem { Label("Combats", systemImage: "gamecontroller.fill") }
            }
        }
        .tint(.orange)
    }
}

