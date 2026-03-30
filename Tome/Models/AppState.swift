import Foundation
import Combine

class AppState: ObservableObject {
    static let shared = AppState()

    @Published var isBlocking: Bool = false
    @Published var activeSchedules: [ScheduleBlock] = []
    @Published var isPaused: Bool = false
    @Published var pauseEndsAt: Date? = nil
    @Published var lockedMode: Bool = false
    @Published var urgentPausesDisabled: Bool = false
    @Published var developerMode: Bool = false

    // pause request countdown (5 min before confirmation)
    @Published var pauseRequestActive: Bool = false
    @Published var pauseRequestEndsAt: Date? = nil

    // countdown expired — waiting for user to confirm duration
    @Published var pendingPauseConfirmation: Bool = false

    var isActivelyBlocking: Bool {
        isBlocking && !isPaused
    }

    var canEditPreferences: Bool {
        !isActivelyBlocking
    }

    var canToggleLockedMode: Bool {
        !isActivelyBlocking
    }

    var canToggleUrgentPausesDisabled: Bool {
        !isActivelyBlocking
    }

    // pause window should be accessible whenever something is happening
    var pauseWindowEnabled: Bool {
        isBlocking || isPaused || pauseRequestActive || pendingPauseConfirmation
    }

    private init() {
        load()
    }

    private let lockedModeKey = "tomeLockedMode"
    private let urgentPausesDisabledKey = "tomeUrgentPausesDisabled"
    private let developerModeKey = "tomeDeveloperMode"

    func load() {
        lockedMode = UserDefaults.standard.bool(forKey: lockedModeKey)
        urgentPausesDisabled = UserDefaults.standard.bool(forKey: urgentPausesDisabledKey)
        developerMode = UserDefaults.standard.bool(forKey: developerModeKey)
    }

    func setDeveloperMode(_ enabled: Bool) {
        developerMode = enabled
        UserDefaults.standard.set(enabled, forKey: developerModeKey)
        if !enabled { DevLogger.shared.clear() }
    }

    func setLockedMode(_ enabled: Bool) {
        lockedMode = enabled
        UserDefaults.standard.set(enabled, forKey: lockedModeKey)
    }

    func setUrgentPausesDisabled(_ disabled: Bool) {
        urgentPausesDisabled = disabled
        UserDefaults.standard.set(disabled, forKey: urgentPausesDisabledKey)
    }
}
