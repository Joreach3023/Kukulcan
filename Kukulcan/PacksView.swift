import SwiftUI

struct PacksView: View {
    @EnvironmentObject var collection: CollectionStore
    private let packCost = 100

    @State private var lastPulled: [Card] = []
    @State private var showOpening = false
    @State private var pulse = false
    @State private var bloodProgress: CGFloat = 0
    @State private var selectedCard: Card? = nil

    var body: some View {
        NavigationStack {
            VStack(spacing: 18) {

                // Carte "Pack"
                ZStack {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(LinearGradient(colors: [.orange, .red],
                                             startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(height: 140)
                        .shadow(color: .orange.opacity(0.6), radius: 12)
                        .overlay(
                            VStack(spacing: 6) {
                                Text("Pack Mythique Maya")
                                    .font(.title2.bold())
                                    .foregroundStyle(.white)
                                Text("3 cartes aléatoires")
                                    .foregroundStyle(.white.opacity(0.9))
                            }
                        )
                        .scaleEffect(pulse ? 1.03 : 1.0)
                        .onAppear {
                            withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) {
                                pulse = true
                            }
                        }
                }
                .padding(.horizontal)

                // Affichage de l'or et du coût
                HStack {
                    Text("Or : \(collection.gold)")
                    Spacer()
                    Text("Coût : \(packCost)")
                }
                .padding(.horizontal)

                // Bouton ouvrir
                Button {
                    if let pulled = collection.buyPack(cost: packCost) {
                        lastPulled = pulled
                        showOpening = true
                    }
                } label: {
                    Label("Ouvrir un pack", systemImage: "sparkles")
                        .font(.headline)
                        .padding(.horizontal, 20).padding(.vertical, 12)
                        .background(Capsule().fill(.orange))
                        .foregroundStyle(.white)
                        .shadow(radius: 6)
                }
                .disabled(collection.gold < packCost)

                // Aperçu des cartes tirées
                if !lastPulled.isEmpty {
                    Text("Nouvelles cartes")
                        .font(.headline)
                        .padding(.top, 6)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(lastPulled) { card in
                                CardView(card: card, faceUp: true, width: 120) {
                                    selectedCard = card
                                }
                                .transition(.scale.combined(with: .opacity))
                                .shadow(color: card.rarity.glow, radius: 10)
                            }
                        }
                        .padding(.horizontal)
                    }
                    .scrollContentBackground(.hidden)
                }

                Spacer()

                Text("Cartes possédées : \(collection.owned.count)")
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                    .padding(.horizontal)
            }
            .toolbar(.hidden, for: .navigationBar)
            .toolbar(.visible, for: .tabBar)
            .background(
                PacksBackdrop(closeUp: showOpening, bloodProgress: bloodProgress).ignoresSafeArea()
            )
        }
        // Animation de sang durant l'ouverture
        .onChange(of: showOpening) { open in
            if open { withAnimation(.easeInOut(duration: 2.4)) { bloodProgress = 1.0 } }
            else    { withAnimation(.easeInOut(duration: 0.6)) { bloodProgress = 0.0 } }
        }
        .sheet(isPresented: $showOpening, onDismiss: {
            withAnimation(.easeInOut(duration: 0.6)) { bloodProgress = 0.0 }
        }) {
            PackOpeningView(cards: lastPulled) { showOpening = false }
        }
        .fullScreenCover(item: $selectedCard) { card in
            CardDetailView(card: card) { selectedCard = nil }
        }
        .onAppear { AudioManager.shared.play(.home) }
    }
}

#Preview {
    PacksView()
        .environmentObject(CollectionStore()) // ⬅️ important pour la preview
}

