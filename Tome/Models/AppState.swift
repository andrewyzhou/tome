import Foundation
import Combine

class AppState: ObservableObject {
    static let shared = AppState()

    @Published var isBlocking: Bool = false
    @Published var activeSchedules: [ScheduleBlock] = []
    @Published var isPaused: Bool = false
    @Published var pauseEndsAt: Date? = nil
    @Published var lockedMode: Bool = false

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

    // pause window should be accessible whenever something is happening
    var pauseWindowEnabled: Bool {
        isBlocking || isPaused || pauseRequestActive || pendingPauseConfirmation
    }

    private init() {
        load()
    }

    private let lockedModeKey = "tomeLockedMode"

    func load() {
        lockedMode = UserDefaults.standard.bool(forKey: lockedModeKey)
    }

    func setLockedMode(_ enabled: Bool) {
        lockedMode = enabled
        UserDefaults.standard.set(enabled, forKey: lockedModeKey)
    }
}
