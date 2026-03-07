import Foundation

struct RunBattleContext: Identifiable {
    let id = UUID()
    let nodeID: UUID
    let enemy: Card
}

@MainActor
final class RunManager: ObservableObject {
    @Published private(set) var runState: RunState?
    @Published var activeBattle: RunBattleContext?
    @Published var pendingRewards: [Reward] = []

    private let normalEnemies: [Card] = Array(CardsDB.commons.prefix(3))
    private let bossEnemy: Card = CardsDB.gods.first(where: { $0.name == "Kukulcan" }) ?? CardsDB.gods[0]

    func startNewRun() {
        let starterCards = Array((CardsDB.commons.prefix(6) + CardsDB.rituals.prefix(2)).shuffled())
        let playerDeck = starterCards.map { RunCardInstance(card: $0) }
        let nodes = generateMapNodes()

        runState = RunState(
            status: .onMap,
            player: PlayerRunState(deck: playerDeck),
            nodes: nodes,
            currentNodeID: nil
        )
        activeBattle = nil
        pendingRewards = []
    }

    func selectNode(_ node: MapNode) {
        guard var state = runState,
              state.status == .onMap,
              isNodeSelectable(node, in: state),
              let nodeIndex = state.nodes.firstIndex(where: { $0.id == node.id }) else {
            return
        }

        state.currentNodeID = node.id
        runState = state

        switch node.type {
        case .combat, .boss:
            startBattle(for: node)
        case .campfire:
            state.player.currentHP = min(state.player.maxHP, state.player.currentHP + 8)
            state.nodes[nodeIndex].isVisited = true
            state.status = .onMap
            runState = state
        case .shop:
            state.player.gold += 30
            state.nodes[nodeIndex].isVisited = true
            state.status = .onMap
            runState = state
        case .event:
            state.player.gold += 15
            state.player.currentHP = min(state.player.maxHP, state.player.currentHP + 3)
            state.nodes[nodeIndex].isVisited = true
            state.status = .onMap
            runState = state
        }
    }

    func startBattle(for node: MapNode) {
        guard var state = runState else { return }

        let enemy: Card
        if node.type == .boss {
            enemy = bossEnemy
        } else {
            enemy = normalEnemies.randomElement() ?? CardsDB.commons[0]
        }

        state.status = .inBattle
        runState = state
        activeBattle = RunBattleContext(nodeID: node.id, enemy: enemy)
    }

    func handleBattleVictory(_ nodeID: UUID) {
        guard var state = runState,
              let nodeIndex = state.nodes.firstIndex(where: { $0.id == nodeID }) else { return }

        state.nodes[nodeIndex].isVisited = true
        state.currentNodeID = nodeID
        state.player.gold += state.nodes[nodeIndex].type == .boss ? 100 : 25

        activeBattle = nil

        if state.nodes[nodeIndex].type == .boss {
            state.status = .victory
            runState = state
            pendingRewards = []
            return
        }

        state.status = .choosingReward
        runState = state
        pendingRewards = buildCombatRewards()
    }

    func chooseReward(_ reward: Reward) {
        guard var state = runState, state.status == .choosingReward else { return }

        switch reward {
        case .card(let card):
            state.player.deck.append(RunCardInstance(card: card))
        case .gold(let amount):
            state.player.gold += amount
        case .heal(let amount):
            state.player.currentHP = min(state.player.maxHP, state.player.currentHP + amount)
        }

        pendingRewards = []
        state.status = .onMap
        runState = state
    }

    func endRun(victory: Bool = false) {
        guard var state = runState else { return }
        state.status = victory ? .victory : .gameOver
        activeBattle = nil
        pendingRewards = []
        runState = state
    }

    func isNodeSelectable(_ node: MapNode) -> Bool {
        guard let state = runState else { return false }
        return isNodeSelectable(node, in: state)
    }

    private func isNodeSelectable(_ node: MapNode, in state: RunState) -> Bool {
        !node.isVisited && node.index == state.nextNodeIndex
    }

    private func generateMapNodes() -> [MapNode] {
        let template: [MapNodeType] = [.combat, .campfire, .combat, .shop, .event, .combat, .boss]
        return template.enumerated().map { index, type in
            MapNode(index: index, type: type)
        }
    }

    private func buildCombatRewards() -> [Reward] {
        let offeredCards = Array((CardsDB.commons + CardsDB.rituals).shuffled().prefix(2))
        return offeredCards.map(Reward.card) + [.gold(20)]
    }
}
