import SwiftUI

@main
struct ElementClashApp: App {
    @State private var showSplash = true
    @StateObject private var collection = CollectionStore()

    var body: some Scene {
        WindowGroup {
            ZStack {
                MainTabView()
                    .environmentObject(collection)
                    .opacity(showSplash ? 0 : 1)
                    .transition(.opacity)

                if showSplash {
                    // Si tu utilises l’intro “MayaBloodSplashView”
                    MayaBloodSplashView {
                        withAnimation(.easeInOut(duration: 0.35)) {
                            showSplash = false
                        }
                    }
                    .transition(.opacity)
                }
            }
        }
    }
}

