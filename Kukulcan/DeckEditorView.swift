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

    var body: some View {
        Form {
            Section("Nom") {
                TextField("Nom du deck", text: $name)
            }
            Section("Cartes (\(selection.count)/10)") {
                ForEach(collection.ownedPlayable) { card in
                    Button {
                        let limit = card.type == .god ? 1 : 3
                        let copies = collection.ownedPlayable.filter {
                            $0.name == card.name && selection.contains($0.id)
                        }.count
                        if selection.contains(card.id) {
                            selection.remove(card.id)
                        } else if selection.count < 10 && copies < limit {
                            selection.insert(card.id)
                        }
                    } label: {
                        HStack {
                            Text(card.name)
                            Spacer()
                            if selection.contains(card.id) {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                    .disabled(
                        !selection.contains(card.id) &&
                        (selection.count >= 10 ||
                         collection.ownedPlayable.filter {
                            $0.name == card.name && selection.contains($0.id)
                         }.count >= (card.type == .god ? 1 : 3))
                    )
                }
            }
        }
        .navigationTitle("Deck")
        .toolbar {
            Button("Enregistrer") {
                deck.name = name
                deck.cards = collection.ownedPlayable.filter { selection.contains($0.id) }
            }
        }
    }
}

