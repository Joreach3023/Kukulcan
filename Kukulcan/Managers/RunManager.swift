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
              isNodeSelectable(node, in: state) else {
            return
        }

        state.currentNodeID = node.id
        runState = state

        switch node.type {
        case .combat, .elite, .boss:
            startBattle(for: node)
        case .campfire:
            state.player.currentHP = min(state.player.maxHP, state.player.currentHP + 8)
            completeNode(node.id, in: &state)
            runState = state
        case .shop:
            state.player.gold += 30
            completeNode(node.id, in: &state)
            runState = state
        case .event:
            state.player.gold += 15
            state.player.currentHP = min(state.player.maxHP, state.player.currentHP + 3)
            completeNode(node.id, in: &state)
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
        guard var state = runState else { return }

        completeNode(nodeID, in: &state)

        if let node = state.nodes.first(where: { $0.id == nodeID }) {
            state.currentNodeID = nodeID
            state.player.gold += node.type == .boss ? 100 : 25

            if node.type == .boss {
                state.status = .victory
                runState = state
                activeBattle = nil
                pendingRewards = []
                return
            }
        }

        activeBattle = nil
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
        node.isUnlocked && !node.isCompleted && state.status == .onMap && !state.isFinished
    }

    private func completeNode(_ nodeID: UUID, in state: inout RunState) {
        guard let nodeIndex = state.nodes.firstIndex(where: { $0.id == nodeID }) else { return }

        state.nodes[nodeIndex].isCompleted = true
        let nextIDs = state.nodes[nodeIndex].nextNodeIDs
        for nextID in nextIDs {
            if let nextIndex = state.nodes.firstIndex(where: { $0.id == nextID }) {
                state.nodes[nextIndex].isUnlocked = true
            }
        }
    }

    private func generateMapNodes() -> [MapNode] {
        let ids = MapNodeIDs.self

        return [
            MapNode(id: ids.startPlaza, type: .event, x: 0.50, y: 0.86, nextNodeIDs: [ids.leftBloodAltar, ids.rightJaguarAltar], isUnlocked: true, isCompleted: false),
            MapNode(id: ids.leftBloodAltar, type: .combat, x: 0.18, y: 0.70, nextNodeIDs: [ids.centerGate], isUnlocked: false, isCompleted: false),
            MapNode(id: ids.rightJaguarAltar, type: .elite, x: 0.82, y: 0.69, nextNodeIDs: [ids.centerGate], isUnlocked: false, isCompleted: false),
            MapNode(id: ids.centerGate, type: .shop, x: 0.50, y: 0.61, nextNodeIDs: [ids.leftLowerTemple, ids.centerCrossroads, ids.rightLowerTemple], isUnlocked: false, isCompleted: false),
            MapNode(id: ids.leftLowerTemple, type: .campfire, x: 0.24, y: 0.50, nextNodeIDs: [ids.leftWaterfallShrine, ids.centerBridge], isUnlocked: false, isCompleted: false),
            MapNode(id: ids.centerCrossroads, type: .event, x: 0.50, y: 0.46, nextNodeIDs: [ids.centerBridge, ids.rightSkullSanctuary], isUnlocked: false, isCompleted: false),
            MapNode(id: ids.rightLowerTemple, type: .combat, x: 0.74, y: 0.49, nextNodeIDs: [ids.rightSkullSanctuary, ids.centerBridge], isUnlocked: false, isCompleted: false),
            MapNode(id: ids.leftWaterfallShrine, type: .shop, x: 0.20, y: 0.33, nextNodeIDs: [ids.topTempleBoss], isUnlocked: false, isCompleted: false),
            MapNode(id: ids.centerBridge, type: .combat, x: 0.50, y: 0.30, nextNodeIDs: [ids.topTempleBoss], isUnlocked: false, isCompleted: false),
            MapNode(id: ids.rightSkullSanctuary, type: .elite, x: 0.76, y: 0.33, nextNodeIDs: [ids.topTempleBoss], isUnlocked: false, isCompleted: false),
            MapNode(id: ids.topTempleBoss, type: .boss, x: 0.50, y: 0.16, nextNodeIDs: [], isUnlocked: false, isCompleted: false)
        ]
    }

    private func buildCombatRewards() -> [Reward] {
        let offeredCards = Array((CardsDB.commons + CardsDB.rituals).shuffled().prefix(2))
        return offeredCards.map(Reward.card) + [.gold(20)]
    }
}

private enum MapNodeIDs {
    static let startPlaza = UUID(uuidString: "A7A88E6D-5E96-47E2-A1A2-99A50E7A2001")!
    static let leftBloodAltar = UUID(uuidString: "A7A88E6D-5E96-47E2-A1A2-99A50E7A2002")!
    static let rightJaguarAltar = UUID(uuidString: "A7A88E6D-5E96-47E2-A1A2-99A50E7A2003")!
    static let centerGate = UUID(uuidString: "A7A88E6D-5E96-47E2-A1A2-99A50E7A2004")!
    static let leftLowerTemple = UUID(uuidString: "A7A88E6D-5E96-47E2-A1A2-99A50E7A2005")!
    static let centerCrossroads = UUID(uuidString: "A7A88E6D-5E96-47E2-A1A2-99A50E7A2006")!
    static let rightLowerTemple = UUID(uuidString: "A7A88E6D-5E96-47E2-A1A2-99A50E7A2007")!
    static let leftWaterfallShrine = UUID(uuidString: "A7A88E6D-5E96-47E2-A1A2-99A50E7A2008")!
    static let centerBridge = UUID(uuidString: "A7A88E6D-5E96-47E2-A1A2-99A50E7A2009")!
    static let rightSkullSanctuary = UUID(uuidString: "A7A88E6D-5E96-47E2-A1A2-99A50E7A2010")!
    static let topTempleBoss = UUID(uuidString: "A7A88E6D-5E96-47E2-A1A2-99A50E7A2011")!
}
