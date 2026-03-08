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

    // Drag & drop depuis la main vers le board
    @State private var draggingCardIndex: Int? = nil
    @State private var dragPosition: CGPoint = .zero
    @State private var hoveredSlot: Int? = nil
    @State private var slotFrames: [Int: CGRect] = [:]
    @State private var sacrificeFrame: CGRect = .zero
    @State private var hoveringSacrifice = false

    // Tailles réduites pour mieux voir l’ensemble du plateau
    private let slotCardWidth: CGFloat = 60
    private let slotCardHeight: CGFloat = 84
    private let deckCardWidth: CGFloat = 60
    private let deckCardHeight: CGFloat = 84
    private let handCardWidth: CGFloat = 90
    private var handCardHeight: CGFloat { handCardWidth * 1.4 }
    private let enemyTurnStepDelay: TimeInterval = 1.4

    private var isPlayerInteractionEnabled: Bool {
        turnPhase == .playerTurn && outcome == nil
    }

    var body: some View {
        GeometryReader { _ in
            ZStack {
                // Fond visuel du combat
                CombatBackground()

                VStack(spacing: 10) {
                    header

                    // Plateau adverse miroité
                    opponentBoard

                    Divider().opacity(0.3)

                    // Board du joueur (3 slots)
                    boardArea

                    // Zone Dieu + Sacrifice + Défausse
                    zonesRow

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 12)
                .padding(.top, 8)
                .padding(.bottom, handCardHeight + 20)

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
            AudioManager.shared.play(.combat)
        }
        .onDisappear {
            NotificationCenter.default.post(name: .combatViewDidDisappear, object: nil)
        }
        .onChange(of: engine.lastDrawnCards) { cards in
            guard engine.currentPlayerIsP1, !cards.isEmpty else { return }
            enqueueDrawAnimation(cards)
        }
        .onChange(of: engine.current.sacrificeSlot?.id) { _ in
            guard engine.current.sacrificeSlot != nil else { return }
            let generator = UIImpactFeedbackGenerator(style: .heavy)
            generator.impactOccurred()
            showBloodRiver = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                showBloodRiver = false
            }
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
                .padding(.bottom, 16)
                .allowsHitTesting(isPlayerInteractionEnabled)
                .opacity(isPlayerInteractionEnabled ? 1 : 0.7)
        }
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Button("Fin du tour") {
                    endPlayerTurnAndRunEnemySequence()
                }
                .disabled(!isPlayerInteractionEnabled)
                Button("Fin de partie") {
                    dismiss()
                }
            }
        }
        .fullScreenCover(item: $selectedCard) { card in
            CardDetailView(card: card) { selectedCard = nil }
        }
        .onChange(of: engine.p1.hp) { hp in
            if hp <= 0 && outcome == nil {
                outcome = .loss
                onLoss?()
            }
        }
        .onChange(of: engine.p2.hp) { hp in
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
            HStack(spacing: 8) {
                ForEach(0..<3) { i in
                    let inst = engine.opponent.board[i]
                    slotView(for: inst?.base, hp: inst?.currentHP)
                }
            }
        }
    }

    private var opponentZonesRow: some View {
        HStack(spacing: 10) {
            VStack(spacing: 6) {
                ZStack {
                    if engine.opponent.deck.isEmpty {
                        emptySlot(width: deckCardWidth, height: deckCardHeight)
                    } else {
                        CardBackView(width: deckCardWidth).frame(width: deckCardWidth, height: deckCardHeight)
                        Text("\(engine.opponent.deck.count)")
                            .font(.headline.bold())
                            .foregroundStyle(.white)
                            .rotationEffect(.degrees(180))
                    }
                }
                .background(
                    GeometryReader { geo in
                        Color.clear
                            .onAppear { enemyDeckFrame = geo.frame(in: .named("combatArea")) }
                            .onChange(of: geo.frame(in: .named("combatArea"))) { enemyDeckFrame = $0 }
                    }
                )
            }

            VStack(spacing: 6) {
                Text("Main IA")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .rotationEffect(.degrees(180))
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.white.opacity(0.16))
                    .frame(width: deckCardWidth + 8, height: deckCardHeight + 8)
                    .overlay(
                        Text("\(engine.opponent.hand.count)")
                            .font(.caption.bold())
                            .foregroundStyle(.white)
                            .rotationEffect(.degrees(180))
                    )
                    .background(
                        GeometryReader { geo in
                            Color.clear
                                .onAppear { enemyHandFrame = geo.frame(in: .named("combatArea")) }
                                .onChange(of: geo.frame(in: .named("combatArea"))) { enemyHandFrame = $0 }
                        }
                    )
            }

            VStack(spacing: 6) {
                slotView(for: engine.opponent.godSlot?.base, hp: engine.opponent.godSlot?.currentHP)
                    .frame(width: slotCardWidth, height: slotCardHeight)
            }

            VStack(spacing: 6) {
                if let inst = engine.opponent.sacrificeSlot {
                    CardView(card: inst.base, faceUp: true, width: slotCardWidth)
                        .rotationEffect(.degrees(180))
                } else {
                    emptySlot(width: slotCardWidth, height: slotCardHeight)
                }
            }
        }
    }

    // MARK: - Board du joueur
    private var boardArea: some View {
        VStack(spacing: 6) {
            Text("Tes unités").font(.caption).foregroundStyle(.secondary)
            HStack(spacing: 8) {
                ForEach(0..<3) { i in
                    let inst = engine.current.board[i]
                    // Carte en jeu
                    ZStack(alignment: .topTrailing) {
                        slotView(for: inst?.base, hp: inst?.currentHP)
                            .background(
                                GeometryReader { geo in
                                    let frame = geo.frame(in: .named("combatArea"))
                                    Color.clear
                                        .onAppear { slotFrames[i] = frame }
                                        .onChange(of: frame) { slotFrames[i] = $0 }
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
                                        .disabled(inst?.hasActedThisTurn != false)
                                        .opacity(inst?.hasActedThisTurn == true ? 0.45 : 1)
                                    }
                                }
                                .padding(6)
                                , alignment: .topTrailing
                            )
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Zones spéciales (Dieu / Sacrifice / Défausse)
    private var zonesRow: some View {
        HStack(spacing: 10) {
            VStack(spacing: 6) {
                Text("Pioche").font(.caption).foregroundStyle(.secondary)
                ZStack {
                    if engine.current.deck.isEmpty {
                        emptySlot(width: deckCardWidth, height: deckCardHeight)
                    } else {
                        CardBackView(width: deckCardWidth).frame(width: deckCardWidth, height: deckCardHeight)
                        Text("\(engine.current.deck.count)")
                            .font(.headline.bold())
                            .foregroundStyle(.white)
                    }
                }
                .background(
                    GeometryReader { geo in
                        Color.clear
                            .onAppear { deckFrame = geo.frame(in: .named("combatArea")) }
                            .onChange(of: geo.frame(in: .named("combatArea"))) { deckFrame = $0 }
                    }
                )
            }

            VStack(spacing: 6) {
                Text("Ton dieu").font(.caption).foregroundStyle(.secondary)
                ZStack(alignment: .topTrailing) {
                    slotView(for: engine.current.godSlot?.base, hp: engine.current.godSlot?.currentHP)
                        .frame(width: slotCardWidth, height: slotCardHeight)
                    if engine.current.godSlot != nil {
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
                        .disabled(engine.current.godSlot?.hasActedThisTurn != false)
                        .opacity(engine.current.godSlot?.hasActedThisTurn == true ? 0.45 : 1)
                        .padding(6)
                    }
                }
            }

            VStack(spacing: 6) {
                Text("Sacrifice").font(.caption).foregroundStyle(.secondary)
                ZStack {
                    if let inst = engine.current.sacrificeSlot {
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
                            .onChange(of: geo.frame(in: .named("combatArea"))) { sacrificeFrame = $0 }
                    }
                )
            }

            VStack(spacing: 6) {
                Text("Défausse").font(.caption).foregroundStyle(.secondary)
                ZStack {
                    emptySlot(width: slotCardWidth, height: slotCardHeight)
                    if !engine.current.discard.isEmpty {
                        Text("\(engine.current.discard.count)")
                            .font(.headline.bold())
                            .padding(8)
                            .background(Circle().fill(.black.opacity(0.6)))
                            .foregroundStyle(.white)
                    }
                }
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    // MARK: - Main du joueur
    private var handStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(engine.current.hand.indices, id: \.self) { idx in
                    let c = engine.current.hand[idx]
                    CardView(card: c, faceUp: true, width: handCardWidth) {
                        selectedCard = c
                    }
                    .rotation3DEffect(.degrees(12), axis: (x: 1, y: 0, z: 0))
                    .opacity(((openingHandCardIDs.contains(c.id) && !displayedHandCardIDs.contains(c.id)) || hiddenHandCardIDs.contains(c.id) || draggingCardIndex == idx) ? 0 : 1)
                    .allowsHitTesting(!openingHandCardIDs.contains(c.id) || displayedHandCardIDs.contains(c.id))
                    .background(
                        GeometryReader { geo in
                            Color.clear.preference(key: HandCardFramePreferenceKey.self, value: [c.id: geo.frame(in: .named("combatArea"))])
                        }
                    )
                    .gesture(
                        DragGesture(minimumDistance: 0, coordinateSpace: .named("combatArea"))
                            .onChanged { value in
                                guard isPlayerInteractionEnabled else { return }
                                dragPosition = value.location
                                if draggingCardIndex == nil {
                                    draggingCardIndex = idx
                                }
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
                                guard isPlayerInteractionEnabled else {
                                    draggingCardIndex = nil
                                    hoveredSlot = nil
                                    hoveringSacrifice = false
                                    return
                                }
                                if let slot = hoveredSlot {
                                    engine.playCommonToBoard(handIndex: idx, slot: slot)
                                } else if hoveringSacrifice {
                                    engine.sacrificeCommon(handIndex: idx)
                                }
                                draggingCardIndex = nil
                                hoveredSlot = nil
                                hoveringSacrifice = false
                            }
                    )
                    .overlay(alignment: .bottom) {
                        actionButtonsForHandCard(c, index: idx)
                            .padding(.bottom, 6)
                    }
                }
            }
            .padding(.horizontal, 4)
        }
        .onPreferenceChange(HandCardFramePreferenceKey.self) { frames in
            handCardFrames.merge(frames) { _, new in new }
            processPendingDrawAnimations()
        }
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
                    pendingRitualHandIndex = index
                    ritualTargetSlot = nil
                    showTargetPickerForRitual = true
                } label: { labelChip("Rituel", system: "wand.and.stars") }
                .disabled(!isPlayerInteractionEnabled)

            case .god:
                Button {
                    guard isPlayerInteractionEnabled else { return }
                    engine.invokeGod(handIndex: index)
                } label: { labelChip("Invoquer", system: "bolt.heart.fill") }
                .disabled(!isPlayerInteractionEnabled || engine.current.blood < c.bloodCost || engine.current.godSlot != nil)
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
            action.execute()
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
        if let slot = engine.current.board.firstIndex(where: { $0 == nil }),
           let idx = engine.current.hand.firstIndex(where: { $0.type == .common }) {
            let card = engine.current.hand[idx]
            return EnemyAction(card: card) {
                engine.playCommonToBoard(handIndex: idx, slot: slot)
            }
        }

        if engine.current.godSlot == nil,
           let gIdx = engine.current.hand.firstIndex(where: { $0.type == .god }) {
            let card = engine.current.hand[gIdx]
            if engine.current.blood >= card.bloodCost {
                return EnemyAction(card: card) {
                    engine.invokeGod(handIndex: gIdx)
                }
            }
        }

        if let idx = engine.current.hand.firstIndex(where: { $0.type == .ritual }) {
            let card = engine.current.hand[idx]
            let target = engine.current.board.firstIndex(where: { $0 != nil })
            return EnemyAction(card: card) {
                engine.playRitual(handIndex: idx, targetSlot: target)
            }
        }

        return nil
    }

    private func performEnemyAttacks() {
        for i in 0..<engine.current.board.count {
            if engine.current.board[i] != nil {
                let target: Target = engine.opponent.board[i] != nil ? .boardSlot(i) : .player
                engine.attack(from: i, to: target)
            }
        }

        if engine.current.godSlot != nil {
            engine.attack(from: -1, to: .player)
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

    // MARK: - Sheets (cibles)
    private var ritualTargetSheet: some View {
        NavigationStack {
            VStack(spacing: 12) {
                Text("Choisir une cible pour le rituel")
                    .font(.headline)

                Picker("Emplacement", selection: Binding(get: {
                    ritualTargetSlot ?? -1
                }, set: { ritualTargetSlot = ($0 == -1 ? nil : $0) })) {
                    Text("Aucune (effet global)").tag(-1)
                    Text("Empl. 1").tag(0)
                    Text("Empl. 2").tag(1)
                    Text("Empl. 3").tag(2)
                }
                .pickerStyle(.wheel)

                HStack {
                    Button("Annuler") { showTargetPickerForRitual = false }
                    Spacer()
                    Button("Jouer") {
                        if let handIdx = pendingRitualHandIndex {
                            engine.playRitual(handIndex: handIdx, targetSlot: ritualTargetSlot)
                        }
                        pendingRitualHandIndex = nil
                        showTargetPickerForRitual = false
                    }
                    .buttonStyle(.borderedProminent)
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
                        engine.attack(from: from, to: .player)
                    }
                    showAttackPicker = false
                }
                .buttonStyle(.borderedProminent)

                Divider().padding(.vertical, 4)

                Button("Dieu adverse") {
                    if let from = attackFromSlot {
                        engine.attack(from: from, to: .god)
                    }
                    showAttackPicker = false
                }

                HStack(spacing: 8) {
                    ForEach(0..<3) { i in
                        Button("Lane \(i+1)") {
                            if let from = attackFromSlot {
                                engine.attack(from: from, to: .boardSlot(i))
                            }
                            showAttackPicker = false
                        }
                        .buttonStyle(.bordered)
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

private struct EnemyAction {
    let card: Card
    let execute: () -> Void
}

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
