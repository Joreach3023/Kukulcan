import Foundation
#if canImport(SwiftUI)
import SwiftUI
#else
@propertyWrapper
struct AppStorage<Value> {
    private let key: String
    private let defaultValue: Value

    init(wrappedValue: Value, _ key: String) {
        self.key = key
        self.defaultValue = wrappedValue
        UserDefaults.standard.register(defaults: [key: wrappedValue])
    }

    var wrappedValue: Value {
        get {
            UserDefaults.standard.object(forKey: key) as? Value ?? defaultValue
        }
        set {
            UserDefaults.standard.set(newValue, forKey: key)
        }
    }
}
#endif

/// Stocke la collection du joueur + ouverture de packs + persistance JSON
final class CollectionStore: ObservableObject {
    // Persistance locale
    @AppStorage("owned_cards_v2") private var ownedData: Data = Data()
    @AppStorage("player_decks_v1") private var decksData: Data = Data()
    @AppStorage("player_gold_v1") private var storedGold: Int = 0

    // Cartes possédées
    @Published var owned: [Card] = [] {
        didSet { save() }
    }

    // Decks du joueur (max 20)
    @Published var decks: [Deck] = [] {
        didSet { saveDecks() }
    }

    // Or du joueur
    @Published var gold: Int = 0 {
        didSet { storedGold = gold }
    }

    init() {
        load()
        loadDecks()
        gold = storedGold
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

    /// Ajoute de l'or au joueur
    func addGold(_ amount: Int) {
        gold += amount
    }

    /// Dépense de l'or si possible
    @discardableResult
    func spendGold(_ amount: Int) -> Bool {
        guard gold >= amount else { return false }
        gold -= amount
        return true
    }

    /// Achète et ouvre un pack si suffisamment d'or. Retourne `nil` si achat impossible.
    @discardableResult
    func buyPack(cost: Int = 100) -> [Card]? {
        guard spendGold(cost) else { return nil }
        return openPack()
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

    private func saveDecks() {
        do {
            let data = try JSONEncoder().encode(decks)
            decksData = data
        } catch {
#if DEBUG
            print("Erreur d’encodage des decks: \(error)")
#endif
        }
    }

    private func loadDecks() {
        guard !decksData.isEmpty else { return }
        do {
            let arr = try JSONDecoder().decode([Deck].self, from: decksData)
            decks = arr
        } catch {
#if DEBUG
            print("Erreur de décodage des decks: \(error)")
#endif
        }
    }

    // MARK: - Debug / Reset

    func resetCollection() {
        owned.removeAll()
        decks.removeAll()
        gold = 0
    }
}

