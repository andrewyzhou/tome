import SwiftUI
import ServiceManagement

struct PreferencesView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var blocklistManager: BlocklistManager
    @EnvironmentObject var scheduleManager: ScheduleManager

    @State private var selectedTab = 0

    var body: some View {
        VStack(spacing: 0) {
            if appState.isActivelyBlocking {
                ActiveSessionBanner()
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
        .frame(width: 408, height: 468)
    }
}

struct ActiveSessionBanner: View {
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "lock.fill")
                .foregroundColor(.orange)
            Text("Read-only during an active block session.")
                .font(.callout)
                .foregroundColor(.primary)
            Spacer()
            Button("Pause...") {
                NotificationCenter.default.post(name: .tomeOpenPauseWindow, object: nil)
            }
            .controlSize(.small)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.orange.opacity(0.12))
    }
}

struct SettingsTabView: View {
    @EnvironmentObject var appState: AppState
    private let hostsManager = HostsFileManager.shared

    @State private var isOpenAtLogin = false

    var body: some View {
        Form {
            Section {
                Toggle("Open at login", isOn: $isOpenAtLogin)
                    .onChange(of: isOpenAtLogin) { enabled in
                        do {
                            if enabled { try SMAppService.mainApp.register() }
                            else { try SMAppService.mainApp.unregister() }
                        } catch {
                            print("SMAppService error: \(error)")
                        }
                    }
            } header: {
                Text("General")
            }

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
        .onAppear {
            isOpenAtLogin = SMAppService.mainApp.status == .enabled
        }
    }
}
