import SwiftUI

struct DeckEditorView: View {
    @Binding var deck: Deck
    @EnvironmentObject var collection: CollectionStore
    @State private var name: String
    @State private var selection: Set<UUID>

    init(deck: Binding<Deck>) {
        _deck = deck
        _name = State(initialValue: deck.wrappedValue.name)
        _selection = State(initialValue: Set(deck.wrappedValue.cards.map { $0.id }))
    }

    private let columns = [GridItem(.adaptive(minimum: 120), spacing: 12)]

    private var selectedCards: [Card] {
        collection.ownedPlayable.filter { selection.contains($0.id) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            TextField("Nom du deck", text: $name)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal)

            VStack(alignment: .leading) {
                Text("Deck (\(selection.count)/10)")
                    .font(.headline)
                    .padding(.horizontal)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(selectedCards) { card in
                            CardView(card: card, faceUp: true, width: 80) {
                                selection.remove(card.id)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }

            ScrollView {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(groupedOwned(collection.ownedPlayable), id: \.card.id) { group in
                        let card = group.card

                        CardView(card: card, faceUp: true, width: 140) {
                            if selection.contains(card.id) {
                                selection.remove(card.id)
                            } else if selection.count < 10 {
                                selection.insert(card.id)
                            }
                        }
                        .overlay(alignment: .topTrailing) {
                            if selection.contains(card.id) {
                                Image(systemName: "checkmark.circle.fill")
                                    .symbolRenderingMode(.multicolor)
                                    .padding(6)
                            } else if group.count > 1 {
                                QuantityBadge(count: group.count)
                                    .padding(.trailing, 6)
                                    .padding(.top, 32)
                            }
                        }
                        .opacity(!selection.contains(card.id) && selection.count >= 10 ? 0.4 : 1)
                    }
                }
                .padding()
            }
        }
        .navigationTitle("Deck")
        .toolbar {
            Button("Enregistrer") {
                deck.name = name
                deck.cards = selectedCards
            }
            .disabled(selection.count != 10)
        }
    }
}

// MARK: - Helpers pour l'affichage façon collection

private struct CardKey: Hashable {
    let name: String
    let imageName: String
    let rarity: Rarity
    let type: CardType

    init(_ c: Card) {
        name = c.name
        imageName = c.imageName
        rarity = c.rarity
        type = c.type
    }
}

private func rarityOrder(_ r: Rarity) -> Int {
    switch r {
    case .legendary: return 0
    case .epic:      return 1
    case .rare:      return 2
    case .common:    return 3
    }
}

private func groupedOwned(_ owned: [Card]) -> [(card: Card, count: Int)] {
    var dict: [CardKey: (card: Card, count: Int)] = [:]
    for c in owned {
        let k = CardKey(c)
        dict[k] = (dict[k]?.card ?? c, (dict[k]?.count ?? 0) + 1)
    }
    return dict.values.sorted {
        $0.card.rarity == $1.card.rarity
        ? $0.card.name < $1.card.name
        : rarityOrder($0.card.rarity) < rarityOrder($1.card.rarity)
    }
}

private struct QuantityBadge: View {
    let count: Int
    var body: some View {
        HStack(spacing: 3) {
            Text("×").font(.caption2.bold())
            Text("\(count)").font(.caption2.bold())
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(.black.opacity(0.65))
        .overlay(Capsule().stroke(.white.opacity(0.65), lineWidth: 1))
        .clipShape(Capsule())
        .foregroundStyle(.white)
        .shadow(radius: 2)
        .accessibilityLabel("\(count) exemplaires")
    }
}


