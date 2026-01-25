import Foundation
import Combine

class ScheduleManager: ObservableObject {
    static let shared = ScheduleManager()

    @Published var schedules: [ScheduleBlock] = []

    private var timer: Timer?
    private let appState = AppState.shared
    private let hostsManager = HostsFileManager.shared
    private let blocklistManager = BlocklistManager.shared

    private let storageURL: URL = {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("Tome")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("schedules.json")
    }()

    private init() {
        load()
        startTimer()
        evaluate()
    }

    func load() {
        guard let data = try? Data(contentsOf: storageURL),
              let decoded = try? JSONDecoder().decode([ScheduleBlock].self, from: data) else { return }
        schedules = decoded
    }

    func save() {
        guard let data = try? JSONEncoder().encode(schedules) else { return }
        try? data.write(to: storageURL)
    }

    func add(_ schedule: ScheduleBlock) {
        schedules.append(schedule)
        save()
        evaluate()
    }

    func update(_ schedule: ScheduleBlock) {
        if let idx = schedules.firstIndex(where: { $0.id == schedule.id }) {
            schedules[idx] = schedule
            save()
            evaluate()
        }
    }

    func delete(id: UUID) {
        schedules.removeAll { $0.id == id }
        save()
        evaluate()
    }

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.evaluate()
        }
        RunLoop.main.add(timer!, forMode: .common)
    }

    func evaluate() {
        guard !appState.isPaused else { return }

        let now = Date()
        let active = schedules.filter { $0.isActive(at: now) }
        let wasBlocking = appState.isBlocking

        DispatchQueue.main.async {
            self.appState.activeSchedules = active
        }

        if active.isEmpty {
            if wasBlocking {
                applyBlock(domains: [])
            }
        } else {
            let allIDs = active.reduce(Set<UUID>()) { $0.union($1.blocklistIDs) }
            let domains = blocklistManager.domains(for: allIDs)
            applyBlock(domains: domains)
        }
    }

    private func applyBlock(domains: [String]) {
        let shouldBlock = !domains.isEmpty
        hostsManager.sendCommand(IPCCommand(
            action: shouldBlock ? .block : .unblock,
            domains: domains
        ))
        DispatchQueue.main.async {
            self.appState.isBlocking = shouldBlock
        }
    }

    // Called when a pause ends — re-evaluates immediately
    func resumeAfterPause() {
        evaluate()
    }
}
