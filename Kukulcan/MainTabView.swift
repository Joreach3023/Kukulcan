import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var collection: CollectionStore

    var body: some View {
        TabView {
            PacksView()
                .tabItem { Label("Accueil", systemImage: "house.fill") }

            CollectionView()
                .tabItem { Label("Collection", systemImage: "square.grid.2x2.fill") }

            if collection.decks.contains(where: { $0.cards.count == 10 }) {
                DeckSelectionView()
                    .tabItem { Label("Combats", systemImage: "gamecontroller.fill") }
            } else {
                Text("Crée un deck de 10 cartes pour combattre.")
                    .padding()
                    .tabItem { Label("Combats", systemImage: "gamecontroller.fill") }
            }
        }
        .tint(.orange)
    }
}

