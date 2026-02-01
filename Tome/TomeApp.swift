import SwiftUI
import AppKit

@main
struct TomeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            PreferencesView()
                .environmentObject(AppState.shared)
                .environmentObject(BlocklistManager.shared)
                .environmentObject(ScheduleManager.shared)
        }
    }
}
