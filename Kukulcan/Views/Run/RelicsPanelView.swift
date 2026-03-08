import SwiftUI

struct RelicsPanelView: View {
    let relics: [Relic]
    var title: String = "Reliques"

    var body: some View {
        NavigationStack {
            Group {
                if relics.isEmpty {
                    ContentUnavailableView(
                        "Aucune relique obtenue pour le moment.",
                        systemImage: "sparkles.slash"
                    )
                } else {
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            ForEach(relics) { relic in
                                RelicRowView(relic: relic)
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct RelicsButton: View {
    let count: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label {
                Text("Reliques")
                Text("\(count)")
                    .font(.caption2.bold())
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.white.opacity(0.2), in: Capsule())
            } icon: {
                Image(systemName: "sparkles")
            }
        }
        .buttonStyle(.borderedProminent)
        .tint(.indigo)
    }
}

private struct RelicRowView: View {
    let relic: Relic

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            relicIcon

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(relic.name)
                        .font(.headline)
                    rarityBadge
                }

                Text(relic.description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text(relic.effect)
                    .font(.footnote)
                    .foregroundStyle(.primary)
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
    }

    private var relicIcon: some View {
        Group {
            if relic.image != "relic_placeholder", UIImage(named: relic.image) != nil {
                Image(relic.image)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "sparkles.rectangle.stack.fill")
                    .resizable()
                    .scaledToFit()
                    .padding(8)
                    .foregroundStyle(.yellow)
            }
        }
        .frame(width: 52, height: 52)
        .background(.black.opacity(0.25), in: RoundedRectangle(cornerRadius: 12))
        .overlay(alignment: .topTrailing) {
            if relic.rarity == .epic || relic.rarity == .legendary {
                Image(systemName: "star.circle.fill")
                    .foregroundStyle(.orange)
                    .background(.black.opacity(0.5), in: Circle())
                    .offset(x: 5, y: -5)
            }
        }
    }

    private var rarityBadge: some View {
        Text(relic.rarity.rawValue.capitalized)
            .font(.caption.bold())
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(rarityColor.opacity(0.22), in: Capsule())
            .foregroundStyle(rarityColor)
    }

    private var rarityColor: Color {
        switch relic.rarity {
        case .common: return .gray
        case .rare: return .blue
        case .epic: return .purple
        case .legendary: return .orange
        }
    }
}

