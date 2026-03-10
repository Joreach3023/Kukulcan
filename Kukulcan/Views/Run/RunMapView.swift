import SwiftUI
import UIKit

struct RunMapView: View {
    @StateObject private var runManager = RunManager()
    @State private var showRelicsSheet = false

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
        .sheet(isPresented: $showRelicsSheet) {
            RelicsPanelView(relics: runManager.runState?.player.relics ?? [])
                .presentationDetents([.medium, .large])
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
                onBuyRelic: { offerID in
                    runManager.buyRelic(offerID: offerID, from: interaction)
                },
                onLeave: {
                    runManager.leaveShop(interaction)
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
        .sheet(item: $runManager.pendingCardSelection) { interaction in
            CardSelectionSheet(
                interaction: interaction,
                onConfirmUpgrade: { cardID in
                    runManager.confirmPendingCardSelection(upgradeCardID: cardID)
                },
                onConfirmAdd: { cardID in
                    runManager.confirmPendingCardSelection(addCardID: cardID)
                }
            )
        }
        .sheet(item: $runManager.pendingCardResult) { result in
            CardSelectionResultSheet(result: result) {
                runManager.dismissCardResult()
            }
        }
        .fullScreenCover(item: $runManager.activeBattle) { battle in
            CombatView(
                engine: GameEngine(
                    p1: PlayerState(name: "Aventurier", deck: runManager.runState?.player.deck.map(\.card) ?? StarterFactory.playerDeck()),
                    p2: PlayerState(name: battle.enemy.name, deck: StarterFactory.randomDeck()),
                    bossType: battle.bossType
                ),
                aiLevel: 1,
                playerRelics: runManager.runState?.player.relics ?? [],
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
                Spacer(minLength: 0)
                RelicsButton(count: run.player.relics.count) {
                    showRelicsSheet = true
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func mapCanvas(run: RunState) -> some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height
            let contentHeight = max(height, width / mapAspectRatio)

            ZStack {
                mapBackground
                    .frame(width: width, height: contentHeight)
                    .clipShape(RoundedRectangle(cornerRadius: 18))

                connectionsLayer(run: run, size: CGSize(width: width, height: contentHeight))

                ForEach(run.nodes) { node in
                    nodeMarker(node: node, run: run, size: CGSize(width: width, height: contentHeight))
                }
            }
            .frame(height: contentHeight)
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
        let yStep = size.height / CGFloat(rows + 1)
        let topPadding = yStep * 0.75
        let bottomPadding = yStep * 1.15
        let x = CGFloat(node.column) * xStep
        let y = size.height - bottomPadding - CGFloat(node.row) * yStep
        return CGPoint(x: x, y: max(topPadding, y))
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

    @State private var selectedCardID: UUID?

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
                    CardSelectionGallery(
                        cards: upgradableCards.map { .init(id: $0.id, card: $0.card) },
                        selectedCardID: $selectedCardID
                    )

                    Button("Confirmer l'amélioration") {
                        if let selectedCardID {
                            onUpgrade(selectedCardID)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(selectedCardID == nil)
                } else {
                    Text("Aucune carte améliorable disponible.")
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
        }
    }
}

private struct CardSelectionGallery: View {
    struct Item: Identifiable {
        let id: UUID
        let card: Card
    }

    let cards: [Item]
    @Binding var selectedCardID: UUID?

    private let cardWidth: CGFloat = 160

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 14) {
                ForEach(cards, id: \.id) { card in
                    let isSelected = selectedCardID == card.id
                    CardView(card: card.card, faceUp: true, width: cardWidth) {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
                            selectedCardID = card.id
                        }
                    }
                    .scaleEffect(isSelected ? 1.06 : 0.96)
                    .overlay {
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(isSelected ? Color.orange : Color.clear, lineWidth: 3)
                            .shadow(color: isSelected ? .orange.opacity(0.8) : .clear, radius: 10)
                    }
                }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 6)
        }
        .frame(height: cardWidth * 1.62)
    }
}

private struct CardSelectionSheet: View {
    let interaction: CardSelectionInteraction
    let onConfirmUpgrade: (UUID) -> Void
    let onConfirmAdd: (UUID) -> Void

    @State private var selectedCardID: UUID?

