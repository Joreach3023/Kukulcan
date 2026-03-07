import SwiftUI

struct RunMapView: View {
    @StateObject private var runManager = RunManager()

    var body: some View {
        VStack(spacing: 16) {
            if let run = runManager.runState {
                header(run: run)
                mapList(run: run)
                statusFooter(run: run)
            } else {
                Spacer()
                Button("New Run") {
                    runManager.startNewRun()
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
                Spacer()
            }
        }
        .padding()
        .navigationTitle("Roguelike")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("New Run") {
                    runManager.startNewRun()
                }
            }
        }
        .sheet(isPresented: Binding(
            get: { !runManager.pendingRewards.isEmpty },
            set: { _ in }
        )) {
            RewardView(rewards: runManager.pendingRewards) { reward in
                runManager.chooseReward(reward)
            }
        }
        .fullScreenCover(item: $runManager.activeBattle) { battle in
            CombatView(
                engine: GameEngine(
                    p1: PlayerState(name: "Aventurier", deck: runManager.runState?.player.deck.map(\.card) ?? StarterFactory.playerDeck()),
                    p2: PlayerState(name: battle.enemy.name, deck: StarterFactory.randomDeck())
                ),
                aiLevel: 1,
                onWin: { _ in
                    runManager.handleBattleVictory(battle.nodeID)
                },
                onLoss: {
                    runManager.endRun(victory: false)
                }
            )
        }
        .onAppear {
            if runManager.runState == nil {
                runManager.startNewRun()
            }
        }
    }

    private func header(run: RunState) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("HP: \(run.player.currentHP)/\(run.player.maxHP)", systemImage: "heart.fill")
            Label("Gold: \(run.player.gold)", systemImage: "bitcoinsign.circle.fill")
            Label("Deck: \(run.player.deck.count) cartes", systemImage: "rectangle.stack.fill")
        }
        .font(.headline)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func mapList(run: RunState) -> some View {
        ScrollView {
            VStack(spacing: 10) {
                ForEach(run.nodes) { node in
                    Button {
                        runManager.selectNode(node)
                    } label: {
                        HStack {
                            Image(systemName: node.type.systemImage)
                                .foregroundStyle(node.type == .boss ? .red : .orange)
                            Text("Nœud \(node.index + 1): \(node.type.title)")
                            Spacer()
                            if node.isVisited {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                            }
                        }
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                    .disabled(!runManager.isNodeSelectable(node) || run.isFinished)
                    .opacity(runManager.isNodeSelectable(node) && !run.isFinished ? 1 : 0.45)
                }
            }
        }
    }

    private func statusFooter(run: RunState) -> some View {
        Group {
            switch run.status {
            case .victory:
                Text("🏆 Victoire ! Le boss final est vaincu.")
                    .font(.headline)
                    .foregroundStyle(.green)
            case .gameOver:
                Text("☠️ Game Over. Lancez une nouvelle run.")
                    .font(.headline)
                    .foregroundStyle(.red)
            case .choosingReward:
                Text("Récompense en cours...")
                    .foregroundStyle(.secondary)
            default:
                Text("Sélectionnez le prochain nœud.")
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
