import SwiftUI

struct DeckSelectionView: View {
    @EnvironmentObject var collection: CollectionStore
    @State private var selectedDeck: Deck? = nil
    @State private var selectedLevel: Int? = nil
    @State private var startCombat = false
    @State private var showLockedAlert = false

    @AppStorage("max_ai_level") private var maxAIUnlocked = 1
    @AppStorage("ai_levels_won_mask") private var aiLevelsWonMask: Int = 0

    private let levelRewards = Array(CardsDB.gods.prefix(5))
    private let winGoldReward = 50
    private let lossGoldReward = 20

    var body: some View {
        NavigationStack {
            VStack {
                List {
                    Section("Niveau IA") {
                        ForEach(1...5, id: \.self) { lvl in
                            let reward = levelRewards[lvl - 1]
                            let locked = lvl > maxAIUnlocked
                            Button {
                                if locked {
                                    showLockedAlert = true
                                } else {
                                    selectedLevel = lvl
                                }
                            } label: {
                                HStack {
                                    Text("Niveau \(lvl)")
                                    Spacer()
                                    CardView(card: reward, faceUp: true, width: 50)
                                        .opacity(levelWon(lvl) ? 0.3 : 1)
                                }
                                .opacity(locked ? 0.5 : 1)
                            }
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
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    NavigationLink {
                        DecksView()
                    } label: {
                        Label("Decks", systemImage: "folder")
                    }
                    NavigationLink {
                        RulesView()
                    } label: {
                        Label("Règles", systemImage: "questionmark.circle")
                    }
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
                        onWin: { handleWin(level: $0) },
                        onLoss: { handleLoss() },
                        winGold: winGoldReward,
                        lossGold: lossGoldReward
                    )
                }
            }
        }
        .alert("Tu dois terminer le niveau précédent.", isPresented: $showLockedAlert) {
            Button("OK", role: .cancel) {}
        }
    }

    private func levelWon(_ level: Int) -> Bool {
        (aiLevelsWonMask & (1 << (level - 1))) != 0
    }

    private func handleWin(level: Int) {
        collection.earnGold(winGoldReward)
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

    private func handleLoss() {
        collection.earnGold(lossGoldReward)
    }
}
