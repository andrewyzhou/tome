import Foundation

class HostsEditor {
    private let hostsPath = "/etc/hosts"
    private let blockMarkerStart = "# tome-block-start"
    private let blockMarkerEnd = "# tome-block-end"

    func applyBlock(domains: [String]) {
        var content = (try? String(contentsOfFile: hostsPath, encoding: .utf8)) ?? ""
        content = removeBlockSection(from: content)

        if !domains.isEmpty {
            let unique = Array(Set(domains)).sorted()
            var block = "\n\(blockMarkerStart)\n"
            for domain in unique {
                block += "0.0.0.0 \(domain)\n"
                // also block www. variant if not already present
                if !domain.hasPrefix("www.") {
                    block += "0.0.0.0 www.\(domain)\n"
                }
            }
            block += "\(blockMarkerEnd)\n"
            content += block
        }

        try? content.write(toFile: hostsPath, atomically: true, encoding: .utf8)
        flushDNSCache()
    }

    func removeAllBlocks() {
        var content = (try? String(contentsOfFile: hostsPath, encoding: .utf8)) ?? ""
        content = removeBlockSection(from: content)
        try? content.write(toFile: hostsPath, atomically: true, encoding: .utf8)
        flushDNSCache()
    }

    private func removeBlockSection(from content: String) -> String {
        var result = ""
        var inBlock = false
        for line in content.components(separatedBy: "\n") {
            if line.trimmingCharacters(in: .whitespaces) == blockMarkerStart {
                inBlock = true
                continue
            }
            if line.trimmingCharacters(in: .whitespaces) == blockMarkerEnd {
                inBlock = false
                continue
            }
            if !inBlock {
                result += line + "\n"
            }
        }
        // trim trailing newlines added by section removal, preserve one
        return result.trimmingCharacters(in: .newlines) + "\n"
    }

    private func flushDNSCache() {
        let task = Process()
        task.launchPath = "/usr/bin/dscacheutil"
        task.arguments = ["-flushcache"]
        try? task.run()
        task.waitUntilExit()

        let task2 = Process()
        task2.launchPath = "/bin/kill"
        task2.arguments = ["-HUP", String(mDNSResponderPID() ?? 0)]
        try? task2.run()
        task2.waitUntilExit()
    }

    private func mDNSResponderPID() -> Int32? {
        let task = Process()
        task.launchPath = "/bin/pgrep"
        task.arguments = ["mDNSResponder"]
        let pipe = Pipe()
        task.standardOutput = pipe
        try? task.run()
        task.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let out = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
              let pid = Int32(out) else { return nil }
        return pid
    }
}
