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

    private var statusTimer: Timer?

    // windows
    private var prefsWindow: NSWindow?
    private var aboutWindow: NSWindow?
    private var pauseWindow: NSWindow?

    // window delegates must be held strongly (NSWindow.delegate is weak)
    private var prefsWindowDelegate: WindowCloseDelegate?
    private var aboutWindowDelegate: WindowCloseDelegate?
    private var pauseWindowDelegate: WindowCloseDelegate?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        _ = ScheduleManager.shared
        _ = BlocklistManager.shared

        setupStatusItem()
        setupObservers()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(openPause),
            name: .tomeOpenPauseWindow,
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
        let statusMenuItem = NSMenuItem(title: statusTitle(), action: nil, keyEquivalent: "")
        statusMenuItem.isEnabled = false
        m.addItem(statusMenuItem)

        m.addItem(.separator())

        // Pause — always present, grayed out when not applicable
        let pauseItem = NSMenuItem(title: "Pause...", action: #selector(openPause), keyEquivalent: "")
        pauseItem.target = self
        pauseItem.isEnabled = appState.pauseWindowEnabled
        m.addItem(pauseItem)

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
        let quitItem = NSMenuItem(
            title: appState.lockedMode && appState.isActivelyBlocking ? "Quit Tome (locked)" : "Quit Tome",
            action: #selector(quit),
            keyEquivalent: "q"
        )
        quitItem.target = self
        quitItem.isEnabled = !(appState.lockedMode && appState.isActivelyBlocking)
        m.addItem(quitItem)

        self.menu = m
        self.statusItem?.menu = m
    }

    private func statusTitle() -> String {
        if appState.isPaused {
            let remaining = pauseManager.breakSecondsRemaining
            return String(format: "Paused — %d:%02d remaining", remaining / 60, remaining % 60)
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
        let rebuild: (Any) -> Void = { [weak self] _ in
            DispatchQueue.main.async {
                self?.updateStatusIcon()
                self?.rebuildMenu()
                self?.updateStatusTimer()
            }
        }

        appState.$isBlocking.receive(on: RunLoop.main).sink(receiveValue: rebuild).store(in: &cancellables)
        appState.$isPaused.receive(on: RunLoop.main).sink(receiveValue: rebuild).store(in: &cancellables)
        appState.$pauseRequestActive.receive(on: RunLoop.main).sink(receiveValue: rebuild).store(in: &cancellables)
        appState.$pendingPauseConfirmation.receive(on: RunLoop.main).sink(receiveValue: rebuild).store(in: &cancellables)
    }

    private func updateStatusTimer() {
        let needsTick = appState.isPaused || appState.pauseRequestActive
        if needsTick && statusTimer == nil {
            let t = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
                self?.menu?.items.first?.title = self?.statusTitle() ?? ""
            }
            RunLoop.main.add(t, forMode: .common)
            statusTimer = t
        } else if !needsTick {
            statusTimer?.invalidate()
            statusTimer = nil
        }
    }

    // MARK: - Actions

    @objc func openPause() {
        if pauseWindow == nil {
            let view = PauseView().environmentObject(appState)
            let window = makeWindow(title: "Pause", content: view, size: NSSize(width: 408, height: 408))
            window.styleMask = [.titled, .closable]
            pauseWindow = window
            let delegate = WindowCloseDelegate { [weak self] in self?.pauseWindow = nil }
            pauseWindowDelegate = delegate
            window.delegate = delegate
        }
        pauseWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func openPreferences() {
        if prefsWindow == nil {
            let view = PreferencesView()
                .environmentObject(appState)
                .environmentObject(BlocklistManager.shared)
                .environmentObject(ScheduleManager.shared)
            let window = makeWindow(title: "Tome Preferences", content: view, size: NSSize(width: 408, height: 468))
            prefsWindow = window
            let delegate = WindowCloseDelegate { [weak self] in self?.prefsWindow = nil }
            prefsWindowDelegate = delegate
            window.delegate = delegate
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
            let delegate = WindowCloseDelegate { [weak self] in self?.aboutWindow = nil }
            aboutWindowDelegate = delegate
            window.delegate = delegate
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
}

class WindowCloseDelegate: NSObject, NSWindowDelegate {
    private let onClose: () -> Void
    init(_ onClose: @escaping () -> Void) { self.onClose = onClose }
    func windowWillClose(_ notification: Notification) { onClose() }
}
