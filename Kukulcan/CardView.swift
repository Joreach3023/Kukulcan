import SwiftUI

struct CardBackView: View {
    /// Largeur de la carte. Utilisée pour calculer la hauteur du dos.
    var width: CGFloat = 140
    /// Rayon des coins pour adapter l'arrondi selon le format d'affichage.
    var cornerRadius: CGFloat = 18
    private let ratio: CGFloat = 1.5

    var body: some View {
        let h = width * ratio

        // Utilise l'image "MayaRiver" comme dos de carte
        Image("MayaRiver")
            .resizable()
            .scaledToFill()
            .frame(width: width, height: h)
            .clipped()
            .cornerRadius(cornerRadius)
    }
}


struct CardView: View {
    let card: Card
    var faceUp: Bool = true
    var width: CGFloat = 140
    var onTap: (() -> Void)? = nil

    private let ratio: CGFloat = 1.5

    // Tailles de police adaptatives
    private var typeFont: Font { .system(size: width * 0.08, weight: .bold) }
    private var nameFont: Font { .system(size: width * 0.12, weight: .semibold) }
    private var statFont: Font { .system(size: width * 0.12, weight: .bold) }
    private var effectFont: Font { .system(size: width * 0.10) }

    var body: some View {
        let h = width * ratio

        // Contenu principal de la carte (face recto)
        let front = ZStack {
            // Fond / cadre carte teinté selon la rareté
            RoundedRectangle(cornerRadius: 18)
                .fill(
                    LinearGradient(
                        colors: [
                            card.rarity.glow.opacity(0.15),
                            .black.opacity(0.85)
                        ],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(glowStroke, lineWidth: 2)
                )
                .shadow(color: card.rarity.glow.opacity(0.6), radius: 10, x: 0, y: 6)

            // Illustration (avec place en haut et en bas)
            VStack(spacing: 0) {
                // Bandeau haut
                header
                    .frame(height: topHeight)
                    .frame(maxWidth: .infinity)
                    .background(headerBG)
                    .clipShape(RoundedCorners(topLeft: 18, topRight: 18, bottomLeft: 0, bottomRight: 0))

                // Image
                ZStack {
                    if let ui = UIImage(named: card.imageName) {
                        Image(uiImage: ui)
                            .resizable()
                            .scaledToFill()
                            .frame(width: width, height: h - topHeight - bottomHeight)
                            .clipped()
                    } else {
                        // Fallback si l’asset est absent
                        CardBackView(width: width)
                            .frame(width: width, height: h - topHeight - bottomHeight)
                    }
                }

                // Bandeau bas (effet)
                footer
                    .frame(height: bottomHeight)
                    .frame(maxWidth: .infinity)
                    .background(footerBG)
                    .clipShape(RoundedCorners(topLeft: 0, topRight: 0, bottomLeft: 18, bottomRight: 18))
            }
            .clipShape(RoundedRectangle(cornerRadius: 18))
        }

        // Dos de carte
        let back = CardBackView(width: width)

        let cardStack = ZStack {
            front
                .opacity(faceUp ? 1 : 0)
                .rotation3DEffect(.degrees(faceUp ? 0 : 180), axis: (x: 0, y: 1, z: 0))

            back
                .opacity(faceUp ? 0 : 1)
                .rotation3DEffect(.degrees(faceUp ? -180 : 0), axis: (x: 0, y: 1, z: 0))
        }
        .frame(width: width, height: h)
        .contentShape(RoundedRectangle(cornerRadius: 18))
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: faceUp)

        // N’applique le geste de tap que si un callback existe.
        return Group {
            if let onTap {
                cardStack.onTapGesture { onTap() }
            } else {
                cardStack
            }
        }
    }

    // MARK: - Layout helpers

    private var topHeight: CGFloat { max(18, width * 0.11) }
    private var bottomHeight: CGFloat { max(15, width * 0.09) }

    private var header: some View {
        HStack(spacing: 8) {
            // Type
            Text(card.rarity == .legendary ? "DIEU" : cardTypeText)
                .font(typeFont)
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background(Capsule().fill(typeChipBG))
                .foregroundStyle(.white)

            // Nom
            Text(card.name)
                .font(nameFont)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .foregroundStyle(.white)

            Spacer()

            // Puissance
            HStack(spacing: 4) {
                Text("\(card.attack)/\(card.health)")
                    .font(statFont)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(.white.opacity(0.15))
            .clipShape(Capsule())
        }
        .padding(.horizontal, 10)
    }

    private var footer: some View {
        HStack {
            Text(card.effect)
                .font(effectFont)
                .foregroundStyle(.white.opacity(0.95))
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
    }

    // MARK: - Styles

    private var glowStroke: LinearGradient {
        LinearGradient(
            colors: [
                card.rarity.glow.opacity(0.9),
                card.rarity.glow.opacity(0.3)
            ],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
    }

    private var headerBG: LinearGradient {
        LinearGradient(
            colors: [.black.opacity(0.55), .black.opacity(0.25)],
            startPoint: .top, endPoint: .bottom
        )
    }

    private var footerBG: LinearGradient {
        LinearGradient(
            colors: [.black.opacity(0.30), .black.opacity(0.55)],
            startPoint: .top, endPoint: .bottom
        )
    }

    private var typeChipBG: LinearGradient {
        if card.rarity == .legendary {
            return LinearGradient(colors: [.orange, .red], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
        return LinearGradient(colors: [.gray, .black.opacity(0.6)], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    private var cardTypeText: String {
        switch card.type {
        case .god:    return "DIEU"
        case .ritual: return "RITUEL"
        case .common: return "PEUPLE"
        }
    }

}

// Coins arrondis sélectifs pour les bandeaux
fileprivate struct RoundedCorners: Shape {
    var topLeft: CGFloat = 0.0
    var topRight: CGFloat = 0.0
    var bottomLeft: CGFloat = 0.0
    var bottomRight: CGFloat = 0.0

    func path(in rect: CGRect) -> Path {
        var path = Path()

        let tl = min(min(self.topLeft, rect.width/2), rect.height/2)
        let tr = min(min(self.topRight, rect.width/2), rect.height/2)
        let bl = min(min(self.bottomLeft, rect.width/2), rect.height/2)
        let br = min(min(self.bottomRight, rect.width/2), rect.height/2)

        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - tr, y: rect.minY))
        path.addArc(center: CGPoint(x: rect.maxX - tr, y: rect.minY + tr),
                    radius: tr, startAngle: .degrees(-90), endAngle: .degrees(0), clockwise: false)
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - br))
        path.addArc(center: CGPoint(x: rect.maxX - br, y: rect.maxY - br),
                    radius: br, startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false)
        path.addLine(to: CGPoint(x: rect.minX + bl, y: rect.maxY))
        path.addArc(center: CGPoint(x: rect.minX + bl, y: rect.maxY - bl),
                    radius: bl, startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false)
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + tl))
        path.addArc(center: CGPoint(x: rect.minX + tl, y: rect.minY + tl),
                    radius: tl, startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)
        path.closeSubpath()
        return path
    }
}

