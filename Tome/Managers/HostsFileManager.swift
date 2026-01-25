import Foundation

class HostsFileManager {
    static let shared = HostsFileManager()

    private let commandFile = URL(fileURLWithPath: tomeCommandFile)
    private let encoder = JSONEncoder()

    private init() {
        encoder.dateEncodingStrategy = .iso8601
    }

    func sendCommand(_ command: IPCCommand) {
        guard let data = try? encoder.encode(command) else { return }
        try? data.write(to: commandFile, options: .atomic)
    }

    func removeAllBlocks() {
        sendCommand(IPCCommand(action: .unblock))
    }

    func setLockedMode(_ enabled: Bool) {
        let bundlePath = Bundle.main.bundlePath
        sendCommand(IPCCommand(action: .setLockedMode, lockedMode: enabled, appBundlePath: bundlePath))
    }
}
