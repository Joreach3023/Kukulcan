import Foundation

#if !canImport(SwiftUI) && !canImport(Combine)
@propertyWrapper
struct Published<Value> {
    var wrappedValue: Value
    init(wrappedValue: Value) { self.wrappedValue = wrappedValue }
}
protocol ObservableObject {}
#endif

// MARK: - Domain

enum Rarity: String, Codable { case common, rare, epic, legendary }

enum CardType: String, Codable { case common, ritual, god, curse }

enum BossType: String, Codable {
    case ahPuch
    case chaac
    case kukulkan
}

/// Rituels pré-définis (tu pourras en ajouter facilement)
enum RitualKind: String, Codable {
    case obsidianKnife     // Sacrifie 1 commune en jeu → +1 blood et pioche 2
    case bloodAltar        // Le prochain sacrifice donne +2 blood au lieu de +1 (ce tour)
    case forestCharm       // +1/+1 à une commune sur le board (buff simple)
}

/// Carte "statique" (modèle)
struct Card: Identifiable, Codable, Hashable {
    let id: UUID
    let name: String
    let type: CardType
    let rarity: Rarity
    let imageName: String

    // Stats (selon type)
    let attack: Int       // pour common/god
    let health: Int       // pour common/god
    let ritual: RitualKind? // pour ritual

    // Coûts / mécaniques
    let bloodCost: Int    // coût d’invocation pour un dieu (sinon 0)
    let effect: String    // texte synthétique à afficher sur la carte (footer)
    let lore: String?     // visible seulement en vue zoom

    init(id: UUID = UUID(),
         name: String,
         type: CardType,
         rarity: Rarity,
         imageName: String,
         attack: Int = 0,
         health: Int = 0,
         ritual: RitualKind? = nil,
         bloodCost: Int = 0,
         effect: String,
         lore: String? = nil) {
        self.id = id
        self.name = name
        self.type = type
        self.rarity = rarity
        self.imageName = imageName
        self.attack = attack
        self.health = health
        self.ritual = ritual
        self.bloodCost = bloodCost
        self.effect = effect
        self.lore = lore
    }
}

/// Instance vivante d’une carte sur le plateau (HP courant, etc.)
struct CardInstance: Identifiable, Codable, Hashable {
    let id: UUID
    let base: Card
    var currentHP: Int
    var currentAttack: Int
    var hasActedThisTurn: Bool
    var silencedTurns: Int
    var isResurrected: Bool

    init(_ card: Card,
         id: UUID = UUID(),
         currentHP: Int? = nil,
         currentAttack: Int? = nil,
         hasActedThisTurn: Bool = false,
         silencedTurns: Int = 0,
         isResurrected: Bool = false) {
        self.id = id
        self.base = card
        self.currentHP = currentHP ?? max(1, card.health)
        self.currentAttack = currentAttack ?? card.attack
        self.hasActedThisTurn = hasActedThisTurn
        self.silencedTurns = silencedTurns
        self.isResurrected = isResurrected
    }
}

// MARK: - Player / State

struct PlayerState: Codable {
    var name: String
    var hp: Int = 10

    var deck: [Card] = []
    var hand: [Card] = []
    var discard: [Card] = []

    var board: [CardInstance?] = Array(repeating: nil, count: 3)   // communes
    var sacrificeSlot: CardInstance? = nil                         // commune sacrifiée (visuelle)
    var godSlot: CardInstance? = nil                               // 1 seul dieu

    var blood: Int = 0                                             // ressource
    var pendingBonusBlood: Int = 0                                 // bonus du rituel Blood Altar (réinitialisé fin de tour)

    mutating func draw(_ n: Int = 1) -> [Card] {
        var drawn: [Card] = []
        for _ in 0..<n {
            if deck.isEmpty { break }
            let c = deck.removeFirst()
            hand.append(c)
            drawn.append(c)
        }
        return drawn
    }
}

// MARK: - Game Engine

enum Target {
    case player                          // viser les PV du joueur adverse
    case boardSlot(Int)                  // viser une carte sur le board
    case god                             // viser le dieu adverse s’il existe
}

final class GameEngine: ObservableObject {
    @Published private(set) var p1: PlayerState
    @Published private(set) var p2: PlayerState

    @Published private(set) var currentPlayerIsP1: Bool = true
    @Published private(set) var log: [String] = []
    @Published var lastDrawnCard: Card? = nil
    @Published var lastDrawnCards: [Card] = []
    @Published private(set) var startingPlayerIsP1: Bool = true
    @Published private(set) var p1CompletedTurns: Int = 0
    @Published private(set) var p2CompletedTurns: Int = 0

    private var p1RelicIDs: Set<String> = []
    private var p1AttackCounter: Int = 0

    let bossType: BossType?
    @Published private(set) var playerNextCardCostsPlus1: Bool = false
    @Published private(set) var playerCardsPlayedThisTurn: Int = 0
    @Published private(set) var playerCardPlayLimit: Int? = nil
    @Published private(set) var playerDidSacrificeThisTurn: Bool = false
    @Published private(set) var combatBannerMessage: String? = nil

    private var ahPuchCursesCreated: Int = 0
    private var ahPuchResurrections: Int = 0
    private var ahPuchDeadAllies: [CardInstance] = []
    private var chaacSacredStormTriggered: Bool = false
    private var chaacLastPlayedUnitID: UUID? = nil
    private var condemnedUnitID: UUID? = nil

    var current: PlayerState { currentPlayerIsP1 ? p1 : p2 }
    var opponent: PlayerState { currentPlayerIsP1 ? p2 : p1 }
    var canCurrentPlayerAttack: Bool { true }

    init(p1: PlayerState, p2: PlayerState, bossType: BossType? = nil) {
        self.p1 = p1
        self.p2 = p2
        self.bossType = bossType
    }

    func configurePlayerRelics(_ relicIDs: [String]) {
        p1RelicIDs = Set(relicIDs)
    }

