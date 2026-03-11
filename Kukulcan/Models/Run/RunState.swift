import Foundation

enum RunStatus: String, Codable {
    case notStarted
    case onMap
    case inBattle
    case choosingReward
    case victory
    case gameOver
}

struct RunState: Codable {
    var status: RunStatus
    var player: PlayerRunState
    var nodes: [MapNode]
    var currentNodeID: UUID?
    var currentAct: Int
    var totalActs: Int
    var bossesDefeated: Int
    var totalBosses: Int

    var isFinished: Bool {
        status == .victory || status == .gameOver
    }
}
