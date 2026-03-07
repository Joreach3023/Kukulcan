import SwiftUI

struct RoguelikePrototypeView: View {
    private let choices = [
        "Renforcer une carte existante",
        "Ajouter une nouvelle carte au deck",
        "Stocker de l'or pour la boutique suivante"
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                headerSection
                conceptSection
                cardsSection
                loopSection
                shopSection
                bossSection
                roguelikeSection
                prototypeSection
            }
            .padding()
        }
        .navigationTitle("Roguelike")
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Prototype Roguelike")
                .font(.largeTitle.bold())

            Text("Testez la future boucle roguelike de Kukulkan : combats, boutiques et choix stratégiques dans une même run.")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var conceptSection: some View {
        GroupBox("🎮 Concept général") {
            Text("Enchaînez des combats contre des IA, gagnez de l'or, améliorez votre deck pendant la run et affrontez des boss inspirés de la mythologie maya.")
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var cardsSection: some View {
        GroupBox("🃏 Système de cartes") {
            VStack(alignment: .leading, spacing: 6) {
                Text("Chaque carte possède :")
                Label("Points de vie (HP)", systemImage: "heart.fill")
                Label("Points d'attaque (ATK)", systemImage: "bolt.fill")
                Label("Effets spéciaux : poison, bouclier, boost, vol de vie…", systemImage: "sparkles")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var loopSection: some View {
        GroupBox("⚔️ Boucle de gameplay principale") {
            VStack(alignment: .leading, spacing: 6) {
                Text("1. Démarrer une nouvelle run")
                Text("2. Combattre un ennemi IA")
                Text("3. Gagner de l'or après la victoire")
                Text("4. Accéder à une boutique ou récompense")
                Text("5. Acheter un pack de cartes")
                Text("6. Choisir 1 carte parmi 3 proposées")
                Text("7. Améliorer son deck")
                Text("8. Avancer vers le prochain combat")
                Text("9. Affronter un boss")
                Text("10. Répéter jusqu'à victoire ou défaite")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var shopSection: some View {
        GroupBox("🏪 Boutique & packs") {
            VStack(alignment: .leading, spacing: 6) {
                Text("Après certains combats :")
                Text("• Dépenser votre or")
                Text("• Acheter un pack de cartes")
                Text("• Découvrir 3 choix aléatoires")
                Text("• Sélectionner une seule carte")
                Text("• Ajouter la carte au deck de la run")
                Text("Objectif : forcer des décisions stratégiques et créer des synergies.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var bossSection: some View {
        GroupBox("👑 Boss & progression permanente") {
            VStack(alignment: .leading, spacing: 6) {
                Text("Chaque zone contient un boss unique.")
                Text("Battre un boss débloque :")
                Text("• De nouvelles cartes permanentes")
                Text("• De nouveaux ennemis")
                Text("• De nouveaux boss")
                Text("Ces éléments deviennent disponibles pour les prochaines runs.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var roguelikeSection: some View {
        GroupBox("🔁 Philosophie roguelike") {
            VStack(alignment: .leading, spacing: 6) {
                Text("• Runs courtes et rejouables")
                Text("• Cartes aléatoires")
                Text("• Ennemis variables")
                Text("• Builds différents à chaque partie")
                Text("• Apprentissage progressif du joueur")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var prototypeSection: some View {
        GroupBox("🧪 Prototype rapide") {
            VStack(alignment: .leading, spacing: 12) {
                Text("Choisissez un prochain objectif pour votre run :")
                ForEach(choices, id: \.self) { choice in
                    Label(choice, systemImage: "circle")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Button("Démarrer une run (bientôt)") {
                    // Prototype visuel uniquement pour l'instant.
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

#Preview {
    RoguelikePrototypeView()
}