    private func isBossTurn() -> Bool {
        currentPlayerIsP1 == false && bossType != nil
    }

    private func bossTurnCount() -> Int {
        p2CompletedTurns + (currentPlayerIsP1 ? 0 : 1)
    }

    private func playerTurnCount() -> Int {
        p1CompletedTurns + (currentPlayerIsP1 ? 1 : 0)
    }

    private func curseCard() -> Card {
        CardsDB.ahPuchMaledictionCurse()
    }

    private func announce(_ text: String) {
        combatBannerMessage = text
        log.append(text)
    }

    // MARK: setup
    func start(mulligan: Int = 5) {
        // Réinitialise intégralement les états de combat pour éviter toute fuite d'une partie précédente.
        p1 = sanitizedStateForNewCombat(from: p1)
        p2 = sanitizedStateForNewCombat(from: p2)

        // Mélange très simple
        p1.deck.shuffle(); p2.deck.shuffle()
        _ = p1.draw(mulligan); _ = p2.draw(mulligan)
        startingPlayerIsP1 = Bool.random()
        currentPlayerIsP1 = startingPlayerIsP1
        p1CompletedTurns = 0
        p2CompletedTurns = 0
        p1AttackCounter = 0
        playerNextCardCostsPlus1 = false
        playerCardsPlayedThisTurn = 0
        playerCardPlayLimit = bossType == .kukulkan ? 3 : nil
        playerDidSacrificeThisTurn = false
        combatBannerMessage = nil
        ahPuchCursesCreated = 0
        ahPuchResurrections = 0
        ahPuchDeadAllies.removeAll()
        chaacSacredStormTriggered = false
        chaacLastPlayedUnitID = nil
        condemnedUnitID = nil
        log.removeAll()
        log.append("La partie commence avec un plateau vide des deux côtés.")
        applyPlayerStartOfCombatRelics()
        if !currentPlayerIsP1 {
            applyStartOfTurnBossEffectsIfNeeded()
        }
        log.append("\(activeName()) joue en premier (tirage 50/50).")
    }

    // MARK: actions (joueur courant)

    func playCommonToBoard(handIndex: Int, slot: Int) {
        guard slot >= 0 && slot < current.board.count else { return }
        var cp = current
        guard handIndex < cp.hand.count else { return }
        let c = cp.hand[handIndex]
        guard c.type == .common else { return }
        guard canPlayCardManually(card: c, owner: cp) else { return }
        guard cp.board[slot] == nil else { return } // slot libre
        cp.hand.remove(at: handIndex)
        applyManualPlayCostAndCounters(card: c, owner: &cp)
        var instance = CardInstance(c)

        if p1RelicIDs.contains("ceremonialDrum"), currentPlayerIsP1 {
            instance.currentAttack += 1
        }

        if c.name == "Guerrier blessé" {
            instance.currentHP += 1
        }

        cp.board[slot] = instance
        if !currentPlayerIsP1 {
            chaacLastPlayedUnitID = instance.id
        }
        setCurrent(cp, log: "\(activeName()) pose \(c.name) sur l’emplacement \(slot+1).")

        if c.name == "Jeune chasseur" {
            drawForCurrent(1)
            log.append("Effet d’arrivée de Jeune chasseur : \(activeName()) pioche 1 carte.")
        }
    }

    func sacrificeCommon(handIndex: Int) {
        // Sacrifice d’une commune depuis la main (ou tu peux adapter pour sacrifier une commune déjà en jeu)
        var cp = current
        guard handIndex < cp.hand.count else { return }
        let c = cp.hand[handIndex]
        guard c.type == .common else { return }
        guard canPlayCardManually(card: c, owner: cp) else { return }

        cp.hand.remove(at: handIndex)
        applyManualPlayCostAndCounters(card: c, owner: &cp)
        if currentPlayerIsP1 { playerDidSacrificeThisTurn = true }
        let inst = CardInstance(c)
        cp.sacrificeSlot = inst
        // Gain de blood
        let gain = 1 + cp.pendingBonusBlood
        cp.blood += gain
        cp.pendingBonusBlood = 0
        cp.discard.append(c)

        if c.name == "Disciple zélé" {
            cp.blood += 1
        }

        setCurrent(cp, log: "\(activeName()) sacrifie \(c.name) → +\(gain) Sang (total \(cp.blood)).")

        if c.name == "Éclaireur perdu" {
            drawForCurrent(1)
            log.append("Effet de sacrifice d’Éclaireur perdu : \(activeName()) pioche 1 carte.")
        }
    }

    func playRitual(handIndex: Int, targetSlot: Int? = nil) {
        var cp = current
        guard handIndex < cp.hand.count else { return }
        let c = cp.hand[handIndex]
        guard c.type == .ritual, let kind = c.ritual else { return }
        guard canPlayCardManually(card: c, owner: cp) else { return }
        if let s = targetSlot, s >= 0, s < cp.board.count, let inst = cp.board[s], inst.silencedTurns > 0 {
            log.append("Unité réduite au silence : rituel impossible ce tour.")
            return
        }
        cp.hand.remove(at: handIndex)
        applyManualPlayCostAndCounters(card: c, owner: &cp)

        switch kind {
        case .obsidianKnife:
            // Sacrifie une commune POSÉE (si targetSlot fourni et valide)
            if let s = targetSlot, s >= 0, s < cp.board.count, let inst = cp.board[s] {
                cp.board[s] = nil
                let gain = 1 + cp.pendingBonusBlood
                cp.blood += gain
                cp.pendingBonusBlood = 0
                cp.sacrificeSlot = inst
                cp.discard.append(inst.base)
                if currentPlayerIsP1 { playerDidSacrificeThisTurn = true }
                cp.discard.append(c)
                setCurrent(cp, log: "\(activeName()) utilise Couteau d’obsidienne sur \(inst.base.name) → +\(gain) Sang (total \(cp.blood)).")
                // pioche 2
                drawForCurrent(2)
            } else {
                // Pas de cible valable, rituel part à la défausse sans effet.
                cp.discard.append(c)
                setCurrent(cp, log: "\(activeName()) a joué Couteau d’obsidienne sans cible.")
            }

        case .bloodAltar:
            cp.pendingBonusBlood = 1 // le prochain sacrifice donnera +2 total
            cp.discard.append(c)
            setCurrent(cp, log: "\(activeName()) érige un Autel de sang → prochain sacrifice +2 Sang.")

        case .forestCharm:
            if let s = targetSlot, s >= 0, s < cp.board.count, var inst = cp.board[s] {
                inst.currentHP += 1
                inst.currentAttack += 1
                // On remplace l’instance modifiée
                cp.board[s] = inst
                cp.discard.append(c)
                setCurrent(cp, log: "\(activeName()) lance Charme forestier sur \(inst.base.name) → +1/+1.")
            } else {
                cp.discard.append(c)
                setCurrent(cp, log: "\(activeName()) joue Charme forestier sans cible.")
            }
        }
    }

