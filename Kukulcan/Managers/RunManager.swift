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

struct ShopRelicOffer: Identifiable, Hashable {
    let id = UUID()
    let relic: Relic
    let cost: Int
    var isPurchased: Bool = false
}

struct ShopInteraction: Identifiable {
    let id = UUID()
    let nodeID: UUID
    var relicOffers: [ShopRelicOffer]
}

struct EventInteraction: Identifiable {
    let id = UUID()
    let nodeID: UUID
    let event: MayaEvent
}

enum CardSelectionMode {
    case upgrade
    case addToDeck
}

struct CardSelectionInteraction: Identifiable {
    let id = UUID()
    let nodeID: UUID
    let title: String
    let description: String
    let mode: CardSelectionMode
    let upgradableCards: [RunCardInstance]
    let cardChoices: [Card]
}

struct CardSelectionResult: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let card: Card
}

@MainActor
final class RunManager: ObservableObject {
    @Published private(set) var runState: RunState?
    @Published var activeBattle: RunBattleContext?
    @Published var pendingRewards: [Reward] = []
    @Published var pendingCampfire: CampfireInteraction?
    @Published var pendingShop: ShopInteraction?
    @Published var pendingEvent: EventInteraction?
    @Published var pendingCardSelection: CardSelectionInteraction?
    @Published var pendingCardResult: CardSelectionResult?

    private let normalEnemies: [Card] = Array(CardsDB.commons.prefix(3))
    private let eliteEnemies: [Card] = Array(CardsDB.gods.filter { $0.name != "Kukulcan" }.prefix(3))
    private let bossEnemy: Card = CardsDB.gods.first(where: { $0.name == "Kukulcan" }) ?? CardsDB.gods[0]
    private var codexBoostNextReward = false

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
        pendingCardSelection = nil
        pendingCardResult = nil
        codexBoostNextReward = false
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
            pendingShop = ShopInteraction(
                nodeID: node.id,
                relicOffers: randomShopRelics(count: 3)
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
        pendingCardResult = nil
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
        pendingCardResult = CardSelectionResult(
            title: "Carte améliorée : \(state.player.deck[index].card.name)",
            subtitle: "Le feu de camp renforce votre carte.",
            card: state.player.deck[index].card
        )
    }

    func buyRelic(offerID: UUID, from interaction: ShopInteraction) {
        guard var state = runState,
              var pending = pendingShop,
              pending.id == interaction.id,
              let offerIndex = pending.relicOffers.firstIndex(where: { $0.id == offerID }),
              !pending.relicOffers[offerIndex].isPurchased else { return }

        let offer = pending.relicOffers[offerIndex]
        guard state.player.gold >= offer.cost else { return }

        state.player.gold -= offer.cost
        grantRelic(offer.relic, to: &state.player)
        runState = state

        pending.relicOffers[offerIndex].isPurchased = true
        pendingShop = pending
    }

    func leaveShop(_ interaction: ShopInteraction) {
        guard var state = runState else { return }
        completeNode(interaction.nodeID, in: &state)
        runState = state
        pendingShop = nil
    }