    private var cards: [CardSelectionGallery.Item] {
        switch interaction.mode {
        case .upgrade:
            interaction.upgradableCards.map { .init(id: $0.id, card: $0.card) }
        case .addToDeck:
            interaction.cardChoices.map { .init(id: $0.id, card: $0) }
        }
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 14) {
                Text(interaction.title)
                    .font(.title3.bold())
                Text(interaction.description)
                    .foregroundStyle(.secondary)

                CardSelectionGallery(cards: cards, selectedCardID: $selectedCardID)

                Button("Confirmer") {
                    guard let selectedCardID else { return }
                    switch interaction.mode {
                    case .upgrade:
                        onConfirmUpgrade(selectedCardID)
                    case .addToDeck:
                        onConfirmAdd(selectedCardID)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(selectedCardID == nil)

                Spacer(minLength: 0)
            }
            .padding()
        }
    }
}

private struct CardSelectionResultSheet: View {
    let result: CardSelectionResult
    let onClose: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 18) {
                Text(result.title)
                    .font(.title3.bold())
                    .multilineTextAlignment(.center)

                Text(result.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                CardView(card: result.card, faceUp: true, width: 210)

                Button("Continuer") {
                    onClose()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
    }
}

private struct ShopChoiceSheet: View {
    let interaction: ShopInteraction
    let player: PlayerRunState?
    let onBuyRelic: (UUID) -> Void
    let onLeave: () -> Void

    @State private var hasEntered = false

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            ZStack {
                Image("shop_background")
                    .resizable()
                    .scaledToFill()
                    .frame(width: size.width, height: size.height)
                    .overlay {
                        LinearGradient(
                            colors: [.black.opacity(0.35), .black.opacity(0.15), .black.opacity(0.65)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    }
                    .clipped()

                HStack {
                    SpriteSheetAnimationView(imageName: "torch_fire_sprite", frameCount: 4, fps: 9)
                        .frame(width: size.width * 0.2, height: size.height * 0.22)
                    Spacer()
                    SpriteSheetAnimationView(imageName: "torch_fire_sprite", frameCount: 4, fps: 9)
                        .frame(width: size.width * 0.2, height: size.height * 0.22)
                        .scaleEffect(x: -1, y: 1)
                }
                .padding(.horizontal, 8)
                .offset(y: -size.height * 0.22)

                SpriteSheetAnimationView(imageName: "shop_incense_smoke", frameCount: 3, fps: 4)
                    .frame(width: size.width * 0.6, height: size.height * 0.26)
                    .opacity(0.35)
                    .offset(y: -size.height * 0.16)

                Image("merchant_maya")
                    .resizable()
                    .scaledToFit()
                    .frame(width: size.width * 0.66)
                    .offset(y: -size.height * 0.08)

                VStack(spacing: 16) {
                    header
                    Spacer()
                    relicOffers(size: size)
                    controls
                }
                .padding(.horizontal, 14)
                .padding(.top, 18)
                .padding(.bottom, max(12, geo.safeAreaInsets.bottom + 8))
            }
            .scaleEffect(hasEntered ? 1 : 1.04)
            .opacity(hasEntered ? 1 : 0)
            .animation(.easeOut(duration: 0.45), value: hasEntered)
            .ignoresSafeArea()
        }
        .onAppear {
            withAnimation { hasEntered = true }
            AudioManager.shared.transitionToMusic(named: AudioManager.Track.collection.rawValue, fadeOutDuration: 0.4, fadeInDuration: 0.6)
        }
        .onDisappear {
            AudioManager.shared.transitionToMusic(named: AudioManager.Track.home.rawValue, fadeOutDuration: 0.35, fadeInDuration: 0.45)
        }
    }

    private var header: some View {
        HStack {
            statPill(icon: "heart.fill", value: "\(player?.currentHP ?? 0)", tint: .red)
            statPill(icon: "bitcoinsign.circle.fill", value: "\(player?.gold ?? 0)", tint: .yellow)
            Spacer()
            Button("Quitter") { onLeave() }
                .buttonStyle(.bordered)
                .tint(.white)
        }
    }

    private func relicOffers(size: CGSize) -> some View {
        let offers = interaction.relicOffers
        return ZStack(alignment: .bottom) {
            Image("shop_pedestal_slots")
                .resizable()
                .scaledToFit()
                .frame(width: min(size.width * 0.95, 520))
                .shadow(color: .black.opacity(0.6), radius: 18, y: 10)

            HStack(spacing: 8) {
                ForEach(offers) { offer in
                    relicCard(offer)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 14)
        }
    }

    private func relicCard(_ offer: ShopRelicOffer) -> some View {
        let playerGold = player?.gold ?? 0
        let affordable = playerGold >= offer.cost
        let disabled = !affordable || offer.isPurchased

        return VStack(spacing: 6) {
            ZStack {
                SpriteSheetAnimationView(imageName: "relic_glow_animation", frameCount: 2, fps: 2)
                    .frame(width: 70, height: 70)
                    .opacity(offer.isPurchased ? 0 : 0.7)

                Circle()
                    .fill(.black.opacity(0.55))
                    .frame(width: 58, height: 58)

                Text(String(offer.relic.name.prefix(1)))
                    .font(.title2.bold())
                    .foregroundStyle(.white)
            }

            Text(offer.relic.name)
                .font(.caption.bold())
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .foregroundStyle(.white)

            Text("\(offer.cost) or")
                .font(.caption2.bold())
                .foregroundStyle(affordable ? .yellow : .red)

            Text(offer.relic.description)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.85))
                .lineLimit(2)
                .multilineTextAlignment(.center)

            Button(offer.isPurchased ? "Achetée" : "Acheter") {
                onBuyRelic(offer.id)
            }
            .buttonStyle(.borderedProminent)
            .tint(offer.isPurchased ? .gray : .orange)
            .disabled(disabled)
            .font(.caption.bold())
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.black.opacity(0.44))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(.white.opacity(0.15), lineWidth: 1))
        )
        .opacity(offer.isPurchased ? 0.62 : 1)
    }

    private var controls: some View {
        Text("Choisissez vos reliques. Les offres déjà achetées restent visibles mais indisponibles.")
            .font(.caption)
            .foregroundStyle(.white.opacity(0.9))
            .multilineTextAlignment(.center)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private func statPill(icon: String, value: String, tint: Color) -> some View {
        Label(value, systemImage: icon)
            .font(.caption.bold())
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.black.opacity(0.5), in: Capsule())
            .overlay(Capsule().stroke(tint.opacity(0.8), lineWidth: 1))
    }
}

private struct SpriteSheetAnimationView: View {
    let imageName: String
    let frameCount: Int
    let fps: Double

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / max(fps, 1), paused: false)) { context in
            let time = context.date.timeIntervalSinceReferenceDate
            let frame = Int(time * max(fps, 1)) % max(frameCount, 1)

            GeometryReader { geo in
                let frameWidth = geo.size.width
                let totalWidth = frameWidth * CGFloat(max(frameCount, 1))

                Image(imageName)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: totalWidth, height: geo.size.height, alignment: .leading)
                    .offset(x: -CGFloat(frame) * frameWidth)
                    .clipped()
            }
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
