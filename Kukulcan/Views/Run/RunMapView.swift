import SwiftUI
import UIKit

struct RunMapView: View {
    @StateObject private var runManager = RunManager()

    private let mapAspectRatio: CGFloat = 0.6
    private let mapColumns: CGFloat = 7

    var body: some View {
        VStack(spacing: 16) {
            if let run = runManager.runState {
                header(run: run)
                mapCanvas(run: run)
                statusFooter(run: run)
            } else {
                Spacer()
                Button("New Run") {
                    runManager.startNewRun()
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
                Spacer()
            }
        }
        .padding()
        .navigationTitle("Roguelike")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("New Run") {
                    runManager.startNewRun()
                }
            }
        }
        .sheet(isPresented: Binding(
            get: { !runManager.pendingRewards.isEmpty },
            set: { _ in }
        )) {
            RewardView(rewards: runManager.pendingRewards) { reward in
                runManager.chooseReward(reward)
            }
        }
        .sheet(item: $runManager.pendingCampfire, onDismiss: {
            runManager.dismissPendingNodeInteractions()
        }) { interaction in
            CampfireChoiceSheet(
                interaction: interaction,
                player: runManager.runState?.player,
                onHeal: {
                    runManager.applyCampfireHeal(interaction)
                },
                onUpgrade: { cardID in
                    runManager.upgradeCardAtCampfire(cardID, interaction: interaction)
                }
            )
        }
        .sheet(item: $runManager.pendingShop, onDismiss: {
            runManager.dismissPendingNodeInteractions()
        }) { interaction in
            ShopChoiceSheet(
                interaction: interaction,
                player: runManager.runState?.player,
                onBuyCard: { card in
                    runManager.buyCard(card, from: interaction)
                },
                onBuyRelic: {
                    runManager.buyRelic(from: interaction)
                },
                onRemoveCard: { cardID in
                    runManager.removeCardFromDeck(cardID, in: interaction)
                }
            )
        }
        .sheet(item: $runManager.pendingEvent, onDismiss: {
            runManager.dismissPendingNodeInteractions()
        }) { interaction in
            EventChoiceSheet(interaction: interaction) { option in
                runManager.chooseEventOption(option, in: interaction)
            }
        }
        .fullScreenCover(item: $runManager.activeBattle) { battle in
            CombatView(
                engine: GameEngine(
                    p1: PlayerState(name: "Aventurier", deck: runManager.runState?.player.deck.map(\.card) ?? StarterFactory.playerDeck()),
                    p2: PlayerState(name: battle.enemy.name, deck: StarterFactory.randomDeck())
                ),
                aiLevel: 1,
                onWin: { _ in
                    runManager.handleBattleVictory(battle.nodeID)
                },
                onLoss: {
                    runManager.endRun(victory: false)
                }
            )
        }
        .onAppear {
            if runManager.runState == nil {
                runManager.startNewRun()
            }
        }
    }

    private func header(run: RunState) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("HP: \(run.player.currentHP)/\(run.player.maxHP)", systemImage: "heart.fill")
            Label("Gold: \(run.player.gold)", systemImage: "bitcoinsign.circle.fill")
            Label("Deck: \(run.player.deck.count) cartes", systemImage: "rectangle.stack.fill")
            Label("Reliques: \(run.player.relics.count)", systemImage: "sparkles")
        }
        .font(.headline)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func mapCanvas(run: RunState) -> some View {
        ScrollView {
            GeometryReader { proxy in
                let width = proxy.size.width
                let height = width / mapAspectRatio

                ZStack {
                    mapBackground
                        .frame(width: width, height: height)
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                        .overlay {
                            RoundedRectangle(cornerRadius: 18)
                                .stroke(Color.orange.opacity(0.45), lineWidth: 1)
                        }

                    connectionsLayer(run: run, size: CGSize(width: width, height: height))

                    ForEach(run.nodes) { node in
                        nodeMarker(node: node, run: run, size: CGSize(width: width, height: height))
                    }
                }
            }
            .frame(height: UIScreen.main.bounds.width / mapAspectRatio)
        }
    }

    private var mapBackground: some View {
        Group {
            if UIImage(named: "roguelike_map_kukulcan") != nil {
                Image("roguelike_map_kukulcan")
                    .resizable()
                    .scaledToFill()
            } else {
                Image("bg_pyramid_close")
                    .resizable()
                    .scaledToFill()
            }
        }
    }

    private func connectionsLayer(run: RunState, size: CGSize) -> some View {
        Canvas { context, _ in
            for node in run.nodes {
                for nextID in node.nextNodeIDs {
                    guard let nextNode = run.nodes.first(where: { $0.id == nextID }) else { continue }

                    var path = Path()
                    let from = mapPoint(for: node, in: size)
                    let to = mapPoint(for: nextNode, in: size)
                    path.move(to: from)
                    path.addLine(to: to)

                    let isVisiblePath = node.isCompleted || nextNode.isUnlocked
                    context.stroke(
                        path,
                        with: .color(isVisiblePath ? Color.orange.opacity(0.75) : Color.black.opacity(0.25)),
                        style: StrokeStyle(lineWidth: isVisiblePath ? 2.5 : 1.2, lineCap: .round, dash: isVisiblePath ? [] : [4, 6])
                    )
                }
            }
        }
    }

    private func nodeMarker(node: MapNode, run: RunState, size: CGSize) -> some View {
        let isSelectable = runManager.isNodeSelectable(node)
        let isLocked = !node.isUnlocked

        return Button {
            runManager.selectNode(node)
        } label: {
            ZStack {
                Circle()
                    .fill(markerFillColor(node: node, isSelectable: isSelectable, isLocked: isLocked))
                    .frame(width: 30, height: 30)
                    .overlay {
                        Circle()
                            .stroke(markerStrokeColor(node: node, isSelectable: isSelectable), lineWidth: 1.5)
                    }

                Image(systemName: node.type.systemImage)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(node.isCompleted ? .green : .white)

                if node.isCompleted {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.green)
                        .offset(x: 14, y: -14)
                }
            }
            .shadow(color: isSelectable ? .orange.opacity(0.5) : .black.opacity(0.2), radius: isSelectable ? 8 : 3)
        }
        .buttonStyle(.plain)
        .disabled(!isSelectable || run.isFinished)
        .position(mapPoint(for: node, in: size))
        .accessibilityLabel("\(node.type.title)")
    }

    private func markerFillColor(node: MapNode, isSelectable: Bool, isLocked: Bool) -> Color {
        if node.isCompleted {
            return Color.green.opacity(0.25)
        }
        if isLocked {
            return Color.black.opacity(0.35)
        }
        return isSelectable ? Color.orange.opacity(0.32) : Color.white.opacity(0.2)
    }

    private func markerStrokeColor(node: MapNode, isSelectable: Bool) -> Color {
        if node.isCompleted {
            return .green
        }
        if node.type == .boss {
            return .red
        }
        return isSelectable ? .orange : .gray
    }


    private func mapPoint(for node: MapNode, in size: CGSize) -> CGPoint {
        let rows = max(1, (runManager.runState?.nodes.map(\.row).max() ?? 1))
        let xStep = size.width / max(1, mapColumns - 1)
        let yStep = size.height / CGFloat(rows)
        let x = CGFloat(node.column) * xStep
        let y = size.height - CGFloat(node.row) * yStep
        return CGPoint(x: x, y: y)
    }

    private func statusFooter(run: RunState) -> some View {
        Group {
            switch run.status {
            case .victory:
                Text("🏆 Victoire ! Le temple du sommet est conquis.")
                    .font(.headline)
                    .foregroundStyle(.green)
            case .gameOver:
                Text("☠️ Game Over. Lancez une nouvelle run.")
                    .font(.headline)
                    .foregroundStyle(.red)
            case .choosingReward:
                Text("Récompense en cours...")
                    .foregroundStyle(.secondary)
            default:
                Text("Cliquez sur un lieu lumineux pour avancer vers le temple du haut.")
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct CampfireChoiceSheet: View {
    let interaction: CampfireInteraction
    let player: PlayerRunState?
    let onHeal: () -> Void
    let onUpgrade: (UUID) -> Void

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("Feu de camp")
                    .font(.title2.bold())
                Text("Choisissez une seule option.")
                    .foregroundStyle(.secondary)

                Button("Heal +\(interaction.healAmount) HP") {
                    onHeal()
                }
                .buttonStyle(.borderedProminent)

                Text("Ou améliorez une carte :")
                    .font(.headline)

                if let upgradableCards = player?.deck.filter({ !$0.isUpgraded }), !upgradableCards.isEmpty {
                    List(upgradableCards) { instance in
                        Button {
                            onUpgrade(instance.id)
                        } label: {
                            HStack {
                                Text(instance.card.name)
                                Spacer()
                                Text("ATK \(instance.card.attack) / HP \(instance.card.health)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .listStyle(.plain)
                } else {
                    Text("Aucune carte améliorable disponible.")
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
        }
    }
}

private struct ShopChoiceSheet: View {
    let interaction: ShopInteraction
    let player: PlayerRunState?
    let onBuyCard: (Card) -> Void
    let onBuyRelic: () -> Void
    let onRemoveCard: (UUID) -> Void

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 14) {
                Text("Marchand Maya")
                    .font(.title2.bold())
                Text("Choisissez un seul achat pour ce shop.")
                    .foregroundStyle(.secondary)
                Text("Or disponible: \(player?.gold ?? 0)")
                    .font(.headline)

                Text("Acheter une carte (\(interaction.cardCost) or)")
                    .font(.headline)
                ForEach(interaction.cardOffers, id: \.id) { card in
                    Button("\(card.name) • \(card.effect)") {
                        onBuyCard(card)
                    }
                    .buttonStyle(.bordered)
                    .disabled((player?.gold ?? 0) < interaction.cardCost)
                }

                Divider()

                Button("Acheter relique: \(interaction.relic.name) (\(interaction.relicCost) or)") {
                    onBuyRelic()
                }
                .buttonStyle(.borderedProminent)
                .disabled((player?.gold ?? 0) < interaction.relicCost)

                Divider()

                Text("Supprimer une carte (\(interaction.removeCardCost) or)")
                    .font(.headline)
                if let deck = player?.deck, !deck.isEmpty {
                    List(deck) { instance in
                        Button("Retirer \(instance.card.name)") {
                            onRemoveCard(instance.id)
                        }
                        .disabled((player?.gold ?? 0) < interaction.removeCardCost)
                    }
                    .listStyle(.plain)
                }
            }
            .padding()
        }
    }
}

private struct EventChoiceSheet: View {
    let interaction: EventInteraction
    let onChoose: (MayaEventOption) -> Void

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text(interaction.event.title)
                    .font(.title2.bold())
                Text(interaction.event.description)
                    .foregroundStyle(.secondary)

                ForEach(interaction.event.options) { option in
                    Button(option.text) {
                        onChoose(option)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding()
        }
    }
}
