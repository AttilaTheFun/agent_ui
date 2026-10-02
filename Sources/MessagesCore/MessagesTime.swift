import Foundation

/// The inbox's time column, as Messages writes it: the time today, the
/// weekday this week, the date before that. Assembled from calendar
/// components, not a DateFormatter, which not every Foundation has (the
/// lightweight one on wasm and Android has Calendar, in UTC).
public enum MessagesTime {
    public static func label(for date: Date, now: Date = Date(), calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.year, .month, .day, .hour, .minute, .weekday], from: date)
        guard let hour = parts.hour, let minute = parts.minute, let year = parts.year,
              let month = parts.month, let day = parts.day, let weekday = parts.weekday else { return "" }
        if calendar.isDate(date, inSameDayAs: now) {
            let h12 = hour % 12 == 0 ? 12 : hour % 12
            return "\(h12):\(minute < 10 ? "0" : "")\(minute) \(hour < 12 ? "AM" : "PM")"
        }
        if let week = calendar.date(byAdding: .day, value: -6, to: now), date > week {
            let names = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
            return names[(weekday - 1 + 7) % 7]
        }
        return "\(month)/\(day)/\(year % 100 < 10 ? "0" : "")\(year % 100)"
    }
}
