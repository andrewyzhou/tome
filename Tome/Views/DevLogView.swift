import SwiftUI
import AppKit

struct DevLogView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject private var logger = DevLogger.shared
    private let tabKiller = TabKiller()

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // State snapshot
            GroupBox("Current State") {
                VStack(alignment: .leading, spacing: 4) {
                    row("isBlocking", "\(appState.isBlocking)")
                    row("isPaused", "\(appState.isPaused)")
                    row("activeSchedules", "\(appState.activeSchedules.count)")
                    row("blockedDomains", blockedDomains().joined(separator: ", ").isEmpty ? "(none)" : blockedDomains().joined(separator: ", "))
                }
                .font(.system(.caption, design: .monospaced))
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            // Action buttons
            HStack(spacing: 8) {
                Button("Run Tab Killer Now") {
                    let domains = blockedDomains()
                    devLog("Manual tab killer trigger: domains=\(domains)")
                    if domains.isEmpty {
                        devLog("Manual trigger: no domains to block")
                    } else {
                        tabKiller.closeBlockedTabs(domains: domains)
                    }
                }
                .controlSize(.small)

                Button("Kill youtube.com") {
                    devLog("Manual youtube kill triggered")
                    tabKiller.closeBlockedTabs(domains: ["youtube.com"])
                }
                .controlSize(.small)

                Spacer()

                Button("Clear") { logger.clear() }
                    .controlSize(.small)

                Button("Copy") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(logger.entries.joined(separator: "\n"), forType: .string)
                }
                .controlSize(.small)
            }

            // Log entries
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        ForEach(Array(logger.entries.enumerated()), id: \.offset) { idx, entry in
                            Text(entry)
                                .font(.system(size: 10, design: .monospaced))
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .id(idx)
                        }
                    }
                    .padding(6)
                }
                .background(Color(NSColor.textBackgroundColor))
                .cornerRadius(6)
                .onChange(of: logger.entries.count) { _ in
                    if let last = logger.entries.indices.last {
                        proxy.scrollTo(last, anchor: .bottom)
                    }
                }
            }
        }
        .padding(12)
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(label + ":").foregroundColor(.secondary).frame(width: 110, alignment: .leading)
            Text(value)
        }
    }

    private func blockedDomains() -> [String] {
        let ids = appState.activeSchedules.reduce(Set<UUID>()) { $0.union($1.blocklistIDs) }
        return BlocklistManager.shared.domains(for: ids)
    }
}
