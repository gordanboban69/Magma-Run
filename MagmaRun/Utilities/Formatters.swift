import Foundation

/// Formatting helpers for numbers and durations shown in the interface.
enum Formatters {
    /// Formats a duration in seconds as `m:ss`.
    static func duration(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds.rounded()))
        let minutes = total / 60
        let remainder = total % 60
        return String(format: "%d:%02d", minutes, remainder)
    }

    /// Formats a score or currency amount with grouping separators.
    static func integer(_ value: Int) -> String {
        value.formatted(.number.grouping(.automatic))
    }

    /// Formats a date for the run history list.
    static func runDate(_ date: Date) -> String {
        date.formatted(.dateTime.day().month(.abbreviated).hour().minute())
    }
}
