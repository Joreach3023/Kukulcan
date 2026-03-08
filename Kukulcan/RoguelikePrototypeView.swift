import SwiftUI

struct RoguelikePrototypeView: View {
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
        GeometryReader { geo in
            let bottomInset = geo.safeAreaInsets.bottom

            ZStack {
                Image("bg_jungle_far")
                    .resizable()
                    .scaledToFill()
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()
                    .overlay {
                        LinearGradient(
                            colors: [.black.opacity(0.45), .clear, .black.opacity(0.65)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    }

                VStack(spacing: 12) {
                    topHud

                    if let boss = currentBoss, currentPhase == .boss {
                        bossBanner(boss)
                    }

                    Spacer()

                    bottomHud
                        .padding(.bottom, max(12, bottomInset + 8))
                }
                .padding(.horizontal, 12)
                .padding(.top, 12)
            }
        }
        .navigationTitle("Roguelike")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if deck.isEmpty { resetRun() }
        }
    }

    private var topHud: some View {
        VStack(spacing: 8) {
            HStack(alignment: .top) {
                hudBadge(title: "HP", value: "\(playerHP)", systemImage: "heart.fill", tint: .red)
                Spacer()
                hudBadge(title: "Or", value: "\(gold)", systemImage: "bitcoinsign.circle.fill", tint: .yellow)
            }

            HStack(spacing: 8) {
                compactBadge(label: "Étage \(floor)", icon: "stairs")
                compactBadge(label: "\(currentPhase.title)", icon: "bolt.fill")
                compactBadge(label: "Deck \(deck.count)", icon: "rectangle.stack.fill")
                compactBadge(label: "Reliques \(currentBossIndex)", icon: "sparkles")
            }
        }
    }

    private var bottomHud: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                Button("Jouer la phase") {
                    playCurrentPhase()
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
                .disabled(isRunOver)

                Button("New Run") {
                    resetRun()
                }
                .buttonStyle(.bordered)
                .tint(.white)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Journal")
                    .font(.caption.bold())
                    .foregroundStyle(.white)

                ForEach(Array(log.suffix(3).reversed().enumerated()), id: \.offset) { _, entry in
                    Text("• \(entry)")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.9))
                        .lineLimit(2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
        }
    }

    private func hudBadge(title: String, value: String, systemImage: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2.bold())
                .foregroundStyle(.white.opacity(0.85))
            Label(value, systemImage: systemImage)
                .font(.headline.bold())
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.black.opacity(0.45))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(tint.opacity(0.85), lineWidth: 1))
        )
    }

    private func compactBadge(label: String, icon: String) -> some View {
        Label(label, systemImage: icon)
            .font(.caption.bold())
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(.black.opacity(0.45), in: Capsule())
    }

    private func bossBanner(_ boss: Card) -> some View {
        Text("Boss: \(boss.name) • ATK \(boss.attack) / HP \(boss.health)")
            .font(.subheadline.bold())
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.orange.opacity(0.9), in: Capsule())
            .shadow(radius: 8)
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
