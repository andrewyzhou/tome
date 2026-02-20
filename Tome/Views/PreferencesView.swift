import SwiftUI

struct PreferencesView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var blocklistManager: BlocklistManager
    @EnvironmentObject var scheduleManager: ScheduleManager

    @State private var selectedTab = 0

    var body: some View {
        VStack(spacing: 0) {
            if appState.isActivelyBlocking {
                ActiveSessionBanner()
                    .environmentObject(appState)
            }

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
        }
        .frame(width: 680, height: 520)
    }
}

struct ActiveSessionBanner: View {
    @EnvironmentObject var appState: AppState
    private let pauseManager = PauseManager.shared

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "lock.fill")
                .foregroundColor(.orange)
            Text("Preferences are read-only during an active block session.")
                .font(.callout)
                .foregroundColor(.primary)
            Spacer()
            if appState.pauseRequestActive {
                let remaining = pauseManager.countdownSecondsRemaining
                Text(String(format: "Pause in %d:%02d", remaining / 60, remaining % 60))
                    .font(.callout)
                    .foregroundColor(.secondary)
                Button("Cancel") { pauseManager.cancelPauseRequest() }
                    .controlSize(.small)
            } else {
                Button("Request pause...") { pauseManager.requestPause() }
                    .controlSize(.small)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.orange.opacity(0.12))
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