    func invokeGod(handIndex: Int) {
        var cp = current
        guard handIndex < cp.hand.count else { return }
        let c = cp.hand[handIndex]
        guard c.type == .god, cp.godSlot == nil else { return }
        guard canPlayCardManually(card: c, owner: cp) else { return }

        cp.hand.remove(at: handIndex)
        applyManualPlayCostAndCounters(card: c, owner: &cp)
        var god = CardInstance(c)
        if p1RelicIDs.contains("ceremonialDrum"), currentPlayerIsP1 {
            god.currentAttack += 1
        }
        cp.godSlot = god

        // Effets d’arrivée d’exemple
        switch c.name {
        case "Kukulcan":
            // -2 HP à toutes les cartes adverses
            var op = opponent
            for i in 0..<op.board.count {
                if var inst = op.board[i] {
                    inst.currentHP -= 2
                    if inst.currentHP <= 0 {
                        op.discard.append(inst.base)
                        op.board[i] = nil
                        triggerDeathEffects(for: inst, ownerIsP1: currentPlayerIsP1 ? false : true, owner: &op)
                    } else {
                        op.board[i] = inst
                    }
                }
            }
            setOpponent(op)
            setCurrent(cp, log: "\(activeName()) invoque \(c.name) (coût \(c.bloodCost) Sang) : frappe la ligne ennemie.")
        case "Ix Chel":
            // Aucun dégât mais message (tu pourras geler 1 tour si tu veux)
            setCurrent(cp, log: "\(activeName()) invoque \(c.name) (coût \(c.bloodCost) Sang).")
        default:
            setCurrent(cp, log: "\(activeName()) invoque \(c.name) (coût \(c.bloodCost) Sang).")
        }
    }

    func playCurse(handIndex: Int) {
        var cp = current
        guard handIndex < cp.hand.count else { return }
        let c = cp.hand[handIndex]
        guard c.type == .curse else { return }
        guard canPlayCardManually(card: c, owner: cp) else { return }

        cp.hand.remove(at: handIndex)
        applyManualPlayCostAndCounters(card: c, owner: &cp)
        cp.discard.append(c)
        if currentPlayerIsP1 {
            playerNextCardCostsPlus1 = true
        }
        setCurrent(cp, log: "\(activeName()) joue Malédiction. La prochaine carte coûte +1 Sang.")
    }

    private func canPlayCardManually(card: Card, owner: PlayerState) -> Bool {
        if currentPlayerIsP1, let limit = playerCardPlayLimit, playerCardsPlayedThisTurn >= limit {
            announce("Loi du temple : 3 cartes max par tour.")
            return false
        }

        var totalCost = card.bloodCost
        if currentPlayerIsP1 && playerNextCardCostsPlus1 { totalCost += 1 }
        if owner.blood < totalCost {
            return false
        }

        return true
    }

    private func applyManualPlayCostAndCounters(card: Card, owner: inout PlayerState) {
        var totalCost = card.bloodCost
        if currentPlayerIsP1 && playerNextCardCostsPlus1 {
            totalCost += 1
            playerNextCardCostsPlus1 = false
        }
        owner.blood = max(0, owner.blood - totalCost)

        if currentPlayerIsP1 {
            playerCardsPlayedThisTurn += 1
        }
    }

