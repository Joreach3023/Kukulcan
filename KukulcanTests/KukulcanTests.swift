//
//  KukulcanTests.swift
//  KukulcanTests
//
//  Created by Jonathan Labbe on 2025-08-24.
//

import Testing
@testable import Kukulcan

struct KukulcanTests {

    /// Vérifie la logique pierre-feuille-ciseaux entre les éléments.
    @Test func elementBeatsLogic() {
        #expect(Element.fire.beats(.plant))
        #expect(Element.water.beats(.fire))
        #expect(Element.plant.beats(.water))
        #expect(!Element.fire.beats(.water))
    }

}
