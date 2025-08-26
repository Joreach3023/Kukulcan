import SwiftUI

@main
struct ElementClashApp: App {
    @State private var showSplash = true
    @StateObject private var collection = CollectionStore()

    var body: some Scene {
        WindowGroup {
            ZStack {
                if showSplash {
                    // Écran d’introduction sans musique
                    MayaBloodSplashView {
                        withAnimation(.easeInOut(duration: 0.35)) {
                            showSplash = false
                        }
                    }
                    .transition(.opacity)
                } else {
                    MainTabView()
                        .environmentObject(collection)
                        .transition(.opacity)
                }
            }
        }
    }
}

