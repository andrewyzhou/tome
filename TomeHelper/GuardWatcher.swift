import Foundation

class GuardWatcher {
    private var lockedMode: Bool = false
    private var appBundlePath: String = "/Applications/Tome.app"
    private var timer: Timer?

    func setLockedMode(_ enabled: Bool, appBundlePath: String?) {
        self.lockedMode = enabled
        if let path = appBundlePath { self.appBundlePath = path }
        if enabled && timer == nil {
            startWatching()
        } else if !enabled {
            stopWatching()
        }
    }

    private func startWatching() {
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.check()
        }
        RunLoop.main.add(timer!, forMode: .common)
    }

    private func stopWatching() {
        timer?.invalidate()
        timer = nil
    }

    private func check() {
        guard lockedMode else { return }
        guard !isTomeRunning() else { return }
        relaunchTome()
    }

    private func isTomeRunning() -> Bool {
        let task = Process()
        task.launchPath = "/bin/pgrep"
        task.arguments = ["-f", "Tome.app/Contents/MacOS/Tome"]
        let pipe = Pipe()
        task.standardOutput = pipe
        try? task.run()
        task.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return !output.isEmpty
    }

    private func relaunchTome() {
        log("Tome not running in locked mode — relaunching from \(appBundlePath)")

        // get the current console user to open as them (not root)
        let user = consoleUser() ?? "andrewzhou"
        let task = Process()
        task.launchPath = "/usr/bin/sudo"
        task.arguments = ["-u", user, "/usr/bin/open", "-a", appBundlePath]
        try? task.run()
    }

    private func consoleUser() -> String? {
        let task = Process()
        task.launchPath = "/usr/bin/stat"
        task.arguments = ["-f", "%Su", "/dev/console"]
        let pipe = Pipe()
        task.standardOutput = pipe
        try? task.run()
        task.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let user = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
        return user?.isEmpty == false ? user : nil
    }
}

func log(_ message: String) {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
    let timestamp = formatter.string(from: Date())
    let line = "\(timestamp) \(message)\n"
    let logPath = "/var/log/tome-helper.log"
    if let data = line.data(using: .utf8),
       let handle = FileHandle(forWritingAtPath: logPath) {
        handle.seekToEndOfFile()
        handle.write(data)
        handle.closeFile()
    } else {
        try? line.data(using: .utf8)?.write(to: URL(fileURLWithPath: logPath), options: .atomic)
    }
}
