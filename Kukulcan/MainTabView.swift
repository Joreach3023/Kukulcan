import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var collection: CollectionStore

    var body: some View {
        ZStack(alignment: .topTrailing) {
            TabView {
                PacksView()
                    .tabItem { Label("Accueil", systemImage: "house.fill") }

                CollectionView()
                    .tabItem { Label("Collection", systemImage: "square.grid.2x2.fill") }

                if collection.decks.contains(where: { $0.cards.count == 10 }) {
                    DeckSelectionView()
                        .tabItem { Label("Combats", systemImage: "gamecontroller.fill") }
                } else {
                    NavigationStack {
                        VStack(spacing: 16) {
                            Text("Crée un deck de 10 cartes pour combattre.")
                                .multilineTextAlignment(.center)
                            NavigationLink {
                                DecksView()
                            } label: {
                                Label("Créer un deck", systemImage: "plus")
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        .padding()
                    }
                    .tabItem { Label("Combats", systemImage: "gamecontroller.fill") }
                }
            }
            .tint(.orange)

            // Affichage global de l'or du joueur
            Text("Or : \(collection.gold)")
                .font(.headline)
                .padding(8)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
                .padding()
        }
    }
}

