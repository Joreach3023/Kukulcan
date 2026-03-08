import SwiftUI
import UIKit
import AudioToolbox

private enum CombatOutcome {
    case win, loss
}

private enum TurnPhase {
    case playerTurn
    case playerEnding
    case enemyTurn
    case enemyDrawing
    case enemyPlaying
    case enemyResolving
    case enemyEnding
    case playerDrawing
}

private enum HitShakeProfile {
    case light
    case heavy

    var amplitude: CGFloat {
        switch self {
        case .light: return 8
        case .heavy: return 14
        }
    }

    var duration: TimeInterval {
        switch self {
        case .light: return 0.18
        case .heavy: return 0.24
        }
    }
}

private struct DamagePopup: Identifiable {
    let id = UUID()
    let value: Int
    let laneOffset: CGFloat
    let isIncoming: Bool
}

private struct RitualSequenceState {
    var dim: Double = 0
    var aura: Double = 0
    var projectile: CGFloat = 0
    var glyph: Double = 0
    var impact: Double = 0
}

private struct HealthSnapshot {
    let playerHP: Int
    let enemyHP: Int

    init(engine: GameEngine) {
        playerHP = engine.p1.hp
        enemyHP = engine.p2.hp
    }
}

struct CombatView: View {
    // Fournis un engine depuis l’extérieur si tu veux (collection/IA), sinon starter par défaut
    @StateObject private var engine: GameEngine
    private let aiLevel: Int
    var onWin: ((Int) -> Void)? = nil
    var onLoss: (() -> Void)? = nil
    private let winGold: Int
    private let lossGold: Int
    @Environment(\.dismiss) private var dismiss

    @State private var outcome: CombatOutcome? = nil

    init(engine: GameEngine? = nil, aiLevel: Int = 1, onWin: ((Int) -> Void)? = nil, onLoss: (() -> Void)? = nil, winGold: Int = 0, lossGold: Int = 0) {
        self.aiLevel = aiLevel
        self.onWin = onWin
        self.onLoss = onLoss
        self.winGold = winGold
        self.lossGold = lossGold
        if let e = engine {
            _engine = StateObject(wrappedValue: e)
        } else {
            let p1 = PlayerState(name: "Toi", deck: StarterFactory.playerDeck())
            let p2 = PlayerState(name: "IA",  deck: StarterFactory.randomDeck())
            _engine = StateObject(wrappedValue: GameEngine(p1: p1, p2: p2))
        }
    }

    // Sélections légères pour actions
    @State private var showTargetPickerForRitual = false
    @State private var ritualTargetSlot: Int? = nil
    @State private var pendingRitualHandIndex: Int? = nil

    @State private var showAttackPicker = false
    @State private var attackFromSlot: Int? = nil  // -1 = dieu

    @State private var selectedCard: Card? = nil

    @State private var showBloodRiver = false

    @State private var deckFrame: CGRect = .zero
    @State private var handCardFrames: [UUID: CGRect] = [:]
    @State private var pendingDrawCards: [Card] = []
    @State private var currentDrawFlight: DrawFlight? = nil
    @State private var drawProgress: CGFloat = 0
    @State private var openingHandCardIDs: Set<UUID> = []
    @State private var displayedHandCardIDs: Set<UUID> = []
    @State private var hiddenHandCardIDs: Set<UUID> = []
    @State private var hasAnimatedOpeningHand = false

    @State private var turnPhase: TurnPhase = .playerTurn
    @State private var turnBanner: String? = nil
    @State private var enemyDeckFrame: CGRect = .zero
    @State private var enemyHandFrame: CGRect = .zero
    @State private var enemyDrawProgress: CGFloat = 0
    @State private var isEnemyDrawAnimating = false
    @State private var enemyActionCard: Card? = nil
    @State private var enemyAttackPulse = false
    @State private var enemyAttackLineVisible = false
    @State private var combatShakeOffset: CGSize = .zero
    @State private var isShakingCombat = false
    @State private var incomingDamageFlash: Double = 0
    @State private var enemyHitBounce: CGFloat = 1
    @State private var ritualState = RitualSequenceState()
    @State private var ritualInProgress = false
    @State private var ritualTintColor: Color = .cyan
    @State private var damagePopups: [DamagePopup] = []

    // Drag & drop depuis la main vers le board
    @State private var draggingCardIndex: Int? = nil
    @State private var activeHandGestureIndex: Int? = nil
    @State private var hoveredHandCardID: UUID? = nil
    @State private var dragPosition: CGPoint = .zero
    @State private var hoveredSlot: Int? = nil
    @State private var slotFrames: [Int: CGRect] = [:]
    @State private var sacrificeFrame: CGRect = .zero
    @State private var hoveringSacrifice = false

    // Tailles adaptatives pour une hiérarchie plus claire sur mobile portrait
    private var isCompactPortrait: Bool {
        let screen = UIScreen.main.bounds
        return screen.height > screen.width
    }

    private var slotCardWidth: CGFloat { isCompactPortrait ? 70 : 64 }
    private var slotCardHeight: CGFloat { slotCardWidth * 1.4 }
    private var deckCardWidth: CGFloat { slotCardWidth }
    private var deckCardHeight: CGFloat { slotCardHeight }
    private var handCardWidth: CGFloat { isCompactPortrait ? 104 : 92 }
    private var handCardHeight: CGFloat { handCardWidth * 1.4 }
    private var handCardSpacing: CGFloat { isCompactPortrait ? -48 : -60 }
    private let handVerticalDragThreshold: CGFloat = 34
    private let handVerticalDragDominanceRatio: CGFloat = 1.15
    private let enemyTurnStepDelay: TimeInterval = 1.4
    private var combatSceneHorizontalPadding: CGFloat { isCompactPortrait ? 12 : 10 }
    private let combatRowSpacing: CGFloat = 10
    private var combatContentWidth: CGFloat { (slotCardWidth * 4) + (combatRowSpacing * 3) }

    private var enemyAIConfiguration: EnemyAI.Configuration {
        switch aiLevel {
        case 1:
            return .init(profile: .defensive, tuning: .defensive)
        case 2:
            return .init(profile: .balanced, tuning: .balanced)
        case 3:
            return .init(profile: .aggressive, tuning: .balanced)
        case 4:
            return .init(profile: .aggressive, tuning: .aggressive)
        default:
            return .init(profile: .balanced, tuning: .aggressive)
        }
    }

    private var enemyAI: EnemyAI {
        EnemyAI(configuration: enemyAIConfiguration)
    }

