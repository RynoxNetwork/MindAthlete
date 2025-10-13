import Foundation

extension Date {
    static func iso8601Formatter(timeZone: TimeZone = .utc) -> ISO8601DateFormatter {
        let formatter = ISO8601DateFormatter()
        formatter.timeZone = timeZone
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }

    func formattedShort() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: self)
    }
}

extension TimeZone {
    static let utc = TimeZone(secondsFromGMT: 0)!
}
