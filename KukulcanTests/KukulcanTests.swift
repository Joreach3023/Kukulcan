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
        var p2 = PlayerState(name: "P2")
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
        var p2 = PlayerState(name: "P2")
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

}
