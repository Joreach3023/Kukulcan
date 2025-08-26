import SwiftUI

struct ContentView: View {
    // ⬇️ GameState injecté (ou créé par défaut)
    @StateObject private var game: GameState
    init(game: GameState? = nil) {
        if let g = game {
            _game = StateObject(wrappedValue: g)
        } else {
            _game = StateObject(wrappedValue: GameState())
        }
    }

    @State private var selectedLane: Int? = nil
    @State private var targetedLane: Int? = nil
    @State private var selectedCard: Card? = nil   // pour le zoom plein écran

    var body: some View {
        ZStack {
            CombatBackground() // ⬅️ fond jungle

            GeometryReader { geo in
                // Tailles adaptatives
                let W = geo.size.width
                let cardW = min(150, max(110, W * 0.32))      // cartes de la main
                let laneCardW = cardW * 0.9                   // cartes posées
                let laneBoxW = laneCardW + 30
                let laneBoxH = laneCardW * 1.5 + 30

                VStack(spacing: 8) {
                    // Titre + scores
                    Text("Combats")
                        .font(.system(size: min(28, W * 0.08), weight: .bold))

                    HStack(spacing: 12) {
                        Label("\(game.playerScore)", systemImage: "person.fill")
                        Label("\(game.aiScore)", systemImage: "cpu.fill")
                    }
                    .font(.system(size: min(22, W * 0.06)))

                    Text(game.message)
                        .font(.subheadline)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .padding(.bottom, 4)

                    // Lanes (scroll horizontal si nécessaire)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(0..<3) { i in
                                VStack(spacing: 6) {
                                    Text("Lane \(i+1)").font(.caption)

                                    ZStack {
                                        let isSelected = (selectedLane == i)
                                        let isTargeted = (targetedLane == i)

                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(.ultraThinMaterial) // lisibilité
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .stroke(
                                                        isTargeted ? .blue :
                                                        (isSelected ? .blue : .secondary),
                                                        style: StrokeStyle(lineWidth: isTargeted ? 3 : 2, dash: [6,4])
                                                    )
                                            )
                                            .frame(width: laneBoxW, height: laneBoxH)
                                            .contentShape(Rectangle())
                                            .onTapGesture { selectedLane = i }
                                            .dropDestination(for: Card.self) { items, _ in
                                                guard let card = items.first else { return false }
                                                withAnimation(.easeInOut) {
                                                    game.play(card: card, to: i)
                                                    selectedLane = nil
                                                }
                                                return true
                                            } isTargeted: { over in
                                                targetedLane = over ? i : (targetedLane == i ? nil : targetedLane)
                                            }

                                        VStack {
                                            // Carte IA
                                            if let ai = game.lanes[i].ai {
                                                CardView(card: ai, faceUp: true, width: laneCardW) {
                                                    selectedCard = ai   // tap = zoom
                                                }
                                                .scaleEffect(0.98)
                                            } else {
                                                Text("IA").foregroundStyle(.secondary)
                                            }

                                            Spacer().frame(height: 8)

                                            // Carte Joueur
                                            if let p = game.lanes[i].player {
                                                CardView(card: p, faceUp: true, width: laneCardW) {
                                                    selectedCard = p    // tap = zoom
                                                }
                                                .scaleEffect(0.98)
                                            } else {
                                                Text("Toi").foregroundStyle(.secondary)
                                            }
                                        }
                                    }
                                }
                                .frame(width: laneBoxW)
                            }
                        }
                        .padding(.horizontal, 8)
                    }
                    .frame(height: laneBoxH + 30)

                    Spacer(minLength: 4)

                    // Actions hautes
                    HStack {
                        Button("Nouvelle partie") {
                            withAnimation(.spring) { game.newGame() }
                            selectedLane = nil
                        }
                        .buttonStyle(.borderedProminent)

                        Spacer()

                        Picker("Lane", selection: Binding(
                            get: { selectedLane ?? -1 },
                            set: { selectedLane = ($0 == -1 ? nil : $0) }
                        )) {
                            Text("Choisis une lane").tag(-1)
                            Text("Lane 1").tag(0)
                            Text("Lane 2").tag(1)
                            Text("Lane 3").tag(2)
                        }
                        .pickerStyle(.menu)
                    }
                    .padding(.horizontal)
                }
                .padding(.top, 8)

                // Main “dockée” en bas
                .safeAreaInset(edge: .bottom) {
                    VStack(spacing: 10) {
                        Divider().opacity(0.4)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(game.playerHand) { card in
                                    ZStack(alignment: .bottomTrailing) {
                                        CardView(card: card, faceUp: true, width: cardW) {
                                            selectedCard = card   // tap = zoom
                                        }
                                        .draggable(card)
                                        .contextMenu {
                                            Button("Jouer sur Lane 1") { withAnimation { game.play(card: card, to: 0) } }
                                            Button("Jouer sur Lane 2") { withAnimation { game.play(card: card, to: 1) } }
                                            Button("Jouer sur Lane 3") { withAnimation { game.play(card: card, to: 2) } }
                                        }
                                        .disabled(game.gameOver)

                                        if let lane = selectedLane {
                                            Button {
                                                withAnimation(.easeInOut) { game.play(card: card, to: lane) }
                                            } label: {
                                                Image(systemName: "play.fill")
                                                    .font(.system(size: 14, weight: .bold))
                                                    .padding(8)
                                                    .background(Circle().fill(.orange))
                                                    .foregroundStyle(.white)
                                                    .shadow(radius: 3)
                                            }
                                            .padding(6)
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                        .padding(.bottom, 6)
                    }
                    .background(.ultraThinMaterial) // lisibilité sur fond jungle
                }
            }
        }
        // Zoom plein écran
        .fullScreenCover(item: $selectedCard) { card in
            CardDetailView(card: card) { selectedCard = nil }
        }
    }
}

