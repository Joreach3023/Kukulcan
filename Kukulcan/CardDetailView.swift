import SwiftUI
import UIKit

struct CardDetailView: View {
    let card: Card
    var onClose: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @State private var isFlipped: Bool = false
    @State private var tilt: CGSize = .zero

    private let corner: CGFloat = 24
    private let ratio: CGFloat = 1.5

    var body: some View {
        ZStack {
            // Fond assombri
            Color.black.opacity(0.6).ignoresSafeArea()

            VStack(spacing: 16) {
                // Header: nom + bouton fermer
                HStack {
                    Text(card.name)
                        .font(.title.bold())
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Spacer()
                    Button {
                        if let onClose { onClose() } else { dismiss() }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.9))
                    }
                    .accessibilityLabel("Fermer")
                }
                .padding(.horizontal)

                // Carte agrandie avec flip au long press
                GeometryReader { geo in
                    let w = min(geo.size.width * 0.85, 360)
                    let h = w * ratio

                    ZStack {
                        RoundedRectangle(cornerRadius: corner)
                            .fill(.ultraThinMaterial)
                            .overlay(
                                RoundedRectangle(cornerRadius: corner)
                                    .stroke(card.rarity.glow.opacity(0.9), lineWidth: 2)
                            )
                            .shadow(color: card.rarity.glow.opacity(0.6), radius: 14, x: 0, y: 10)

                        VStack(spacing: 0) {
                            // Bandeau haut
                            header
                                .frame(height: max(44, w * 0.22))
                                .frame(maxWidth: .infinity)
                                .background(
                                    LinearGradient(colors: [.black.opacity(0.55), .black.opacity(0.25)],
                                                   startPoint: .top, endPoint: .bottom)
                                )
                                .clipShape(RoundedCorners(topLeft: corner, topRight: corner, bottomLeft: 0, bottomRight: 0))

                            // Illustration / Dos
                            ZStack {
                                if !isFlipped {
                                    Image(card.imageName)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: w, height: h - topHeight(w) - bottomHeight(w))
                                        .clipped()
                                } else {
                                    // Dos : fond coloré + soleil
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(
                                            LinearGradient(colors: card.rarity.colors,
                                                           startPoint: .topLeading, endPoint: .bottomTrailing)
                                        )
                                        .overlay(
                                            Image("kinich_ahau")
                                                .resizable()
                                                .scaledToFit()
                                                .frame(width: w * 0.4, height: w * 0.4)
                                        )
                                        .frame(width: w, height: h - topHeight(w) - bottomHeight(w))
                                        .clipped()
                                }
                            }

                            // Bandeau bas (texte d’effet)
                            HStack {
                                Text(card.effect ?? "")
                                    .font(.footnote)
                                    .foregroundStyle(.white.opacity(0.95))
                                    .lineLimit(2)
                                    .minimumScaleFactor(0.7)
                                Spacer(minLength: 0)
                            }
                            .padding(.horizontal, 12)
                            .frame(height: max(38, w * 0.18))
                            .frame(maxWidth: .infinity)
                            .background(
                                LinearGradient(colors: [.black.opacity(0.30), .black.opacity(0.55)],
                                               startPoint: .top, endPoint: .bottom)
                            )
                            .clipShape(RoundedCorners(topLeft: 0, topRight: 0, bottomLeft: corner, bottomRight: corner))
                        }
                        .frame(width: w, height: h)
                        .rotation3DEffect(.degrees(isFlipped ? 180 : 0), axis: (x: 0, y: 1, z: 0))
                        .rotation3DEffect(.degrees(Double(tilt.width / 10)), axis: (x: 0, y: 1, z: 0))
                        .rotation3DEffect(.degrees(Double(-tilt.height / 10)), axis: (x: 1, y: 0, z: 0))
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    tilt = CGSize(
                                        width: value.translation.width.clamped(to: -40...40),
                                        height: value.translation.height.clamped(to: -40...40)
                                    )
                                }
                                .onEnded { value in
                                    let translation = value.translation
                                    if abs(translation.width) > abs(translation.height),
                                       abs(translation.width) > 30 {
                                        withAnimation(.easeInOut(duration: 0.35)) { isFlipped.toggle() }
                                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                    }
                                    withAnimation(.spring()) { tilt = .zero }
                                }
                        )
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.35)) { isFlipped.toggle() }
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        }

                        .accessibilityAddTraits(.isButton)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .frame(height: 520)

                // Infos détaillées (lore + rareté)
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Label(cardTypeText, systemImage: iconForType)
                            .padding(.horizontal, 10).padding(.vertical, 6)
                            .background(Capsule().fill(.white.opacity(0.12)))
                        Spacer()
                        Text("ATK \(card.attack) • HP \(card.health)")
                            .font(.headline)
                    }
                    .foregroundStyle(.white)

                    if let lore = card.lore, !lore.isEmpty {
                        Text(lore)   // ⬅️ on a unwrapped avec if let
                            .font(.callout)
                            .foregroundStyle(.white.opacity(0.9))
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    HStack(spacing: 8) {
                        Text(card.rarity.title)
                            .font(.caption.bold())
                            .padding(.horizontal, 8).padding(.vertical, 4)
                            .background(Capsule().fill(LinearGradient(colors: card.rarity.colors, startPoint: .topLeading, endPoint: .bottomTrailing)))
                            .foregroundStyle(.white)
                    }
                }
                .padding(.horizontal)

                Spacer(minLength: 10)
            }
        }
    }

    // MARK: - Subviews / helpers

    private func topHeight(_ w: CGFloat) -> CGFloat { max(44, w * 0.22) }
    private func bottomHeight(_ w: CGFloat) -> CGFloat { max(38, w * 0.18) }

    private var header: some View {
        HStack(spacing: 8) {
            Text(cardTypeText)
                .font(.caption2.bold())
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background(Capsule().fill(typeChipBG))
                .foregroundStyle(.white)

            Text(card.name)
                .font(.headline)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .foregroundStyle(.white)

            Spacer()

            HStack(spacing: 6) {
                Text("\(card.attack)/\(card.health)")
                    .font(.headline.bold())
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(.white.opacity(0.15))
            .clipShape(Capsule())
        }
        .padding(.horizontal, 12)
    }

    private var typeChipBG: LinearGradient {
        switch card.type {
        case .god:    return LinearGradient(colors: [.orange, .red], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .ritual: return LinearGradient(colors: [.purple, .pink], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .common: return LinearGradient(colors: [.gray, .black.opacity(0.6)], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }

    private var cardTypeText: String {
        switch card.type {
        case .god:    return "DIEU"
        case .ritual: return "RITUEL"
        case .common: return "PEUPLE"
        }
    }

    private var iconForType: String {
        switch card.type {
        case .god:    return "sparkles"
        case .ritual: return "wand.and.stars"
        case .common: return "person.fill"
        }
    }

    // Les éléments ne sont plus utilisés, on affiche uniquement les statistiques.
}

// Coins arrondis sélectifs
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

// Petit helper clamp
fileprivate extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

