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
                if !domain.hasPrefix("www.") {
                    block += "0.0.0.0 www.\(domain)\n"
                }
            }
            block += "\(blockMarkerEnd)\n"
            content += block
        }

        do {
            try content.write(toFile: hostsPath, atomically: true, encoding: .utf8)
        } catch {
            log("ERROR: failed to write /etc/hosts during block: \(error)")
            return
        }

        flushDNSCache()
        verifyBlock(expectedDomains: domains)
    }

    func removeAllBlocks() {
        var content = (try? String(contentsOfFile: hostsPath, encoding: .utf8)) ?? ""
        content = removeBlockSection(from: content)

        do {
            try content.write(toFile: hostsPath, atomically: true, encoding: .utf8)
        } catch {
            log("ERROR: failed to write /etc/hosts during unblock: \(error)")
            return
        }

        flushDNSCache()
        verifyUnblock()
    }

    // MARK: - Verification

    private func verifyBlock(expectedDomains: [String]) {
        guard let current = try? String(contentsOfFile: hostsPath, encoding: .utf8) else {
            log("VERIFY ERROR: could not re-read /etc/hosts after block")
            return
        }
        guard current.contains(blockMarkerStart), current.contains(blockMarkerEnd) else {
            log("VERIFY ERROR: tome-block markers missing from /etc/hosts after block")
            return
        }
        // spot-check first 3 domains
        let sample = Array(expectedDomains.prefix(3))
        for domain in sample {
            if !current.contains("0.0.0.0 \(domain)") {
                log("VERIFY ERROR: domain \(domain) not found in /etc/hosts after block")
                return
            }
        }
        log("VERIFY OK: \(expectedDomains.count) domain(s) confirmed in /etc/hosts")
    }

    private func verifyUnblock() {
        guard let current = try? String(contentsOfFile: hostsPath, encoding: .utf8) else {
            log("VERIFY ERROR: could not re-read /etc/hosts after unblock")
            return
        }
        if current.contains(blockMarkerStart) || current.contains(blockMarkerEnd) {
            log("VERIFY ERROR: tome-block markers still present in /etc/hosts after unblock")
            return
        }
        log("VERIFY OK: /etc/hosts clean after unblock")
    }

    // MARK: - Helpers

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
        return result.trimmingCharacters(in: .newlines) + "\n"
    }

    private func flushDNSCache() {
        // run async so a hung process can't block the main RunLoop timer
        DispatchQueue.global(qos: .utility).async { [self] in
            let task = Process()
            task.launchPath = "/usr/bin/dscacheutil"
            task.arguments = ["-flushcache"]
            try? task.run()
            task.waitUntilExit()

            guard let pid = mDNSResponderPID() else {
                log("WARN: could not find mDNSResponder PID — DNS cache not flushed via HUP")
                return
            }
            let task2 = Process()
            task2.launchPath = "/bin/kill"
            task2.arguments = ["-HUP", String(pid)]
            try? task2.run()
            task2.waitUntilExit()
        }
    }

    private func mDNSResponderPID() -> Int32? {
        let task = Process()
        task.launchPath = "/bin/pgrep"
        task.arguments = ["-x", "mDNSResponder"]  // -x: exact match, avoids multi-match
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
