import Foundation
import Combine

class PauseManager: ObservableObject {
    static let shared = PauseManager()

    private let appState = AppState.shared
    private let scheduleManager = ScheduleManager.shared
    private let hostsManager = HostsFileManager.shared

    private var countdownTimer: Timer?
    private var breakTimer: Timer?

    private init() {}

    // MARK: - Pause Request (5-min countdown before confirmation)

    func requestPause() {
        guard appState.isActivelyBlocking, !appState.pauseRequestActive else { return }
        let endsAt = Date().addingTimeInterval(5 * 60)
        DispatchQueue.main.async {
            self.appState.pauseRequestActive = true
            self.appState.pauseRequestEndsAt = endsAt
        }
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.tickCountdown()
        }
        RunLoop.main.add(countdownTimer!, forMode: .common)
    }

    func cancelPauseRequest() {
        countdownTimer?.invalidate()
        countdownTimer = nil
        DispatchQueue.main.async {
            self.appState.pauseRequestActive = false
            self.appState.pauseRequestEndsAt = nil
        }
    }

    private func tickCountdown() {
        guard let endsAt = appState.pauseRequestEndsAt else { return }
        if Date() >= endsAt {
            countdownTimer?.invalidate()
            countdownTimer = nil
            DispatchQueue.main.async {
                self.appState.pauseRequestActive = false
                self.appState.pauseRequestEndsAt = nil
            }
            NotificationCenter.default.post(name: .tomeShowPauseConfirmation, object: nil)
        }
    }

    var countdownSecondsRemaining: Int {
        guard let endsAt = appState.pauseRequestEndsAt else { return 0 }
        return max(0, Int(endsAt.timeIntervalSinceNow))
    }

    // MARK: - Confirmed Pause (1-15 min break)

    func confirmPause(minutes: Int) {
        let duration = TimeInterval(minutes * 60)
        let endsAt = Date().addingTimeInterval(duration)

        // remove blocks while paused
        hostsManager.removeAllBlocks()

        DispatchQueue.main.async {
            self.appState.isPaused = true
            self.appState.pauseEndsAt = endsAt
            self.appState.isBlocking = false
        }

        breakTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.tickBreak()
        }
        RunLoop.main.add(breakTimer!, forMode: .common)
    }

    private func tickBreak() {
        guard let endsAt = appState.pauseEndsAt else { return }
        if Date() >= endsAt {
            endPause()
        }
    }

    func endPause() {
        breakTimer?.invalidate()
        breakTimer = nil
        DispatchQueue.main.async {
            self.appState.isPaused = false
            self.appState.pauseEndsAt = nil
        }
        scheduleManager.resumeAfterPause()
    }

    var breakSecondsRemaining: Int {
        guard let endsAt = appState.pauseEndsAt else { return 0 }
        return max(0, Int(endsAt.timeIntervalSinceNow))
    }
}

extension Notification.Name {
    static let tomeShowPauseConfirmation = Notification.Name("tomeShowPauseConfirmation")
}