    /// Attaque depuis un slot du board courant (ou le dieu si slot = -1) vers une cible
    func attack(from slot: Int, to target: Target) {
        var atkOwner = current
        var defOwner = opponent

        // Récup attaquant
        var attacker: CardInstance?
        var isGod = false
        if slot == -1 {
            attacker = atkOwner.godSlot
            isGod = true
        } else if slot >= 0, slot < atkOwner.board.count {
            attacker = atkOwner.board[slot]
        }
        guard var atker = attacker else { return }
        guard !atker.hasActedThisTurn else { return }
        atker.hasActedThisTurn = true

        let hasJadeSerpentBonus = currentPlayerIsP1 && p1RelicIDs.contains("jadeSerpent")
        var attackDamage = atker.currentAttack
        if hasJadeSerpentBonus {
            p1AttackCounter += 1
            if p1AttackCounter % 3 == 0 {
                attackDamage += 4
                log.append("Serpent de jade : +4 dégâts bonus sur cette attaque.")
            }
        }

        func assignBackAttacker() {
            if isGod {
                atkOwner.godSlot = atker
            } else if slot >= 0, slot < atkOwner.board.count {
                atkOwner.board[slot] = atker
            }
        }

        switch target {
        case .player:
            defOwner.hp -= attackDamage
            if defOwner.hp < 0 { defOwner.hp = 0 }
            log.append("\(activeName()) attaque directement → \(passiveName()) perd \(attackDamage) PV (\(defOwner.hp) restants).")
            assignBackAttacker()

        case .god:
            guard var def = defOwner.godSlot else { return }
            def.currentHP -= attackDamage
            atker.currentHP -= def.currentAttack
            if def.currentHP <= 0 { defOwner.discard.append(def.base); defOwner.godSlot = nil }
            if atker.currentHP <= 0 {
                if isGod {
                    atkOwner.discard.append(atker.base)
                    atkOwner.godSlot = nil
                } else {
                    atkOwner.discard.append(atker.base)
                    atkOwner.board[slot] = nil
                    triggerDeathEffects(for: atker, ownerIsP1: currentPlayerIsP1, owner: &atkOwner)
                }
            } else {
                assignBackAttacker()
                if def.currentHP > 0 {
                    defOwner.godSlot = def
                }
            }

        case .boardSlot(let i):
            guard i >= 0, i < defOwner.board.count, var def = defOwner.board[i] else {
                // pas de défenseur → attaque le joueur
                defOwner.hp -= attackDamage
                if defOwner.hp < 0 { defOwner.hp = 0 }
                log.append("\(activeName()) trouve la voie libre et frappe \(passiveName()) pour \(attackDamage) PV.")
                assignBackAttacker()
                break
            }
            // combat
            def.currentHP -= attackDamage
            atker.currentHP -= def.currentAttack

            if def.currentHP <= 0 {
                defOwner.discard.append(def.base)
                defOwner.board[i] = nil
                triggerDeathEffects(for: def, ownerIsP1: !currentPlayerIsP1, owner: &defOwner)

                if atker.base.name == "Archer maladroit" {
                    drawForCurrent(1)
                    log.append("Archer maladroit élimine une unité : \(activeName()) pioche 1 carte.")
                }
            } else {
                defOwner.board[i] = def
            }

            if atker.currentHP <= 0 {
                if isGod {
                    atkOwner.discard.append(atker.base)
                    atkOwner.godSlot = nil
                } else {
                    atkOwner.discard.append(atker.base)
                    atkOwner.board[slot] = nil
                    triggerDeathEffects(for: atker, ownerIsP1: currentPlayerIsP1, owner: &atkOwner)
                }
            } else {
                assignBackAttacker()
            }
        }

        setCurrent(atkOwner)
        setOpponent(defOwner)
    }

    private func applyPlayerStartOfCombatRelics() {
        guard !p1RelicIDs.isEmpty else { return }

        if p1RelicIDs.contains("palenqueRoyalJade") {
            p1.blood += 1
            log.append("Jade royal de Palenque : +1 Sang au début du combat.")
        }

        if p1RelicIDs.contains("pakalFuneraryMask") {
            p1.hp = min(10, p1.hp + 5)
            log.append("Masque funéraire de Pakal : vous récupérez 5 PV au début du combat.")
        }

        if p1RelicIDs.contains("sunStone") {
            for i in 0..<p2.board.count {
                if var inst = p2.board[i] {
                    inst.currentHP -= 3
                    if inst.currentHP <= 0 {
                        p2.discard.append(inst.base)
                        p2.board[i] = nil
                        triggerDeathEffects(for: inst, ownerIsP1: false, owner: &p2)
                    } else {
                        p2.board[i] = inst
                    }
                }
            }
            if let god = p2.godSlot {
                var updatedGod = god
                updatedGod.currentHP -= 3
                if updatedGod.currentHP <= 0 {
                    p2.discard.append(updatedGod.base)
                    p2.godSlot = nil
                } else {
                    p2.godSlot = updatedGod
                }
            }
            log.append("Pierre solaire : 3 dégâts initiaux à tous les ennemis.")
        }
    }

    private func triggerDeathEffects(for instance: CardInstance, ownerIsP1: Bool, owner: inout PlayerState) {
        switch instance.base.name {
        case "Prisonnier captif":
            owner.blood += 1
        case "Prophète délirant":
            if !owner.deck.isEmpty {
                let drawn = owner.deck.removeFirst()
                owner.hand.append(drawn)
            }
        default:
            break
        }

        guard let bossType else { return }

        switch bossType {
        case .ahPuch:
            if ownerIsP1 {
                if ahPuchCursesCreated < 3 {
                    p1.deck.insert(curseCard(), at: 0)
                    ahPuchCursesCreated += 1
                    announce("Ah Puch maudit votre deck.")
                }
            } else if !instance.isResurrected {
                ahPuchDeadAllies.append(instance)
            }
        case .kukulkan:
            if let condemnedUnitID, ownerIsP1, condemnedUnitID == instance.id {
                self.condemnedUnitID = nil
            }
        case .chaac:
            break
        }
    }

    func endTurn() {
        if currentPlayerIsP1 {
            if bossType == .kukulkan && !playerDidSacrificeThisTurn {
                if var god = p2.godSlot {
                    god.currentAttack += 1
                    p2.godSlot = god
                    announce("Kukulkan exige une offrande.")
                }
            }

            p1CompletedTurns += 1
            if p1RelicIDs.contains("tzolkinCalendar"), p1CompletedTurns % 3 == 0 {
                p1.blood += 2
                log.append("Calendrier Tzolk’in : +2 Sang après 3 tours.")
            }
        } else {
            p2CompletedTurns += 1
        }

        resetEndTurnState()
        currentPlayerIsP1.toggle()
        resetActionStateForCurrentPlayer()
        applyStartOfTurnBossEffectsIfNeeded()
        log.append("—— Tour terminé. À \(activeName()) de jouer.")
        drawForCurrent(1)
    }

