import SwiftUI

/// Fond d’accueil : jungle lointaine → pyramide en gros plan, + overlay “sang” qui coule
struct PacksBackdrop: View {
    var closeUp: Bool          // true pendant l’ouverture du pack
    var bloodProgress: CGFloat // 0 → 1 : quantité de “rouge”

    var body: some View {
        ZStack {
            // Jungle lointaine
            Image("bg_jungle_far")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
                .opacity(closeUp ? 0 : 1)
                .scaleEffect(closeUp ? 1.05 : 1.0)
                .animation(.easeInOut(duration: 0.5), value: closeUp)

            // Pyramide proche
            Image("bg_pyramid_close")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
                .opacity(closeUp ? 1 : 0)
                .scaleEffect(closeUp ? 1.0 : 1.05)
                .animation(.easeInOut(duration: 0.6), value: closeUp)

            // Légère vignette pour lisibilité du texte/boutons
            LinearGradient(colors: [.black.opacity(0.35), .clear, .black.opacity(0.45)],
                           startPoint: .top, endPoint: .bottom)
            .ignoresSafeArea()

            // “Rivière” de sang stylisée (du haut au bas, centrée)
            GeometryReader { geo in
                let w = geo.size.width
                let h = geo.size.height
                // Largeur approx. de la coulée
                let riverW = max(90, w * 0.18)

                Rectangle()
                    .fill(LinearGradient(
                        colors: [
                            Color.red.opacity(min(0.85, 0.4 + bloodProgress * 0.7)),
                            Color.red.opacity(min(0.75, 0.25 + bloodProgress * 0.6))
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    ))
                    // hauteur animée
                    .frame(width: riverW, height: h * bloodProgress)
                    .position(x: w/2, y: (h * bloodProgress) / 2) // coule du haut vers le bas
                    .blur(radius: 6)
                    .blendMode(.plusLighter)
                    .opacity(closeUp ? 1 : 0) // visible seulement en “close-up”
                    .animation(.easeInOut(duration: 0.5), value: closeUp)
            }
            .allowsHitTesting(false)
        }
    }
}

