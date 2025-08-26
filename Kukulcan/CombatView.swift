import SwiftUI

struct CombatView: View {
    // Fournis un engine depuis l’extérieur si tu veux (collection/IA), sinon starter par défaut
    @StateObject private var engine: GameEngine

    init(engine: GameEngine? = nil) {
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

    var body: some View {
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
        }
        .onAppear {
            // Démarrer la partie si pas déjà fait
            if engine.p1.hand.isEmpty && engine.p2.hand.isEmpty {
                engine.start()
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
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 8) {
                footerControls
                handStrip
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 4)
            .background(.ultraThinMaterial)
        }
        .fullScreenCover(item: $selectedCard) { card in
            CardDetailView(card: card) { selectedCard = nil }
        }
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
            Text("Plateau adverse").font(.caption).foregroundStyle(.secondary)

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
                            .dropDestination(for: Card.self) { items, _ in
                                guard let card = items.first,
                                      let idx = engine.current.hand.firstIndex(where: { $0.id == card.id }) else { return false }
                                engine.playCommonToBoard(handIndex: idx, slot: i)
                                return true
                            }
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
                Text("Ton dieu").font(.caption).foregroundStyle(.secondary)
                ZStack(alignment: .topTrailing) {
                    slotView(for: engine.current.godSlot?.base, hp: engine.current.godSlot?.currentHP)
                        .frame(width: 92, height: 128)
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
                    CardView(card: inst.base, faceUp: true, width: 92) {
                        selectedCard = inst.base
                    }
                    .rotationEffect(.degrees(90))
                    .overlay(Text("+1 Sang").font(.caption2.bold()).padding(4).background(.black.opacity(0.6)).clipShape(Capsule()).foregroundStyle(.white), alignment: .bottom)
                } else {
                    emptySlot(width: 92, height: 128)
                }
            }

            VStack(spacing: 6) {
                Text("Défausse").font(.caption).foregroundStyle(.secondary)
                ZStack {
                    emptySlot(width: 92, height: 128)
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
        VStack(spacing: 6) {
            Text("Ta main").font(.caption).foregroundStyle(.secondary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(engine.current.hand.indices, id: \.self) { idx in
                        let c = engine.current.hand[idx]
                        CardView(card: c, faceUp: true, width: 120) {
                            selectedCard = c
                        }
                        .draggable(c)
                        .overlay(alignment: .bottom) {
                            actionButtonsForHandCard(c, index: idx)
                                .padding(.bottom, 6)
                        }
                    }
                }
                .padding(.horizontal, 4)
            }
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

    // MARK: - Bas de vue (log + fin de tour)
    private var footerControls: some View {
        VStack(spacing: 8) {
            HStack {
                Text(engine.log.last ?? "À toi de jouer.")
                    .font(.footnote)
                    .lineLimit(2)
                Spacer()
                Button {
                    engine.resetGame()
                } label: {
                    Label("Nouvelle partie", systemImage: "arrow.clockwise")
                }
                Button {
                    engine.endTurn()
                    engine.performEasyAITurn()
                } label: {
                    Label("Fin du tour", systemImage: "arrow.uturn.right.circle.fill")
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(.vertical, 6)
    }

    // MARK: - Helpers visuels
    private func slotView(for card: Card?, hp: Int?) -> some View {
        ZStack {
            if let card {
                CardView(card: card, faceUp: true, width: 92) {
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
                emptySlot(width: 92, height: 128)
            }
        }
        .frame(width: 92, height: 128)
    }

    private func emptySlot(width: CGFloat, height: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 12)
            .stroke(style: StrokeStyle(lineWidth: 2, dash: [6,4]))
            .foregroundStyle(.secondary)
            .frame(width: width, height: height)
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


