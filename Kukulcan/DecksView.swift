import SwiftUI

struct DecksView: View {
    @EnvironmentObject var collection: CollectionStore

    var body: some View {
        List {
            ForEach(collection.decks.indices, id: \.self) { i in
                NavigationLink(destination: DeckEditorView(deck: $collection.decks[i])) {
                    HStack {
                        Text(collection.decks[i].name)
                        Spacer()
                        Text("\(collection.decks[i].cards.count)/10")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .onDelete { offsets in
                collection.decks.remove(atOffsets: offsets)
            }

            if collection.decks.count < 20 {
                Button {
                    collection.decks.append(Deck(name: "Nouveau deck", cards: []))
                } label: {
                    Label("Créer un deck", systemImage: "plus")
                }
            }
        }
        .navigationTitle("Decks")
        .toolbar { EditButton() }
    }
}

