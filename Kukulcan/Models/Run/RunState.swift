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

    var isFinished: Bool {
        status == .victory || status == .gameOver
    }
}
