import SwiftUI
import UIKit
import AudioToolbox

struct CombatView: View {
    // Fournis un engine depuis l’extérieur si tu veux (collection/IA), sinon starter par défaut
    @StateObject private var engine: GameEngine
    private let aiLevel: Int
    var onWin: ((Int) -> Void)? = nil
    @Environment(\.dismiss) private var dismiss

    init(engine: GameEngine? = nil, aiLevel: Int = 1, onWin: ((Int) -> Void)? = nil) {
        self.aiLevel = aiLevel
        self.onWin = onWin
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

    @Namespace private var drawNamespace
    @State private var animatingCard: Card? = nil
    @State private var showBloodRiver = false

    // Drag & drop depuis la main vers le board
    @State private var draggingCardIndex: Int? = nil
    @State private var dragPosition: CGPoint = .zero
    @State private var hoveredSlot: Int? = nil
    @State private var slotFrames: [Int: CGRect] = [:]

    // Tailles réduites pour mieux voir l’ensemble du plateau
    private let slotCardWidth: CGFloat = 72
    private let slotCardHeight: CGFloat = 100
    private let deckCardWidth: CGFloat = 46
    private let deckCardHeight: CGFloat = 64

    var body: some View {
        GeometryReader { _ in
            ZStack {
                // Fond visuel du combat
                CombatBackground()

                VStack(spacing: 10) {
                    header

                    // Opposant (aperçu simple)
                    opponentStrip

                    Divider().opacity(0.3)

                    // Board du joueur (4 slots)
                    boardArea

                    // Zone Dieu + Sacrifice + Défausse
                    zonesRow

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 12)
                .padding(.top, 8)

                if showBloodRiver {
                    BloodRiverView()
                        .transition(.move(edge: .top))
                        .allowsHitTesting(false)
                }

                if let idx = draggingCardIndex {
                    CardView(card: engine.current.hand[idx], faceUp: true, width: 120)
                        .position(dragPosition)
                        .shadow(radius: 8)
                        .zIndex(1)
                }
            }
        }
        .onAppear {
            // Démarrer la partie si pas déjà fait
            if engine.p1.hand.isEmpty && engine.p2.hand.isEmpty {
                engine.start()
            }
        }
        .onChange(of: engine.lastDrawnCard) { card in
            guard let card else { return }
            animatingCard = card
            withAnimation(.easeInOut(duration: 0.6)) { }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                animatingCard = nil
            }
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
        }
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Button("Fin du tour") {
                    playEndTurnSound()
                    engine.endTurn()
                    engine.performAITurn(level: aiLevel)
                }
                Button("Fin de partie") {
                    dismiss()
                }
            }
        }
        .fullScreenCover(item: $selectedCard) { card in
            CardDetailView(card: card) { selectedCard = nil }
        }
        .onChange(of: engine.p1.hp) { hp in
            if hp <= 0 {
                dismiss()
            }
        }
        .onChange(of: engine.p2.hp) { hp in
            if hp <= 0 {
                onWin?(aiLevel)
                dismiss()
            }
        }
        .coordinateSpace(name: "combatArea")
    }

    // MARK: - Header (scores / sang)
    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(engine.p1.name)
                    .font(.headline)
                HStack(spacing: 10) {
                    Label("\(engine.p1.hp)", systemImage: "heart.fill")
                    Label("\(engine.p1.blood)", systemImage: "drop.fill")
                }.font(.subheadline)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text(engine.p2.name)
                    .font(.headline)
                HStack(spacing: 10) {
                    Label("\(engine.p2.hp)", systemImage: "heart.fill")
                    Label("\(engine.p2.blood)", systemImage: "drop.fill")
                }.font(.subheadline)
            }
        }
    }

    // MARK: - Opponent strip (aperçu board/dieu)
    private var opponentStrip: some View {
        VStack(spacing: 6) {
            Text("Main adverse").font(.caption).foregroundStyle(.secondary)

            opponentHandRow

            Text("Plateau adverse").font(.caption).foregroundStyle(.secondary)

            // Pioche adverse
            HStack(spacing: 8) {
                Text("Pioche :").font(.caption)
                ZStack {
                    if engine.opponent.deck.isEmpty {
                        emptySlot(width: 46, height: 64)
                    } else {
                        CardBackView().frame(width: 46, height: 64)
                        Text("\(engine.opponent.deck.count)")
                            .font(.caption.bold())
                            .foregroundStyle(.white)
                    }
                }
            }

            // Dieu adverse
            HStack(spacing: 8) {
                Text("Dieu :").font(.caption)
                slotView(for: engine.opponent.godSlot?.base, hp: engine.opponent.godSlot?.currentHP)
            }

            // Lanes adverses
            HStack(spacing: 8) {
                ForEach(0..<4) { i in
                    let inst = engine.opponent.board[i]
                    slotView(for: inst?.base, hp: inst?.currentHP)
                }
            }
        }
    }

    private var opponentHandRow: some View {
        ZStack {
            ForEach(engine.opponent.hand.indices, id: \.self) { i in
                CardBackView(width: 46)
                    .rotation3DEffect(.degrees(15), axis: (x: 1, y: 0, z: 0))
                    .rotationEffect(.degrees(Double(i - engine.opponent.hand.count/2) * 8))
                    .offset(x: CGFloat(i - engine.opponent.hand.count/2) * 20)
            }
        }
        .frame(height: 70)
    }

    // MARK: - Board du joueur
    private var boardArea: some View {
        VStack(spacing: 6) {
            Text("Tes unités").font(.caption).foregroundStyle(.secondary)
            HStack(spacing: 8) {
                ForEach(0..<4) { i in
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
                                            attackFromSlot = i
                                            showAttackPicker = true
                                        } label: {
                                            Image(systemName: "target")
                                                .font(.caption2.bold())
                                                .padding(6)
                                                .background(Circle().fill(.orange))
                                                .foregroundStyle(.white)
                                        }
                                    }
                                }
                                .padding(6)
                                , alignment: .topTrailing
                            )
                    }
                }
            }
        }
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
                        CardBackView().frame(width: deckCardWidth, height: deckCardHeight)
                        Text("\(engine.current.deck.count)")
                            .font(.headline.bold())
                            .foregroundStyle(.white)
                    }
                    if let animatingCard {
                        CardBackView().frame(width: deckCardWidth, height: deckCardHeight)
                            .matchedGeometryEffect(id: animatingCard.id, in: drawNamespace)
                    }
                }
            }

            VStack(spacing: 6) {
                Text("Ton dieu").font(.caption).foregroundStyle(.secondary)
                ZStack(alignment: .topTrailing) {
                    slotView(for: engine.current.godSlot?.base, hp: engine.current.godSlot?.currentHP)
                        .frame(width: slotCardWidth, height: slotCardHeight)
                    if engine.current.godSlot != nil {
                        Button {
                            attackFromSlot = -1
                            showAttackPicker = true
                        } label: {
                            Image(systemName: "target")
                                .font(.caption2.bold())
                                .padding(6)
                                .background(Circle().fill(.orange))
                                .foregroundStyle(.white)
                        }
                        .padding(6)
                    }
                }
            }

            VStack(spacing: 6) {
                Text("Sacrifice").font(.caption).foregroundStyle(.secondary)
                // visuel tourné à 90° si présent
                if let inst = engine.current.sacrificeSlot {
                    CardView(card: inst.base, faceUp: true, width: slotCardWidth) {
                        selectedCard = inst.base
                    }
                    .rotationEffect(.degrees(90))
                    .overlay(Text("+1 Sang").font(.caption2.bold()).padding(4).background(.black.opacity(0.6)).clipShape(Capsule()).foregroundStyle(.white), alignment: .bottom)
                } else {
                    emptySlot(width: slotCardWidth, height: slotCardHeight)
                }
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
    }

    // MARK: - Main du joueur
    private var handStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(engine.current.hand.indices, id: \.self) { idx in
                    let c = engine.current.hand[idx]
                    CardView(card: c, faceUp: true, width: 120) {
                        selectedCard = c
                    }
                    .matchedGeometryEffect(id: c.id, in: drawNamespace)
                    .rotation3DEffect(.degrees(12), axis: (x: 1, y: 0, z: 0))
                    .opacity((animatingCard?.id == c.id || draggingCardIndex == idx) ? 0 : 1)
                    .gesture(
                        DragGesture(minimumDistance: 0, coordinateSpace: .named("combatArea"))
                            .onChanged { value in
                                dragPosition = value.location
                                if draggingCardIndex == nil {
                                    draggingCardIndex = idx
                                }
                                if let slot = slotFrames.first(where: { $0.value.contains(value.location) })?.key {
                                    if hoveredSlot != slot {
                                        hoveredSlot = slot
                                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    }
                                } else {
                                    hoveredSlot = nil
                                }
                            }
                            .onEnded { _ in
                                if let slot = hoveredSlot {
                                    engine.playCommonToBoard(handIndex: idx, slot: slot)
                                }
                                draggingCardIndex = nil
                                hoveredSlot = nil
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
                    Button("Poser → Empl. 4") { engine.playCommonToBoard(handIndex: index, slot: 3) }
                    Divider()
                    Button("Sacrifier (+1 Sang)") { engine.sacrificeCommon(handIndex: index) }
                } label: {
                    labelChip("Jouer", system: "hand.tap.fill")
                }

            case .ritual:
                Button {
                    pendingRitualHandIndex = index
                    ritualTargetSlot = nil
                    showTargetPickerForRitual = true
                } label: { labelChip("Rituel", system: "wand.and.stars") }

            case .god:
                Button {
                    engine.invokeGod(handIndex: index)
                } label: { labelChip("Invoquer", system: "bolt.heart.fill") }
                .disabled(engine.current.blood < c.bloodCost || engine.current.godSlot != nil)
            }
        }
    }

    // MARK: - Helpers visuels
    private func slotView(for card: Card?, hp: Int?) -> some View {
        ZStack {
            if let card {
                CardView(card: card, faceUp: true, width: slotCardWidth) {
                    selectedCard = card
                }
                .overlay(alignment: .bottomTrailing) {
                    if let hp {
                        Text("\(hp)❤︎")
                            .font(.caption2.bold())
                            .padding(6)
                            .background(.black.opacity(0.6))
                            .foregroundStyle(.white)
                            .clipShape(Capsule())
                            .padding(4)
                    }
                    }
            } else {
                emptySlot(width: slotCardWidth, height: slotCardHeight)
            }
        }
        .frame(width: slotCardWidth, height: slotCardHeight)
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
                    Text("Empl. 4").tag(3)
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
                    ForEach(0..<4) { i in
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


