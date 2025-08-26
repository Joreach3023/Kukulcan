import SwiftUI

struct DeckSelectionView: View {
    @EnvironmentObject var collection: CollectionStore
    @State private var selectedDeck: Deck? = nil
    @State private var selectedLevel: Int? = nil
    @State private var startCombat = false

    @AppStorage("max_ai_level") private var maxAIUnlocked = 1
    @AppStorage("ai_levels_won_mask") private var aiLevelsWonMask: Int = 0

    private let levelRewards = Array(CardsDB.gods.prefix(5))

    var body: some View {
        NavigationStack {
            VStack {
                List {
                    Section("Niveau IA") {
                        ForEach(1...5, id: \.self) { lvl in
                            let reward = levelRewards[lvl - 1]
                            Button {
                                selectedLevel = lvl
                            } label: {
                                HStack {
                                    Text("Niveau \(lvl)")
                                    Spacer()
                                    CardView(card: reward, faceUp: true, width: 50)
                                        .opacity(levelWon(lvl) ? 0.3 : 1)
                                }
                            }
                            .disabled(lvl > maxAIUnlocked)
                            .listRowBackground(selectedLevel == lvl ? Color.blue.opacity(0.2) : nil)
                        }
                    }
                    Section("Decks") {
                        ForEach(collection.decks) { deck in
                            Button {
                                selectedDeck = deck
                            } label: {
                                HStack {
                                    Text(deck.name)
                                    Spacer()
                                    Text("\(deck.cards.count)/10")
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .disabled(deck.cards.count != 10)
                            .listRowBackground(selectedDeck?.id == deck.id ? Color.blue.opacity(0.2) : nil)
                        }
                    }
                }
                Button("Débuter combat") {
                    startCombat = true
                }
                .disabled(selectedDeck == nil || selectedLevel == nil)
                .padding()
            }
            .navigationTitle("Choisir un deck")
            .toolbar {
                NavigationLink {
                    DecksView()
                } label: {
                    Label("Decks", systemImage: "folder")
                }
            }
            .navigationDestination(isPresented: $startCombat) {
                if let deck = selectedDeck, let lvl = selectedLevel {
                    CombatView(
                        engine: GameEngine(
                            p1: PlayerState(name: "Toi", deck: deck.cards),
                            p2: PlayerState(name: "IA", deck: StarterFactory.randomDeck())
                        ),
                        aiLevel: lvl,
                        onWin: { handleWin(level: $0) }
                    )
                }
            }
        }
    }

    private func levelWon(_ level: Int) -> Bool {
        (aiLevelsWonMask & (1 << (level - 1))) != 0
    }

    private func handleWin(level: Int) {
        let mask = 1 << (level - 1)
        if aiLevelsWonMask & mask == 0 {
            aiLevelsWonMask |= mask
            if maxAIUnlocked < 5 && level == maxAIUnlocked {
                maxAIUnlocked = level + 1
            }
            let reward = levelRewards[level - 1]
            collection.add([reward])
        }
    }
}
