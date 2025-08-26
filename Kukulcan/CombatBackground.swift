import SwiftUI

struct CombatBackground: View {
    var body: some View {
        ZStack {
            Image("bg_combat_jungle")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()

            // Vignette pour contraste
            LinearGradient(colors: [.black.opacity(0.35), .clear, .black.opacity(0.4)],
                           startPoint: .top, endPoint: .bottom)
            .ignoresSafeArea()
        }
    }
}

