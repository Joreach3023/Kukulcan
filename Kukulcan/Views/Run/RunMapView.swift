import SwiftUI
import UIKit

struct RunMapView: View {
    @StateObject private var runManager = RunManager()

    private let mapAspectRatio: CGFloat = 0.6
    private let mapColumns: CGFloat = 7

    private enum MapTuning {
        static let startNodeCount = 3
        static let fogRowsAhead = 4
        static let fogNearVeilOpacity = 0.08
        static let fogFarVeilOpacity = 0.58
        static let fogFarContentOpacity = 0.4
        static let fogMaxBlur: CGFloat = 2.8
    }

    var body: some View {
        GeometryReader { geo in
            let bottomInset = geo.safeAreaInsets.bottom

            ZStack {
                mapBackground
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()
                    .overlay {
                        LinearGradient(
                            colors: [.black.opacity(0.5), .clear, .black.opacity(0.72)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    }

                VStack(spacing: 12) {
                    if let run = runManager.runState {
                        header(run: run)
                        mapCanvas(run: run)
                        statusFooter(run: run)
                            .padding(.bottom, max(8, bottomInset + 6))
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
                .padding(.horizontal, 12)
                .padding(.top, 8)
            }
        }
        .navigationTitle("Roguelike")
        .navigationBarTitleDisplayMode(.inline)
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
            HStack(spacing: 8) {
                hudBadge(text: "\(run.player.currentHP)/\(run.player.maxHP)", icon: "heart.fill", tint: .red)
                hudBadge(text: "\(run.player.gold)", icon: "bitcoinsign.circle.fill", tint: .yellow)
            }

            HStack(spacing: 8) {
                compactBadge(text: "Deck \(run.player.deck.count)", icon: "rectangle.stack.fill")
                compactBadge(text: "Reliques \(run.player.relics.count)", icon: "sparkles")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func mapCanvas(run: RunState) -> some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height

            GeometryReader { proxy in
                let contentHeight = max(height, width / mapAspectRatio)

                ZStack {
                    RoundedRectangle(cornerRadius: 18)
                        .fill(.black.opacity(0.18))
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))

                    mapBackground
                        .frame(width: width, height: contentHeight)
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                        .overlay {
                            RoundedRectangle(cornerRadius: 18)
                                .stroke(Color.orange.opacity(0.45), lineWidth: 1)
                        }

                    connectionsLayer(run: run, size: CGSize(width: width, height: contentHeight))

                    ForEach(run.nodes) { node in
                        nodeMarker(node: node, run: run, size: CGSize(width: width, height: contentHeight))
                    }
                }
            }
            .frame(height: max(height, width / mapAspectRatio))
        }
        .frame(maxHeight: .infinity)
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
                    let fog = max(fogAmount(for: node.row, in: run), fogAmount(for: nextNode.row, in: run))
                    let baseColor = isVisiblePath ? Color.orange.opacity(0.75) : Color.black.opacity(0.25)
                    context.stroke(
                        path,
                        with: .color(baseColor.opacity(1 - (fog * 0.65))),
                        style: StrokeStyle(lineWidth: isVisiblePath ? 2.5 : 1.2, lineCap: .round, dash: isVisiblePath ? [] : [4, 6])
                    )
                }
            }
        }
    }

    private func nodeMarker(node: MapNode, run: RunState, size: CGSize) -> some View {
        let isSelectable = runManager.isNodeSelectable(node)
        let isLocked = !node.isUnlocked
        let fog = fogAmount(for: node.row, in: run)

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

                if node.type == .campfire {
                    CampfireNodeView(size: 28)
                        .opacity(node.isCompleted ? 0.7 : 1)
                } else {
                    Image(systemName: node.type.systemImage)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(node.isCompleted ? .green : .white)
                }

                if node.isDisabled {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white.opacity(0.9))
                }

                if node.isCompleted {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.green)
                        .offset(x: 14, y: -14)
                }

                Circle()
                    .fill(Color.black.opacity(veilOpacity(for: fog)))
                    .frame(width: 30, height: 30)
            }
            .opacity(contentOpacity(for: fog))
            .blur(radius: blurRadius(for: fog))
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
        if node.isDisabled {
            return Color.gray.opacity(0.18)
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
        if node.isDisabled {
            return .gray.opacity(0.7)
        }
        if node.type == .boss {
            return .red
        }
        return isSelectable ? .orange : .gray
    }

    private func currentExplorationRow(in run: RunState) -> Int {
        if let currentNodeID = run.currentNodeID,
           let node = run.nodes.first(where: { $0.id == currentNodeID }) {
            return node.row
        }

        return run.nodes.filter(\.isCompleted).map(\.row).max() ?? 0
    }

    private func fogAmount(for row: Int, in run: RunState) -> Double {
        let baseRow = currentExplorationRow(in: run)
        let aheadDistance = row - baseRow

        if aheadDistance <= 1 {
            return 0
        }

        let normalized = min(1, Double(aheadDistance - 1) / Double(max(1, MapTuning.fogRowsAhead - 1)))
        return normalized
    }

    private func veilOpacity(for fogAmount: Double) -> Double {
        MapTuning.fogNearVeilOpacity + (MapTuning.fogFarVeilOpacity - MapTuning.fogNearVeilOpacity) * fogAmount
    }

    private func contentOpacity(for fogAmount: Double) -> Double {
        1 - ((1 - MapTuning.fogFarContentOpacity) * fogAmount)
    }

    private func blurRadius(for fogAmount: Double) -> CGFloat {
        CGFloat(fogAmount) * MapTuning.fogMaxBlur
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
                Text("Choisissez 1 des \(MapTuning.startNodeCount) voies puis progressez vers le temple du haut.")
                    .foregroundStyle(.secondary)
            }
        }
        .font(.caption.bold())
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func hudBadge(text: String, icon: String, tint: Color) -> some View {
        Label(text, systemImage: icon)
            .font(.headline.bold())
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.black.opacity(0.45))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(tint.opacity(0.85), lineWidth: 1))
            )
    }

    private func compactBadge(text: String, icon: String) -> some View {
        Label(text, systemImage: icon)
            .font(.caption.bold())
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(.black.opacity(0.42), in: Capsule())
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

                Button {
                    onBuyRelic()
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Acheter relique: \(interaction.relic.name) (\(interaction.relicCost) or)")
                            .font(.headline)
                        Text(interaction.relic.effect)
                            .font(.subheadline)
                        Text("Rareté: \(interaction.relic.rarity.title)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
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
