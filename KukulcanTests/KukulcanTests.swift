//
//  KukulcanTests.swift
//  KukulcanTests
//
//  Created by Jonathan Labbe on 2025-08-24.
//

import Testing
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

}
