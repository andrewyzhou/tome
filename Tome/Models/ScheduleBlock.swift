import Foundation

enum Weekday: Int, Codable, CaseIterable, Identifiable {
    case sunday = 1, monday, tuesday, wednesday, thursday, friday, saturday

    var id: Int { rawValue }

    var shortName: String {
        switch self {
        case .sunday: return "Su"
        case .monday: return "Mo"
        case .tuesday: return "Tu"
        case .wednesday: return "We"
        case .thursday: return "Th"
        case .friday: return "Fr"
        case .saturday: return "Sa"
        }
    }

    var fullName: String {
        switch self {
        case .sunday: return "Sunday"
        case .monday: return "Monday"
        case .tuesday: return "Tuesday"
        case .wednesday: return "Wednesday"
        case .thursday: return "Thursday"
        case .friday: return "Friday"
        case .saturday: return "Saturday"
        }
    }
}

struct TimeOfDay: Codable, Equatable, Hashable {
    var hour: Int    // 0-23
    var minute: Int  // 0-59

    var displayString: String {
        let h = hour % 12 == 0 ? 12 : hour % 12
        let m = String(format: "%02d", minute)
        let period = hour < 12 ? "AM" : "PM"
        return "\(h):\(m) \(period)"
    }

    func toDate(relativeTo date: Date = Date()) -> Date {
        var cal = Calendar.current
        cal.timeZone = TimeZone.current
        var components = cal.dateComponents([.year, .month, .day], from: date)
        components.hour = hour
        components.minute = minute
        components.second = 0
        return cal.date(from: components) ?? date
    }

    static func from(date: Date) -> TimeOfDay {
        let cal = Calendar.current
        return TimeOfDay(
            hour: cal.component(.hour, from: date),
            minute: cal.component(.minute, from: date)
        )
    }
}

struct ScheduleBlock: Identifiable, Codable, Hashable {
    var id: UUID
    var name: String
    var days: Set<Weekday>
    var isAllDay: Bool
    var startTime: TimeOfDay
    var endTime: TimeOfDay
    var blocklistIDs: Set<UUID>
    var isEnabled: Bool

    init(
        id: UUID = UUID(),
        name: String = "New Schedule",
        days: Set<Weekday> = [.monday, .tuesday, .wednesday, .thursday, .friday],
        isAllDay: Bool = false,
        startTime: TimeOfDay = TimeOfDay(hour: 9, minute: 0),
        endTime: TimeOfDay = TimeOfDay(hour: 17, minute: 0),
        blocklistIDs: Set<UUID> = [],
        isEnabled: Bool = true
    ) {
        self.id = id
        self.name = name
        self.days = days
        self.isAllDay = isAllDay
        self.startTime = startTime
        self.endTime = endTime
        self.blocklistIDs = blocklistIDs
        self.isEnabled = isEnabled
    }

    func isActive(at date: Date = Date()) -> Bool {
        guard isEnabled else { return false }
        let cal = Calendar.current
        let weekdayNum = cal.component(.weekday, from: date)
        guard let today = Weekday(rawValue: weekdayNum), days.contains(today) else { return false }
        if isAllDay { return true }

        let nowHour = cal.component(.hour, from: date)
        let nowMinute = cal.component(.minute, from: date)
        let nowTotal = nowHour * 60 + nowMinute
        let startTotal = startTime.hour * 60 + startTime.minute
        let endTotal = endTime.hour * 60 + endTime.minute

        if startTotal <= endTotal {
            return nowTotal >= startTotal && nowTotal < endTotal
        } else {
            // overnight schedule
            return nowTotal >= startTotal || nowTotal < endTotal
        }
    }
}
