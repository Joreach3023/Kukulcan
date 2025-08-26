import SwiftUI

struct SplashView: View {
    @State private var scale: CGFloat = 0.8
    @State private var opacity: Double = 0.0
    let onFinish: () -> Void

    var body: some View {
        ZStack {
            Color(.sRGB, red: 0.043, green: 0.071, blue: 0.078, opacity: 1) // #0B1214
                .ignoresSafeArea()

            // Mets "LaunchLogo" ou "LaunchLogo_KinichAhau" selon ce que tu préfères
            Image("LaunchLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 220, height: 220)
                .scaleEffect(scale)
                .opacity(opacity)
                .onAppear {
                    withAnimation(.easeOut(duration: 0.6)) {
                        scale = 1.0
                        opacity = 1.0
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
                        withAnimation(.easeIn(duration: 0.25)) { opacity = 0 }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { onFinish() }
                    }
                }
        }
    }
}
