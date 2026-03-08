import SwiftUI

struct CombatBackground: View {
    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black.ignoresSafeArea()

                Image("bg_combat_jungle")
                    .resizable()
                    .scaledToFit()
                    .frame(width: geo.size.width, height: geo.size.height)
                    .ignoresSafeArea()

                // Vignette pour contraste
                LinearGradient(colors: [.black.opacity(0.35), .clear, .black.opacity(0.4)],
                               startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            }
        }
    }
}
