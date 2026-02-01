import SwiftUI

// Shown after the 5-min countdown expires — asks user to confirm pause and pick duration
struct PauseConfirmView: View {
    @EnvironmentObject var appState: AppState
    @State private var breakMinutes: Double = 5
    @State private var confirmed = false

    private let pauseManager = PauseManager.shared

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "pause.circle.fill")
                .font(.system(size: 40))
                .foregroundColor(.orange)

            Text("Take a break?")
                .font(.title2)
                .fontWeight(.semibold)

            Text("You've waited 5 minutes. Confirm your break duration below.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

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
                    closeWindow()
                }
                .keyboardShortcut(.escape)

                Button("Start break") {
                    pauseManager.confirmPause(minutes: Int(breakMinutes))
                    closeWindow()
                }
                .keyboardShortcut(.return)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(28)
        .frame(width: 320, height: 280)
    }

    private func closeWindow() {
        NSApplication.shared.keyWindow?.close()
    }
}
