import Foundation

/// Default court label from date/time until the user renames it on iPhone.
enum CourtDefaultName {
    static func make(date: Date = Date()) -> String {
        let locale = Locale(identifier: "en_US")
        let weekday = DateFormatter()
        weekday.locale = locale
        weekday.setLocalizedDateFormatFromTemplate("EEE")

        let time = DateFormatter()
        time.locale = locale
        time.setLocalizedDateFormatFromTemplate("HH:mm")

        let day = DateFormatter()
        day.locale = locale
        day.setLocalizedDateFormatFromTemplate("d MMM")

        return "\(weekday.string(from: date)) \(time.string(from: date)) · \(day.string(from: date))"
    }
}