    private func applyStartOfTurnBossEffectsIfNeeded() {
        if currentPlayerIsP1 {
            playerCardsPlayedThisTurn = 0
            playerDidSacrificeThisTurn = false
            chaacLastPlayedUnitID = nil
            clearSilenceOnPlayerUnits()
            return
        }

        guard let bossType else { return }

        switch bossType {
        case .ahPuch:
            if bossTurnCount() % 3 == 0,
               ahPuchResurrections < 2,
               let resurrected = resurrectAhPuchUnit() {
                deployResurrectedEnemyUnit(resurrected)
                ahPuchResurrections += 1
                announce("Ah Puch ressuscite les morts.")
            }
        case .chaac:
            applyChaacStorm()
            if !chaacSacredStormTriggered,
               let god = p2.godSlot,
               god.currentHP * 2 <= god.base.health {
                chaacSacredStormTriggered = true
                applyChaacSacredStorm()
                announce("Chaac déchaîne l’Orage sacré !")
            }
        case .kukulkan:
            if let condemnedUnitID,
               let slot = p1.board.firstIndex(where: { $0?.id == condemnedUnitID }),
               let doomed = p1.board[slot] {
                p1.discard.append(doomed.base)
                p1.board[slot] = nil
                triggerDeathEffects(for: doomed, ownerIsP1: true, owner: &p1)
                announce("Le temple réclame son dû.")
            }
            condemnedUnitID = nil

            if bossTurnCount() % 2 == 0,
               let slot = weakestPlayerUnitSlot(),
               let doomed = p1.board[slot] {
                condemnedUnitID = doomed.id
                announce("Kukulkan exige une offrande.")
            }
        }
    }

    private func clearSilenceOnPlayerUnits() {
        for i in 0..<p1.board.count {
            if var inst = p1.board[i] {
                inst.silencedTurns = max(0, inst.silencedTurns - 1)
                p1.board[i] = inst
            }
        }
        if var god = p1.godSlot {
            god.silencedTurns = max(0, god.silencedTurns - 1)
            p1.godSlot = god
        }
    }

    private func weakestPlayerUnitSlot() -> Int? {
        let candidates = p1.board.enumerated().compactMap { idx, inst -> (Int, Int)? in
            guard let inst else { return nil }
            return (idx, inst.currentAttack)
        }
        return candidates.min(by: { lhs, rhs in
            if lhs.1 == rhs.1 { return lhs.0 < rhs.0 }
            return lhs.1 < rhs.1
        })?.0
    }

    private func resurrectAhPuchUnit() -> CardInstance? {
        while let last = ahPuchDeadAllies.popLast() {
            if last.isResurrected { continue }
            let hp = max(1, Int(ceil(Double(last.base.health) / 2.0)))
            return CardInstance(last.base, currentHP: hp, currentAttack: last.base.attack + 1, isResurrected: true)
        }
        return nil
    }

    private func deployResurrectedEnemyUnit(_ unit: CardInstance) {
        if let slot = p2.board.firstIndex(where: { $0 == nil }) {
            p2.board[slot] = unit
            return
        }
        if p2.sacrificeSlot == nil {
            p2.sacrificeSlot = unit
        }
    }

    private func applyChaacStorm() {
        let slots = p1.board.enumerated().compactMap { idx, inst -> (Int, CardInstance)? in
            guard let inst else { return nil }
            if inst.id == chaacLastPlayedUnitID { return nil }
            return (idx, inst)
        }
        guard !slots.isEmpty else { return }

        let target = slots.randomElement()!
        let roll = Int.random(in: 0..<100)
        announce("La tempête de Chaac frappe le champ de bataille.")

        if roll < 50 {
            var inst = target.1
            inst.currentHP -= 2
            if inst.currentHP <= 0 {
                p1.discard.append(inst.base)
                p1.board[target.0] = nil
                triggerDeathEffects(for: inst, ownerIsP1: true, owner: &p1)
            } else {
                p1.board[target.0] = inst
            }
            return
        }

        if roll < 80 {
            var inst = target.1
            inst.silencedTurns = 1
            p1.board[target.0] = inst
            return
        }

        let handCap = 10
        if p1.hand.count < handCap {
            p1.board[target.0] = nil
            p1.hand.append(target.1.base)
        } else {
            p1.board[target.0] = nil
            p1.discard.append(target.1.base)
            triggerDeathEffects(for: target.1, ownerIsP1: true, owner: &p1)
        }
    }

    private func applyChaacSacredStorm() {
        for i in 0..<p1.board.count {
            if var inst = p1.board[i] {
                inst.currentHP -= 2
                if inst.currentHP <= 0 {
                    p1.discard.append(inst.base)
                    p1.board[i] = nil
                    triggerDeathEffects(for: inst, ownerIsP1: true, owner: &p1)
                } else {
                    p1.board[i] = inst
                }
            }
        }

        for i in 0..<p2.board.count {
            if var inst = p2.board[i] {
                inst.currentHP -= 1
                if inst.currentHP <= 0 {
                    p2.discard.append(inst.base)
                    p2.board[i] = nil
                    triggerDeathEffects(for: inst, ownerIsP1: false, owner: &p2)
                } else {
                    p2.board[i] = inst
                }
            }
        }
    }

    private func resetActionStateForCurrentPlayer() {
        if currentPlayerIsP1 {
            for i in 0..<p1.board.count {
                if var inst = p1.board[i] {
                    inst.hasActedThisTurn = false
                    p1.board[i] = inst
                }
            }
            if var god = p1.godSlot {
                god.hasActedThisTurn = false
                p1.godSlot = god
            }
        } else {
            for i in 0..<p2.board.count {
                if var inst = p2.board[i] {
                    inst.hasActedThisTurn = false
                    p2.board[i] = inst
                }
            }
            if var god = p2.godSlot {
                god.hasActedThisTurn = false
                p2.godSlot = god
            }
        }
    }

    /// Réinitialise les informations temporaires de fin de tour
    private func resetEndTurnState() {
        if currentPlayerIsP1 {
            p1.sacrificeSlot = nil
            p1.pendingBonusBlood = 0
        } else {
            p2.sacrificeSlot = nil
            p2.pendingBonusBlood = 0
        }
    }

