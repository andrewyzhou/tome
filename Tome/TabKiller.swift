import Foundation
import AppKit

class TabKiller {

    private let queue = DispatchQueue(label: "com.andrewzhou.tome.tabkiller", qos: .utility)
    private var isRunning = false

    func closeBlockedTabs(domains: [String]) {
        guard !domains.isEmpty else { devLog("TabKiller: skipped — no domains"); return }
        guard !isRunning else { devLog("TabKiller: skipped — previous run still active"); return }

        var patterns: [String] = []
        for d in domains {
            patterns.append(d)
            if !d.hasPrefix("www.") { patterns.append("www." + d) }
        }

        let patternList = patterns
            .map { "\"\(escapeAppleScript($0))\"" }
            .joined(separator: ", ")

        let script = buildScript(patternList: patternList)
        isRunning = true
        devLog("TabKiller: running for domains: \(patterns.prefix(5).joined(separator: ", "))")

        queue.async { [weak self] in
            let task = Process()
            task.launchPath = "/usr/bin/osascript"
            task.arguments = ["-e", script]

            let outPipe = Pipe()
            let errPipe = Pipe()
            task.standardOutput = outPipe
            task.standardError = errPipe

            do {
                try task.run()
                task.waitUntilExit()
                let stdout = String(data: outPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                let stderr = String(data: errPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                if task.terminationStatus != 0 {
                    devLog("TabKiller: osascript exit=\(task.terminationStatus) stderr=\(stderr)")
                } else {
                    devLog("TabKiller: result=\(stdout)")
                }
            } catch {
                devLog("TabKiller: failed to launch osascript: \(error)")
            }
            DispatchQueue.main.async { self?.isRunning = false }
        }
    }

    // MARK: - Private

    private func escapeAppleScript(_ s: String) -> String {
        s.replacingOccurrences(of: "\\", with: "\\\\")
         .replacingOccurrences(of: "\"", with: "\\\"")
    }

    private func buildScript(patternList: String) -> String {
        """
        set blockedPatterns to {\(patternList)}
        set report to ""

        -- Google Chrome: iterate backwards by index so deletion doesn't corrupt the list
        try
            if application "Google Chrome" is running then
                tell application "Google Chrome"
                    set wCount to count of windows
                    set killed to 0
                    repeat with wIdx from 1 to wCount
                        set tCount to count of tabs of window wIdx
                        repeat with tIdx from tCount to 1 by -1
                            set u to URL of tab tIdx of window wIdx
                            repeat with p in blockedPatterns
                                if u contains p then
                                    delete tab tIdx of window wIdx
                                    set killed to killed + 1
                                    exit repeat
                                end if
                            end repeat
                        end repeat
                    end repeat
                    set report to "chrome:" & killed
                end tell
            else
                set report to "chrome:not_running"
            end if
        on error errMsg number errNum
            set report to "chrome:error(" & errNum & ")" & errMsg
        end try

        -- Safari: same backwards-index approach
        try
            if application "Safari" is running then
                tell application "Safari"
                    set wCount to count of windows
                    set killed to 0
                    repeat with wIdx from 1 to wCount
                        set tCount to count of tabs of window wIdx
                        repeat with tIdx from tCount to 1 by -1
                            set u to URL of tab tIdx of window wIdx
                            repeat with p in blockedPatterns
                                if u contains p then
                                    close tab tIdx of window wIdx
                                    set killed to killed + 1
                                    exit repeat
                                end if
                            end repeat
                        end repeat
                    end repeat
                    set report to report & " safari:" & killed
                end tell
            else
                set report to report & " safari:not_running"
            end if
        on error errMsg number errNum
            set report to report & " safari:error(" & errNum & ")" & errMsg
        end try

        return report
        """
    }
}
