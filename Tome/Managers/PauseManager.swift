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

    func urgentPause() {
        guard appState.isActivelyBlocking,
              !appState.pauseRequestActive,
              !appState.pendingPauseConfirmation else { return }
        appState.pendingPauseConfirmation = true
    }

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
            self.appState.pendingPauseConfirmation = false
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
                self.appState.pendingPauseConfirmation = true
            }
        }
    }

    var countdownSecondsRemaining: Int {
        guard let endsAt = appState.pauseRequestEndsAt else { return 0 }
        return max(0, Int(endsAt.timeIntervalSinceNow))
    }

    // MARK: - Confirmed Pause (1-15 min break)

    func confirmPause(minutes: Int) {
        let endsAt = Date().addingTimeInterval(TimeInterval(minutes * 60))
        // set isPaused synchronously FIRST so evaluate() cannot re-apply blocks
        appState.pendingPauseConfirmation = false
        appState.isPaused = true
        appState.pauseEndsAt = endsAt
        appState.isBlocking = false
        hostsManager.removeAllBlocks()
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
        // set state synchronously before resumeAfterPause so evaluate() sees isPaused = false
        appState.isPaused = false
        appState.pauseEndsAt = nil
        scheduleManager.resumeAfterPause()
    }

    var breakSecondsRemaining: Int {
        guard let endsAt = appState.pauseEndsAt else { return 0 }
        return max(0, Int(endsAt.timeIntervalSinceNow))
    }
}

extension Notification.Name {
    static let tomeOpenPauseWindow = Notification.Name("tomeOpenPauseWindow")
}
