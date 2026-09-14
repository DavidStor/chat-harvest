import Foundation

struct MessageSearchEntry {
    var id: String { "\(chatID):\(messageID)" }
    let chatID: Int64
    let messageID: Int64
    let text: String
    let date: Date?
}
struct KeywordMatch: Identifiable, Equatable {
    let messageID: Int64
    let range: NSRange
    var id: String { "\(messageID):\(range.location)" }
}
enum KeywordSearch {
    static func query(_ value: String) -> String { value.trimmingCharacters(in: .whitespacesAndNewlines) }
    static func ranges(in text: String, query value: String, cancelled: () -> Bool = { false }) -> [NSRange] {
        let needle = query(value)
        guard !needle.isEmpty else { return [] }
        var result: [NSRange] = []
        var remaining = text.startIndex..<text.endIndex
        while let found = text.range(of: needle, options: [.caseInsensitive, .diacriticInsensitive], range: remaining) {
            if cancelled() { return [] }
            result.append(NSRange(found, in: text))
            remaining = found.upperBound..<text.endIndex
        }
        return result
    }
    static func matches(rows: [ExportRow], query: String, cancelled: () -> Bool = { false }) -> [KeywordMatch] {
        guard !self.query(query).isEmpty else { return [] }
        var matches: [KeywordMatch] = []
        for row in rows {
            if cancelled() { return [] }
            matches += ranges(in: row.text, query: query, cancelled: cancelled).map { KeywordMatch(messageID: row.id, range: $0) }
        }
        return cancelled() ? [] : matches
    }
    static func search(_ entries: [MessageSearchEntry], query: String, cancelled: () -> Bool = { false }) -> [MessageSearchEntry] {
        let needle = self.query(query)
        guard !needle.isEmpty else { return [] }
        var result: [MessageSearchEntry] = []
        for entry in entries {
            if cancelled() { return [] }
            // Global results need existence, not every occurrence in each message.
            if entry.text.range(of: needle, options: [.caseInsensitive, .diacriticInsensitive]) != nil { result.append(entry) }
        }
        if cancelled() { return [] }
        return result.sorted { ($0.date ?? .distantPast, $0.messageID) > ($1.date ?? .distantPast, $1.messageID) }
    }
    static func snippet(_ text: String, query: String) -> String {
        guard !self.query(query).isEmpty, let match = text.range(of: self.query(query), options: [.caseInsensitive, .diacriticInsensitive]) else { return String(text.prefix(130)) }
        let start = text.index(match.lowerBound, offsetBy: -35, limitedBy: text.startIndex) ?? text.startIndex
        let end = text.index(match.upperBound, offsetBy: 95, limitedBy: text.endIndex) ?? text.endIndex
        return (start > text.startIndex ? "…" : "") + text[start..<end].replacingOccurrences(of: "\n", with: " ") + (end < text.endIndex ? "…" : "")
    }
}

enum CalendarRange {
    static func normalized(_ a: Date, _ b: Date, calendar: Calendar = .current) -> (Date, Date) {
        let a = calendar.startOfDay(for: a), b = calendar.startOfDay(for: b)
        return (min(a, b), max(a, b))
    }
    static func lastDays(_ count: Int, endingAt date: Date = Date(), calendar: Calendar = .current) -> (Date, Date) {
        let end = calendar.startOfDay(for: date)
        return (calendar.date(byAdding: .day, value: -(max(1, count) - 1), to: end)!, end)
    }
}

/// A bounded viewport keeps SwiftUI from laying out thousands of offscreen bubbles for scrollTo.
enum TimelineWindow {
    static let capacity = 160
    static let overlap = 40
    static func range(count: Int, around index: Int? = nil) -> Range<Int> {
        guard count > 0 else { return 0..<0 }
        let start = min(max(0, (index ?? count) - capacity / 2), max(0, count - capacity))
        return start..<min(count, start + capacity)
    }
    static func clamped(_ range: Range<Int>, count: Int) -> Range<Int> {
        guard !range.isEmpty else { return self.range(count: count) }
        let start = min(range.lowerBound, max(0, count - capacity))
        return start..<min(count, start + capacity)
    }
    static func page(_ range: Range<Int>, direction: Int, count: Int) -> Range<Int> {
        let start = min(max(0, range.lowerBound + direction * (capacity - overlap)), max(0, count - capacity))
        return start..<min(count, start + capacity)
    }
}
