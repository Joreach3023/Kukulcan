import SwiftUI

struct CardBackView: View {
    var width: CGFloat? = nil   // non utilisé, mais conservé pour matcher l’appel existant

    var body: some View {
        ZStack {
            // Dos neutre stylé
            RoundedRectangle(cornerRadius: 12)
                .fill(
                    LinearGradient(
                        colors: [.gray.opacity(0.6), .black.opacity(0.85)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(.white.opacity(0.2), lineWidth: 1)
                )

            // Petit symbole central
            Image(systemName: "triangle.fill")
                .font(.system(size: 42, weight: .bold))
                .foregroundStyle(.white.opacity(0.85))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity) // s’étire dans le conteneur parent
        .clipped()
    }
}


struct CardView: View {
    let card: Card
    var faceUp: Bool = true
    var width: CGFloat = 140
    var onTap: (() -> Void)? = nil

    private let ratio: CGFloat = 1.5

    var body: some View {
        let h = width * ratio

        ZStack {
            // Fond / cadre carte
            RoundedRectangle(cornerRadius: 18)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(glowStroke, lineWidth: 2)
                )
                .shadow(color: card.rarity.glow.opacity(0.6), radius: 10, x: 0, y: 6)

            // Illustration (avec place en haut et en bas)
            VStack(spacing: 0) {
                // Bandeau haut
                header
                    .frame(height: max(36, width * 0.22))
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
                        CardBackView()
                            .frame(width: width, height: h - topHeight - bottomHeight)
                    }

                }

                // Bandeau bas (effet)
                footer
                    .frame(height: max(30, width * 0.18))
                    .frame(maxWidth: .infinity)
                    .background(footerBG)
                    .clipShape(RoundedCorners(topLeft: 0, topRight: 0, bottomLeft: 18, bottomRight: 18))
            }
            .clipShape(RoundedRectangle(cornerRadius: 18))
        }
        .frame(width: width, height: h)
        .contentShape(RoundedRectangle(cornerRadius: 18))
        .onTapGesture { onTap?() }
    }

    // MARK: - Layout helpers

    private var topHeight: CGFloat { max(36, width * 0.22) }
    private var bottomHeight: CGFloat { max(30, width * 0.18) }

    private var header: some View {
        HStack(spacing: 8) {
            // Type
            Text(card.rarity == .legendary ? "DIEU" : cardTypeText)
                .font(.caption2.bold())
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background(Capsule().fill(typeChipBG))
                .foregroundStyle(.white)

            // Nom
            Text(card.name)
                .font(.headline)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .foregroundStyle(.white)

            Spacer()

            // Puissance
            HStack(spacing: 4) {
                Image(systemName: elementIcon)
                Text("\(card.attack)/\(card.health)")
                    .font(.headline.bold())
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
            Text(card.effect ?? "")
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.95))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
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

    private var elementIcon: String {
        switch card.element {
        case .fire:  return "flame.fill"
        case .water: return "drop.fill"
        case .plant: return "leaf.fill"
        }
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

