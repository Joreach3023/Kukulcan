import Foundation

struct MayaEvent {
    let title: String
    let description: String
    let options: [MayaEventOption]
}

struct MayaEventOption: Identifiable {
    let id = UUID()
    let text: String
    let effects: [MayaEventEffect]
}

enum MayaEventEffect {
    case gainGold(Int)
    case loseGold(Int)
    case gainHP(Int)
    case loseHP(Int)
    case gainRelic
    case gainCard(rarity: Rarity?)
    case removeCard
    case upgradeCard
    case startEliteFight
}

enum MayaEventCatalog {
    static let events: [MayaEvent] = [
        MayaEvent(
            title: "Autel du Soleil",
            description: "Un ancien autel sacré brûle d'une lumière divine.",
            options: [
                MayaEventOption(text: "Sacrifier du sang (-6 HP, gagner une relique)", effects: [.loseHP(6), .gainRelic]),
                MayaEventOption(text: "Prier le soleil (heal 8 HP)", effects: [.gainHP(8)]),
                MayaEventOption(text: "Partir sans rien", effects: [])
            ]
        ),
        MayaEvent(
            title: "Statue de Kukulcan",
            description: "Une immense statue du serpent à plumes vous observe.",
            options: [
                MayaEventOption(text: "Toucher la statue (obtenir une carte rare)", effects: [.gainCard(rarity: .rare)]),
                MayaEventOption(text: "Offrir un sacrifice (-8 HP, upgrade une carte)", effects: [.loseHP(8), .upgradeCard]),
                MayaEventOption(text: "Profaner la statue (combat elite)", effects: [.startEliteFight])
            ]
        ),
        MayaEvent(
            title: "Temple du Sacrifice",
            description: "Un autel couvert de sang ancien.",
            options: [
                MayaEventOption(text: "Sacrifier une carte (gain relique)", effects: [.removeCard, .gainRelic]),
                MayaEventOption(text: "Sacrifier du sang (-10 HP, gagner 80 gold)", effects: [.loseHP(10), .gainGold(80)]),
                MayaEventOption(text: "Refuser le rituel", effects: [])
            ]
        ),
        MayaEvent(
            title: "Guerrier Jaguar",
            description: "Un ancien guerrier jaguar garde le passage.",
            options: [
                MayaEventOption(text: "Accepter le duel (combat elite)", effects: [.startEliteFight]),
                MayaEventOption(text: "Offrir de l'or (-40 gold)", effects: [.loseGold(40)]),
                MayaEventOption(text: "Fuir (-5 HP)", effects: [.loseHP(5)])
            ]
        ),
        MayaEvent(
            title: "Trésor oublié",
            description: "Un coffre ancien repose dans une pièce abandonnée.",
            options: [
                MayaEventOption(text: "Ouvrir le coffre (+100 gold)", effects: [.gainGold(100)]),
                MayaEventOption(text: "Laisser une offrande (gain relique)", effects: [.gainRelic])
            ]
        ),
        MayaEvent(
            title: "Esprit de la Jungle",
            description: "Un esprit ancien apparaît dans la jungle.",
            options: [
                MayaEventOption(text: "Recevoir la bénédiction (heal 10 HP)", effects: [.gainHP(10)]),
                MayaEventOption(text: "Demander du pouvoir (gain carte)", effects: [.gainCard(rarity: nil)]),
                MayaEventOption(text: "Ignorer l'esprit", effects: [])
            ]
        ),
        MayaEvent(
            title: "Feu Sacré",
            description: "Un feu rituel brûle au centre d'un cercle de pierres.",
            options: [
                MayaEventOption(text: "Brûler une carte (remove card)", effects: [.removeCard]),
                MayaEventOption(text: "Offrande (-30 gold, upgrade carte)", effects: [.loseGold(30), .upgradeCard]),
                MayaEventOption(text: "Se reposer (heal 6 HP)", effects: [.gainHP(6)])
            ]
        ),
        MayaEvent(
            title: "Masque de Jade",
            description: "Un masque ancien repose sur un piédestal.",
            options: [
                MayaEventOption(text: "Prendre le masque (gain relique)", effects: [.gainRelic]),
                MayaEventOption(text: "Offrande (-6 HP, gain 60 gold)", effects: [.loseHP(6), .gainGold(60)]),
                MayaEventOption(text: "Ne rien toucher", effects: [])
            ]
        ),
        MayaEvent(
            title: "Ancien Squelette",
            description: "Un squelette tient un poignard d'obsidienne.",
            options: [
                MayaEventOption(text: "Prendre l'arme (gain carte)", effects: [.gainCard(rarity: nil)]),
                MayaEventOption(text: "Fouiller les restes (+40 gold)", effects: [.gainGold(40)]),
                MayaEventOption(text: "Prier l'esprit (heal 5 HP)", effects: [.gainHP(5)])
            ]
        ),
        MayaEvent(
            title: "Éclipse",
            description: "Une éclipse plonge le temple dans l'ombre.",
            options: [
                MayaEventOption(text: "Offrir du sang (-7 HP, relique)", effects: [.loseHP(7), .gainRelic]),
                MayaEventOption(text: "Canaliser l'énergie (upgrade carte)", effects: [.upgradeCard]),
                MayaEventOption(text: "Se cacher (heal 4 HP)", effects: [.gainHP(4)])
            ]
        )
    ]
}

