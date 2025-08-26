import SwiftUI

/// Root view used when launching a quick match.
/// It simply wraps `CombatView`, which displays the full
/// board with decks, hands, discard piles, sacrifice and god slots.
struct ContentView: View {
    var body: some View {
        CombatView()
    }
}

#Preview {
    ContentView()
}
