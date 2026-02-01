import AppKit
import SwiftUI
import Combine

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var menu: NSMenu?
    private var cancellables = Set<AnyCancellable>()

    private let appState = AppState.shared
    private let pauseManager = PauseManager.shared
    private let hostsManager = HostsFileManager.shared
    private let scheduleManager = ScheduleManager.shared

    // windows
    private var prefsWindow: NSWindow?
    private var aboutWindow: NSWindow?
    private var pauseWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        setupStatusItem()
        setupObservers()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(showPauseConfirmation),
            name: .tomeShowPauseConfirmation,
            object: nil
        )
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if appState.lockedMode && appState.isActivelyBlocking {
            return .terminateCancel
        }
        hostsManager.removeAllBlocks()
        hostsManager.setLockedMode(false)
        return .terminateNow
    }

    // MARK: - Status Item

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        updateStatusIcon()
        statusItem?.button?.action = #selector(statusItemClicked)
        statusItem?.button?.target = self
        rebuildMenu()
    }

    private func updateStatusIcon() {
        guard let button = statusItem?.button else { return }
        let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .medium)
        if appState.isPaused {
            button.image = NSImage(systemSymbolName: "pause.circle", accessibilityDescription: "Tome paused")?.withSymbolConfiguration(config)
        } else if appState.isBlocking {
            button.image = NSImage(systemSymbolName: "book.closed.fill", accessibilityDescription: "Tome blocking")?.withSymbolConfiguration(config)
        } else {
            button.image = NSImage(systemSymbolName: "book.closed", accessibilityDescription: "Tome inactive")?.withSymbolConfiguration(config)
        }
    }

    @objc private func statusItemClicked() {
        rebuildMenu()
        statusItem?.button?.performClick(nil)
    }

    // MARK: - Menu

    private func rebuildMenu() {
        let m = NSMenu()

        // Status line
        let statusItem = NSMenuItem(title: statusTitle(), action: nil, keyEquivalent: "")
        statusItem.isEnabled = false
        m.addItem(statusItem)

        // Pause countdown line if active
        if appState.pauseRequestActive {
            let remaining = pauseManager.countdownSecondsRemaining
            let mins = remaining / 60
            let secs = remaining % 60
            let countdownItem = NSMenuItem(
                title: String(format: "Pause request: %d:%02d remaining", mins, secs),
                action: #selector(cancelPauseRequest),
                keyEquivalent: ""
            )
            countdownItem.target = self
            m.addItem(countdownItem)
        }

        m.addItem(.separator())

        // Pause / Cancel Pause / Resume
        if appState.isPaused {
            let breakRemaining = pauseManager.breakSecondsRemaining
            let mins = breakRemaining / 60
            let secs = breakRemaining % 60
            let resumeItem = NSMenuItem(
                title: String(format: "End break early (%d:%02d left)", mins, secs),
                action: #selector(endBreakEarly),
                keyEquivalent: ""
            )
            resumeItem.target = self
            m.addItem(resumeItem)
        } else if appState.isBlocking {
            if appState.pauseRequestActive {
                let cancelItem = NSMenuItem(title: "Cancel pause request", action: #selector(cancelPauseRequest), keyEquivalent: "")
                cancelItem.target = self
                m.addItem(cancelItem)
            } else {
                let pauseItem = NSMenuItem(title: "Request pause...", action: #selector(requestPause), keyEquivalent: "")
                pauseItem.target = self
                m.addItem(pauseItem)
            }
        }

        m.addItem(.separator())

        // Preferences
        let prefsItem = NSMenuItem(title: "Preferences...", action: #selector(openPreferences), keyEquivalent: ",")
        prefsItem.target = self
        m.addItem(prefsItem)

        // About
        let aboutItem = NSMenuItem(title: "About Tome", action: #selector(openAbout), keyEquivalent: "")
        aboutItem.target = self
        m.addItem(aboutItem)

        m.addItem(.separator())

        // Quit — disabled in locked mode during active blocking
        let quitItem = NSMenuItem(title: "Quit Tome", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        if appState.lockedMode && appState.isActivelyBlocking {
            quitItem.isEnabled = false
            quitItem.title = "Quit Tome (locked)"
        }
        m.addItem(quitItem)

        self.menu = m
        self.statusItem?.menu = m
    }

    private func statusTitle() -> String {
        if appState.isPaused {
            let mins = pauseManager.breakSecondsRemaining / 60
            let secs = pauseManager.breakSecondsRemaining % 60
            return String(format: "Paused — %d:%02d remaining", mins, secs)
        } else if appState.isBlocking {
            if let first = appState.activeSchedules.first {
                return "Blocking · \(first.name)"
            }
            return "Blocking"
        } else {
            return "Inactive"
        }
    }

    // MARK: - Observers

    private func setupObservers() {
        appState.$isBlocking
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.updateStatusIcon() }
            .store(in: &cancellables)

        appState.$isPaused
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.updateStatusIcon() }
            .store(in: &cancellables)
    }

    // MARK: - Actions

    @objc private func requestPause() {
        pauseManager.requestPause()
        rebuildMenu()
    }

    @objc private func cancelPauseRequest() {
        pauseManager.cancelPauseRequest()
        rebuildMenu()
    }

    @objc private func endBreakEarly() {
        pauseManager.endPause()
        rebuildMenu()
    }

    @objc func showPauseConfirmation() {
        let view = PauseConfirmView()
            .environmentObject(appState)
        showFloatingWindow(title: "Confirm Pause", content: view, identifier: "pause", size: NSSize(width: 320, height: 240))
    }

    @objc private func openPreferences() {
        if prefsWindow == nil {
            let view = PreferencesView()
                .environmentObject(appState)
                .environmentObject(BlocklistManager.shared)
                .environmentObject(ScheduleManager.shared)
            let window = makeWindow(title: "Tome Preferences", content: view, size: NSSize(width: 680, height: 520))
            prefsWindow = window
            window.delegate = WindowCloseDelegate { [weak self] in self?.prefsWindow = nil }
        }
        prefsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func openAbout() {
        if aboutWindow == nil {
            let view = AboutView()
            let window = makeWindow(title: "About Tome", content: view, size: NSSize(width: 340, height: 300))
            window.styleMask = [.titled, .closable]
            aboutWindow = window
            window.delegate = WindowCloseDelegate { [weak self] in self?.aboutWindow = nil }
        }
        aboutWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    // MARK: - Window helpers

    private func makeWindow<V: View>(title: String, content: V, size: NSSize) -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = title
        window.center()
        window.contentView = NSHostingView(rootView: content)
        window.isReleasedWhenClosed = false
        return window
    }

    private func showFloatingWindow<V: View>(title: String, content: V, identifier: String, size: NSSize) {
        let window = NSPanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.titled, .closable, .nonactivatingPanel, .hudWindow],
            backing: .buffered,
            defer: false
        )
        window.title = title
        window.center()
        window.contentView = NSHostingView(rootView: content)
        window.isReleasedWhenClosed = true
        window.level = .floating
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        pauseWindow = window
    }
}

class WindowCloseDelegate: NSObject, NSWindowDelegate {
    private let onClose: () -> Void
    init(_ onClose: @escaping () -> Void) { self.onClose = onClose }
    func windowWillClose(_ notification: Notification) { onClose() }
}
