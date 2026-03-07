import Foundation

struct Relic: Identifiable, Codable, Hashable {
    let id: UUID
    let name: String
    let effectDescription: String

    init(id: UUID = UUID(), name: String, effectDescription: String) {
        self.id = id
        self.name = name
        self.effectDescription = effectDescription
    }
}