    private func sanitizedStateForNewCombat(from source: PlayerState) -> PlayerState {
        let allCards = source.deck
            + source.hand
            + source.discard
            + source.board.compactMap { $0?.base }
            + [source.sacrificeSlot?.base, source.godSlot?.base].compactMap { $0 }

        return PlayerState(
            name: source.name,
            hp: source.hp,
            deck: allCards,
            hand: [],
            discard: [],
            board: Array(repeating: nil, count: 3),
            sacrificeSlot: nil,
            godSlot: nil,
            blood: 0,
            pendingBonusBlood: 0
        )
    }

    // MARK: - Helpers mutateurs

    private func activeName() -> String { currentPlayerIsP1 ? p1.name : p2.name }
    private func passiveName() -> String { currentPlayerIsP1 ? p2.name : p1.name }

    private func setCurrent(_ s: PlayerState, log line: String? = nil) {
        if currentPlayerIsP1 { p1 = s } else { p2 = s }
        if let l = line { log.append(l) }
    }

    private func setOpponent(_ s: PlayerState) {
        if currentPlayerIsP1 { p2 = s } else { p1 = s }
    }

    func drawForCurrent(_ n: Int) {
        let drawn: [Card]
        if currentPlayerIsP1 {
            drawn = p1.draw(n)
        } else {
            drawn = p2.draw(n)
        }
        lastDrawnCard = drawn.last
        lastDrawnCards = drawn
    }

    func clearCombatBannerMessage() {
        combatBannerMessage = nil
    }

    func isPlayerUnitCondemned(_ unitID: UUID) -> Bool {
        condemnedUnitID == unitID
    }

    // MARK: - IA par priorités
    func performEasyAITurn() {
        performPriorityAITurn(configuration: .init(profile: .defensive, tuning: .defensive))
    }

    func performAITurn(level: Int) {
        let configuration: EnemyAI.Configuration
        switch level {
        case 1:
            configuration = .init(profile: .defensive, tuning: .defensive)
        case 2:
            configuration = .init(profile: .balanced, tuning: .balanced)
        case 3:
            configuration = .init(profile: .aggressive, tuning: .balanced)
        case 4:
            configuration = .init(profile: .aggressive, tuning: .aggressive)
        default:
            configuration = .init(profile: .balanced, tuning: .aggressive)
        }
        performPriorityAITurn(configuration: configuration)
    }

    private func performPriorityAITurn(configuration: EnemyAI.Configuration) {
        guard !currentPlayerIsP1 else { return }

        let ai = EnemyAI(configuration: configuration)

        if let action = ai.chooseBestAction(engine: self) {
            _ = action.execute(on: self)
        }

        let attacks = ai.chooseAttackPlan(engine: self)
        for attack in attacks {
            self.attack(from: attack.attackerSlot, to: attack.target)
        }

        endTurn()
    }

    // MARK: - Réinitialisation
    func resetGame() {
        p1 = PlayerState(name: p1.name, deck: StarterFactory.playerDeck())
        p2 = PlayerState(name: p2.name, deck: StarterFactory.randomDeck())
        currentPlayerIsP1 = true
        startingPlayerIsP1 = true
        p1CompletedTurns = 0
        p2CompletedTurns = 0
        log.removeAll()
        start()
    }

    private func autoDeployOpeningCommons(forP1: Bool) {
        var player = forP1 ? p1 : p2
        for slot in player.board.indices {
            guard let handIndex = player.hand.firstIndex(where: { $0.type == .common }) else { break }
            let card = player.hand.remove(at: handIndex)
            player.board[slot] = CardInstance(card)
        }

        if forP1 {
            p1 = player
        } else {
            p2 = player
        }
    }
}

struct EnemyAI {
    enum Profile {
        case aggressive
        case defensive
        case balanced
    }

    struct Tuning {
        let aggressiveness: Double
        let lowHealthThreshold: Int
        let defensiveCardValue: Double
        let lethalPriority: Double

        static let defensive = Tuning(aggressiveness: 0.8, lowHealthThreshold: 5, defensiveCardValue: 2.1, lethalPriority: 14)
        static let balanced = Tuning(aggressiveness: 1.0, lowHealthThreshold: 4, defensiveCardValue: 1.4, lethalPriority: 12)
        static let aggressive = Tuning(aggressiveness: 1.35, lowHealthThreshold: 3, defensiveCardValue: 0.9, lethalPriority: 11)
    }

    struct Configuration {
        let profile: Profile
        let tuning: Tuning
    }

    struct PlannedAction {
        enum PlacementTarget {
            case board(slot: Int)
            case god
            case sacrifice
            case none
        }

        let card: Card
        let target: PlacementTarget
        private let executeImpl: (GameEngine) -> Bool

        init(card: Card, target: PlacementTarget = .none, execute: @escaping (GameEngine) -> Bool) {
            self.card = card
            self.target = target
            self.executeImpl = execute
        }

        @discardableResult
        func execute(on engine: GameEngine) -> Bool {
            executeImpl(engine)
        }
    }

    struct PlannedAttack {
        let attackerSlot: Int
        let target: Target
    }

    private let config: Configuration

    init(configuration: Configuration) {
        self.config = configuration
    }

    func chooseBestAction(engine: GameEngine) -> PlannedAction? {
        let state = AIState(current: engine.current, opponent: engine.opponent)
        let shouldPrioritizeDefense = shouldDefend(state: state)

        let candidates = buildActionCandidates(from: state)
        let ranked = candidates.map { candidate -> (candidate: ActionCandidate, score: Double) in
            (candidate, evaluateCard(candidate: candidate, state: state, shouldPrioritizeDefense: shouldPrioritizeDefense))
        }

        guard let best = ranked.max(by: { $0.score < $1.score }), best.score > 0 else {
            return nil
        }

        return plannedAction(for: best.candidate)
    }

