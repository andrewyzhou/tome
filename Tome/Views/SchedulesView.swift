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
                    .disabled(isLocked)

                    Button(action: deleteSelected) {
                        Image(systemName: "minus").frame(width: 28, height: 24)
                    }
                    .buttonStyle(.plain)
                    .disabled(isLocked || selectedID == nil)

                    Spacer()
                }
                .padding(.horizontal, 4)
                .frame(height: 28)
                .background(Color(NSColor.controlBackgroundColor))
            }
            .frame(minWidth: 200, maxWidth: 240)

            // Detail
            if let id = selectedID, let idx = scheduleManager.schedules.firstIndex(where: { $0.id == id }) {
                ScheduleDetailView(
                    schedule: $scheduleManager.schedules[idx],
                    blocklists: blocklistManager.blocklists,
                    isLocked: isLocked
                )
                .onDisappear { scheduleManager.save() }
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

    private func deleteSelected() {
        guard let id = selectedID else { return }
        scheduleManager.delete(id: id)
        selectedID = nil
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

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Name + enabled toggle
                HStack {
                    TextField("Schedule name", text: $schedule.name)
                        .textFieldStyle(.roundedBorder)
                        .disabled(isLocked)
                    Toggle("Enabled", isOn: $schedule.isEnabled)
                        .disabled(isLocked)
                }

                // Days of week
                VStack(alignment: .leading, spacing: 8) {
                    Text("Days").font(.headline)
                    HStack(spacing: 6) {
                        ForEach(Weekday.allCases) { day in
                            DayToggleButton(
                                day: day,
                                isSelected: schedule.days.contains(day),
                                isLocked: isLocked
                            ) {
                                if schedule.days.contains(day) {
                                    schedule.days.remove(day)
                                } else {
                                    schedule.days.insert(day)
                                }
                            }
                        }
                    }
                }

                // Time range
                VStack(alignment: .leading, spacing: 8) {
                    Text("Time").font(.headline)
                    Toggle("All day", isOn: $schedule.isAllDay)
                        .disabled(isLocked)
                    if !schedule.isAllDay {
                        HStack(spacing: 12) {
                            TimePickerView(label: "From", time: $schedule.startTime, isLocked: isLocked)
                            Text("–").foregroundColor(.secondary)
                            TimePickerView(label: "To", time: $schedule.endTime, isLocked: isLocked)
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
                                get: { schedule.blocklistIDs.contains(list.id) },
                                set: { checked in
                                    if checked { schedule.blocklistIDs.insert(list.id) }
                                    else { schedule.blocklistIDs.remove(list.id) }
                                }
                            ))
                            .disabled(isLocked)
                        }
                    }
                }

                Spacer()
            }
            .padding(20)
        }
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
                .font(.caption)
                .fontWeight(isSelected ? .semibold : .regular)
                .frame(width: 32, height: 28)
                .background(isSelected ? Color.accentColor : Color(NSColor.controlBackgroundColor))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(6)
        }
        .buttonStyle(.plain)
        .opacity(isLocked ? 0.5 : 1)
    }
}

struct TimePickerView: View {
    let label: String
    @Binding var time: TimeOfDay
    let isLocked: Bool

    @State private var selectedDate: Date = Date()

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.caption).foregroundColor(.secondary)
            DatePicker("", selection: $selectedDate, displayedComponents: .hourAndMinute)
                .labelsHidden()
                .disabled(isLocked)
                .onChange(of: selectedDate) { newDate in
                    time = TimeOfDay.from(date: newDate)
                }
                .onAppear {
                    selectedDate = time.toDate()
                }
        }
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
