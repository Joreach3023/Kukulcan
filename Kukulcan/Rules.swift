import Foundation

// MARK: - Domain

enum Rarity: String, Codable { case common, rare, epic, legendary }

enum CardType: String, Codable { case common, ritual, god }

/// Rituels pré-définis (tu pourras en ajouter facilement)
enum RitualKind: String, Codable {
    case obsidianKnife     // Sacrifie 1 commune en jeu → +1 blood et pioche 2
    case bloodAltar        // Le prochain sacrifice donne +2 blood au lieu de +1 (ce tour)
    case forestCharm       // +1/+1 à une commune sur le board (buff simple)
}

/// Carte "statique" (modèle)
struct Card: Identifiable, Codable, Hashable {
    let id = UUID()
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

    init(name: String,
         type: CardType,
         rarity: Rarity,
         imageName: String,
         attack: Int = 0,
         health: Int = 0,
         ritual: RitualKind? = nil,
         bloodCost: Int = 0,
         effect: String,
         lore: String? = nil) {
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
    let id = UUID()
    let base: Card
    var currentHP: Int

    init(_ card: Card) {
        self.base = card
        self.currentHP = max(1, card.health)
    }
}

// MARK: - Player / State

struct PlayerState: Codable {
    var name: String
    var hp: Int = 10

    var deck: [Card] = []
    var hand: [Card] = []
    var discard: [Card] = []

    var board: [CardInstance?] = Array(repeating: nil, count: 4)   // communes
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
    case boardSlot(Int)                  // viser une carte sur le board (0..3)
    case god                             // viser le dieu adverse s’il existe
}

final class GameEngine: ObservableObject {
    @Published private(set) var p1: PlayerState
    @Published private(set) var p2: PlayerState

    @Published private(set) var currentPlayerIsP1: Bool = true
    @Published private(set) var log: [String] = []
    @Published var lastDrawnCard: Card? = nil

    var current: PlayerState { currentPlayerIsP1 ? p1 : p2 }
    var opponent: PlayerState { currentPlayerIsP1 ? p2 : p1 }

    init(p1: PlayerState, p2: PlayerState) {
        self.p1 = p1; self.p2 = p2
    }

    // MARK: setup
    func start(mulligan: Int = 5) {
        // Mélange très simple
        p1.deck.shuffle(); p2.deck.shuffle()
        _ = p1.draw(mulligan); _ = p2.draw(mulligan)
        log.removeAll()
        log.append("La partie commence. \(p1.name) joue en premier.")
    }

    // MARK: actions (joueur courant)

    func playCommonToBoard(handIndex: Int, slot: Int) {
        guard slot >= 0 && slot < current.board.count else { return }
        var cp = current
        guard handIndex < cp.hand.count else { return }
        let c = cp.hand[handIndex]
        guard c.type == .common else { return }
        guard cp.board[slot] == nil else { return } // slot libre
        cp.hand.remove(at: handIndex)
        cp.board[slot] = CardInstance(c)
        setCurrent(cp, log: "\(activeName()) pose \(c.name) sur l’emplacement \(slot+1).")
    }

    func sacrificeCommon(handIndex: Int) {
        // Sacrifice d’une commune depuis la main (ou tu peux adapter pour sacrifier une commune déjà en jeu)
        var cp = current
        guard handIndex < cp.hand.count else { return }
        let c = cp.hand[handIndex]
        guard c.type == .common else { return }

        cp.hand.remove(at: handIndex)
        let inst = CardInstance(c)
        cp.sacrificeSlot = inst
        // Gain de blood
        let gain = 1 + cp.pendingBonusBlood
        cp.blood += gain
        cp.pendingBonusBlood = 0
        cp.discard.append(c)
        setCurrent(cp, log: "\(activeName()) sacrifie \(c.name) → +\(gain) Sang (total \(cp.blood)).")
    }

