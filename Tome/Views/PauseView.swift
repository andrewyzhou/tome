import SwiftUI

struct PauseView: View {
    @EnvironmentObject var appState: AppState
    @State private var breakMinutes: Double = 5
    @State private var pauseInput: String = ""
    private let pauseManager = PauseManager.shared

    private var isValidInput: Bool {
        let v = pauseInput.trimmingCharacters(in: .whitespaces).lowercased()
        return v == "pause" || v == "urgent"
    }

    private func submitPauseInput() {
        let v = pauseInput.trimmingCharacters(in: .whitespaces).lowercased()
        if v == "pause" { pauseManager.requestPause() }
        else if v == "urgent" { pauseManager.urgentPause() }
        pauseInput = ""
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1.0)) { _ in
            content
        }
        .frame(width: 408, height: 468)
        .padding(28)
    }

    @ViewBuilder
    private var content: some View {
        if appState.isPaused {
            breakActiveView
        } else if appState.pendingPauseConfirmation {
            confirmView
        } else if appState.pauseRequestActive {
            countdownView
        } else {
            idleView
        }
    }

    // MARK: - States

    private var idleView: some View {
        VStack(spacing: 10) {
            Image(systemName: "pause.circle")
                .font(.system(size: 28))
                .foregroundColor(.secondary)
            Text("Pause")
                .font(.headline).fontWeight(.semibold)
            VStack(spacing: 2) {
                Text("Type \"pause\" to pause Tome after a 5-minute wait.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                Text("Type \"urgent\" to pause Tome immediately.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            HStack(spacing: 6) {
                TextField("", text: $pauseInput)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 100)
                    .onSubmit { submitPauseInput() }
                Button("→") { submitPauseInput() }
                    .buttonStyle(.borderedProminent)
                    .disabled(!isValidInput)
            }
        }
    }

    private var countdownView: some View {
        let remaining = pauseManager.countdownSecondsRemaining
        return VStack(spacing: 10) {
            Image(systemName: "timer")
                .font(.system(size: 28))
                .foregroundColor(.orange)
            Text("Pause requested")
                .font(.headline).fontWeight(.semibold)
            Text(String(format: "%d:%02d", remaining / 60, remaining % 60))
                .font(.system(size: 32, weight: .thin, design: .monospaced))
                .foregroundColor(.orange)
            Text("Confirm your pause when the timer reaches zero.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Button("Cancel") { pauseManager.cancelPauseRequest() }
        }
    }

    private var confirmView: some View {
        VStack(spacing: 10) {
            Image(systemName: "pause.circle.fill")
                .font(.system(size: 28))
                .foregroundColor(.orange)
            Text("Take a break?")
                .font(.headline).fontWeight(.semibold)
            VStack(spacing: 4) {
                Text("\(Int(breakMinutes)) minute\(Int(breakMinutes) == 1 ? "" : "s")")
                    .font(.subheadline)
                Slider(value: $breakMinutes, in: 1...15, step: 1)
                    .frame(width: 130)
                HStack {
                    Text("1 min").font(.caption2).foregroundColor(.secondary)
                    Spacer()
                    Text("15 min").font(.caption2).foregroundColor(.secondary)
                }
                .frame(width: 130)
            }
            HStack(spacing: 8) {
                Button("Cancel") { pauseManager.cancelPauseRequest() }
                Button("Start break") {
                    pauseManager.confirmPause(minutes: Int(breakMinutes))
                    closeWindow()
                }
                .keyboardShortcut(.return)
                .buttonStyle(.borderedProminent)
            }
        }
    }

    private var breakActiveView: some View {
        let remaining = pauseManager.breakSecondsRemaining
        return VStack(spacing: 10) {
            Image(systemName: "pause.circle.fill")
                .font(.system(size: 28))
                .foregroundColor(.green)
            Text("Paused")
                .font(.headline).fontWeight(.semibold)
            Text(String(format: "%d:%02d", remaining / 60, remaining % 60))
                .font(.system(size: 32, weight: .thin, design: .monospaced))
                .foregroundColor(.green)
            Text("Tome will resume automatically after your pause finishes.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Button("End pause early") {
                pauseManager.endPause()
                closeWindow()
            }
        }
    }

    private func closeWindow() {
        NSApplication.shared.keyWindow?.close()
    }
}