    private var isPlayerInteractionEnabled: Bool {
        turnPhase == .playerTurn && outcome == nil
    }

    private var playerState: PlayerState {
        engine.p1
    }

    private var enemyState: PlayerState {
        engine.p2
    }

    private var canCurrentPlayerAttack: Bool {
        let player = engine.current
        return player.godSlot?.hasActedThisTurn == false
            || player.board.contains { $0?.hasActedThisTurn == false }
    }

    private var hasAvailablePlayerAction: Bool {
        let player = engine.current

        let hasReadyAttacker = canCurrentPlayerAttack && (
            player.board.contains { $0?.hasActedThisTurn == false }
            || player.godSlot?.hasActedThisTurn == false
        )

        if hasReadyAttacker {
            return true
        }

        for card in player.hand {
            switch card.type {
            case .common:
                return true // au minimum: sacrifice
            case .ritual:
                return true
            case .god:
                if player.godSlot == nil && player.blood >= card.bloodCost {
                    return true
                }
            }
        }

        return false
    }

    private var playerActionStateSignature: String {
        let player = engine.current
        let handState = player.hand
            .map { "\($0.id.uuidString)-\($0.type.rawValue)-\($0.bloodCost)" }
            .joined(separator: "|")
        let boardState = player.board
            .map { inst in
                guard let inst else { return "empty" }
                return "\(inst.base.id.uuidString)-\(inst.hasActedThisTurn)-\(inst.currentHP)"
            }
            .joined(separator: "|")
        let godState: String
        if let god = player.godSlot {
            godState = "\(god.base.id.uuidString)-\(god.hasActedThisTurn)-\(god.currentHP)"
        } else {
            godState = "none"
        }

        return [
            String(turnPhaseHash),
            String(engine.currentPlayerIsP1),
            String(outcome != nil),
            String(player.blood),
            handState,
            boardState,
            godState
        ].joined(separator: "#")
    }

