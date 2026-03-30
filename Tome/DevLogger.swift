import Foundation
import Combine

class DevLogger: ObservableObject {
    static let shared = DevLogger()
    @Published var entries: [String] = []

    private let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        return f
    }()

    func log(_ message: String) {
        let entry = "[\(formatter.string(from: Date()))] \(message)"
        NSLog("TomeApp: %@", message)
        DispatchQueue.main.async {
            self.entries.append(entry)
            if self.entries.count > 300 { self.entries.removeFirst() }
        }
    }

    func clear() {
        entries = []
    }
}

func devLog(_ message: String) {
    guard AppState.shared.developerMode else { return }
    DevLogger.shared.log(message)
}
