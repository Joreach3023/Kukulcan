import SwiftUI
import AVFoundation

struct PackOpeningView: View {
    let cards: [Card]
    let onClose: () -> Void

    @State private var stage: Int = 0
    @State private var showCards: [Bool] = [false, false, false]
    @State private var packScale: CGFloat = 1.0
    @State private var packOpacity: Double = 1.0
    @State private var burst: Double = 0.0
    @State private var selectedCard: Card? = nil

    var body: some View {
        ZStack {
            backgroundView

            if stage == 0 {
                packClosedView
            }

            if stage >= 1 {
                cardsRow
                    .offset(y: stage == 1 ? 40 : 0)
            }

            if stage >= 2 {
                closeButton
            }
        }
        .animation(.default, value: stage)
        .animation(.default, value: showCards)
        .fullScreenCover(item: $selectedCard) { card in
            CardDetailView(card: card) { selectedCard = nil }
        }
    }
}

// MARK: - Subviews

private extension PackOpeningView {
    var backgroundView: some View {
        ZStack {
            RadialGradient(
                colors: [.black, .black.opacity(0.2), .orange.opacity(0.2)],
                center: .center, startRadius: 20, endRadius: 500
            )
            .ignoresSafeArea()

            SparksLayer(time: burst)
                .opacity(0.9)
                .blendMode(.plusLighter)
                .allowsHitTesting(false)
        }
    }

    var packClosedView: some View {
        RoundedRectangle(cornerRadius: 22)
            .fill(
                LinearGradient(
                    colors: [.orange, .red],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .overlay(
                VStack(spacing: 6) {
                    Text("Pack Mythique Maya")
                        .font(.title3.bold())
                        .foregroundStyle(.white)
                    Text("Touchez pour ouvrir")
                        .foregroundStyle(.white.opacity(0.9))
                }
                .padding()
            )
            .frame(width: 260, height: 360)
            .shadow(color: .orange.opacity(0.8), radius: 18)
            .scaleEffect(packScale)
            .opacity(packOpacity)
            .onAppear {
                withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) {
                    packScale = 1.03
                }
            }
            .onTapGesture { open() }
    }

    var cardsRow: some View {
        HStack(spacing: 14) {
            ForEach(0..<3, id: \.self) { i in
                cardSlot(index: i)
            }
        }
        .padding(.horizontal, 16)
    }

    @ViewBuilder
    func cardSlot(index i: Int) -> some View {
        if i < cards.count, showCards[i] {
            CardView(card: cards[i], faceUp: true, width: 120) {
                selectedCard = cards[i]
            }
            .transition(.scale.combined(with: .opacity))
            .shadow(color: cards[i].rarity.glow, radius: 14)
        } else {
            PlaceholderCard(width: 120, height: 180)
        }
    }

    var closeButton: some View {
        VStack {
            Spacer()
            Button {
                onClose()
            } label: {
                Label("Ajouter à la collection", systemImage: "checkmark.seal.fill")
                    .font(.headline)
                    .padding(.horizontal, 18).padding(.vertical, 12)
                    .background(Capsule().fill(.orange))
                    .foregroundStyle(.white)
                    .shadow(radius: 6)
            }
            .padding(.bottom, 24)
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}

// MARK: - Actions

private extension PackOpeningView {
    func open() {
        // Haptic
        let gen = UIImpactFeedbackGenerator(style: .heavy)
        gen.impactOccurred()

        // Disparition du booster + “burst”
        withAnimation(.easeInOut(duration: 0.25)) {
            packScale = 0.9
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
            withAnimation(.easeOut(duration: 0.25)) {
                packOpacity = 0
                stage = 1
                burst = 10
            }
            // Révéler les cartes en cascade
            for i in 0..<min(3, cards.count) {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25 + Double(i) * 0.3) {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) {
                        showCards[i] = true
                    }
                    let g = UINotificationFeedbackGenerator()
                    g.notificationOccurred(.success)
                    AudioServicesPlaySystemSound(1104) // petit “tock” système
                }
            }
            // Bouton
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                withAnimation(.easeInOut(duration: 0.35)) { stage = 2 }
            }
        }
    }
}

// MARK: - Placeholder

struct PlaceholderCard: View {
    let width: CGFloat
    let height: CGFloat

    var body: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(Color.gray.opacity(0.18))
            .overlay(
                Image(systemName: "seal.fill")
                    .font(.system(size: 28, weight: .regular))
                    .foregroundStyle(.white.opacity(0.35))
            )
            .frame(width: width, height: height)
            .shadow(radius: 3)
    }
}

