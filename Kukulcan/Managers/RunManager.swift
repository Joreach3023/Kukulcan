import Foundation

struct RunBattleContext: Identifiable {
    let id = UUID()
    let nodeID: UUID
    let enemy: Card
}

struct CampfireInteraction: Identifiable {
    let id = UUID()
    let nodeID: UUID
    let healAmount: Int
}

struct ShopInteraction: Identifiable {
    let id = UUID()
    let nodeID: UUID
    let cardOffers: [Card]
    let cardCost: Int
    let relic: Relic
    let relicCost: Int
    let removeCardCost: Int
}

struct EventInteraction: Identifiable {
    let id = UUID()
    let nodeID: UUID
    let event: MayaEvent
}

@MainActor
final class RunManager: ObservableObject {
    @Published private(set) var runState: RunState?
    @Published var activeBattle: RunBattleContext?
    @Published var pendingRewards: [Reward] = []
    @Published var pendingCampfire: CampfireInteraction?
    @Published var pendingShop: ShopInteraction?
    @Published var pendingEvent: EventInteraction?

    private let normalEnemies: [Card] = Array(CardsDB.commons.prefix(3))
    private let eliteEnemies: [Card] = Array(CardsDB.gods.filter { $0.name != "Kukulcan" }.prefix(3))
    private let bossEnemy: Card = CardsDB.gods.first(where: { $0.name == "Kukulcan" }) ?? CardsDB.gods[0]

