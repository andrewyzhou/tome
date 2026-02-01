import SwiftUI

struct PreferencesView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var blocklistManager: BlocklistManager
    @EnvironmentObject var scheduleManager: ScheduleManager

    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            BlocklistsView()
                .environmentObject(appState)
                .environmentObject(blocklistManager)
                .tabItem { Label("Blocklists", systemImage: "list.bullet") }
                .tag(0)

            SchedulesView()
                .environmentObject(appState)
                .environmentObject(scheduleManager)
                .environmentObject(blocklistManager)
                .tabItem { Label("Schedules", systemImage: "calendar.badge.clock") }
                .tag(1)

            SettingsTabView()
                .environmentObject(appState)
                .tabItem { Label("Settings", systemImage: "gearshape") }
                .tag(2)
        }
        .frame(width: 680, height: 520)
    }
}

struct SettingsTabView: View {
    @EnvironmentObject var appState: AppState
    private let hostsManager = HostsFileManager.shared

    var body: some View {
        Form {
            Section {
                Toggle("Locked mode", isOn: Binding(
                    get: { appState.lockedMode },
                    set: { newVal in
                        appState.setLockedMode(newVal)
                        hostsManager.setLockedMode(newVal)
                    }
                ))
                .disabled(!appState.canToggleLockedMode)

                Text("When locked, Tome cannot be quit or killed while a schedule is active. Can only be disabled outside of block hours.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } header: {
                Text("Security")
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}
