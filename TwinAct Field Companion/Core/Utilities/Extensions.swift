//
//  Extensions.swift
//  TwinAct Field Companion
//
//  Common utility extensions used throughout the app.
//

import Foundation
import SwiftUI

// MARK: - String Extensions

public extension String {
    /// Returns true if the string contains only whitespace or is empty.
    var isBlank: Bool {
        trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Returns nil if the string is blank, otherwise returns self.
    var nilIfBlank: String? {
        isBlank ? nil : self
    }

    /// Truncates the string to the specified length with an optional suffix.
    /// - Parameters:
    ///   - length: Maximum length of the result (including suffix).
    ///   - suffix: Suffix to append when truncated (default: "…").
    /// - Returns: Truncated string.
    func truncated(to length: Int, suffix: String = "…") -> String {
        guard count > length else { return self }
        let endIndex = index(startIndex, offsetBy: max(0, length - suffix.count))
        return String(self[..<endIndex]) + suffix
    }

    /// Removes the specified prefix if present.
    func removingPrefix(_ prefix: String) -> String {
        guard hasPrefix(prefix) else { return self }
        return String(dropFirst(prefix.count))
    }

    /// Removes the specified suffix if present.
    func removingSuffix(_ suffix: String) -> String {
        guard hasSuffix(suffix) else { return self }
        return String(dropLast(suffix.count))
    }
}

// MARK: - Optional String Extension

public extension Optional where Wrapped == String {
    /// Returns true if the optional is nil or the wrapped string is blank.
    var isNilOrBlank: Bool {
        self?.isBlank ?? true
    }
}

// MARK: - Date Extensions

public extension Date {
    /// Returns a relative time description (e.g., "2 hours ago", "yesterday").
    var relativeDescription: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: self, relativeTo: Date())
    }

    /// Returns true if the date is today.
    var isToday: Bool {
        Calendar.current.isDateInToday(self)
    }

    /// Returns true if the date is yesterday.
    var isYesterday: Bool {
        Calendar.current.isDateInYesterday(self)
    }

    /// Returns an ISO8601 formatted string (e.g., "2024-01-15T10:30:00Z").
    var iso8601String: String {
        ISO8601DateFormatter().string(from: self)
    }

    /// Creates a Date from an ISO8601 string.
    /// - Parameter string: ISO8601 formatted date string.
    /// - Returns: Parsed Date or nil if parsing fails.
    static func fromISO8601(_ string: String) -> Date? {
        ISO8601DateFormatter().date(from: string)
    }
}

// MARK: - Collection Extensions

public extension Collection {
    /// Returns the element at the specified index if it exists, otherwise nil.
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

public extension Array {
    /// Splits the array into chunks of the specified size.
    /// - Parameter size: Maximum size of each chunk.
    /// - Returns: Array of chunks.
    func chunked(into size: Int) -> [[Element]] {
        guard size > 0 else { return [] }
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}

public extension Sequence where Element: Hashable {
    /// Returns an array with duplicate elements removed, preserving order.
    var uniqued: [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}

// MARK: - Data Extensions

public extension Data {
    /// Returns a hex-encoded string representation of the data.
    var hexEncodedString: String {
        map { String(format: "%02hhx", $0) }.joined()
    }

    /// Returns a pretty-printed JSON string if the data is valid JSON.
    var prettyPrintedJSON: String? {
        guard let object = try? JSONSerialization.jsonObject(with: self),
              let prettyData = try? JSONSerialization.data(withJSONObject: object, options: .prettyPrinted),
              let string = String(data: prettyData, encoding: .utf8) else {
            return nil
        }
        return string
    }
}

// MARK: - URL Extensions

public extension URL {
    /// Appends query items to the URL.
    /// - Parameter queryItems: Dictionary of query parameter names and values.
    /// - Returns: URL with appended query items, or self if modification fails.
    func appendingQueryItems(_ queryItems: [String: String]) -> URL {
        guard var components = URLComponents(url: self, resolvingAgainstBaseURL: true) else {
            return self
        }
        var existing = components.queryItems ?? []
        existing.append(contentsOf: queryItems.map { URLQueryItem(name: $0.key, value: $0.value) })
        components.queryItems = existing
        return components.url ?? self
    }
}

// MARK: - SwiftUI View Extensions

public extension View {
    /// Conditionally applies a modifier to a view.
    /// - Parameters:
    ///   - condition: Condition that determines if the modifier should be applied.
    ///   - transform: Transform to apply when condition is true.
    /// - Returns: Modified view or original view.
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }

    /// Conditionally applies one of two modifiers to a view.
    /// - Parameters:
    ///   - condition: Condition that determines which modifier to apply.
    ///   - ifTrue: Transform to apply when condition is true.
    ///   - ifFalse: Transform to apply when condition is false.
    /// - Returns: Modified view.
    @ViewBuilder
    func `if`<TrueContent: View, FalseContent: View>(
        _ condition: Bool,
        ifTrue: (Self) -> TrueContent,
        ifFalse: (Self) -> FalseContent
    ) -> some View {
        if condition {
            ifTrue(self)
        } else {
            ifFalse(self)
        }
    }

    /// Hides the view based on a condition.
    /// - Parameter hidden: Whether to hide the view.
    /// - Returns: View that may be hidden.
    @ViewBuilder
    func isHidden(_ hidden: Bool) -> some View {
        if hidden {
            self.hidden()
        } else {
            self
        }
    }
}

// MARK: - Result Extensions

public extension Result {
    /// Returns the success value or nil.
    var successValue: Success? {
        if case .success(let value) = self {
            return value
        }
        return nil
    }

    /// Returns the failure error or nil.
    var failureError: Failure? {
        if case .failure(let error) = self {
            return error
        }
        return nil
    }
}

// MARK: - Task Extensions

public extension Task where Success == Never, Failure == Never {
    /// Sleeps for the specified number of seconds.
    /// - Parameter seconds: Duration to sleep in seconds.
    static func sleep(seconds: Double) async throws {
        try await sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
    }
}
