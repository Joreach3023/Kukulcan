//
//  KukulcanTests.swift
//  KukulcanTests
//
//  Created by Jonathan Labbe on 2025-08-24.
//

import Testing
import Foundation
@testable import Kukulcan

struct KukulcanTests {

    /// Test trivial pour s'assurer que l'environnement de test fonctionne.
    @Test func arithmeticWorks() {
        #expect(1 + 1 == 2)
    }

    /// Vérifie que le rituel Couteau d'obsidienne est bien défaussé après utilisation.
    @Test func obsidianKnifeIsDiscarded() {
        var p1 = PlayerState(name: "P1")
        let p2 = PlayerState(name: "P2")
        let ritual = Card(name: "Couteau d'obsidienne", type: .ritual, rarity: .rare,
                          imageName: "", ritual: .obsidianKnife, effect: "")
        let common = Card(name: "Soldat", type: .common, rarity: .common,
                          imageName: "soldat", attack: 1, health: 1, effect: "")
        p1.hand = [ritual]
        p1.board[0] = CardInstance(common)
        let engine = GameEngine(p1: p1, p2: p2)
        engine.playRitual(handIndex: 0, targetSlot: 0)
        #expect(engine.p1.discard.contains(where: { $0.id == ritual.id }))
    }

    /// `Card` should keep the same `id` after encoding and decoding.
    @Test func cardIDIsStableThroughCoding() throws {
        let card = Card(name: "Test", type: .common, rarity: .common,
                        imageName: "test", attack: 1, health: 1, effect: "")
        let data = try JSONEncoder().encode(card)
        let decoded = try JSONDecoder().decode(Card.self, from: data)
        #expect(card.id == decoded.id)
    }

    /// `CardInstance` should keep the same `id` after encoding and decoding.
    @Test func cardInstanceIDIsStableThroughCoding() throws {
        let card = Card(name: "Test", type: .common, rarity: .common,
                        imageName: "test", attack: 1, health: 1, effect: "")
        let inst = CardInstance(card)
        let data = try JSONEncoder().encode(inst)
        let decoded = try JSONDecoder().decode(CardInstance.self, from: data)
        #expect(inst.id == decoded.id)
    }

    /// `Charme forestier` should grant +1 attack and +1 health to a targeted common.
    @Test func forestCharmBuffsStats() {
        var p1 = PlayerState(name: "P1")
        let p2 = PlayerState(name: "P2")
        let ritual = Card(name: "Charme forestier", type: .ritual, rarity: .rare,
                          imageName: "", ritual: .forestCharm, effect: "")
        let common = Card(name: "Soldat", type: .common, rarity: .common,
                          imageName: "soldat", attack: 1, health: 1, effect: "")
        p1.hand = [ritual]
        p1.board[0] = CardInstance(common)
        let engine = GameEngine(p1: p1, p2: p2)
        engine.playRitual(handIndex: 0, targetSlot: 0)
        let inst = engine.p1.board[0]
        #expect(inst?.currentAttack == 2)
        #expect(inst?.currentHP == 2)
    }

    /// `pendingBonusBlood` should reset to 0 at end of turn.
    @Test func pendingBonusBloodResets() {
        var p1 = PlayerState(name: "P1")
        let p2 = PlayerState(name: "P2")
        p1.pendingBonusBlood = 1
        let engine = GameEngine(p1: p1, p2: p2)
        engine.endTurn()
        #expect(engine.p1.pendingBonusBlood == 0)
    }

    /// Blood gained should persist across turns so players can save for gods.
    @Test func bloodAccumulatesAcrossTurns() {
        var p1 = PlayerState(name: "P1")
        let p2 = PlayerState(name: "P2")
        let common = Card(name: "Soldat", type: .common, rarity: .common,
                          imageName: "soldat", attack: 1, health: 1, effect: "")
        // Deux cartes pour pouvoir sacrifier deux fois
        p1.hand = [common, common]
        let engine = GameEngine(p1: p1, p2: p2)

        // Premier sacrifice
        engine.sacrificeCommon(handIndex: 0)
        #expect(engine.p1.blood == 1)

        // Fin du tour de P1 puis P2 termine immédiatement son tour
        engine.endTurn()
        engine.endTurn()

        // Le sang doit être conservé
        #expect(engine.p1.blood == 1)

        // Nouveau sacrifice pour accumuler
        engine.sacrificeCommon(handIndex: 0)
        #expect(engine.p1.blood == 2)
    }

    /// Decks should respect copy limits: max 3 per card, 1 for gods.
    @Test func deckCopyLimits() {
        let c1 = Card(name: "Soldat", type: .common, rarity: .common,
                      imageName: "soldat", attack: 1, health: 1, effect: "")
        let c2 = Card(name: "Soldat", type: .common, rarity: .common,
                      imageName: "soldat", attack: 1, health: 1, effect: "")
        let c3 = Card(name: "Soldat", type: .common, rarity: .common,
                      imageName: "soldat", attack: 1, health: 1, effect: "")
        let c4 = Card(name: "Soldat", type: .common, rarity: .common,
                      imageName: "soldat", attack: 1, health: 1, effect: "")
        let g1 = Card(name: "Kinich", type: .god, rarity: .legendary,
                      imageName: "kinich", attack: 5, health: 5, bloodCost: 7, effect: "")
        let g2 = Card(name: "Kinich", type: .god, rarity: .legendary,
                      imageName: "kinich", attack: 5, health: 5, bloodCost: 7, effect: "")

        #expect(Deck(name: "ok", cards: [c1, c2, c3]).isValid())
        #expect(!Deck(name: "too many", cards: [c1, c2, c3, c4]).isValid())
        #expect(!Deck(name: "gods", cards: [g1, g2]).isValid())
        #expect(Deck(name: "one god", cards: [g1, c1]).isValid())
    }

    /// Gold should persist across instances, spending should reduce it and buying packs should fail if insufficient.
    @Test func testGoldSpendingAndSaving() {
        var store = CollectionStore()
        store.resetCollection() // clean state

        // Add and spend gold
        store.addGold(200)
        #expect(store.spendGold(150))
        #expect(store.gold == 50)

        // Gold should persist after reloading
        var reloaded = CollectionStore()
        #expect(reloaded.gold == 50)

        // Cannot buy pack without enough gold
        let attempt = reloaded.buyPack(cost: 100)
        #expect(attempt == nil)
        #expect(reloaded.owned.isEmpty)
        #expect(reloaded.gold == 50)

        // Add enough gold and buy a pack
        reloaded.addGold(100)
        let pack = reloaded.buyPack(cost: 100)
        #expect(pack?.count == 3)
        #expect(reloaded.gold == 50)

        // Reset should clear gold and collection
        reloaded.resetCollection()
        #expect(reloaded.gold == 0)
        #expect(reloaded.owned.isEmpty)

        // Reloaded instance after reset should also have zero gold
        let fresh = CollectionStore()
        #expect(fresh.gold == 0)
        #expect(fresh.owned.isEmpty)
    }
}
