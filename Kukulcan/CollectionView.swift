import SwiftUI

// MARK: - Agrégation des doublons
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

// MARK: - Vue principale
struct CollectionView: View {
    @EnvironmentObject var collection: CollectionStore
    @State private var selectedCard: Card? = nil

    private let columns = [GridItem(.adaptive(minimum: 120), spacing: 12)]

    var body: some View {
        NavigationStack {
            Group {
                if collection.owned.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(groupedOwned(collection.owned), id: \.card.id) { group in
                                let card = group.card
                                let count = group.count

                                CardView(card: card, faceUp: true, width: 140) {
                                    selectedCard = card
                                }
                                .overlay(alignment: .topTrailing) {
                                    if count > 1 {
                                        QuantityBadge(count: count)
                                            .padding(.trailing, 6)
                                            .padding(.top, 32)
                                    }
                                }
                            }
                        }
                        .padding()
                    }
                    .scrollContentBackground(.hidden)   // ⬅︎ empêche le fond du scroll de recouvrir le nôtre
                }
            }
            .navigationTitle("Collection")
            .toolbar {
                NavigationLink {
                    DecksView()
                } label: {
                    Label("Decks", systemImage: "folder")
                }
            }
            // ⬇︎ Place le fond derrière tout le contenu de la stack
            .background(
                CollectionBackground()
                    .ignoresSafeArea()
            )
        }
        .fullScreenCover(item: $selectedCard) { card in
            CardDetailView(card: card) { selectedCard = nil }
        }
    }


    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "square.grid.2x2")
                .font(.system(size: 42))
                .foregroundStyle(.secondary)
            Text("Ta collection est vide.")
                .font(.headline)
            Text("Ouvre des packs dans l’onglet Accueil pour obtenir tes premières cartes.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
        }
        .padding(.top, 40)
    }
}

// MARK: - Badge ×N
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