    func playRitual(handIndex: Int, targetSlot: Int? = nil) {
        var cp = current
        guard handIndex < cp.hand.count else { return }
        let c = cp.hand[handIndex]
        guard c.type == .ritual, let kind = c.ritual else { return }
        cp.hand.remove(at: handIndex)

        switch kind {
        case .obsidianKnife:
            // Sacrifie une commune POSÉE (si targetSlot fourni et valide)
            if let s = targetSlot, s >= 0, s < cp.board.count, var inst = cp.board[s] {
                cp.board[s] = nil
                let gain = 1 + cp.pendingBonusBlood
                cp.blood += gain
                cp.pendingBonusBlood = 0
                cp.sacrificeSlot = inst
                cp.discard.append(inst.base)
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
        guard cp.blood >= c.bloodCost else { return }

        cp.hand.remove(at: handIndex)
        cp.blood -= c.bloodCost
        cp.godSlot = CardInstance(c)

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

        func assignBackAttacker() {
            if isGod {
                atkOwner.godSlot = atker
            } else if slot >= 0, slot < atkOwner.board.count {
                atkOwner.board[slot] = atker
            }
        }

        switch target {
        case .player:
            defOwner.hp -= atker.base.attack
            if defOwner.hp < 0 { defOwner.hp = 0 }
            log.append("\(activeName()) attaque directement → \(passiveName()) perd \(atker.base.attack) PV (\(defOwner.hp) restants).")

        case .god:
            guard var def = defOwner.godSlot else { return }
            def.currentHP -= atker.base.attack
            atker.currentHP -= def.base.attack
            if def.currentHP <= 0 { defOwner.discard.append(def.base); defOwner.godSlot = nil }
            if atker.currentHP <= 0 {
                if isGod { atkOwner.discard.append(atker.base); atkOwner.godSlot = nil }
                else { atkOwner.discard.append(atker.base); atkOwner.board[slot] = nil }
            } else {
                assignBackAttacker()
                defOwner.godSlot = def
            }

        case .boardSlot(let i):
            guard i >= 0, i < defOwner.board.count, var def = defOwner.board[i] else {
                // pas de défenseur → attaque le joueur
                defOwner.hp -= atker.base.attack
                if defOwner.hp < 0 { defOwner.hp = 0 }
                log.append("\(activeName()) trouve la voie libre et frappe \(passiveName()) pour \(atker.base.attack) PV.")
                break
            }
            // combat
            def.currentHP -= atker.base.attack
            atker.currentHP -= def.base.attack

            if def.currentHP <= 0 { defOwner.discard.append(def.base); defOwner.board[i] = nil }
            else { defOwner.board[i] = def }

            if atker.currentHP <= 0 {
                if isGod { atkOwner.discard.append(atker.base); atkOwner.godSlot = nil }
                else { atkOwner.discard.append(atker.base); atkOwner.board[slot] = nil }
            } else {
                assignBackAttacker()
            }
        }

        setCurrent(atkOwner)
        setOpponent(defOwner)
    }

    func endTurn() {
        // reset visuel slot sacrifice
        if currentPlayerIsP1 { p1.sacrificeSlot = nil } else { p2.sacrificeSlot = nil }
        currentPlayerIsP1.toggle()
        log.append("—— Tour terminé. À \(activeName()) de jouer.")
        // pioche automatique
        drawForCurrent(1)
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

    private func drawForCurrent(_ n: Int) {
        if currentPlayerIsP1 {
            let d = p1.draw(n)
            lastDrawnCard = d.last
        } else {
            let d = p2.draw(n)
            lastDrawnCard = d.last
        }
    }

    // MARK: - IA facile
    func performEasyAITurn() {
        guard !currentPlayerIsP1 else { return }
        if let slot = current.board.firstIndex(where: { $0 == nil }),
           let idx = current.hand.firstIndex(where: { $0.type == .common }) {
            playCommonToBoard(handIndex: idx, slot: slot)
        }
        for i in 0..<current.board.count {
            if current.board[i] != nil {
                attack(from: i, to: .boardSlot(i))
            }
        }
        if current.godSlot != nil {
            attack(from: -1, to: .player)
        }
        endTurn()
    }

    // MARK: - Réinitialisation
    func resetGame() {
        p1 = PlayerState(name: p1.name, deck: StarterFactory.playerDeck())
        p2 = PlayerState(name: p2.name, deck: StarterFactory.randomDeck())
        currentPlayerIsP1 = true
        log.removeAll()
        start()
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
        d += [ritual(.obsidianKnife, name: "Couteau d’obsidienne", img: "archer_maladroit", effect: "Sacrifie 1 commune posée, pioche 2.")]
        d += [ritual(.bloodAltar, name: "Autel de sang", img: "disciple_zele", effect: "Prochain sacrifice +2 sang.")]
        d += [ritual(.forestCharm, name: "Charme forestier", img: "eclaireur_perdu", effect: "+1/+1 à une commune.")]

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
        CardsDB.battleDeck
    }
}