    private var turnPhaseHash: Int {
        switch turnPhase {
        case .playerTurn: return 0
        case .playerEnding: return 1
        case .enemyTurn: return 2
        case .enemyDrawing: return 3
        case .enemyPlaying: return 4
        case .enemyResolving: return 5
        case .enemyEnding: return 6
        case .playerDrawing: return 7
        }
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Fond visuel du combat
                CombatBackground()

                VStack(spacing: 8) {
                    header

                    // Plateau adverse miroité
                    opponentBoard
                        .scaleEffect(enemyHitBounce)

                    Spacer(minLength: 2)

                    // Board du joueur (3 slots)
                    boardArea

                    // Zone Dieu + Sacrifice + Défausse
                    zonesRow

                    Spacer(minLength: 0)
                }
                .frame(maxWidth: 560, maxHeight: .infinity, alignment: .center)
                .padding(.horizontal, combatSceneHorizontalPadding)
                .padding(.top, 8)
                .padding(.bottom, max(8, geometry.safeAreaInsets.bottom))
                .frame(maxWidth: .infinity)
                .offset(combatShakeOffset)
                .overlay(alignment: .center) { ritualVisualOverlay }
                .overlay(alignment: .top) { damagePopupsOverlay }

                if showBloodRiver {
                    BloodRiverView()
                        .transition(.move(edge: .top))
                        .allowsHitTesting(false)
                }

                if let idx = draggingCardIndex {
                    CardView(card: engine.current.hand[idx], faceUp: true, width: handCardWidth)
                        .position(dragPosition)
                        .shadow(radius: 8)
                        .zIndex(1)
                }

                if let flight = currentDrawFlight {
                    DrawFlyingCardView(card: flight.card, progress: drawProgress, start: flight.start, end: flight.end, width: handCardWidth)
                        .zIndex(2)
                        .allowsHitTesting(false)
                }

                if isEnemyDrawAnimating {
                    EnemyDrawFlightView(progress: enemyDrawProgress, start: CGPoint(x: enemyDeckFrame.midX, y: enemyDeckFrame.midY), end: CGPoint(x: enemyHandFrame.midX, y: enemyHandFrame.midY), width: deckCardWidth)
                        .zIndex(3)
                        .allowsHitTesting(false)
                }

                if let enemyActionCard {
                    enemyActionOverlay(enemyActionCard)
                        .zIndex(4)
                        .allowsHitTesting(false)
                }

                if enemyAttackLineVisible {
                    EnemyAttackLineView(pulsing: enemyAttackPulse)
                        .zIndex(4)
                        .allowsHitTesting(false)
                }

                Color.red
                    .opacity(incomingDamageFlash)
                    .ignoresSafeArea()
                    .zIndex(4)
                    .allowsHitTesting(false)

                if let turnBanner {
                    Text(turnBanner)
                        .font(.title2.bold())
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(.black.opacity(0.75))
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                        .transition(.opacity.combined(with: .scale))
                        .zIndex(5)
                        .allowsHitTesting(false)
                }
            }
        }
        .onAppear {
            NotificationCenter.default.post(name: .combatViewDidAppear, object: nil)
            // Démarrer la partie si pas déjà fait
            if engine.p1.hand.isEmpty && engine.p2.hand.isEmpty {
                engine.start()
            }
            queueOpeningHandAnimationIfNeeded()
            configureInitialTurnFlowIfNeeded()
            AudioManager.shared.transitionToMusic(named: AudioManager.Track.combat.rawValue)
        }
        .onDisappear {
            NotificationCenter.default.post(name: .combatViewDidDisappear, object: nil)
        }
        .onChange(of: engine.lastDrawnCards) { _, cards in
            guard engine.currentPlayerIsP1, !cards.isEmpty else { return }
            enqueueDrawAnimation(cards)
        }
        .onChange(of: engine.current.sacrificeSlot?.id) {
            guard engine.current.sacrificeSlot != nil else { return }
            let generator = UIImpactFeedbackGenerator(style: .heavy)
            generator.impactOccurred()
            showBloodRiver = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                showBloodRiver = false
            }
        }
        .onChange(of: playerActionStateSignature) {
            maybeAutoEndPlayerTurn()
        }
        .sheet(isPresented: $showTargetPickerForRitual) {
            ritualTargetSheet
                .presentationDetents([.height(280)])
        }
        .sheet(isPresented: $showAttackPicker) {
            attackTargetSheet
                .presentationDetents([.height(320)])
        }
        .navigationTitle("Combats")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .safeAreaInset(edge: .bottom) {
            handStrip
                .padding(.horizontal, 12)
                .padding(.top, 10)
                .padding(.bottom, 10)
                .allowsHitTesting(isPlayerInteractionEnabled)
                .opacity(isPlayerInteractionEnabled ? 1 : 0.7)
        }
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Button("Fin du tour") {
                    endPlayerTurnAndRunEnemySequence()
                }
                .disabled(!isPlayerInteractionEnabled)
                Button("Quitter") {
                    quitCombat()
                }
            }
        }
        .fullScreenCover(item: $selectedCard) { card in
            CardDetailView(card: card) { selectedCard = nil }
        }
        .onChange(of: engine.p1.hp) { _, hp in
            if hp <= 0 && outcome == nil {
                outcome = .loss
                onLoss?()
            }
        }
        .onChange(of: engine.p2.hp) { _, hp in
            if hp <= 0 && outcome == nil {
                outcome = .win
                onWin?(aiLevel)
            }
        }
        .coordinateSpace(name: "combatArea")
        .overlay {
            if let outcome {
                let gold = outcome == .win ? winGold : lossGold
                CombatResultView(isWin: outcome == .win, gold: gold) {
                    dismiss()
                }
            }
        }
    }

    // MARK: - Header (scores / sang)
    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(engine.p1.name)
                    .font(.headline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .foregroundColor(.white)
                HStack(spacing: 10) {
                    HStack(spacing: 4) {
                        Image(systemName: "heart.fill")
                            .foregroundColor(.green)
                        Text("\(engine.p1.hp)")
                            .foregroundColor(.white)
                    }
                    HStack(spacing: 4) {
                        Image(systemName: "drop.fill")
                            .foregroundColor(.red)
                        Text("\(engine.p1.blood)")
                            .foregroundColor(.white)
                    }
                }
                .font(.subheadline)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text(engine.p2.name)
                    .font(.headline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .foregroundColor(.white)
                HStack(spacing: 10) {
                    HStack(spacing: 4) {
                        Image(systemName: "heart.fill")
                            .foregroundColor(.green)
                        Text("\(engine.p2.hp)")
                            .foregroundColor(.white)
                    }
                    HStack(spacing: 4) {
                        Image(systemName: "drop.fill")
                            .foregroundColor(.red)
                        Text("\(engine.p2.blood)")
                            .foregroundColor(.white)
                    }
                }
                .font(.subheadline)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(.black.opacity(0.42), in: RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Plateau adverse (miroir vertical)
    private var opponentBoard: some View {
        VStack(spacing: 6) {
            opponentZonesRow
            opponentBoardArea
        }
        .rotationEffect(.degrees(180))
    }

    private var opponentBoardArea: some View {
        VStack(spacing: 6) {
            HStack(spacing: combatRowSpacing) {
                // `opponentBoard` est retourné à 180°: le slot fantôme doit être
                // placé en tête pour rester visuellement à droite après rotation.
                Color.clear
                    .frame(width: slotCardWidth, height: slotCardHeight)

                ForEach(Array(enemyState.board.indices.reversed()), id: \.self) { i in
                    let inst = enemyState.board[i]
                    slotView(for: inst?.base, hp: inst?.currentHP)
                        .rotationEffect(.degrees(180))
                }
            }
            .frame(width: combatContentWidth, alignment: .leading)
        }
    }

    private var opponentZonesRow: some View {
        HStack(spacing: combatRowSpacing) {
            VStack(spacing: 6) {
                ZStack {
                    if enemyState.deck.isEmpty {
                        emptySlot(width: deckCardWidth, height: deckCardHeight)
                    } else {
                        CardBackView(width: deckCardWidth).frame(width: deckCardWidth, height: deckCardHeight)
                        Text("\(enemyState.deck.count)")
                            .font(.headline.bold())
                            .foregroundStyle(.white)
                            .rotationEffect(.degrees(180))
                    }
                }
                .background(
                    GeometryReader { geo in
                        Color.clear
                            .onAppear { enemyDeckFrame = geo.frame(in: .named("combatArea")) }
                            .onChange(of: geo.frame(in: .named("combatArea"))) { _, frame in enemyDeckFrame = frame }
                    }
                )
            }

            VStack(spacing: 6) {
                Text("Main IA")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .rotationEffect(.degrees(180))
                ZStack(alignment: .center) {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.white.opacity(0.16))
                        .frame(width: deckCardWidth + 8, height: deckCardHeight + 8)

                    if enemyState.hand.isEmpty {
                        Text("0")
                            .font(.caption.bold())
                            .foregroundStyle(.white)
                            .rotationEffect(.degrees(180))
                    } else {
                        HStack(spacing: -deckCardWidth * 0.65) {
                            ForEach(0..<min(enemyState.hand.count, 4), id: \.self) { _ in
                                CardBackView(width: deckCardWidth * 0.68)
                                    .rotationEffect(.degrees(180))
                            }
                        }
                    }
                }
                    .background(
                        GeometryReader { geo in
                            Color.clear
                                .onAppear { enemyHandFrame = geo.frame(in: .named("combatArea")) }
                                .onChange(of: geo.frame(in: .named("combatArea"))) { _, frame in enemyHandFrame = frame }
                        }
                    )
            }

            VStack(spacing: 6) {
                slotView(for: enemyState.godSlot?.base, hp: enemyState.godSlot?.currentHP)
                    .rotationEffect(.degrees(180))
                    .frame(width: slotCardWidth, height: slotCardHeight)
            }

            VStack(spacing: 6) {
                if let inst = enemyState.sacrificeSlot {
                    CardView(card: inst.base, faceUp: true, width: slotCardWidth)
                        .rotationEffect(.degrees(180))
                } else {
                    emptySlot(width: slotCardWidth, height: slotCardHeight)
                }
            }
        }
        .frame(width: combatContentWidth, alignment: .leading)
    }

    // MARK: - Board du joueur
    private var boardArea: some View {
        VStack(spacing: 6) {
            Text("Tes unités")
                .font(.caption)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .foregroundStyle(.secondary)
            HStack(spacing: combatRowSpacing) {
                ForEach(engine.current.board.indices, id: \.self) { i in
                    let inst = engine.current.board[i]
                    // Carte en jeu
                    ZStack(alignment: .topTrailing) {
                        slotView(for: inst?.base, hp: inst?.currentHP)
                            .background(
                                GeometryReader { geo in
                                    let frame = geo.frame(in: .named("combatArea"))
                                    Color.clear
                                        .onAppear { slotFrames[i] = frame }
                                        .onChange(of: frame) { _, newFrame in slotFrames[i] = newFrame }
                                }
                            )
                            .overlay(
                                VStack(spacing: 6) {
                                    // Attaquer depuis ce slot
                                    if inst != nil {
                                        Button {
                                            guard isPlayerInteractionEnabled else { return }
                                            attackFromSlot = i
                                            showAttackPicker = true
                                        } label: {
                                            Image(systemName: "target")
                                                .font(.caption2.bold())
                                                .padding(6)
                                                .background(Circle().fill(.orange))
                                                .foregroundStyle(.white)
                                        }
                                        .disabled(inst?.hasActedThisTurn != false || !canCurrentPlayerAttack)
                                        .opacity((inst?.hasActedThisTurn == true || !canCurrentPlayerAttack) ? 0.45 : 1)
                                    }
                                }
                                .padding(6)
                                , alignment: .topTrailing
                            )
                    }
                }

                Color.clear
                    .frame(width: slotCardWidth, height: slotCardHeight)
            }
            .frame(width: combatContentWidth, alignment: .leading)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 6)
        .padding(.vertical, 8)
        .background(.black.opacity(0.28), in: RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Zones spéciales (Dieu / Sacrifice / Défausse)
    private var zonesRow: some View {
        HStack(spacing: combatRowSpacing) {
            VStack(spacing: 6) {
                Text("Pioche")
                    .font(.caption)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .foregroundStyle(.secondary)
                ZStack {
                    if playerState.deck.isEmpty {
                        emptySlot(width: deckCardWidth, height: deckCardHeight)
                    } else {
                        CardBackView(width: deckCardWidth).frame(width: deckCardWidth, height: deckCardHeight)
                        Text("\(playerState.deck.count)")
                            .font(.headline.bold())
                            .foregroundStyle(.white)
                    }
                }
                .background(
                    GeometryReader { geo in
                        Color.clear
                            .onAppear { deckFrame = geo.frame(in: .named("combatArea")) }
                            .onChange(of: geo.frame(in: .named("combatArea"))) { _, frame in deckFrame = frame }
                    }
                )
            }

            VStack(spacing: 6) {
                Text("Ton dieu")
                    .font(.caption)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .foregroundStyle(.secondary)
                ZStack(alignment: .topTrailing) {
                    slotView(for: playerState.godSlot?.base, hp: playerState.godSlot?.currentHP)
                        .frame(width: slotCardWidth, height: slotCardHeight)
                    if playerState.godSlot != nil {
                        Button {
                            guard isPlayerInteractionEnabled else { return }
                            attackFromSlot = -1
                            showAttackPicker = true
                        } label: {
                            Image(systemName: "target")
                                .font(.caption2.bold())
                                .padding(6)
                                .background(Circle().fill(.orange))
                                .foregroundStyle(.white)
                        }
                        .disabled(playerState.godSlot?.hasActedThisTurn != false || !canCurrentPlayerAttack)
                        .opacity((playerState.godSlot?.hasActedThisTurn == true || !canCurrentPlayerAttack) ? 0.45 : 1)
                        .padding(6)
                    }
                }
            }

            VStack(spacing: 6) {
                Text("Sacrifice")
                    .font(.caption)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .foregroundStyle(.secondary)
                ZStack {
                    if let inst = playerState.sacrificeSlot {
                        CardView(card: inst.base, faceUp: true, width: slotCardWidth) {
                            selectedCard = inst.base
                        }
                        .rotationEffect(.degrees(180))
                        .overlay(Text("+1 Sang").font(.caption2.bold()).padding(4).background(.black.opacity(0.6)).clipShape(Capsule()).foregroundStyle(.white), alignment: .bottom)
                    } else {
                        emptySlot(width: slotCardWidth, height: slotCardHeight)
                    }
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.yellow, lineWidth: 3)
                        .opacity(hoveringSacrifice ? 1 : 0)
                }
                .frame(width: slotCardWidth, height: slotCardHeight)
                .background(
                    GeometryReader { geo in
                        Color.clear
                            .onAppear { sacrificeFrame = geo.frame(in: .named("combatArea")) }
                            .onChange(of: geo.frame(in: .named("combatArea"))) { _, frame in sacrificeFrame = frame }
                    }
                )
            }

            VStack(spacing: 6) {
                Text("Défausse")
                    .font(.caption)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .foregroundStyle(.secondary)
                ZStack {
                    emptySlot(width: slotCardWidth, height: slotCardHeight)
                    if !playerState.discard.isEmpty {
                        Text("\(playerState.discard.count)")
                            .font(.headline.bold())
                            .padding(8)
                            .background(Circle().fill(.black.opacity(0.6)))
                            .foregroundStyle(.white)
                    }
                }
            }
        }
        .frame(width: combatContentWidth, alignment: .leading)
        .padding(.horizontal, 6)
        .padding(.vertical, 8)
        .background(.black.opacity(0.24), in: RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Main du joueur
    private var handStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack {
                Spacer(minLength: 0)

                HStack(spacing: handCardSpacing) {
                    ForEach(playerState.hand.indices, id: \.self) { idx in
                        let c = playerState.hand[idx]
                        let isHovered = hoveredHandCardID == c.id
                        let isDragging = draggingCardIndex == idx
                        CardView(card: c, faceUp: true, width: handCardWidth) {
                            hoveredHandCardID = c.id
                            selectedCard = c
                        }
                        .rotation3DEffect(.degrees(12), axis: (x: 1, y: 0, z: 0))
                        .scaleEffect(isHovered ? 1.08 : 1.0)
                        .brightness(isHovered ? 0.08 : 0)
                        .shadow(color: .yellow.opacity(isHovered ? 0.35 : 0), radius: isHovered ? 12 : 0, x: 0, y: isHovered ? 6 : 0)
                        .zIndex(isDragging ? 400 : (isHovered ? 300 : Double(idx)))
                        .opacity(((openingHandCardIDs.contains(c.id) && !displayedHandCardIDs.contains(c.id)) || hiddenHandCardIDs.contains(c.id) || isDragging) ? 0 : 1)
                        .allowsHitTesting(!openingHandCardIDs.contains(c.id) || displayedHandCardIDs.contains(c.id))
                        .background(
                            GeometryReader { geo in
                                Color.clear.preference(key: HandCardFramePreferenceKey.self, value: [c.id: geo.frame(in: .named("combatArea"))])
                            }
                        )
                        .animation(.spring(response: 0.22, dampingFraction: 0.82), value: isHovered)
                        .gesture(
                            DragGesture(minimumDistance: 0, coordinateSpace: .named("combatArea"))
                                .onChanged { value in
                                    guard isPlayerInteractionEnabled else { return }
                                    if activeHandGestureIndex == nil {
                                        activeHandGestureIndex = idx
                                    }
                                    guard activeHandGestureIndex == idx else { return }

                                    hoveredHandCardID = handCardID(at: value.location)

                                    if draggingCardIndex == nil {
                                        let upwardDistance = -value.translation.height
                                        let horizontalDistance = abs(value.translation.width)
                                        let isMostlyVerticalForward = upwardDistance > handVerticalDragThreshold
                                            && upwardDistance > horizontalDistance * handVerticalDragDominanceRatio

                                        guard isMostlyVerticalForward else {
                                            hoveredSlot = nil
                                            hoveringSacrifice = false
                                            return
                                        }

                                        draggingCardIndex = idx
                                        hoveredHandCardID = nil
                                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                    }

                                    dragPosition = value.location
                                    if let slot = slotFrames.first(where: { $0.value.contains(value.location) })?.key {
                                        if hoveredSlot != slot {
                                            hoveredSlot = slot
                                            hoveringSacrifice = false
                                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                        }
                                    } else if sacrificeFrame.contains(value.location) {
                                        if !hoveringSacrifice {
                                            hoveringSacrifice = true
                                            hoveredSlot = nil
                                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                        }
                                    } else {
                                        hoveredSlot = nil
                                        hoveringSacrifice = false
                                    }
                                }
                                .onEnded { _ in
                                    guard activeHandGestureIndex == idx else { return }
                                    defer {
                                        activeHandGestureIndex = nil
                                        draggingCardIndex = nil
                                        hoveredSlot = nil
                                        hoveringSacrifice = false
                                        hoveredHandCardID = nil
                                    }

                                    guard isPlayerInteractionEnabled else {
                                        return
                                    }

                                    guard draggingCardIndex == idx else { return }

                                    if let slot = hoveredSlot {
                                        engine.playCommonToBoard(handIndex: idx, slot: slot)
                                    } else if hoveringSacrifice {
                                        engine.sacrificeCommon(handIndex: idx)
                                    }
                                }
                        )
                        .overlay(alignment: .bottom) {
                            actionButtonsForHandCard(c, index: idx)
                                .padding(.bottom, 6)
                        }
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 4)
            .frame(maxWidth: .infinity)
        }
        .frame(minHeight: handCardHeight + 34, alignment: .center)
        .onPreferenceChange(HandCardFramePreferenceKey.self) { frames in
            handCardFrames.merge(frames) { _, new in new }
            processPendingDrawAnimations()
        }
    }

    private func handCardID(at location: CGPoint) -> UUID? {
        let matching = playerState.hand
            .enumerated()
            .filter { handCardFrames[$0.element.id]?.contains(location) == true }

        return matching.max(by: { $0.offset < $1.offset })?.element.id
    }

    // Boutons d’actions sur une carte en main
    private func actionButtonsForHandCard(_ c: Card, index: Int) -> some View {
        HStack(spacing: 6) {
            switch c.type {
            case .common:
                Menu {
                    Button("Poser → Empl. 1") { engine.playCommonToBoard(handIndex: index, slot: 0) }
                    Button("Poser → Empl. 2") { engine.playCommonToBoard(handIndex: index, slot: 1) }
                    Button("Poser → Empl. 3") { engine.playCommonToBoard(handIndex: index, slot: 2) }
                    Divider()
                    Button("Sacrifier (+1 Sang)") { engine.sacrificeCommon(handIndex: index) }
                } label: {
                    labelChip("Jouer", system: "hand.tap.fill")
                }
                .disabled(!isPlayerInteractionEnabled)

            case .ritual:
                Button {
                    guard isPlayerInteractionEnabled else { return }
                    guard let kind = c.ritual else { return }
                    if ritualNeedsTarget(kind) {
                        pendingRitualHandIndex = index
                        ritualTargetSlot = firstOccupiedBoardSlot()
                        showTargetPickerForRitual = true
                    } else {
                        performPlayerRitual(handIndex: index)
                    }
                } label: { labelChip("Rituel", system: "wand.and.stars") }
                .disabled(!isPlayerInteractionEnabled)

            case .god:
                Button {
                    guard isPlayerInteractionEnabled else { return }
                    engine.invokeGod(handIndex: index)
                } label: { labelChip("Invoquer", system: "bolt.heart.fill") }
                .disabled(!isPlayerInteractionEnabled || playerState.blood < c.bloodCost || playerState.godSlot != nil)
            }
        }
    }


    private func queueOpeningHandAnimationIfNeeded() {
        guard !hasAnimatedOpeningHand else { return }
        hasAnimatedOpeningHand = true
        let openingHand = engine.p1.hand
        guard !openingHand.isEmpty else { return }
        openingHandCardIDs = Set(openingHand.map(\.id))
        displayedHandCardIDs.removeAll()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            enqueueDrawAnimation(openingHand)
        }
    }

    private func enqueueDrawAnimation(_ cards: [Card]) {
        pendingDrawCards.append(contentsOf: cards)
        processPendingDrawAnimations()
    }

    private func processPendingDrawAnimations() {
        guard currentDrawFlight == nil, !pendingDrawCards.isEmpty else { return }
        guard deckFrame != .zero else { return }

        let card = pendingDrawCards.removeFirst()
        guard let targetFrame = handCardFrames[card.id] else {
            pendingDrawCards.insert(card, at: 0)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                processPendingDrawAnimations()
            }
            return
        }

        hiddenHandCardIDs.insert(card.id)
        currentDrawFlight = DrawFlight(card: card, start: CGPoint(x: deckFrame.midX, y: deckFrame.midY), end: CGPoint(x: targetFrame.midX, y: targetFrame.midY))
        drawProgress = 0

        withAnimation(.timingCurve(0.22, 0.95, 0.18, 1, duration: 0.95)) {
            drawProgress = 1
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.95) {
            hiddenHandCardIDs.remove(card.id)
            displayedHandCardIDs.insert(card.id)
            currentDrawFlight = nil
            drawProgress = 0
            processPendingDrawAnimations()
        }
    }

    private func endPlayerTurnAndRunEnemySequence() {
        guard isPlayerInteractionEnabled else { return }
        playEndTurnSound()
        turnPhase = .playerEnding
        showTurnBanner("Enemy Turn")

        DispatchQueue.main.asyncAfter(deadline: .now() + enemyTurnStepDelay) {
            runEnemyTurnSequence()
        }
    }

    private func maybeAutoEndPlayerTurn() {
        guard isPlayerInteractionEnabled, !hasAvailablePlayerAction else { return }
        endPlayerTurnAndRunEnemySequence()
    }

    private func quitCombat() {
        onLoss?()
        dismiss()
    }

    private func runEnemyTurnSequence() {
        guard outcome == nil else { return }

        if engine.currentPlayerIsP1 {
            engine.endTurn()
        }

        turnPhase = .enemyTurn

        runEnemyDrawStep {
            runEnemyPlayStep {
                runEnemyResolveStep {
                    runEnemyEndStep()
                }
            }
        }
    }

    private func configureInitialTurnFlowIfNeeded() {
        guard turnPhase == .playerTurn else { return }

        if engine.currentPlayerIsP1 {
            showTurnBanner("Player Turn")
            return
        }

        showTurnBanner("Enemy Turn")
        turnPhase = .enemyTurn
        DispatchQueue.main.asyncAfter(deadline: .now() + enemyTurnStepDelay) {
            runEnemyTurnSequence()
        }
    }

    private func runEnemyDrawStep(completion: @escaping () -> Void) {
        turnPhase = .enemyDrawing
        let didDraw = !engine.current.deck.isEmpty
        engine.drawForCurrent(1)

        if didDraw {
            animateEnemyDraw()
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.25) {
                completion()
            }
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                completion()
            }
        }
    }

    private func runEnemyPlayStep(completion: @escaping () -> Void) {
        turnPhase = .enemyPlaying
        if let action = chooseEnemyAction() {
            enemyActionCard = action.card
            let didExecute = action.execute(on: engine)
            if !didExecute {
                enemyActionCard = nil
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + enemyTurnStepDelay) {
                completion()
            }
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                completion()
            }
        }
    }

    private func runEnemyResolveStep(completion: @escaping () -> Void) {
        turnPhase = .enemyResolving

        let enemyHasAttacker = engine.current.board.contains { $0 != nil } || engine.current.godSlot != nil
        if enemyHasAttacker {
            enemyAttackLineVisible = true
            withAnimation(.easeInOut(duration: 0.25).repeatCount(2, autoreverses: true)) {
                enemyAttackPulse.toggle()
            }
        }

        performEnemyAttacks()

        DispatchQueue.main.asyncAfter(deadline: .now() + enemyTurnStepDelay) {
            enemyAttackLineVisible = false
            enemyAttackPulse = false
            completion()
        }
    }

    private func runEnemyEndStep() {
        turnPhase = .enemyEnding
        enemyActionCard = nil
        engine.endTurn()
        turnPhase = .playerDrawing
        showTurnBanner("Player Turn")

        DispatchQueue.main.asyncAfter(deadline: .now() + enemyTurnStepDelay) {
            turnPhase = .playerTurn
        }
    }

    private func showTurnBanner(_ text: String) {
        withAnimation(.easeInOut(duration: 0.2)) {
            turnBanner = text
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            withAnimation(.easeInOut(duration: 0.2)) {
                turnBanner = nil
            }
        }
    }

    private func animateEnemyDraw() {
        guard enemyDeckFrame != .zero, enemyHandFrame != .zero else { return }
        isEnemyDrawAnimating = true
        enemyDrawProgress = 0
        withAnimation(.timingCurve(0.22, 0.95, 0.18, 1, duration: 0.95)) {
            enemyDrawProgress = 1
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.95) {
            isEnemyDrawAnimating = false
            enemyDrawProgress = 0
        }
    }

    private func chooseEnemyAction() -> EnemyAction? {
        enemyAI.chooseBestAction(engine: engine)
    }

    private func performEnemyAttacks() {
        let plan = enemyAI.chooseAttackPlan(engine: engine)
        for attack in plan {
            performEnemyAttack(from: attack.attackerSlot, to: attack.target)
        }
    }

    private func performPlayerAttack(from slot: Int, to target: Target) {
        let before = HealthSnapshot(engine: engine)
        engine.attack(from: slot, to: target)
        let after = HealthSnapshot(engine: engine)
        applyHitFeedback(before: before, after: after, initiatedByPlayer: true)
    }

    private func performEnemyAttack(from slot: Int, to target: Target) {
        let before = HealthSnapshot(engine: engine)
        engine.attack(from: slot, to: target)
        let after = HealthSnapshot(engine: engine)
        applyHitFeedback(before: before, after: after, initiatedByPlayer: false)
    }

    private func performPlayerRitual(handIndex: Int, targetSlot: Int? = nil) {
        guard handIndex >= 0, handIndex < engine.current.hand.count else { return }
        let ritual = engine.current.hand[handIndex].ritual
        playRitualSequence(kind: ritual)
        engine.playRitual(handIndex: handIndex, targetSlot: targetSlot)
    }

    private func applyHitFeedback(before: HealthSnapshot, after: HealthSnapshot, initiatedByPlayer: Bool) {
        let enemyDamage = max(0, before.enemyHP - after.enemyHP)
        let playerDamage = max(0, before.playerHP - after.playerHP)

        if enemyDamage > 0 {
            triggerCombatShake(.light)
            bounceEnemyBoard()
            spawnDamagePopup(value: enemyDamage, isIncoming: false)
        }

        if playerDamage > 0 {
            triggerCombatShake(.heavy)
            spawnDamagePopup(value: playerDamage, isIncoming: true)
            triggerIncomingDamageFlash()
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }

        if enemyDamage == 0 && playerDamage == 0 && initiatedByPlayer {
            triggerCombatShake(.light)
        }
    }

    private func triggerCombatShake(_ profile: HitShakeProfile) {
        guard !isShakingCombat else { return }
        isShakingCombat = true
        withAnimation(.easeInOut(duration: profile.duration / 4)) {
            combatShakeOffset = CGSize(width: profile.amplitude, height: 0)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + profile.duration / 4) {
            withAnimation(.easeInOut(duration: profile.duration / 4)) {
                combatShakeOffset = CGSize(width: -profile.amplitude * 0.65, height: 0)
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + profile.duration / 2) {
            withAnimation(.easeOut(duration: profile.duration / 2)) {
                combatShakeOffset = .zero
            }
            isShakingCombat = false
        }
    }

    private func bounceEnemyBoard() {
        withAnimation(.spring(response: 0.16, dampingFraction: 0.55)) {
            enemyHitBounce = 1.06
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.14) {
            withAnimation(.spring(response: 0.22, dampingFraction: 0.85)) {
                enemyHitBounce = 1
            }
        }
    }

    private func triggerIncomingDamageFlash() {
        withAnimation(.easeOut(duration: 0.12)) {
            incomingDamageFlash = 0.22
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            withAnimation(.easeIn(duration: 0.2)) {
                incomingDamageFlash = 0
            }
        }
    }

    private func spawnDamagePopup(value: Int, isIncoming: Bool) {
        let popup = DamagePopup(
            value: value,
            laneOffset: CGFloat.random(in: -22...22),
            isIncoming: isIncoming
        )
        damagePopups.append(popup)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            damagePopups.removeAll { $0.id == popup.id }
        }
    }

    private func playRitualSequence(kind: RitualKind?) {
        guard !ritualInProgress else { return }
        ritualInProgress = true
        ritualTintColor = ritualTint(for: kind)

        withAnimation(.easeOut(duration: 0.3)) {
            ritualState.dim = 0.28
            ritualState.aura = 1
            ritualState.glyph = 0.75
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
            withAnimation(.easeInOut(duration: 0.3)) {
                ritualState.projectile = 1
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
            withAnimation(.easeOut(duration: 0.2)) {
                ritualState.impact = 1
            }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.82) {
            withAnimation(.easeInOut(duration: 0.25)) {
                ritualState = RitualSequenceState()
            }
            ritualInProgress = false
        }
    }

    private func ritualTint(for kind: RitualKind?) -> Color {
        switch kind {
        case .obsidianKnife:
            return Color(red: 0.4, green: 0.92, blue: 0.85)
        case .bloodAltar:
            return Color(red: 0.58, green: 0.08, blue: 0.12)
        case .forestCharm:
            return Color(red: 0.98, green: 0.82, blue: 0.24)
        case nil:
            return Color.cyan
        }
    }

    private var ritualVisualOverlay: some View {
        GeometryReader { geo in
            let source = CGPoint(x: geo.size.width * 0.42, y: geo.size.height * 0.72)
            let target = CGPoint(x: geo.size.width * 0.56, y: geo.size.height * 0.26)
            let projectileX = source.x + (target.x - source.x) * ritualState.projectile
            let projectileY = source.y + (target.y - source.y) * ritualState.projectile
            let tint = ritualTintColor

            ZStack {
                Color.black
                    .opacity(ritualState.dim)
                    .ignoresSafeArea()

                Circle()
                    .fill(tint.opacity(0.28))
                    .frame(width: 150, height: 150)
                    .overlay(Circle().stroke(tint.opacity(0.9), lineWidth: 2.2))
                    .scaleEffect(0.85 + (ritualState.aura * 0.25))
                    .position(source)
                    .blur(radius: 0.6)

                Image(systemName: "seal.fill")
                    .font(.system(size: 52))
                    .foregroundStyle(tint.opacity(0.45))
                    .position(x: source.x, y: source.y - 10)
                    .opacity(ritualState.glyph)
                    .rotationEffect(.degrees(ritualState.glyph * 36))

                Circle()
                    .fill(tint)
                    .frame(width: 22, height: 22)
                    .position(x: projectileX, y: projectileY)
                    .opacity(ritualState.projectile > 0 ? 0.95 : 0)
                    .shadow(color: tint, radius: 10)

                Circle()
                    .fill(Color.white.opacity(0.85))
                    .frame(width: 124, height: 124)
                    .position(target)
                    .opacity(ritualState.impact)
                    .blur(radius: 2)
            }
            .allowsHitTesting(false)
            .opacity(ritualInProgress ? 1 : 0)
        }
    }

    private var damagePopupsOverlay: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(damagePopups) { popup in
                    Text("-\(popup.value)")
                        .font(.title3.bold())
                        .foregroundStyle(popup.isIncoming ? .red : .white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.black.opacity(0.55), in: Capsule())
                        .position(
                            x: (geo.size.width * 0.52) + popup.laneOffset,
                            y: popup.isIncoming ? geo.size.height * 0.72 : geo.size.height * 0.24
                        )
                        .transition(.opacity.combined(with: .scale))
                }
            }
            .allowsHitTesting(false)
        }
    }

    private func enemyActionOverlay(_ card: Card) -> some View {
        VStack(spacing: 8) {
            Text("Enemy plays")
                .font(.caption.bold())
                .foregroundStyle(.white.opacity(0.9))
            CardView(card: card, faceUp: true, width: handCardWidth * 0.8)
                .rotationEffect(.degrees(180))
                .shadow(radius: 10)
        }
        .padding(10)
        .background(.black.opacity(0.55))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(.top, 84)
    }

    // MARK: - Helpers visuels
    private func slotView(for card: Card?, hp: Int?) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(card == nil ? Color.white.opacity(0.2) : Color.clear)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(style: StrokeStyle(lineWidth: 2, dash: [6,4]))
                        .foregroundColor(.white)
                )
            if let card {
                CardView(card: card, faceUp: true, width: slotCardWidth) {
                    selectedCard = card
                }
                .overlay(alignment: .bottomTrailing) {
                    if let hp { hpBadge(hp) }
                }
            }
        }
        .frame(width: slotCardWidth, height: slotCardHeight)
    }

    private func hpBadge(_ hp: Int) -> some View {
        HStack(spacing: 2) {
            Text("\(hp)")
                .foregroundColor(.white)
            Image(systemName: "heart.fill")
                .foregroundColor(.green)
        }
        .font(.caption2.bold())
        .padding(6)
        .background(.black.opacity(0.6))
        .clipShape(Capsule())
        .padding(4)
    }

    private func emptySlot(width: CGFloat, height: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Color.white)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(style: StrokeStyle(lineWidth: 2, dash: [6,4]))
                    .foregroundStyle(.secondary)
            )
            .frame(width: width, height: height)
    }

    private func playEndTurnSound() {
        AudioServicesPlaySystemSound(1057)
    }

    private func labelChip(_ text: String, system: String) -> some View {
        Label(text, systemImage: system)
            .font(.caption.bold())
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(Capsule().fill(.ultraThinMaterial))
    }

    private func ritualNeedsTarget(_ kind: RitualKind) -> Bool {
        switch kind {
        case .obsidianKnife, .forestCharm:
            return true
        case .bloodAltar:
            return false
        }
    }

    private func firstOccupiedBoardSlot() -> Int? {
        engine.current.board.firstIndex(where: { $0 != nil })
    }

    private var pendingRitualKind: RitualKind? {
        guard let idx = pendingRitualHandIndex,
              idx >= 0,
              idx < engine.current.hand.count else {
            return nil
        }
        return engine.current.hand[idx].ritual
    }

    private var availableRitualTargetSlots: [Int] {
        engine.current.board.enumerated().compactMap { offset, card in
            card == nil ? nil : offset
        }
    }

    // MARK: - Sheets (cibles)
    private var ritualTargetSheet: some View {
        NavigationStack {
            VStack(spacing: 12) {
                Text("Choisir une cible pour le rituel")
                    .font(.headline)

                if let kind = pendingRitualKind, ritualNeedsTarget(kind) {
                    Picker("Emplacement", selection: Binding(get: {
                        ritualTargetSlot ?? -1
                    }, set: { ritualTargetSlot = ($0 == -1 ? nil : $0) })) {
                        ForEach(availableRitualTargetSlots, id: \.self) { slot in
                            Text("Empl. \(slot + 1)").tag(slot)
                        }
                    }
                    .pickerStyle(.wheel)

                    if availableRitualTargetSlots.isEmpty {
                        Text("Aucune commune en jeu : ce rituel ne peut pas être lancé.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                } else {
                    Text("Ce rituel n'a pas besoin de cible.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Button("Annuler") {
                        pendingRitualHandIndex = nil
                        ritualTargetSlot = nil
                        showTargetPickerForRitual = false
                    }
                    Spacer()
                    Button("Jouer") {
                        if let handIdx = pendingRitualHandIndex {
                            performPlayerRitual(handIndex: handIdx, targetSlot: ritualTargetSlot)
                        }
                        pendingRitualHandIndex = nil
                        ritualTargetSlot = nil
                        showTargetPickerForRitual = false
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled((pendingRitualKind.map(ritualNeedsTarget) ?? false) && ritualTargetSlot == nil)
                }
            }
            .padding()
        }
    }

    private var attackTargetSheet: some View {
        NavigationStack {
            VStack(spacing: 12) {
                Text("Cible de l’attaque")
                    .font(.headline)

                Button("Joueur adverse (PV)") {
                    if let from = attackFromSlot {
                        performPlayerAttack(from: from, to: .player)
                    }
                    showAttackPicker = false
                }
                .buttonStyle(.borderedProminent)

                Divider().padding(.vertical, 4)

                Button("Dieu adverse") {
                    if let from = attackFromSlot {
                        performPlayerAttack(from: from, to: .god)
                    }
                    showAttackPicker = false
                }

                ViewThatFits {
                    HStack(spacing: 8) {
                        laneAttackButtons
                    }
                    VStack(spacing: 8) {
                        laneAttackButtons
                    }
                }

                Button("Annuler") {
                    showAttackPicker = false
                }
                .padding(.top, 6)
            }
            .padding()
        }
    }
}

private extension CombatView {
    var laneAttackButtons: some View {
        ForEach(engine.current.board.indices, id: \.self) { i in
            Button("Lane \(i + 1)") {
                if let from = attackFromSlot {
                    performPlayerAttack(from: from, to: .boardSlot(i))
                }
                showAttackPicker = false
            }
            .buttonStyle(.bordered)
            .lineLimit(1)
            .minimumScaleFactor(0.75)
        }
    }
}

private struct BloodRiverView: View {
    @State private var offsetY: CGFloat = -UIScreen.main.bounds.height

    var body: some View {
        GeometryReader { geo in
            Rectangle()
                .fill(LinearGradient(colors: [Color.red.opacity(0.8), Color.clear], startPoint: .top, endPoint: .bottom))
                .frame(height: geo.size.height)
                .offset(y: offsetY)
                .onAppear {
                    offsetY = -geo.size.height
                    withAnimation(.easeInOut(duration: 0.7)) {
                        offsetY = geo.size.height
                    }
                }
        }
        .ignoresSafeArea()
    }
}


private struct DrawFlight {
    let card: Card
    let start: CGPoint
    let end: CGPoint
}

private typealias EnemyAction = EnemyAI.PlannedAction

private struct DrawFlyingCardView: View {
    let card: Card
    let progress: CGFloat
    let start: CGPoint
    let end: CGPoint
    let width: CGFloat

    var body: some View {
        CardView(card: card, faceUp: true, width: width)
            .scaleEffect(0.82 + (0.18 * progress))
            .rotationEffect(.degrees(Double((1 - progress) * -9)))
            .opacity(0.2 + (0.8 * progress))
            .position(position)
            .shadow(color: .black.opacity(0.25), radius: 12, x: 0, y: 8)
    }

    private var position: CGPoint {
        let x = start.x + ((end.x - start.x) * progress)
        let baseY = start.y + ((end.y - start.y) * progress)
        let arcLift = sin(progress * .pi) * 36
        return CGPoint(x: x, y: baseY - arcLift)
    }
}

private struct EnemyDrawFlightView: View {
    let progress: CGFloat
    let start: CGPoint
    let end: CGPoint
    let width: CGFloat

    var body: some View {
        CardBackView(width: width)
            .rotationEffect(.degrees(180))
            .scaleEffect(0.82 + (0.18 * progress))
            .rotationEffect(.degrees(Double((1 - progress) * -9)))
            .opacity(0.2 + (0.8 * progress))
            .position(position)
            .shadow(color: .black.opacity(0.25), radius: 12, x: 0, y: 8)
    }

    private var position: CGPoint {
        let x = start.x + ((end.x - start.x) * progress)
        let baseY = start.y + ((end.y - start.y) * progress)
        let arcLift = sin(progress * .pi) * 28
        return CGPoint(x: x, y: baseY - arcLift)
    }
}

private struct EnemyAttackLineView: View {
    let pulsing: Bool

    var body: some View {
        VStack {
            Spacer(minLength: 120)
            Rectangle()
                .fill(Color.red.opacity(0.75))
                .frame(height: 3)
                .overlay(
                    Rectangle()
                        .fill(Color.red.opacity(0.35))
                        .blur(radius: 6)
                )
                .padding(.horizontal, 30)
                .scaleEffect(x: pulsing ? 1.06 : 0.94, y: 1, anchor: .center)
            Spacer()
        }
    }
}

private struct HandCardFramePreferenceKey: PreferenceKey {
    static var defaultValue: [UUID: CGRect] = [:]

    static func reduce(value: inout [UUID: CGRect], nextValue: () -> [UUID: CGRect]) {
        value.merge(nextValue()) { _, new in new }
    }
}
