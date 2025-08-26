import Foundation
import SwiftUI

/// Stocke la collection du joueur + ouverture de packs + persistance JSON
final class CollectionStore: ObservableObject {
    // Persistance locale
    @AppStorage("owned_cards_v2") private var ownedData: Data = Data()

    // Cartes possédées
    @Published var owned: [Card] = [] {
        didSet { save() }
    }

    init() {
        load()
    }

    // MARK: - Packs

    /// Ouvre un pack (mélange commune/rituel/dieu selon `CardsDB.mixedPack`)
    /// et ajoute les cartes tirées à la collection.
    @discardableResult
    func openPack() -> [Card] {
        // Toujours 3 cartes : 2 PEUPLE + (1 rituel 40% / sinon 1 PEUPLE) + 20% chance de remplacer par un DIEU
        var result: [Card] = []
        let commons = CardsDB.commons.shuffled()

        // 2 cartes PEUPLE
        result.append(contentsOf: Array(commons.prefix(2)))

        // 3e carte : 40% rituel, sinon PEUPLE
        if Int.random(in: 0..<100) < 40, let r = CardsDB.rituals.randomElement() {
            result.append(r)
        } else if let c = commons.dropFirst(2).first {
            result.append(c)
        }

        // Chance 20% d’upgrader la 3e en DIEU
        if Int.random(in: 0..<100) < 20, let g = CardsDB.gods.randomElement() {
            result[2] = g
        }

        owned.append(contentsOf: result)
        return result
    }

    /// Ajoute manuellement des cartes à la collection
    func add(_ cards: [Card]) {
        owned.append(contentsOf: cards)
    }

    // MARK: - Helpers d’affichage

    /// Cartes jouables en combat (exclut les rituels)
    var ownedPlayable: [Card] {
        owned.filter { $0.type != .ritual }
    }

    /// Compte des cartes par rareté (utile pour des stats UI)
    func count(by rarity: Rarity) -> Int {
        owned.filter { $0.rarity == rarity }.count
    }

    // MARK: - Persistance

    private func save() {
        do {
            let data = try JSONEncoder().encode(owned)
            ownedData = data
        } catch {
#if DEBUG
            print("Erreur d’encodage des cartes possédées: \(error)")
#endif
        }
    }

    private func load() {
        guard !ownedData.isEmpty else { return }
        do {
            let arr = try JSONDecoder().decode([Card].self, from: ownedData)
            owned = arr
        } catch {
#if DEBUG
            print("Erreur de décodage des cartes possédées: \(error)")
#endif
        }
    }

    // MARK: - Debug / Reset

    func resetCollection() {
        owned.removeAll()
    }
}

