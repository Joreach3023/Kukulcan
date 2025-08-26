import SwiftUI

struct DeckSelectionView: View {
    @EnvironmentObject var collection: CollectionStore
    @State private var selected: Deck?

    var body: some View {
        NavigationStack {
            List {
                ForEach(collection.decks) { deck in
                    Button {
                        selected = deck
                    } label: {
                        HStack {
                            Text(deck.name)
                            Spacer()
                            Text("\(deck.cards.count)/10")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .disabled(deck.cards.count != 10)
                }
            }
            .navigationTitle("Choisir un deck")
            .navigationDestination(item: $selected) { deck in
                CombatView(
                    engine: GameEngine(
                        p1: PlayerState(name: "Toi", deck: deck.cards),
                        p2: PlayerState(name: "IA", deck: StarterFactory.randomDeck())
                    )
                )
            }
        }
    }
}

