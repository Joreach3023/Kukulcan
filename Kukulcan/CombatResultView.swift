import SwiftUI

struct CombatResultView: View {
    let isWin: Bool
    let gold: Int
    var onContinue: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Text(isWin ? "Victoire" : "Défaite")
                .font(.largeTitle)
                .bold()
            Text("Tu gagnes \(gold) or.")
                .font(.title2)
            Button("Continuer") {
                onContinue()
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 8)
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.6).ignoresSafeArea())
    }
}

#Preview {
    CombatResultView(isWin: true, gold: 50, onContinue: {})
}
