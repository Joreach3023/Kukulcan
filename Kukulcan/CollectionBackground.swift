import SwiftUI

struct CollectionBackground: View {
    /// Nom de l'image de fond unique (par défaut: papier taché)
    var imageName: String = "bg_collection_paper"
    /// Active une légère vignette pour le contraste du contenu
    var vignette: Bool = true

    var body: some View {
        ZStack {
            Image(imageName)
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()

            if vignette {
                LinearGradient(
                    colors: [
                        .black.opacity(0.15),
                        .clear,
                        .black.opacity(0.15)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            }
        }
    }
}

