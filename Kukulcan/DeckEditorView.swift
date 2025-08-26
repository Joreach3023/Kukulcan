import SwiftUI

// Agrégation des doublons (clé sans "power")
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

struct DeckEditorView: View {
    @Binding var deck: Deck
    @EnvironmentObject var collection: CollectionStore
    @State private var name: String

    private let columns = [GridItem(.adaptive(minimum: 120), spacing: 12)]

    init(deck: Binding<Deck>) {
        _deck = deck
        _name = State(initialValue: deck.wrappedValue.name)
    }

    var body: some View {
        VStack(spacing: 12) {
            TextField("Nom du deck", text: $name)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(deck.cards) { card in
                        CardView(card: card, faceUp: true, width: 80) {
                            deck.cards.removeAll { $0.id == card.id }
                        }
                    }
                }
                .padding(.horizontal)
            }
            .frame(height: 120)

            Text("\(deck.cards.count)/10")
                .font(.headline)

            ScrollView {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(groupedOwned(collection.ownedPlayable), id: \.card.id) { group in
                        let card = group.card
                        let count = group.count

                        CardView(card: card, faceUp: true, width: 140) {
                            add(card)
                        }
                        .overlay(alignment: .topTrailing) {
                            if count > 1 {
                                QuantityBadge(count: count)
                                    .padding(.trailing, 6)
                                    .padding(.top, 32)
                            }
                        }
                        .opacity(canAdd(card) ? 1 : 0.3)
                        .disabled(!canAdd(card))
                    }
                }
                .padding()
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Deck")
        .background(
            CollectionBackground()
                .ignoresSafeArea()
        )
        .toolbar {
            Button("Enregistrer") {
                deck.name = name
            }
            .disabled(deck.cards.count != 10)
        }
    }

    private func add(_ card: Card) {
        guard canAdd(card) else { return }
        let ids = deck.cards.map { $0.id }
        if let copy = collection.ownedPlayable.first(where: { $0.name == card.name && !ids.contains($0.id) }) {
            deck.cards.append(copy)
        }
    }

    private func canAdd(_ card: Card) -> Bool {
        let limit = card.type == .god ? 1 : 3
        let copies = deck.cards.filter { $0.name == card.name }.count
        return deck.cards.count < 10 && copies < limit
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

