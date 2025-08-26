import SwiftUI

struct MayaBloodSplashView: View {
    var onFinish: () -> Void
    
    @State private var fillAmount: CGFloat = 0.0   // 0 = pas de sang, 1 = tout rouge
    
    var body: some View {
        ZStack {
            // Image de fond
            Image("MayaRiver")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
            
            // Couche rouge qui recouvre progressivement le fond
            Rectangle()
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.red.opacity(0.9),
                            Color.red.opacity(0.6),
                            Color.clear
                        ]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .mask(
                    // masque : une forme qui descend du haut vers le bas
                    GeometryReader { geo in
                        Rectangle()
                            .frame(height: geo.size.height * fillAmount)
                            .position(x: geo.size.width / 2, y: (geo.size.height * fillAmount) / 2)
                    }
                )
                .ignoresSafeArea()
                .blendMode(.multiply) // donne un effet plus réaliste
        
            // Logo centré (optionnel)
            VStack {
                Spacer()
                Text("Kukulcan")
                    .font(.largeTitle.bold())
                    .foregroundStyle(.white)
                    .shadow(radius: 8)
                Spacer()
            }
        }
        .onAppear {
            withAnimation(.linear(duration: 4.0)) {   // vitesse : 4 secondes
                fillAmount = 1.0
            }
            
            // Quand c’est terminé → passe à l’app
            DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
                onFinish()
            }
        }
    }
}

