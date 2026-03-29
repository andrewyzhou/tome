import Foundation

class PFManager {
    private let anchorName = "tome"
    private let tableName = "tome_blocked"
    private let pfConf = "/etc/pf.conf"

    /// Call once at startup (runs as root) to ensure anchor is wired in and pf is enabled.
    func setup() {
        // Add anchor line to pf.conf if missing
        let anchorLine = "anchor \"tome\""
        if let existing = try? String(contentsOfFile: pfConf, encoding: .utf8),
           !existing.contains(anchorLine) {
            let updated = existing.hasSuffix("\n") ? existing + anchorLine + "\n"
                                                   : existing + "\n" + anchorLine + "\n"
            try? updated.write(toFile: pfConf, atomically: true, encoding: .utf8)
            log("PF: added anchor to \(pfConf)")
        }

        // Enable pf (idempotent)
        run("/sbin/pfctl", ["-e"])

        // Reload pf.conf so the anchor is live
        run("/sbin/pfctl", ["-f", pfConf])

        log("PF: setup complete")
    }

    func applyBlock(domains: [String]) {
        guard !domains.isEmpty else {
            removeAllBlocks()
            return
        }

        // Resolve IPs for each domain + www. variant
        var ips: Set<String> = []
        let allDomains = domains.flatMap { d -> [String] in
            d.hasPrefix("www.") ? [d] : [d, "www." + d]
        }
        for domain in allDomains {
            for ip in resolveIPs(for: domain) {
                ips.insert(ip)
            }
        }

        guard !ips.isEmpty else {
            log("PF: no IPs resolved for \(domains.count) domain(s), skipping")
            return
        }

        let tableEntries = ips.sorted().joined(separator: ", ")
        let rules = """
        table <\(tableName)> { \(tableEntries) }
        block drop out quick to <\(tableName)>
        block drop in quick from <\(tableName)>
        """

        loadRules(rules)
        killExistingStates(ips: ips)
        log("PF: loaded \(ips.count) IP(s) for \(domains.count) domain(s)")
    }

    func removeAllBlocks() {
        flushAnchor()
        log("PF: anchor flushed")
    }

    // MARK: - Private

    private func resolveIPs(for hostname: String) -> [String] {
        var hints = addrinfo()
        hints.ai_family = AF_UNSPEC
        hints.ai_socktype = SOCK_STREAM
        hints.ai_flags = AI_ADDRCONFIG

        var res: UnsafeMutablePointer<addrinfo>? = nil
        guard getaddrinfo(hostname, nil, &hints, &res) == 0, let res = res else { return [] }
        defer { freeaddrinfo(res) }

        var ips: [String] = []
        var ptr: UnsafeMutablePointer<addrinfo>? = res
        while let current = ptr {
            var hostBuf = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            if getnameinfo(current.pointee.ai_addr, current.pointee.ai_addrlen,
                           &hostBuf, socklen_t(NI_MAXHOST),
                           nil, 0, NI_NUMERICHOST) == 0 {
                let ip = String(cString: hostBuf)
                // skip loopback and link-local
                if ip != "127.0.0.1" && ip != "::1" && !ip.hasPrefix("fe80:") {
                    ips.append(ip)
                }
            }
            ptr = current.pointee.ai_next
        }
        return ips
    }

    /// Send TCP RSTs for all existing pf state entries involving these IPs.
    private func killExistingStates(ips: Set<String>) {
        for ip in ips {
            run("/sbin/pfctl", ["-k", ip])
        }
    }

    /// Fire-and-forget process helper (suppresses stdout/stderr).
    @discardableResult
    private func run(_ executable: String, _ args: [String]) -> Int32 {
        let task = Process()
        task.launchPath = executable
        task.arguments = args
        let devNull = Pipe()
        task.standardOutput = devNull
        task.standardError = devNull
        try? task.run()
        task.waitUntilExit()
        return task.terminationStatus
    }

    private func loadRules(_ rules: String) {
        let task = Process()
        task.launchPath = "/sbin/pfctl"
        task.arguments = ["-a", anchorName, "-f", "-"]

        let inputPipe = Pipe()
        let devNull = Pipe()
        task.standardInput = inputPipe
        task.standardOutput = devNull
        task.standardError = devNull

        do {
            try task.run()
        } catch {
            log("PF ERROR: failed to launch pfctl: \(error)")
            return
        }

        inputPipe.fileHandleForWriting.write(rules.data(using: .utf8)!)
        inputPipe.fileHandleForWriting.closeFile()
        task.waitUntilExit()

        if task.terminationStatus != 0 {
            log("PF WARN: pfctl exited with status \(task.terminationStatus)")
        }
    }

    private func flushAnchor() {
        run("/sbin/pfctl", ["-a", anchorName, "-F", "all"])
    }
}
