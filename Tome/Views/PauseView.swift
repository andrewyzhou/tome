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
        // TimelineView forces a re-render every second so countdowns are always live
        TimelineView(.periodic(from: .now, by: 1.0)) { _ in
            content
        }
        .frame(width: 320, height: 300)
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
        VStack(spacing: 20) {
            Image(systemName: "pause.circle")
                .font(.system(size: 44))
                .foregroundColor(.secondary)
            Text("Pause")
                .font(.title2).fontWeight(.semibold)
            Text("Type \"pause\" for a 5‑minute wait before your break, or \"urgent\" to pause immediately.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            HStack(spacing: 8) {
                TextField("pause or urgent", text: $pauseInput)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 160)
                    .onSubmit { submitPauseInput() }
                Button("→") { submitPauseInput() }
                    .buttonStyle(.borderedProminent)
                    .disabled(!isValidInput)
            }
        }
    }

    private var countdownView: some View {
        let remaining = pauseManager.countdownSecondsRemaining
        return VStack(spacing: 20) {
            Image(systemName: "timer")
                .font(.system(size: 44))
                .foregroundColor(.orange)
            Text("Pause requested")
                .font(.title2).fontWeight(.semibold)
            Text(String(format: "%d:%02d", remaining / 60, remaining % 60))
                .font(.system(size: 52, weight: .thin, design: .monospaced))
                .foregroundColor(.orange)
            Text("Sit tight. Confirm your break when the timer reaches zero.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Button("Cancel") {
                pauseManager.cancelPauseRequest()
            }
        }
    }

    private var confirmView: some View {
        VStack(spacing: 20) {
            Image(systemName: "pause.circle.fill")
                .font(.system(size: 44))
                .foregroundColor(.orange)
            Text("Take a break?")
                .font(.title2).fontWeight(.semibold)
            VStack(spacing: 8) {
                Text("\(Int(breakMinutes)) minute\(Int(breakMinutes) == 1 ? "" : "s")")
                    .font(.headline)
                Slider(value: $breakMinutes, in: 1...15, step: 1)
                    .frame(width: 240)
                HStack {
                    Text("1 min").font(.caption).foregroundColor(.secondary)
                    Spacer()
                    Text("15 min").font(.caption).foregroundColor(.secondary)
                }
                .frame(width: 240)
            }
            HStack(spacing: 12) {
                Button("Cancel") {
                    pauseManager.cancelPauseRequest()
                }
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
        return VStack(spacing: 20) {
            Image(systemName: "pause.circle.fill")
                .font(.system(size: 44))
                .foregroundColor(.green)
            Text("On break")
                .font(.title2).fontWeight(.semibold)
            Text(String(format: "%d:%02d", remaining / 60, remaining % 60))
                .font(.system(size: 52, weight: .thin, design: .monospaced))
                .foregroundColor(.green)
            Text("Blocking will resume automatically when your break ends.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Button("End break early") {
                pauseManager.endPause()
                closeWindow()
            }
        }
    }

    private func closeWindow() {
        NSApplication.shared.keyWindow?.close()
    }
}
