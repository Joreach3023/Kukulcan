//
//  KukulcanTests.swift
//  KukulcanTests
//
//  Created by Jonathan Labbe on 2025-08-24.
//

import Testing
@testable import Kukulcan

struct KukulcanTests {

    /// Vérifie que l’élément Plante possède un titre lisible.
    @Test func plantElementHasTitle() {
        #expect(Element.plant.title == "Plante")
    }

}
