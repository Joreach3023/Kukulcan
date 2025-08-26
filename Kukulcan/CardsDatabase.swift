//
//  CardsDatabase.swift
//  Kukulcan
//
//  Base de données des cartes (communes, rituels, dieux)
//  Compatible avec le modèle de Rules.swift
//

import Foundation

enum CardSet {
    case commons
    case rituals
    case gods
}

struct CardsDB {

    // MARK: - Helpers de construction

    private static func common(
        _ name: String,
        el: Element,
        atk: Int,
        hp: Int,
        img: String,
        effect: String? = nil,
        lore: String? = nil
    ) -> Card {
        Card(
            name: name,
            type: .common,
            element: el,
            rarity: .common,
            imageName: img,
            attack: atk,
            health: hp,
            ritual: nil,
            bloodCost: 0,
            effect: effect,
            lore: lore
        )
    }

    private static func ritual(
        _ name: String,
        kind: RitualKind,
        img: String,
        rarity: Rarity = .rare,
        effect: String,
        lore: String? = nil
    ) -> Card {
        Card(
            name: name,
            type: .ritual,
            element: .plant, // élément arbitraire pour rituels
            rarity: rarity,
            imageName: img,
            attack: 0,
            health: 0,
            ritual: kind,
            bloodCost: 0,
            effect: effect,
            lore: lore
        )
    }

    private static func god(
        _ name: String,
        el: Element,
        atk: Int,
        hp: Int,
        img: String,
        bloodCost: Int = 7,
        lore: String
    ) -> Card {
        Card(
            name: name,
            type: .god,
            element: el,
            rarity: .legendary,
            imageName: img,
            attack: atk,
            health: hp,
            ritual: nil,
            bloodCost: bloodCost,
            effect: "Invocation : pouvoir divin.",
            lore: lore
        )
    }

    // MARK: - COMMUNES (Disciples / Guerriers faibles)

    static let commons: [Card] = [
        common("Villageois effrayé",
               el: .plant, atk: 1, hp: 1,
               img: "villageois_effraye",
               effect: "Sacrifice : +1 sang.",
               lore: "Il tremble devant l’autel, mais ses cris nourrissent les dieux."),
        common("Jeune chasseur",
               el: .plant, atk: 2, hp: 1,
               img: "jeune_chasseur",
               lore: "Encore naïf, il croit pouvoir survivre à l’épreuve."),
        common("Prisonnier captif",
               el: .fire, atk: 1, hp: 2,
               img: "prisonnier_captif",
               lore: "Ses chaînes résonnent comme un chant d’offrande."),
        common("Guerrier blessé",
               el: .fire, atk: 2, hp: 3,
               img: "guerrier_blesse",
               lore: "Le sang qui s’écoule de sa plaie est déjà une offrande."),
        common("Éclaireur perdu",
               el: .plant, atk: 1, hp: 2,
               img: "eclaireur_perdu",
               lore: "Isolé dans la jungle, il devient proie autant que soldat."),
        common("Archer maladroit",
               el: .plant, atk: 2, hp: 2,
               img: "archer_maladroit",
               effect: "Si élimine une carte : pioche 1.",
               lore: "Ses flèches ratent souvent… mais son cœur vise juste les dieux."),
        common("Disciple zélé",
               el: .fire, atk: 1, hp: 1,
               img: "disciple_zele",
               effect: "Sacrifice : +2 sang.",
               lore: "Il supplie qu’on l’offre au plus vite."),
        common("Prophète délirant",
               el: .water, atk: 1, hp: 1,
               img: "prophete_delirant",
               effect: "Mort : pioche 1.",
               lore: "Ses visions troublées alimentent l’autel.")
    ]

    // MARK: - RITUELS (effets définis dans GameEngine.playRitual)

    static let rituals: [Card] = [
        ritual("Couteau d’obsidienne",
               kind: .obsidianKnife,
               img: "disciple_zele", // placeholder d’illustration
               rarity: .rare,
               effect: "Sacrifie 1 commune posée, pioche 2.",
               lore: "Tranchant comme la nuit, il ouvre la voie aux dieux."),
        ritual("Autel de sang",
               kind: .bloodAltar,
               img: "eclaireur_perdu",
               rarity: .epic,
               effect: "Prochain sacrifice : +2 sang.",
               lore: "Chaque pierre absorbe l’offrande."),
        ritual("Charme forestier",
               kind: .forestCharm,
               img: "archer_maladroit",
               rarity: .rare,
               effect: "+1/+1 à une commune.",
               lore: "Un murmure des anciens esprits.")
    ]

    // MARK: - DIEUX (Légendaires)

    static let gods: [Card] = [
        god("Kinich Ahau",
            el: .fire, atk: 7, hp: 7,
            img: "kinich_ahau",
            lore: "Le soleil brûlant de Kinich Ahau éclaire la jungle et châtie ses ennemis d’une chaleur implacable."),
        god("Kukulcan",
            el: .plant, atk: 7, hp: 8,
            img: "kukulcan",                      // ⚠️ bien orthographié
            lore: "Le serpent à plumes s’élève dans le vent et fauche les orgueilleux d’un seul souffle."),
        god("Chaac",
            el: .water, atk: 6, hp: 7,
            img: "chaac",
            lore: "Le tonnerre gronde avec Chaac, et chaque éclair abreuve la terre… ou foudroie les impies."),
        god("Ix Chel",
            el: .water, atk: 6, hp: 7,
            img: "ix_chel",
            lore: "Déesse de la lune et des marées, elle ourdit les destins comme on tisse un voile d’argent."),
        god("Itzamna",
            el: .plant, atk: 5, hp: 7,
            img: "itzamna",
            lore: "Seigneur du ciel et des écritures, il murmure la naissance et la fin des mondes."),
        god("Buluc Chabtan",
            el: .fire, atk: 6, hp: 6,
            img: "buluc_chabtan",
            lore: "La guerre est sa prière ; il exige des cœurs ardents et offre la victoire en retour.")
    ]

    // MARK: - Decks utilitaires

    /// Deck “de base” mélangeant tout
    static var baseDeck: [Card] {
        (commons + rituals + gods).shuffled()
    }

    /// Deck jouable pour combats – ici on retire les rituels si tu veux un test simple
    static var battleDeck: [Card] {
        (commons + gods).shuffled()
    }

    /// Paquets pour onglet Packs
    static var commonPack: [Card] {
        Array(commons.shuffled().prefix(3))
    }

    static var mixedPack: [Card] {
        var result: [Card] = []
        result.append(contentsOf: Array(commons.shuffled().prefix(2)))
        if Bool.random() { result.append(rituals.randomElement()!) }
        if Int.random(in: 0..<5) == 0 { result.append(gods.randomElement()!) }
        return result
    }
}

