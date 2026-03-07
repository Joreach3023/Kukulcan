import SwiftUI

struct RewardView: View {
    let rewards: [Reward]
    let onChoose: (Reward) -> Void

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("Choisissez une récompense")
                    .font(.title3.bold())

                ForEach(rewards) { reward in
                    Button {
                        onChoose(reward)
                    } label: {
                        HStack {
                            Image(systemName: iconName(for: reward))
                                .foregroundStyle(.orange)
                            Text(reward.title)
                                .foregroundStyle(.primary)
                            Spacer()
                        }
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                }

                Spacer()
            }
            .padding()
            .navigationTitle("Reward")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func iconName(for reward: Reward) -> String {
        switch reward {
        case .card: return "rectangle.stack.badge.plus"
        case .gold: return "bitcoinsign.circle.fill"
        case .heal: return "heart.fill"
        }
    }
}