    func chooseAttackPlan(engine: GameEngine) -> [PlannedAttack] {
        guard engine.canCurrentPlayerAttack else { return [] }
        let state = AIState(current: engine.current, opponent: engine.opponent)
        let attackers = availableAttackers(from: state.current)

        guard !attackers.isEmpty else { return [] }

        if canDealLethal(state: state) {
            return attackers.map { PlannedAttack(attackerSlot: $0, target: .player) }
        }

        return attackers.map { slot in
            PlannedAttack(attackerSlot: slot, target: bestTarget(for: slot, state: state))
        }
    }

    func canDealLethal(state: AIState) -> Bool {
        let totalDamage = availableAttackers(from: state.current)
            .compactMap { attackValue(for: $0, from: state.current) }
            .reduce(0, +)
        return totalDamage >= state.opponent.hp
    }

    func shouldDefend(state: AIState) -> Bool {
        if state.current.hp <= config.tuning.lowHealthThreshold {
            return true
        }

        let incomingThreat = boardThreat(of: state.opponent)
        return incomingThreat >= max(2, state.current.hp / 2)
    }

    func evaluateCard(candidate: ActionCandidate, state: AIState, shouldPrioritizeDefense: Bool) -> Double {
        let baseAggro = config.tuning.aggressiveness
        let defenseMultiplier = shouldPrioritizeDefense ? config.tuning.defensiveCardValue : 1.0

        switch candidate.kind {
        case .playCommon(let emptySlot):
            let card = candidate.card
            let laneThreat = laneThreatScore(on: emptySlot, opponent: state.opponent)
            let offensiveValue = Double(card.attack) * baseAggro
            let defensiveValue = Double(card.health + laneThreat) * defenseMultiplier
            return offensiveValue + defensiveValue

        case .invokeGod:
            let card = candidate.card
            var score = 6.0 + Double(card.attack + card.health) * baseAggro
            if card.name == "Kukulcan" {
                score += Double(state.opponent.board.compactMap { $0 }.count) * 2.5
            }
            if state.opponent.hp <= card.attack {
                score += config.tuning.lethalPriority
            }
            return score

        case .playRitual(let target):
            guard let ritual = candidate.card.ritual else { return -100 }
            switch ritual {
            case .obsidianKnife:
                guard let slot = target else { return -50 }
                guard let victim = state.current.board[slot] else { return -50 }
                let resourceValue = 3.0
                let sacrificePenalty = Double(victim.currentAttack + victim.currentHP) * 0.3
                let canEnableGod = hasAffordableGodAfterKnife(state: state)
                return resourceValue - sacrificePenalty + (canEnableGod ? 4.0 : 0)
            case .bloodAltar:
                let hasFollowUpSacrifice = state.current.hand.contains(where: { $0.type == .common })
                return hasFollowUpSacrifice ? 3.4 : -2.0
            case .forestCharm:
                guard let slot = target, let unit = state.current.board[slot] else { return -5.0 }
                let attackValue = Double(unit.currentAttack + 1) * baseAggro
                let surviveValue = Double(unit.currentHP + 1) * defenseMultiplier
                return attackValue + surviveValue
            }

        case .sacrificeCommon:
            let hasGodInHand = state.current.hand.contains(where: { $0.type == .god })
            return hasGodInHand ? 3.8 : 1.2
        }
    }
}

extension EnemyAI {
    struct AIState {
        let current: PlayerState
        let opponent: PlayerState
    }

    enum ActionKind {
        case playCommon(emptySlot: Int)
        case invokeGod
        case playRitual(target: Int?)
        case sacrificeCommon
    }

    struct ActionCandidate {
        let card: Card
        let handIndex: Int
        let kind: ActionKind
    }

    private func buildActionCandidates(from state: AIState) -> [ActionCandidate] {
        var candidates: [ActionCandidate] = []
        let emptySlots = state.current.board.indices.filter { state.current.board[$0] == nil }

        for (idx, card) in state.current.hand.enumerated() {
            switch card.type {
            case .common:
                for slot in emptySlots {
                    candidates.append(ActionCandidate(card: card, handIndex: idx, kind: .playCommon(emptySlot: slot)))
                }
                candidates.append(ActionCandidate(card: card, handIndex: idx, kind: .sacrificeCommon))

            case .god:
                guard state.current.godSlot == nil, state.current.blood >= card.bloodCost else { continue }
                candidates.append(ActionCandidate(card: card, handIndex: idx, kind: .invokeGod))

            case .ritual:
                guard let ritual = card.ritual else { continue }
                switch ritual {
                case .obsidianKnife, .forestCharm:
                    for slot in state.current.board.indices where state.current.board[slot] != nil {
                        candidates.append(ActionCandidate(card: card, handIndex: idx, kind: .playRitual(target: slot)))
                    }
                case .bloodAltar:
                    candidates.append(ActionCandidate(card: card, handIndex: idx, kind: .playRitual(target: nil)))
                }
            case .curse:
                continue
            }
        }

        return candidates
    }

    private func plannedAction(for candidate: ActionCandidate) -> PlannedAction {
        let target: PlannedAction.PlacementTarget
        switch candidate.kind {
        case .playCommon(let slot):
            target = .board(slot: slot)
        case .invokeGod:
            target = .god
        case .sacrificeCommon:
            target = .sacrifice
        case .playRitual:
            target = .none
        }

        return PlannedAction(card: candidate.card, target: target) { engine in
            guard let currentHandIndex = engine.current.hand.firstIndex(where: { $0.id == candidate.card.id }) else {
                return false
            }

            switch candidate.kind {
            case .playCommon(let slot):
                guard slot >= 0, slot < engine.current.board.count, engine.current.board[slot] == nil else {
                    return false
                }
                engine.playCommonToBoard(handIndex: currentHandIndex, slot: slot)
                return true

            case .invokeGod:
                guard engine.current.godSlot == nil else { return false }
                let card = engine.current.hand[currentHandIndex]
                guard engine.current.blood >= card.bloodCost else { return false }
                engine.invokeGod(handIndex: currentHandIndex)
                return true

            case .playRitual(let target):
                if let target {
                    guard target >= 0, target < engine.current.board.count, engine.current.board[target] != nil else { return false }
                }
                engine.playRitual(handIndex: currentHandIndex, targetSlot: target)
                return true

            case .sacrificeCommon:
                engine.sacrificeCommon(handIndex: currentHandIndex)
                return true
            }
        }
    }

