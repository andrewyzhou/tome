import Foundation

// Ensure shared directory exists
let sharedDir = "/Library/Application Support/Tome"
try? FileManager.default.createDirectory(
    atPath: sharedDir,
    withIntermediateDirectories: true,
    attributes: [.posixPermissions: 0o777]
)

let hostsEditor = HostsEditor()
let pfManager = PFManager()
let guardWatcher = GuardWatcher()
let decoder = JSONDecoder()
decoder.dateDecodingStrategy = .iso8601

var lastCommandTimestamp: Date? = nil

log("TomeHelper started (PID \(ProcessInfo.processInfo.processIdentifier))")
pfManager.setup()

// Main loop
let timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
    processCommands()
}
RunLoop.main.add(timer, forMode: .common)
RunLoop.main.run()

func processCommands() {
    let commandPath = "/Library/Application Support/Tome/command.json"
    guard let data = try? Data(contentsOf: URL(fileURLWithPath: commandPath)),
          let command = try? decoder.decode(IPCCommand.self, from: data) else { return }

    // skip if we've already processed this command
    if let last = lastCommandTimestamp, command.timestamp <= last { return }
    lastCommandTimestamp = command.timestamp

    log("Processing command: \(command.action.rawValue)")

    switch command.action {
    case .block:
        let domains = command.domains ?? []
        hostsEditor.applyBlock(domains: domains)
        DispatchQueue.global(qos: .userInitiated).async {
            pfManager.applyBlock(domains: domains)
        }
        log("Blocked \(domains.count) domain(s)")

    case .unblock:
        hostsEditor.removeAllBlocks()
        DispatchQueue.global(qos: .userInitiated).async {
            pfManager.removeAllBlocks()
        }
        log("Removed all blocks")

    case .setLockedMode:
        let enabled = command.lockedMode ?? false
        guardWatcher.setLockedMode(enabled, appBundlePath: command.appBundlePath)
        log("Locked mode: \(enabled)")

    case .ping:
        break
    }
}
