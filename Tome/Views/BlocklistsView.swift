import SwiftUI
import UniformTypeIdentifiers

struct BlocklistsView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var blocklistManager: BlocklistManager

    @State private var selectedID: UUID? = nil
    @State private var isAdding = false
    @State private var showImportPanel = false
    @State private var importError: String? = nil

    private var isLocked: Bool { appState.isActivelyBlocking }

    var body: some View {
        HSplitView {
            // Sidebar: list of blocklists
            VStack(spacing: 0) {
                List(selection: $selectedID) {
                    ForEach(blocklistManager.blocklists) { list in
                        HStack {
                            Text(list.name)
                            Spacer()
                            Text("\(list.domains.count)")
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                        .tag(list.id)
                    }
                }

                Divider()

                HStack(spacing: 0) {
                    Button(action: addBlocklist) {
                        Image(systemName: "plus")
                            .frame(width: 28, height: 24)
                    }
                    .buttonStyle(.plain)
                    .disabled(isLocked)
                    .help("Add blocklist")

                    Button(action: deleteSelected) {
                        Image(systemName: "minus")
                            .frame(width: 28, height: 24)
                    }
                    .buttonStyle(.plain)
                    .disabled(isLocked || selectedID == nil)
                    .help("Delete selected blocklist")

                    Spacer()

                    Button(action: { showImportPanel = true }) {
                        Image(systemName: "square.and.arrow.down")
                            .frame(width: 28, height: 24)
                    }
                    .buttonStyle(.plain)
                    .disabled(isLocked)
                    .help("Import from file")
                }
                .padding(.horizontal, 4)
                .frame(height: 28)
                .background(Color(NSColor.controlBackgroundColor))
            }
            .frame(minWidth: 180, maxWidth: 220)

            // Detail: domain editor
            if let id = selectedID, let idx = blocklistManager.blocklists.firstIndex(where: { $0.id == id }) {
                BlocklistDetailView(blocklist: $blocklistManager.blocklists[idx], isLocked: isLocked)
                    .id(id)
                    .onDisappear { blocklistManager.save() }
            } else {
                Color.clear
                    .overlay(
                        Text("Select a blocklist")
                            .foregroundColor(.secondary)
                    )
            }
        }
        .sheet(isPresented: $isAdding) {
            NewBlocklistSheet { name in
                let list = Blocklist(name: name)
                blocklistManager.add(list)
                selectedID = list.id
            }
            .environmentObject(blocklistManager)
        }
        .fileImporter(
            isPresented: $showImportPanel,
            allowedContentTypes: [.text, .plainText],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                let name = url.deletingPathExtension().lastPathComponent
                _ = blocklistManager.importFromFile(url: url, name: name)
            case .failure(let err):
                importError = err.localizedDescription
            }
        }
        .alert("Import failed", isPresented: Binding(get: { importError != nil }, set: { if !$0 { importError = nil } })) {
            Button("OK") { importError = nil }
        } message: {
            Text(importError ?? "")
        }
        .overlay(isLocked ? lockedBanner : nil, alignment: .top)
    }

    private var lockedBanner: some View {
        HStack {
            Image(systemName: "lock.fill")
            Text("Preferences are read-only during an active block session.")
                .font(.caption)
        }
        .padding(8)
        .background(Color.orange.opacity(0.15))
        .cornerRadius(6)
        .padding(.top, 8)
    }

    private func addBlocklist() {
        isAdding = true
    }

    private func deleteSelected() {
        guard let id = selectedID else { return }
        blocklistManager.delete(id: id)
        selectedID = nil
    }
}

struct BlocklistDetailView: View {
    @Binding var blocklist: Blocklist
    let isLocked: Bool

    @State private var domainsText: String = ""
    @State private var isDirty = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                TextField("Blocklist name", text: $blocklist.name)
                    .textFieldStyle(.roundedBorder)
                    .disabled(isLocked)
                Spacer()
                Text("\(blocklist.domains.count) domains")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
            .padding(12)

            Divider()

            TextEditor(text: $domainsText)
                .font(.system(.body, design: .monospaced))
                .disabled(isLocked)
                .onChange(of: domainsText) { _ in isDirty = true }

            if isDirty {
                HStack {
                    Spacer()
                    Button("Apply") { applyEdits() }
                        .buttonStyle(.borderedProminent)
                        .padding(8)
                }
            }
        }
        .onAppear {
            domainsText = blocklist.domains.joined(separator: "\n")
        }
        .onChange(of: blocklist.id) { _ in
            domainsText = blocklist.domains.joined(separator: "\n")
            isDirty = false
        }
    }

    private func applyEdits() {
        let parsed = domainsText
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !$0.hasPrefix("#") }
        blocklist.domains = Array(Set(parsed)).sorted()
        isDirty = false
    }
}

struct NewBlocklistSheet: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var blocklistManager: BlocklistManager
    @State private var name = ""
    let onCreate: (String) -> Void

    private var isDuplicate: Bool {
        blocklistManager.blocklists.contains { $0.name.lowercased() == name.lowercased() }
    }

    var body: some View {
        VStack(spacing: 16) {
            Text("New Blocklist")
                .font(.headline)

            VStack(alignment: .leading, spacing: 4) {
                TextField("Name", text: $name)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 240)
                if isDuplicate {
                    Text("A blocklist with this name already exists.")
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }

            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.escape)
                Button("Create") {
                    onCreate(name.trimmingCharacters(in: .whitespaces))
                    dismiss()
                }
                .keyboardShortcut(.return)
                .buttonStyle(.borderedProminent)
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || isDuplicate)
            }
        }
        .padding(24)
        .frame(width: 300, height: 160)
    }
}
