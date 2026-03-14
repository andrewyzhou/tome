import SwiftUI

struct SchedulesView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var scheduleManager: ScheduleManager
    @EnvironmentObject var blocklistManager: BlocklistManager

    @State private var selectedID: UUID? = nil
    @State private var isAdding = false

    private var isLocked: Bool { appState.isActivelyBlocking }

    var body: some View {
        HSplitView {
            // Sidebar
            VStack(spacing: 0) {
                List(selection: $selectedID) {
                    ForEach(scheduleManager.schedules) { schedule in
                        ScheduleRowView(schedule: schedule)
                            .tag(schedule.id)
                    }
                }

                Divider()

                HStack(spacing: 0) {
                    Button(action: { isAdding = true }) {
                        Image(systemName: "plus").frame(width: 28, height: 24)
                    }
                    .buttonStyle(.plain)

                    Button {
                        guard let id = selectedID else { return }
                        selectedID = nil
                        scheduleManager.delete(id: id)
                    } label: {
                        Image(systemName: "minus")
                            .frame(width: 28, height: 24)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(selectedID == nil)

                    Spacer()
                }
                .padding(.horizontal, 4)
                .frame(height: 28)
                .background(Color(NSColor.controlBackgroundColor))
            }
            .frame(minWidth: 120, idealWidth: 120, maxWidth: 180)

            // Detail
            if let id = selectedID, let idx = scheduleManager.schedules.firstIndex(where: { $0.id == id }) {
                ScheduleDetailView(
                    schedule: $scheduleManager.schedules[idx],
                    blocklists: blocklistManager.blocklists,
                    isLocked: isLocked
                )
            } else {
                Color.clear.overlay(Text("Select a schedule").foregroundColor(.secondary))
            }
        }
        .sheet(isPresented: $isAdding) {
            NewScheduleSheet { schedule in
                scheduleManager.add(schedule)
                selectedID = schedule.id
            }
        }
    }
}

struct ScheduleRowView: View {
    let schedule: ScheduleBlock

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(schedule.name)
                    .fontWeight(.medium)
                if !schedule.isEnabled {
                    Text("off")
                        .font(.caption2)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Color.secondary.opacity(0.2))
                        .cornerRadius(3)
                }
            }
            Text(schedule.isAllDay ? "All day" : "\(schedule.startTime.displayString) – \(schedule.endTime.displayString)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 2)
    }
}

struct ScheduleDetailView: View {
    @Binding var schedule: ScheduleBlock
    let blocklists: [Blocklist]
    let isLocked: Bool

    @State private var draft: ScheduleBlock = ScheduleBlock()
    @State private var isDirty = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Name + enabled toggle
                HStack {
                    TextField("Schedule name", text: $draft.name)
                        .textFieldStyle(.roundedBorder)
                        .disabled(isLocked)
                        .onChange(of: draft.name) { _ in isDirty = true }
                    Toggle("Enabled", isOn: $draft.isEnabled)
                        .disabled(isLocked)
                        .onChange(of: draft.isEnabled) { _ in isDirty = true }
                }

                // Days of week
                VStack(alignment: .leading, spacing: 8) {
                    Text("Days").font(.headline)
                    HStack(spacing: 6) {
                        ForEach(Weekday.allCases) { day in
                            DayToggleButton(
                                day: day,
                                isSelected: draft.days.contains(day),
                                isLocked: isLocked
                            ) {
                                if draft.days.contains(day) { draft.days.remove(day) }
                                else { draft.days.insert(day) }
                                isDirty = true
                            }
                        }
                    }
                }

                // Time range
                VStack(alignment: .leading, spacing: 8) {
                    Text("Time").font(.headline)
                    Toggle("All day", isOn: $draft.isAllDay)
                        .disabled(isLocked)
                        .onChange(of: draft.isAllDay) { _ in isDirty = true }
                    if !draft.isAllDay {
                        HStack(spacing: 12) {
                            TimePickerView(label: "From", time: $draft.startTime, isLocked: isLocked) {
                                isDirty = true
                            }
                            Text("–").foregroundColor(.secondary)
                            TimePickerView(label: "To", time: $draft.endTime, isLocked: isLocked) {
                                isDirty = true
                            }
                        }
                    }
                }