    func startNewRun() {
        let starterCards = Array((CardsDB.commons.prefix(6) + CardsDB.rituals.prefix(2)).shuffled())
        let playerDeck = starterCards.map { RunCardInstance(card: $0) }
        let graph = MapGenerator().generateActMap()

        runState = RunState(
            status: .onMap,
            player: PlayerRunState(deck: playerDeck),
            nodes: graph.nodes,
            currentNodeID: nil
        )
        activeBattle = nil
        pendingRewards = []
        pendingCampfire = nil
        pendingShop = nil
        pendingEvent = nil
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
        case .combat:
            startBattle(for: node)
        case .elite:
            startBattle(for: node, forceElite: true)
        case .boss:
            startBattle(for: node)
        case .campfire:
            let healAmount = max(1, Int(Double(state.player.maxHP) * 0.3))
            pendingCampfire = CampfireInteraction(nodeID: node.id, healAmount: healAmount)
        case .shop:
            let cardCostModifier = hasRelic(named: "Totem d'obsidienne", in: state.player) ? 15 : 0
            pendingShop = ShopInteraction(
                nodeID: node.id,
                cardOffers: randomShopCards(),
                cardCost: max(0, 65 - cardCostModifier),
                relic: randomRelic(),
                relicCost: 110,
                removeCardCost: 55
            )
        case .event:
            if let event = MayaEventCatalog.events.randomElement() {
                pendingEvent = EventInteraction(nodeID: node.id, event: event)
            }
        case .treasure:
            guard var state = runState else { return }
            grantRelic(randomRelic(), to: &state.player)
            state.player.gold += 40
            completeNode(node.id, in: &state)
            runState = state
        }
    }

    func applyCampfireHeal(_ interaction: CampfireInteraction) {
        guard var state = runState else { return }
        state.player.currentHP = min(state.player.maxHP, state.player.currentHP + interaction.healAmount)
        completeNode(interaction.nodeID, in: &state)
        runState = state
        pendingCampfire = nil
    }

    func upgradeCardAtCampfire(_ cardID: UUID, interaction: CampfireInteraction) {
        guard var state = runState,
              let index = state.player.deck.firstIndex(where: { $0.id == cardID }),
              !state.player.deck[index].isUpgraded else { return }

        state.player.deck[index].isUpgraded = true
        state.player.deck[index].card = upgradedCard(from: state.player.deck[index].card)
        completeNode(interaction.nodeID, in: &state)
        runState = state
        pendingCampfire = nil
    }

    func buyCard(_ card: Card, from interaction: ShopInteraction) {
        guard var state = runState, state.player.gold >= interaction.cardCost else { return }

        state.player.gold -= interaction.cardCost
        state.player.deck.append(RunCardInstance(card: card))
        completeNode(interaction.nodeID, in: &state)
        runState = state
        pendingShop = nil
    }

    func buyRelic(from interaction: ShopInteraction) {
        guard var state = runState, state.player.gold >= interaction.relicCost else { return }

        state.player.gold -= interaction.relicCost
        grantRelic(interaction.relic, to: &state.player)
        completeNode(interaction.nodeID, in: &state)
        runState = state
        pendingShop = nil
    }

    func removeCardFromDeck(_ cardID: UUID, in interaction: ShopInteraction) {
        guard var state = runState,
              state.player.gold >= interaction.removeCardCost,
              let index = state.player.deck.firstIndex(where: { $0.id == cardID }) else { return }

        state.player.gold -= interaction.removeCardCost
        state.player.deck.remove(at: index)
        completeNode(interaction.nodeID, in: &state)
        runState = state
        pendingShop = nil
    }

    func chooseEventOption(_ option: MayaEventOption, in interaction: EventInteraction) {
        guard var state = runState else { return }

        var triggerEliteFight = false
        for effect in option.effects {
            switch effect {
            case .gainGold(let amount):
                state.player.gold += amount
            case .loseGold(let amount):
                state.player.gold = max(0, state.player.gold - amount)
            case .gainHP(let amount):
                state.player.currentHP = min(state.player.maxHP, state.player.currentHP + amount)
            case .loseHP(let amount):
                state.player.currentHP = max(0, state.player.currentHP - amount)
            case .gainRelic:
                grantRelic(randomRelic(), to: &state.player)
            case .gainCard(let rarity):
                if let card = randomCard(rarity: rarity) {
                    state.player.deck.append(RunCardInstance(card: card))
                }
            case .removeCard:
                if !state.player.deck.isEmpty {
                    state.player.deck.remove(at: Int.random(in: 0..<state.player.deck.count))
                }
            case .upgradeCard:
                upgradeRandomCard(in: &state.player.deck)
            case .startEliteFight:
                triggerEliteFight = true
            }
        }

        if state.player.currentHP <= 0 {
            state.status = .gameOver
            runState = state
            pendingEvent = nil
            return
        }

        completeNode(interaction.nodeID, in: &state)
        runState = state
        pendingEvent = nil

        if triggerEliteFight, let node = state.nodes.first(where: { $0.id == interaction.nodeID }) {
            startBattle(for: node, forceElite: true)
        }
    }

    func dismissPendingNodeInteractions() {
        pendingCampfire = nil
        pendingShop = nil
        pendingEvent = nil
    }

    func startBattle(for node: MapNode, forceElite: Bool = false) {
        guard var state = runState else { return }

        let enemy: Card
        if node.type == .boss {
            enemy = bossEnemy
        } else if node.type == .elite || forceElite {
            enemy = eliteEnemies.randomElement() ?? bossEnemy
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
            let baseGold = node.type == .boss ? 100 : 25
            let relicGoldBonus = hasRelic(named: "Idole solaire", in: state.player) ? 1 : 0
            state.player.gold += baseGold + relicGoldBonus

            if node.type == .elite,
               hasRelic(named: "Plume de Kukulcan", in: state.player) {
                state.player.currentHP = min(state.player.maxHP, state.player.currentHP + 2)
            }

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
        pendingRewards = buildCombatRewards(for: state.player)
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
        pendingCampfire = nil
        pendingShop = nil
        pendingEvent = nil
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

    private func randomShopCards() -> [Card] {
        Array((CardsDB.commons + CardsDB.rituals + CardsDB.gods).shuffled().prefix(3))
    }

    private func randomRelic() -> Relic {
        MayaRelicPool.all.randomElement() ?? Relic(name: "Amulette de jade", effectDescription: "+1 pioche au début du combat")
    }

    private func randomCard(rarity: Rarity?) -> Card? {
        let pool = CardsDB.commons + CardsDB.rituals + CardsDB.gods
        if let rarity {
            return pool.filter { $0.rarity == rarity }.randomElement() ?? pool.randomElement()
        }
        return pool.randomElement()
    }

    private func upgradeRandomCard(in deck: inout [RunCardInstance]) {
        let upgradable = deck.enumerated().filter { !$0.element.isUpgraded }
        guard let target = upgradable.randomElement()?.offset else { return }
        deck[target].isUpgraded = true
        deck[target].card = upgradedCard(from: deck[target].card)
    }

    private func upgradedCard(from card: Card) -> Card {
        Card(
            id: card.id,
            name: card.name + "+",
            type: card.type,
            rarity: card.rarity,
            imageName: card.imageName,
            attack: card.attack + (card.type == .ritual ? 0 : 1),
            health: card.health + (card.type == .common ? 1 : 0),
            ritual: card.ritual,
            bloodCost: max(0, card.bloodCost - (card.type == .god ? 1 : 0)),
            effect: card.effect + " (Améliorée)",
            lore: card.lore
        )
    }

    private func buildCombatRewards(for player: PlayerRunState) -> [Reward] {
        let basePool = CardsDB.commons + CardsDB.rituals
        let rareBoost: [Card]
        if hasRelic(named: "Masque rituel", in: player) {
            rareBoost = Array(repeating: CardsDB.gods, count: 2).flatMap { $0 }
        } else {
            rareBoost = []
        }

        let offeredCards = Array((basePool + rareBoost).shuffled().prefix(2))
        return offeredCards.map(Reward.card) + [.gold(20)]
    }

    private func grantRelic(_ relic: Relic, to player: inout PlayerRunState) {
        player.relics.append(relic)

        if relic.name == "Bassin lunaire" {
            player.maxHP += 5
            player.currentHP += 5
        }
    }

    private func hasRelic(named relicName: String, in player: PlayerRunState) -> Bool {
        player.relics.contains(where: { $0.name == relicName })
    }
}
