import Foundation

// Shared directory used for app <-> helper communication
let tomeSharedDir = "/Library/Application Support/Tome"
let tomeCommandFile = "/Library/Application Support/Tome/command.json"
let tomeStateFile = "/Library/Application Support/Tome/state.json"

enum IPCAction: String, Codable {
    case block
    case unblock
    case setLockedMode
    case ping
}

struct IPCCommand: Codable {
    var action: IPCAction
    var domains: [String]?
    var lockedMode: Bool?
    var appBundlePath: String?
    var timestamp: Date

    init(action: IPCAction, domains: [String]? = nil, lockedMode: Bool? = nil, appBundlePath: String? = nil) {
        self.action = action
        self.domains = domains
        self.lockedMode = lockedMode
        self.appBundlePath = appBundlePath
        self.timestamp = Date()
    }
}

struct IPCState: Codable {
    var isBlocking: Bool
    var blockedDomains: [String]
    var lockedMode: Bool
    var helperPID: Int32
    var lastUpdated: Date

    init(isBlocking: Bool = false, blockedDomains: [String] = [], lockedMode: Bool = false, helperPID: Int32 = 0) {
        self.isBlocking = isBlocking
        self.blockedDomains = blockedDomains
        self.lockedMode = lockedMode
        self.helperPID = helperPID
        self.lastUpdated = Date()
    }
}