                // Blocklists
                VStack(alignment: .leading, spacing: 8) {
                    Text("Blocklists").font(.headline)
                    if blocklists.isEmpty {
                        Text("No blocklists yet — create one in the Blocklists tab.")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    } else {
                        ForEach(blocklists) { list in
                            Toggle(list.name + " (\(list.domains.count) domains)", isOn: Binding(
                                get: { draft.blocklistIDs.contains(list.id) },
                                set: { checked in
                                    if checked { draft.blocklistIDs.insert(list.id) }
                                    else { draft.blocklistIDs.remove(list.id) }
                                    isDirty = true
                                }
                            ))
                            .disabled(isLocked)
                        }
                    }
                }

                Spacer()

                if isDirty && !isLocked {
                    HStack {
                        Spacer()
                        Button("Save Changes") { save() }
                            .buttonStyle(.borderedProminent)
                    }
                }
            }
            .padding(20)
        }
        .onAppear { draft = schedule; isDirty = false }
        .onChange(of: schedule.id) { _ in draft = schedule; isDirty = false }
    }

    private func save() {
        schedule = draft
        ScheduleManager.shared.save()
        ScheduleManager.shared.evaluate()
        isDirty = false
    }
}

struct DayToggleButton: View {
    let day: Weekday
    let isSelected: Bool
    let isLocked: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: { if !isLocked { onToggle() } }) {
            Text(day.shortName)
                .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                .frame(width: 26, height: 26)
                .background(isSelected ? Color.accentColor : Color.clear)
                .foregroundColor(isSelected ? .white : .primary)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(isSelected ? Color.clear : Color.secondary.opacity(0.4), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .opacity(isLocked ? 0.5 : 1)
    }
}

private struct RowWidthKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

struct TimePickerView: View {
    let label: String
    @Binding var time: TimeOfDay
    let isLocked: Bool
    var onCommit: (() -> Void)? = nil

    @State private var hourText: String = ""
    @State private var minuteText: String = ""
    @State private var isPM: Bool = false
    @State private var rowWidth: CGFloat = 75

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.caption).foregroundColor(.secondary)
            HStack(spacing: 3) {
                TextField("9", text: $hourText)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 34)
                    .multilineTextAlignment(.center)
                    .disabled(isLocked)
                    .onChange(of: hourText) { _ in commitChange() }
                Text(":").foregroundColor(.secondary)
                TextField("00", text: $minuteText)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 34)
                    .multilineTextAlignment(.center)
                    .disabled(isLocked)
                    .onChange(of: minuteText) { _ in commitChange() }
            }
            .fixedSize()
            .background(GeometryReader { geo in
                Color.clear.preference(key: RowWidthKey.self, value: geo.size.width)
            })
            .onPreferenceChange(RowWidthKey.self) { w in rowWidth = w }
            Picker("", selection: $isPM) {
                Text("AM").tag(false)
                Text("PM").tag(true)
            }
            .pickerStyle(.segmented)
            .frame(width: rowWidth)
            .disabled(isLocked)
            .onChange(of: isPM) { _ in commitChange() }
        }
        .onAppear { loadFromTime() }
        .onChange(of: time) { _ in loadFromTime() }
    }

    private func loadFromTime() {
        let h = time.hour % 12 == 0 ? 12 : time.hour % 12
        hourText = "\(h)"
        minuteText = String(format: "%02d", time.minute)
        isPM = time.hour >= 12
    }

    private func commitChange() {
        guard let h = Int(hourText), h >= 1, h <= 12,
              let m = Int(minuteText), m >= 0, m <= 59 else { return }
        var hour24 = h
        if isPM && h != 12 { hour24 = h + 12 }
        else if !isPM && h == 12 { hour24 = 0 }
        time = TimeOfDay(hour: hour24, minute: m)
        onCommit?()
    }
}

struct NewScheduleSheet: View {
    @Environment(\.dismiss) var dismiss
    @State private var name = ""
    let onCreate: (ScheduleBlock) -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text("New Schedule").font(.headline)
            TextField("Name", text: $name)
                .textFieldStyle(.roundedBorder)
                .frame(width: 240)
            HStack {
                Button("Cancel") { dismiss() }.keyboardShortcut(.escape)
                Button("Create") {
                    onCreate(ScheduleBlock(name: name.isEmpty ? "Untitled" : name))
                    dismiss()
                }
                .keyboardShortcut(.return)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
        .frame(width: 300, height: 140)
    }
}