    func chooseEventOption(_ option: MayaEventOption, in interaction: EventInteraction) {
        guard var state = runState else { return }

        var triggerEliteFight = false
        var needsUpgradeSelection = false
        var needsCardSelection = false
        var cardRarity: Rarity?

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
                needsCardSelection = true
                cardRarity = rarity
            case .removeCard:
                if !state.player.deck.isEmpty {
                    let removed = state.player.deck.remove(at: Int.random(in: 0..<state.player.deck.count))
                    pendingCardResult = CardSelectionResult(
                        title: "Carte brûlée : \(removed.card.name)",
                        subtitle: "Le rituel consume cette carte de votre deck.",
                        card: removed.card
                    )
                }
            case .upgradeCard:
                needsUpgradeSelection = true
            case .startEliteFight:
                triggerEliteFight = true
            }
        }

        if hasRelic(.sacredCodex, in: state.player) {
            codexBoostNextReward = true
        }

        if state.player.currentHP <= 0 {
            state.status = .gameOver
            runState = state
            pendingEvent = nil
            return
        }

        if needsUpgradeSelection {
            let upgradable = state.player.deck.filter { !$0.isUpgraded }
            guard !upgradable.isEmpty else {
                completeNode(interaction.nodeID, in: &state)
                runState = state
                pendingEvent = nil
                return
            }

            runState = state
            pendingEvent = nil
            pendingCardSelection = CardSelectionInteraction(
                nodeID: interaction.nodeID,
                title: "Choisissez une carte à améliorer",
                description: "Sélectionnez la carte que vous souhaitez améliorer.",
                mode: .upgrade,
                upgradableCards: upgradable,
                cardChoices: []
            )
            return
        }

        if needsCardSelection {
            let choices = randomCardChoices(rarity: cardRarity, count: 3)
            guard !choices.isEmpty else {
                completeNode(interaction.nodeID, in: &state)
                runState = state
                pendingEvent = nil
                return
            }

            runState = state
            pendingEvent = nil
            pendingCardSelection = CardSelectionInteraction(
                nodeID: interaction.nodeID,
                title: "Choisissez une carte à ajouter",
                description: "Cette carte sera ajoutée immédiatement à votre deck.",
                mode: .addToDeck,
                upgradableCards: [],
                cardChoices: choices
            )
            return
        }

        completeNode(interaction.nodeID, in: &state)
        runState = state
        pendingEvent = nil

        if triggerEliteFight, let node = state.nodes.first(where: { $0.id == interaction.nodeID }) {
            startBattle(for: node, forceElite: true)
        }
    }

    func confirmPendingCardSelection(upgradeCardID: UUID? = nil, addCardID: UUID? = nil) {
        guard let selection = pendingCardSelection,
              var state = runState else { return }

        switch selection.mode {
        case .upgrade:
            guard let upgradeCardID,
                  let index = state.player.deck.firstIndex(where: { $0.id == upgradeCardID }),
                  !state.player.deck[index].isUpgraded else { return }

            state.player.deck[index].isUpgraded = true
            state.player.deck[index].card = upgradedCard(from: state.player.deck[index].card)
            pendingCardResult = CardSelectionResult(
                title: "Carte améliorée : \(state.player.deck[index].card.name)",
                subtitle: "Le pouvoir de l'événement a transformé votre carte.",
                card: state.player.deck[index].card
            )
        case .addToDeck:
            guard let addCardID,
                  let card = selection.cardChoices.first(where: { $0.id == addCardID }) else { return }
            state.player.deck.append(RunCardInstance(card: card))
            pendingCardResult = CardSelectionResult(
                title: "Carte ajoutée au deck : \(card.name)",
                subtitle: "Votre deck s'enrichit d'une nouvelle carte.",
                card: card
            )
        }

        completeNode(selection.nodeID, in: &state)
        runState = state
        pendingCardSelection = nil

    }

    func dismissCardResult() {
        pendingCardResult = nil
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
            let relicGoldBonus = hasRelic(.obsidianOffering, in: state.player) ? 2 : 0
            state.player.gold += baseGold + relicGoldBonus

            if node.type == .elite,
               hasRelic(.quetzalFeather, in: state.player) {
                state.player.currentHP = min(state.player.maxHP, state.player.currentHP + 2)
            }

            if node.type == .boss {
                state.player.gold += 100
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
        pendingRewards = buildCombatRewards(for: state.player, includeBonusCard: codexBoostNextReward)
        codexBoostNextReward = false
    }

    func chooseReward(_ reward: Reward) {
        guard var state = runState, state.status == .choosingReward else { return }

        switch reward {
        case .card(let card):
            state.player.deck.append(RunCardInstance(card: card))
            pendingCardResult = CardSelectionResult(
                title: "Carte gagnée : \(card.name)",
                subtitle: "Cette carte a été ajoutée à votre deck après le combat.",
                card: card
            )
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
        pendingCardSelection = nil
        pendingCardResult = nil
        codexBoostNextReward = false
        runState = state
    }

    func isNodeSelectable(_ node: MapNode) -> Bool {
        guard let state = runState else { return false }
        return isNodeSelectable(node, in: state)
    }

    private func isNodeSelectable(_ node: MapNode, in state: RunState) -> Bool {
        node.isUnlocked && !node.isCompleted && !node.isDisabled && state.status == .onMap && !state.isFinished
    }

    private func completeNode(_ nodeID: UUID, in state: inout RunState) {
        let indexByID = Dictionary(uniqueKeysWithValues: state.nodes.enumerated().map { ($0.element.id, $0.offset) })
        guard let nodeIndex = indexByID[nodeID] else { return }

        state.nodes[nodeIndex].isCompleted = true
        disableCompetingNodes(in: state.nodes[nodeIndex].row, selectedNodeID: nodeID, state: &state)
        let nextIDs = state.nodes[nodeIndex].nextNodeIDs
        for nextID in nextIDs {
            if let nextIndex = indexByID[nextID] {
                state.nodes[nextIndex].isUnlocked = true
            }
        }
    }


    private func disableCompetingNodes(in row: Int, selectedNodeID: UUID, state: inout RunState) {
        for index in state.nodes.indices where state.nodes[index].row == row && state.nodes[index].id != selectedNodeID && !state.nodes[index].isCompleted {
            state.nodes[index].isUnlocked = false
            state.nodes[index].isDisabled = true
        }
    }

    private func randomShopRelics(count: Int) -> [ShopRelicOffer] {
        let minCost = 75
        return Array(MayaRelicPool.all.shuffled().prefix(count)).map {
            ShopRelicOffer(relic: $0, cost: minCost + rarityCostBonus(for: $0.rarity))
        }
    }

    private func rarityCostBonus(for rarity: Rarity) -> Int {
        switch rarity {
        case .common: 0
        case .rare: 25
        case .epic: 35
        case .legendary: 45
        }
    }

    private func randomRelic() -> Relic {
        MayaRelicPool.all.randomElement() ?? MayaRelicPool.all[0]
    }

    private func randomCard(rarity: Rarity?) -> Card? {
        let pool = CardsDB.commons + CardsDB.rituals + CardsDB.gods
        if let rarity {
            return pool.filter { $0.rarity == rarity }.randomElement() ?? pool.randomElement()
        }
        return pool.randomElement()
    }

    private func randomCardChoices(rarity: Rarity?, count: Int) -> [Card] {
        let pool = CardsDB.commons + CardsDB.rituals + CardsDB.gods
        let filteredPool = rarity.map { requested in
            pool.filter { $0.rarity == requested }
        } ?? pool

        let base = filteredPool.isEmpty ? pool : filteredPool
        return Array(base.shuffled().prefix(max(1, count)))
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

    private func buildCombatRewards(for player: PlayerRunState, includeBonusCard: Bool = false) -> [Reward] {
        _ = player
        let basePool = CardsDB.commons + CardsDB.rituals
        let cardCount = includeBonusCard ? 3 : 2
        let offeredCards = Array(basePool.shuffled().prefix(cardCount))
        return offeredCards.map(Reward.card) + [.gold(20)]
    }

    private func grantRelic(_ relic: Relic, to player: inout PlayerRunState) {
        player.relics.append(relic)
    }

    private func hasRelic(_ relicID: RelicID, in player: PlayerRunState) -> Bool {
        player.relics.contains(where: { $0.relicID == relicID })
    }
}
