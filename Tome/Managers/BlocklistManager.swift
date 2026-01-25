import Foundation

class BlocklistManager: ObservableObject {
    static let shared = BlocklistManager()

    @Published var blocklists: [Blocklist] = []

    private let storageURL: URL = {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("Tome")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("blocklists.json")
    }()

    private init() {
        load()
    }

    func load() {
        guard let data = try? Data(contentsOf: storageURL),
              let decoded = try? JSONDecoder().decode([Blocklist].self, from: data) else { return }
        blocklists = decoded
    }

    func save() {
        guard let data = try? JSONEncoder().encode(blocklists) else { return }
        try? data.write(to: storageURL)
    }

    func add(_ blocklist: Blocklist) {
        blocklists.append(blocklist)
        save()
    }

    func update(_ blocklist: Blocklist) {
        if let idx = blocklists.firstIndex(where: { $0.id == blocklist.id }) {
            blocklists[idx] = blocklist
            save()
        }
    }

    func delete(id: UUID) {
        blocklists.removeAll { $0.id == id }
        save()
    }

    func blocklist(for id: UUID) -> Blocklist? {
        blocklists.first { $0.id == id }
    }

    func domains(for ids: Set<UUID>) -> [String] {
        ids.compactMap { blocklist(for: $0) }.flatMap { $0.domains }
    }

    // MARK: - Import

    func importFromText(_ text: String, name: String) -> Blocklist {
        let domains = parseDomains(from: text)
        let list = Blocklist(name: name, domains: domains)
        add(list)
        return list
    }

    func importFromFile(url: URL, name: String) -> Blocklist? {
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return nil }
        return importFromText(text, name: name)
    }

    private func parseDomains(from text: String) -> [String] {
        var domains: [String] = []
        let lines = text.components(separatedBy: .newlines)

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            // skip empty lines and comments
            guard !trimmed.isEmpty, !trimmed.hasPrefix("#") else { continue }

            // handle /etc/hosts format: "0.0.0.0 domain.com" or "127.0.0.1 domain.com"
            let parts = trimmed.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
            if parts.count >= 2,
               let first = parts.first,
               (first == "0.0.0.0" || first == "127.0.0.1" || first == "::1") {
                let domain = parts[1]
                if isValidDomain(domain) { domains.append(domain) }
                continue
            }

            // handle uBlock Origin format: "||domain.com^"
            if trimmed.hasPrefix("||") {
                var domain = trimmed
                domain = String(domain.dropFirst(2))
                if let caretIdx = domain.firstIndex(of: "^") {
                    domain = String(domain[..<caretIdx])
                }
                if isValidDomain(domain) { domains.append(domain) }
                continue
            }

            // plain domain
            if isValidDomain(trimmed) {
                domains.append(trimmed)
            }
        }

        return Array(Set(domains)).sorted()
    }

    private func isValidDomain(_ s: String) -> Bool {
        guard !s.isEmpty, s.contains("."), !s.hasPrefix("."), !s.hasSuffix(".") else { return false }
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: ".-"))
        return s.unicodeScalars.allSatisfy { allowed.contains($0) }
    }
}
