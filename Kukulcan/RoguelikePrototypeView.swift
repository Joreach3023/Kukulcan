import SwiftUI

struct RoguelikePrototypeView: View {
    private let choices = [
        "Renforcer une carte existante",
        "Ajouter une nouvelle carte au deck",
        "Stocker de l'or pour la boutique suivante"
    ]

    @State private var playerHP = 26
    @State private var gold = 0
    @State private var floor = 1
    @State private var deck: [Card] = []
    @State private var currentPhase: RunPhase = .combat
    @State private var currentBossIndex = 0
    @State private var log: [String] = ["Une nouvelle run commence. Préparez votre deck !"]

    private var bossOrder: [Card] {
        let nonKukulcan = CardsDB.gods.filter { $0.name != "Kukulcan" }.shuffled()
        if let kukulcan = CardsDB.gods.first(where: { $0.name == "Kukulcan" }) {
            return nonKukulcan + [kukulcan]
        }
        return nonKukulcan
    }

    private var runAttackPower: Int {
        max(4, deck.reduce(0) { $0 + $1.attack } / max(1, deck.count / 2))
    }

    private var runHealthBuffer: Int {
        deck.reduce(0) { $0 + $1.health } / max(1, deck.count)
    }

    private var currentBoss: Card? {
        guard currentBossIndex < bossSequence.count else { return nil }
        return bossSequence[currentBossIndex]
    }

    @State private var bossSequence: [Card] = []

