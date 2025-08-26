import SwiftUI

final class GameState: ObservableObject {
    // États visibles
    @Published var playerHand: [Card] = []
    @Published var aiHand: [Card] = []
    @Published var lanes: [(player: Card?, ai: Card?)] = Array(repeating: (nil, nil), count: 3)
    @Published var playerScore = 0
    @Published var aiScore = 0
    @Published var gameOver = false
    @Published var message: String = "Place une carte !"

    // Deux pioches indépendantes
    private var playerDeck: [Card] = []
    private var aiDeck: [Card] = []

    // ⬇️ NOUVEAU : deck de base injecté (les cartes possédées)
    private var baseDeckOverride: [Card]? = nil

    // Init par défaut (utilise le deck 6 cartes)
    init() { newGame() }

    // ⬇️ NOUVEAU : init avec deck dispo (collection possédée)
    init(available: [Card]) {
        self.baseDeckOverride = available
        newGame()
    }

    // Retourne le deck de base courant
    private func baseDeck() -> [Card] {
        if let o = baseDeckOverride, !o.isEmpty { return o }
        return Self.sampleDeck()
    }

    // MARK: - Cycle de partie

    func newGame() {
        playerScore = 0
        aiScore = 0
        gameOver = false
        message = "Place une carte !"
        lanes = Array(repeating: (nil, nil), count: 3)

        // Chaque joueur a son propre deck, mélangé indépendamment
        let base = baseDeck()
        playerDeck = base.shuffled()
        aiDeck     = base.shuffled()

        // Main de départ: 5 cartes chacun (si deck vide, on recompose automatiquement)
        playerHand = draw(from: &playerDeck, count: 5)
        aiHand     = draw(from: &aiDeck,     count: 5)
    }

    // MARK: - Jouer une carte (tap ou drag&drop)

    func play(card: Card, to laneIndex: Int) {
        guard lanes.indices.contains(laneIndex),
              lanes[laneIndex].player == nil,
              !gameOver else { return }

        // Retrouver la vraie carte dans la main (drag encodé/décodé)
        guard let idx = playerHand.firstIndex(where: {
            $0.name == card.name &&
            $0.attack == card.attack &&
            $0.health == card.health &&
            $0.imageName == card.imageName &&
            $0.rarity == card.rarity &&
            $0.type == card.type
        }) else { return }

        let realCard = playerHand[idx]
        lanes[laneIndex].player = realCard
        playerHand.remove(at: idx)

        // Repioche
        if playerHand.count < 5 {
            playerHand.append(contentsOf: draw(from: &playerDeck, count: 1))
        }

        aiRespond(to: laneIndex)
        resolveIfReady(laneIndex)
        checkEnd()
    }

    // MARK: - IA

    private func aiRespond(to laneIndex: Int) {
        guard lanes[laneIndex].ai == nil, !aiHand.isEmpty else { return }

        let chosen: Card = aiHand.randomElement()!
        lanes[laneIndex].ai = chosen
        aiHand.removeAll { $0.id == chosen.id }

        if aiHand.count < 5 {
            aiHand.append(contentsOf: draw(from: &aiDeck, count: 1))
        }
    }

    // MARK: - Résolution & fin

    private func resolveIfReady(_ i: Int) {
        guard let p = lanes[i].player, let a = lanes[i].ai else { return }
        let winner: Int = {
            return p.attack == a.attack ? 0 : (p.attack > a.attack ? 1 : -1)
        }()
        switch winner {
        case 1: playerScore += 1; message = "Tu gagnes la lane \(i+1) !"
        case -1: aiScore += 1;    message = "L’IA gagne la lane \(i+1)…"
        default:                  message = "Égalité sur la lane \(i+1)."
        }
    }

    private func checkEnd() {
        let lanesRemplies = lanes.filter { $0.player != nil && $0.ai != nil }.count
        if playerScore == 2 || aiScore == 2 || lanesRemplies == 3 {
            gameOver = true
            message += playerScore > aiScore ? " 🎉 Victoire !" :
                       (playerScore < aiScore ? " 💀 Défaite." : " 🤝 Match nul.")
        }
    }

    // MARK: - Pioche

    private func draw(from deck: inout [Card], count: Int) -> [Card] {
        var res: [Card] = []
        for _ in 0..<count {
            if deck.isEmpty { deck = baseDeck().shuffled() }
            if !deck.isEmpty { res.append(deck.removeFirst()) }
        }
        return res
    }

    // MARK: - Deck de secours (6 cartes)
    private static func sampleDeck() -> [Card] {
        return [
            Card(
                name: "Kinich Ahau",
                type: .god,
                rarity: .legendary,
                imageName: "kinich_ahau",
                attack: 6,
                health: 7,
                ritual: nil,
                bloodCost: 7,
                effect: "Invocation : brûle les impies.",
                lore: "Le soleil brûlant de Kinich Ahau éclaire la jungle et châtie ses ennemis d’une chaleur implacable."
            ),
            Card(
                name: "Buluc Chabtan",
                type: .god,
                rarity: .legendary,
                imageName: "buluc_chabtan",
                attack: 4,
                health: 6,
                ritual: nil,
                bloodCost: 7,
                effect: "Invocation : héraut de la guerre.",
                lore: "Les tambours de Buluc Chabtan annoncent la guerre : là où il passe, le silence tombe après la bataille."
            ),
            Card(
                name: "Chaac",
                type: .god,
                rarity: .legendary,
                imageName: "chaac",
                attack: 6,
                health: 7,
                ritual: nil,
                bloodCost: 7,
                effect: "Invocation : la pluie et la foudre répondent.",
                lore: "D’un coup de hache de foudre, Chaac fend les nuages et fait tomber une pluie nourricière."
            ),
            Card(
                name: "Ix Chel",
                type: .god,
                rarity: .legendary,
                imageName: "ix_chel",
                attack: 4,
                health: 6,
                ritual: nil,
                bloodCost: 7,
                effect: "Invocation : voile lunaire.",
                lore: "Sous la lueur d’Ix Chel, la guérison et les rêves tissent les destins des hommes."
            ),
            Card(
                name: "Kukulcan",
                type: .god,
                rarity: .legendary,
                imageName: "kukulcan",
                attack: 5,
                health: 7,
                ritual: nil,
                bloodCost: 7,
                effect: "Invocation : le serpent à plumes se déchaîne.",
                lore: "Le serpent ailé s’élève vers le ciel, reliant les dieux aux mortels par sa danse dans les vents."
            ),
            Card(
                name: "Itzamna",
                type: .god,
                rarity: .legendary,
                imageName: "itzamna",
                attack: 3,
                health: 5,
                ritual: nil,
                bloodCost: 7,
                effect: "Invocation : sagesse des origines.",
                lore: "Itzamna, sage ancien, trace l’ordre du monde dans les étoiles et enseigne la connaissance aux hommes."
            )
        ]
    }

}

