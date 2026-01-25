import Foundation

struct Blocklist: Identifiable, Codable, Hashable {
    var id: UUID
    var name: String
    var domains: [String]

    init(id: UUID = UUID(), name: String, domains: [String] = []) {
        self.id = id
        self.name = name
        self.domains = domains
    }
}