enum MayaRelicPool {
    static let all: [Relic] = [
        Relic(
            relicID: .pakalFuneraryMask,
            name: "Masque funéraire de Pakal",
            description: "Masque de jade enterré avec le roi Pakal de Palenque.",
            effect: "Lorsque votre vie tombe sous 50 %, gagnez +2 pouvoir pendant 2 tours.",
            rarity: .rare,
            image: "relic_placeholder"
        ),
        Relic(
            relicID: .sacredCodex,
            name: "Codex sacré",
            description: "Un ancien manuscrit maya contenant des prophéties et des rituels.",
            effect: "Après un événement, choisissez entre 3 cartes au lieu de 2.",
            rarity: .rare,
            image: "relic_placeholder"
        ),
        Relic(
            relicID: .palenqueRoyalJade,
            name: "Jade royal de Palenque",
            description: "Un bijou porté par les rois mayas, symbole de vie et de pouvoir.",
            effect: "+1 énergie au début du combat.",
            rarity: .rare,
            image: "relic_placeholder"
        ),
        Relic(
            relicID: .tzolkinCalendar,
            name: "Calendrier Tzolk’in",
            description: "Le calendrier sacré de 260 jours utilisé par les prêtres mayas.",
            effect: "Tous les 3 tours, gagnez +2 énergie.",
            rarity: .legendary,
            image: "relic_placeholder"
        ),
        Relic(
            relicID: .quetzalFeather,
            name: "Plume de Quetzal",
            description: "Plume sacrée de l’oiseau quetzal, symbole de royauté.",
            effect: "+2 esquive au début du combat.",
            rarity: .common,
            image: "relic_placeholder"
        ),
        Relic(
            relicID: .ceremonialDrum,
            name: "Tambour cérémoniel",
            description: "Tambour utilisé lors des cérémonies et rituels religieux.",
            effect: "Les invocations ou alliés gagnent +1 attaque.",
            rarity: .common,
            image: "relic_placeholder"
        ),
        Relic(
            relicID: .jadeSerpent,
            name: "Serpent de jade",
            description: "Amulette représentant Kukulcan, le serpent à plumes.",
            effect: "Toutes les 3 attaques infligent +4 dégâts bonus.",
            rarity: .legendary,
            image: "relic_placeholder"
        ),
        Relic(
            relicID: .obsidianOffering,
            name: "Offrande d’obsidienne",
            description: "Fragment d’obsidienne utilisé dans les offrandes aux dieux.",
            effect: "Chaque ennemi vaincu donne +2 or supplémentaire.",
            rarity: .common,
            image: "relic_placeholder"
        ),
        Relic(
            relicID: .sunStone,
            name: "Pierre solaire",
            description: "Pierre gravée représentant le pouvoir du soleil.",
            effect: "Au début du combat, inflige 3 dégâts à tous les ennemis.",
            rarity: .rare,
            image: "relic_placeholder"
        )
    ]
}