    private var isRunOver: Bool {
        playerHP <= 0 || (currentBossIndex >= bossSequence.count && currentPhase == .victory)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                headerSection
                conceptSection
                cardsSection
                importedCardsSection
                loopSection
                gameplaySection
                shopSection
                bossSection
                roguelikeSection
                prototypeSection
            }
            .padding()
        }
        .navigationTitle("Roguelike")
        .onAppear {
            if deck.isEmpty { resetRun() }
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Prototype Roguelike")
                .font(.largeTitle.bold())

            Text("La run utilise maintenant les cartes existantes du jeu : communes, rituels et dieux légendaires comme boss.")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var conceptSection: some View {
        GroupBox("🎮 Concept général") {
            Text("Enchaînez des combats contre des IA, gagnez de l'or, recrutez de vraies cartes de Kukulcan pendant la run et terrassez tous les dieux. Le dernier boss est toujours Kukulcan.")
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var cardsSection: some View {
        GroupBox("🃏 Système de cartes") {
            VStack(alignment: .leading, spacing: 6) {
                Text("Chaque carte importée garde :")
                Label("Points de vie (HP)", systemImage: "heart.fill")
                Label("Points d'attaque (ATK)", systemImage: "bolt.fill")
                Label("Rareté et effets déjà définis", systemImage: "sparkles")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var importedCardsSection: some View {
        GroupBox("📦 Cartes importées dans la run") {
            VStack(alignment: .leading, spacing: 8) {
                Text("Deck actuel : \(deck.count) cartes • ATK run \(runAttackPower) • Buffer \(runHealthBuffer)")
                    .font(.subheadline.bold())

                ForEach(Array(deck.prefix(6)), id: \.id) { card in
                    HStack {
                        Text(card.name)
                        Spacer()
                        Text(card.rarity.rawValue.capitalized)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if deck.count > 6 {
                    Text("+\(deck.count - 6) autres cartes…")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Divider()

                Text("Progression des boss légendaires")
                    .font(.subheadline.bold())
                ForEach(Array(bossSequence.enumerated()), id: \.element.id) { index, boss in
                    Label {
                        Text("\(boss.name) \(index < currentBossIndex ? "✅" : "")")
                    } icon: {
                        Image(systemName: index == currentBossIndex ? "flame.fill" : "crown.fill")
                    }
                    .foregroundStyle(index == bossSequence.count - 1 ? .orange : .primary)
                }
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
                Text("4. Passer en boutique/recrutement")
                Text("5. Importer 1 carte depuis la base du jeu")
                Text("6. Renforcer son deck de run")
                Text("7. Affronter un boss légendaire aux étages clés")
                Text("8. Finir contre Kukulcan")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var shopSection: some View {
        GroupBox("🏪 Boutique & recrutement") {
            VStack(alignment: .leading, spacing: 6) {
                Text("Après certains combats :")
                Text("• Dépenser votre or")
                Text("• Tirer 3 cartes de la base existante")
                Text("• Récupérer automatiquement la plus puissante")
                Text("• Ajouter la carte au deck de la run")
                Text("Objectif : créer des synergies réelles à partir des cartes déjà présentes dans le jeu.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var gameplaySection: some View {
        GroupBox("🕹️ Gameplay jouable") {
            VStack(alignment: .leading, spacing: 12) {
                Text("Étage \(floor) • Phase : \(currentPhase.title)")
                    .font(.headline)

                if let boss = currentBoss, currentPhase == .boss {
                    Text("Boss en cours : \(boss.name) (ATK \(boss.attack) / HP \(boss.health))")
                        .font(.subheadline)
                        .foregroundStyle(.orange)
                }

                HStack(spacing: 16) {
                    Label("\(playerHP) HP", systemImage: "heart.fill")
                    Label("\(gold) or", systemImage: "bitcoinsign.circle.fill")
                    Label("Deck \(deck.count)", systemImage: "rectangle.stack.fill")
                }
                .font(.subheadline)

                HStack(spacing: 10) {
                    Button("Jouer la phase") {
                        playCurrentPhase()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                    .disabled(isRunOver)

                    Button("Nouvelle run") {
                        resetRun()
                    }
                    .buttonStyle(.bordered)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Journal de run")
                        .font(.subheadline.bold())
                    ForEach(Array(log.suffix(6).reversed().enumerated()), id: \.offset) { _, entry in
                        Text("• \(entry)")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var bossSection: some View {
        GroupBox("👑 Boss légendaires") {
            VStack(alignment: .leading, spacing: 6) {
                Text("Chaque carte légendaire devient un boss de run.")
                Text("L'ordre est aléatoire, sauf le dernier boss : Kukulcan.")
                Text("Vaincre un boss donne de l'or et améliore votre deck.")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var roguelikeSection: some View {
        GroupBox("🔁 Philosophie roguelike") {
            VStack(alignment: .leading, spacing: 6) {
                Text("• Runs courtes et rejouables")
                Text("• Cartes réelles du jeu comme progression")
                Text("• Boss légendaires à route variable")
                Text("• Fin de run épique contre Kukulcan")
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

                Button("Démarrer une run") {
                    resetRun()
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private extension RoguelikePrototypeView {
    enum RunPhase {
        case combat
        case shop
        case boss
        case victory

        var title: String {
            switch self {
            case .combat: return "Combat"
            case .shop: return "Boutique"
            case .boss: return "Boss"
            case .victory: return "Victoire"
            }
        }
    }

    func playCurrentPhase() {
        guard playerHP > 0 else { return }

        switch currentPhase {
        case .combat:
            let enemyCard = CardsDB.commons.randomElement() ?? CardsDB.gods[0]
            let enemyPower = enemyCard.attack + floor
            let damage = max(0, enemyPower - runAttackPower / 2)
            let reward = 5 + floor

            playerHP = max(0, playerHP - damage)
            gold += reward
            log.append("Combat vs \(enemyCard.name) : +\(reward) or, -\(damage) HP.")

            if playerHP <= 0 {
                log.append("Vous avez été vaincu pendant la run.")
                return
            }
            currentPhase = floor.isMultiple(of: 3) ? .boss : .shop

        case .shop:
            recruitCardFromGamePool()
            floor += 1
            currentPhase = .combat

        case .boss:
            guard let boss = currentBoss else {
                currentPhase = .victory
                log.append("Tous les boss ont été vaincus. Run terminée !")
                return
            }

            let bossPower = boss.attack + boss.health / 2 + floor
            let damage = max(1, bossPower - (runAttackPower + runHealthBuffer) / 2)
            playerHP = max(0, playerHP - damage)

            if playerHP > 0 {
                let reward = 14 + boss.attack
                gold += reward
                currentBossIndex += 1
                deck.append(boss)
                log.append("Boss vaincu : \(boss.name) • +\(reward) or. Sa carte rejoint votre deck.")

                if currentBossIndex >= bossSequence.count {
                    currentPhase = .victory
                    log.append("Victoire finale ! Kukulcan est tombé.")
                } else {
                    floor += 1
                    currentPhase = .combat
                }
            } else {
                log.append("Défaite contre \(boss.name). Relancez une nouvelle run.")
            }

        case .victory:
            log.append("La run est déjà gagnée. Lancez une nouvelle run.")
        }
    }

    func recruitCardFromGamePool() {
        let offerPool = CardsDB.commons + CardsDB.rituals
        let offer = Array(offerPool.shuffled().prefix(3))
        guard !offer.isEmpty else {
            log.append("Boutique vide : aucune carte trouvée.")
            return
        }

        let selected = offer.max(by: { ($0.attack + $0.health) < ($1.attack + $1.health) }) ?? offer[0]
        let cost = 8
        if gold >= cost {
            gold -= cost
            deck.append(selected)
            log.append("Boutique : \(selected.name) recruté pour \(cost) or.")
        } else {
            playerHP = min(30, playerHP + 1)
            log.append("Pas assez d'or. Repos rituel : +1 HP.")
        }
    }

    func resetRun() {
        playerHP = 26
        gold = 0
        floor = 1
        currentPhase = .combat
        currentBossIndex = 0
        bossSequence = bossOrder

        let startingCommons = Array(CardsDB.commons.shuffled().prefix(5))
        let startingRitual = CardsDB.rituals.randomElement().map { [$0] } ?? []
        deck = startingCommons + startingRitual

        log = [
            "Nouvelle run : deck importé avec \(deck.count) cartes existantes.",
            "Ordre des boss défini. Dernier boss : Kukulcan."
        ]
    }
}

#Preview {
    RoguelikePrototypeView()
}