    private func availableAttackers(from state: PlayerState) -> [Int] {
        var attackers = state.board.indices.filter { idx in
            guard let unit = state.board[idx] else { return false }
            return !unit.hasActedThisTurn
        }

        if let god = state.godSlot, !god.hasActedThisTurn {
            attackers.append(-1)
        }

        return attackers
    }

    private func bestTarget(for attackerSlot: Int, state: AIState) -> Target {
        let attackerAttack = attackValue(for: attackerSlot, from: state.current) ?? 0
        var bestTarget: Target = .player
        var bestScore = Double(attackerAttack) * config.tuning.aggressiveness

        for idx in state.opponent.board.indices {
            guard let target = state.opponent.board[idx] else { continue }
            let killBonus = attackerAttack >= target.currentHP ? 2.8 : 0.6
            let threatReduction = Double(target.currentAttack) * (shouldDefend(state: state) ? 1.5 : 0.8)
            let score = killBonus + threatReduction
            if score > bestScore {
                bestScore = score
                bestTarget = .boardSlot(idx)
            }
        }

        if let enemyGod = state.opponent.godSlot {
            let killBonus = attackerAttack >= enemyGod.currentHP ? 3.2 : 1.0
            let godThreat = Double(enemyGod.currentAttack)
            let godScore = killBonus + godThreat
            if godScore > bestScore {
                bestTarget = .god
            }
        }

        return bestTarget
    }

    private func attackValue(for slot: Int, from state: PlayerState) -> Int? {
        if slot == -1 {
            return state.godSlot?.currentAttack
        }

        guard slot >= 0, slot < state.board.count else { return nil }
        return state.board[slot]?.currentAttack
    }

    private func boardThreat(of state: PlayerState) -> Int {
        let boardDamage = state.board.compactMap { $0?.currentAttack }.reduce(0, +)
        let godDamage = state.godSlot?.currentAttack ?? 0
        return boardDamage + godDamage
    }

    private func laneThreatScore(on slot: Int, opponent: PlayerState) -> Int {
        guard slot >= 0, slot < opponent.board.count else { return 0 }
        return opponent.board[slot]?.currentAttack ?? 0
    }

    private func hasAffordableGodAfterKnife(state: AIState) -> Bool {
        let projectedBlood = state.current.blood + 1 + state.current.pendingBonusBlood
        return state.current.hand.contains(where: { $0.type == .god && $0.bloodCost <= projectedBlood })
    }
}




// MARK: - Sample Decks (starter)

struct StarterFactory {
    static func common(_ name: String, atk: Int, hp: Int, img: String, effect: String) -> Card {
        Card(name: name, type: .common, rarity: .common, imageName: img,
             attack: atk, health: hp, effect: effect, lore: nil)
    }
    static func ritual(_ kind: RitualKind, name: String, img: String, effect: String) -> Card {
        Card(name: name, type: .ritual, rarity: .rare, imageName: img,
             ritual: kind, effect: effect)
    }
    static func god(_ name: String, atk: Int, hp: Int, img: String, cost: Int, effect: String, lore: String) -> Card {
        Card(name: name, type: .god, rarity: .legendary, imageName: img,
             attack: atk, health: hp, bloodCost: cost, effect: effect, lore: lore)
    }

    static func playerDeck() -> [Card] {
        var d: [Card] = []
        // Communes (utilise les noms d’assets que tu as)
        d += Array(repeating: common("Villageois effrayé", atk: 1, hp: 1, img: "villageois_effraye",
                                     effect: "Sacrifice : +1 sang."), count: 3)
        d += Array(repeating: common("Jeune chasseur", atk: 2, hp: 1, img: "jeune_chasseur",
                                     effect: "Arrivée : pioche 1."), count: 2)
        d += Array(repeating: common("Prisonnier captif", atk: 1, hp: 2, img: "prisonnier_captif",
                                     effect: "Mort : +1 sang."), count: 2)
        d += [common("Guerrier blessé", atk: 2, hp: 3, img: "guerrier_blesse",
                     effect: "Arrivée : gagne +1 PV.")]
        d += [common("Éclaireur perdu", atk: 1, hp: 2, img: "eclaireur_perdu",
                     effect: "Sacrifice : pioche 1.")]
        d += [common("Archer maladroit", atk: 2, hp: 2, img: "archer_maladroit",
                     effect: "Si tue une carte : pioche 1.")]

        // Rituels
        d += [ritual(.obsidianKnife, name: "Couteau d’obsidienne", img: "couteau_obsidienne", effect: "Sacrifie 1 commune posée, pioche 2.")]
        d += [ritual(.bloodAltar, name: "Autel de sang", img: "autel_de_sang", effect: "Prochain sacrifice +2 sang.")]
        d += [ritual(.forestCharm, name: "Charme forestier", img: "danse_macabre", effect: "+1/+1 à une commune.")]

        // Dieux (tes assets existants)
        d += [god("Ix Chel", atk: 6, hp: 7, img: "ix_chel", cost: 7,
                  effect: "Invocation : voile lunaire.",
                  lore: "Déesse de la lune et des marées, elle ourdit les destins comme on tisse un voile d’argent.")]
        d += [god("Kukulcan", atk: 7, hp: 8, img: "kukulcan", cost: 7,
                  effect: "Invocation : le serpent à plumes se déchaîne.",
                  lore: "Serpent à plumes, cyclone vivant des jungles oubliées.")]
        return d
    }

    static func randomDeck() -> [Card] {
        playerDeck()
    }
}
