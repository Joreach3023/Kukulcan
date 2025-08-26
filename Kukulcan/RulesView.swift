import SwiftUI

struct RulesView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Règles du jeu")
                    .font(.title)
                Text("""
Kukulcan est un jeu de cartes tactique. Chaque joueur commence avec 10 points de vie.
Pose des cartes communes pour attaquer, sacrifie-les pour gagner du sang et invoquer des dieux puissants.
Le premier à réduire les points de vie de l'adversaire à zéro remporte la partie.
""")
            }
            .padding()
        }
        .navigationTitle("Règles")
    }
}

#Preview {
    RulesView()
}
