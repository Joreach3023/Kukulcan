import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var collection: CollectionStore

    var body: some View {
        TabView {
            PacksView()
                .tabItem { Label("Accueil", systemImage: "house.fill") }

            CollectionView()
                .tabItem { Label("Collection", systemImage: "square.grid.2x2.fill") }

            CombatView()
                .tabItem { Label("Combats", systemImage: "gamecontroller.fill") }
        }
        .tint(.orange)
    }
}

