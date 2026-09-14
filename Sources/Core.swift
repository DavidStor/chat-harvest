import Foundation
import SQLite3

enum MediaPlaceholder {
    static func label(name: String, mime: String = "", uti: String = "", sticker: Bool = false) -> String {
        if sticker { return "[sticker]" }
        let mime = mime.lowercased(), uti = uti.lowercased()
        let ext = (name as NSString).pathExtension.lowercased()
        if mime.hasPrefix("video/") || ["public.movie", "public.video", "public.mpeg-4", "com.apple.quicktime-movie"].contains(uti) || ["mov", "mp4", "m4v", "avi", "webm", "3gp"].contains(ext) { return "[video]" }
        if mime.hasPrefix("audio/") || uti.contains("audio") || ["m4a", "mp3", "wav", "caf", "amr", "aac", "aiff", "ogg"].contains(ext) { return "[audio]" }
        if mime.hasPrefix("image/") || ["public.image", "public.heic", "public.heics", "public.jpeg", "public.png", "public.tiff", "com.compuserve.gif"].contains(uti) || ["heic", "heics", "jpg", "jpeg", "png", "gif", "webp", "tiff", "bmp", "avif"].contains(ext) { return "[photo]" }
        if mime == "text/vcard" || uti.contains("vcard") || ext == "vcf" { return "[contact]" }
        return "[attachment]"
    }
}

struct Chat: Identifiable, Hashable {
    let id: Int64
    let guid: String
    let displayName: String
    let identifier: String
    let handles: [String]
    let count: Int
    let lastDate: Date?
    let snippet: String
}

struct Message: Identifiable {
    let id: Int64
    let guid: String
    let date: Date?
    let sender: String
    let fromMe: Bool
    let text: String
    let reactionType: Int
    let associatedGUID: String
    let replyGUID: String
    let system: Bool
    let attachments: [String]
    let unreadable: Bool
    var isReaction: Bool { (2000..<4000).contains(reactionType) }
}

enum DatabaseError: LocalizedError {
    case failure(String)
    var errorDescription: String? { if case .failure(let text) = self { return text }; return nil }
}

final class Database {
    private var db: OpaquePointer?
    let path: String
    init(path: String) throws {
        self.path = path
        guard sqlite3_open_v2(path, &db, SQLITE_OPEN_READONLY | SQLITE_OPEN_FULLMUTEX, nil) == SQLITE_OK else {
            if let db { sqlite3_close(db) }; db = nil
            throw DatabaseError.failure("Cannot open this database. Choose a readable copy of chat.db, with its -wal and -shm files beside it when present.")
        }
        sqlite3_busy_timeout(db, 5000)
        do { try run("PRAGMA query_only = ON") { _ in } }
        catch { sqlite3_close(db); db = nil; throw error }
    }
    deinit { sqlite3_close(db) }
    private func run(_ sql: String, bind: Int64? = nil, row: (OpaquePointer) -> Void) throws {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK, let stmt else {
            throw DatabaseError.failure("This database could not be read: \(String(cString: sqlite3_errmsg(db)))")
        }
        defer { sqlite3_finalize(stmt) }
        if let bind { sqlite3_bind_int64(stmt, 1, bind) }
        var result = sqlite3_step(stmt)
        while result == SQLITE_ROW { row(stmt); result = sqlite3_step(stmt) }
        guard result == SQLITE_DONE else { throw DatabaseError.failure(String(cString: sqlite3_errmsg(db))) }
    }
    private func string(_ s: OpaquePointer, _ i: Int32) -> String {
        guard let bytes = sqlite3_column_text(s, i) else { return "" }
        return String(cString: bytes)
    }
    private func body(_ s: OpaquePointer, text: Int32, blob: Int32) -> (String, Bool) {
        let plain = string(s, text)
        if !plain.isEmpty { return (plain, false) }
        let length = Int(sqlite3_column_bytes(s, blob))
        if length > 0, let bytes = sqlite3_column_blob(s, blob) {
            if let decoded = DecodeMessageBody(Data(bytes: bytes, count: length)) { return (decoded, false) }
            return ("[Message body could not be decoded]", true)
        }
        return ("", false)
    }
    static func appleDate(_ value: Int64) -> Date? {
        guard value != 0 else { return nil }
        let seconds = abs(value) > 100_000_000_000 ? Double(value) / 1_000_000_000 : Double(value)
        return Date(timeIntervalSinceReferenceDate: seconds)
    }
    func chats() throws -> [Chat] {
        let media = try attachmentLabels()
        var participants: [Int64: [String]] = [:]
        try run("SELECT j.chat_id,h.id FROM chat_handle_join j JOIN handle h ON h.ROWID=j.handle_id ORDER BY h.id") { s in
            participants[sqlite3_column_int64(s, 0), default: []].append(string(s, 1))
        }
        var chats: [Chat] = []
        try run("""
            SELECT c.ROWID,c.guid,c.display_name,c.chat_identifier,
                (SELECT count(*) FROM chat_message_join j WHERE j.chat_id=c.ROWID),m.date,m.text,m.attributedBody,m.ROWID
            FROM chat c LEFT JOIN message m ON m.ROWID=(
                SELECT m2.ROWID FROM chat_message_join j JOIN message m2 ON m2.ROWID=j.message_id
                WHERE j.chat_id=c.ROWID ORDER BY m2.date DESC,m2.ROWID DESC LIMIT 1)
            ORDER BY m.date DESC,c.ROWID DESC
            """) { s in
            let id = sqlite3_column_int64(s, 0)
            let labels = media[sqlite3_column_int64(s, 8)] ?? []
            let text = body(s, text: 6, blob: 7).0.replacingOccurrences(of: "\u{FFFC}", with: labels.isEmpty ? "[attachment]" : "").trimmingCharacters(in: .whitespacesAndNewlines)
            let snippet = ([text] + labels).filter { !$0.isEmpty }.joined(separator: " ")
            chats.append(Chat(id: id, guid: string(s, 1), displayName: string(s, 2), identifier: string(s, 3),
                handles: participants[id] ?? [], count: Int(sqlite3_column_int64(s, 4)),
                lastDate: Self.appleDate(sqlite3_column_int64(s, 5)), snippet: snippet.isEmpty ? "Attachment or service message" : snippet))
        }
        return chats
    }
    private func attachmentLabels(chatID: Int64? = nil) throws -> [Int64: [String]] {
        var attachments: [Int64: [String]] = [:]
        var columns: Set<String> = []
        try run("PRAGMA table_info(attachment)") { columns.insert(string($0, 1)) }
        func col(_ name: String, fallback: String = "''") -> String { columns.contains(name) ? "t.\(name)" : fallback }
        try run("""
            SELECT a.message_id,t.transfer_name,t.filename,\(col("mime_type")),\(col("uti")),\(col("is_sticker", fallback: "0")) FROM message_attachment_join a
            JOIN attachment t ON t.ROWID=a.attachment_id
            \(chatID == nil ? "" : "JOIN chat_message_join j ON j.message_id=a.message_id WHERE j.chat_id=?") ORDER BY t.ROWID
            """, bind: chatID) { s in
            let name = string(s, 1)
            let fallback = (string(s, 2) as NSString).lastPathComponent
            let label = MediaPlaceholder.label(name: name.isEmpty ? fallback : name, mime: string(s, 3), uti: string(s, 4), sticker: sqlite3_column_int(s, 5) != 0)
            attachments[sqlite3_column_int64(s, 0), default: []].append(label)
        }
        return attachments
    }
    func messages(chatID: Int64) throws -> [Message] {
        var attachments = try attachmentLabels(chatID: chatID)
        var result: [Message] = []
        // Optional columns vary between macOS versions.
        var columns: Set<String> = []
        try run("PRAGMA table_info(message)") { columns.insert(string($0, 1)) }
        func col(_ name: String, fallback: String = "''") -> String { columns.contains(name) ? "m.\(name)" : fallback }
        try run("""
            SELECT m.ROWID,m.guid,m.date,h.id,m.is_from_me,m.text,m.attributedBody,
            \(col("associated_message_type", fallback: "0")),\(col("associated_message_guid")),
            \(col("thread_originator_guid")),\(col("is_system_message", fallback: "0")),
            \(col("item_type", fallback: "0")),\(col("associated_message_emoji")),\(col("cache_has_attachments", fallback: "0"))
            FROM message m JOIN chat_message_join j ON j.message_id=m.ROWID
            LEFT JOIN handle h ON h.ROWID=m.handle_id WHERE j.chat_id=? ORDER BY m.date,m.ROWID
            """, bind: chatID) { s in
            let id = sqlite3_column_int64(s, 0)
            let decoded = body(s, text: 5, blob: 6)
            if attachments[id] == nil && (sqlite3_column_int(s, 13) != 0 || decoded.0.contains("\u{FFFC}")) {
                attachments[id] = ["[attachment]"]
            }
            let type = Int(sqlite3_column_int(s, 7))
            var text = decoded.0.replacingOccurrences(of: "\u{FFFC}", with: "")
            if text.isEmpty && (2000..<4000).contains(type) {
                let names = ["Loved", "Liked", "Disliked", "Laughed", "Emphasized", "Questioned"]
                let offset = type % 1000
                text = (type >= 3000 ? "Removed reaction: " : "Reaction: ") + (offset < names.count ? names[offset] : (string(s, 12).isEmpty ? "Custom reaction" : string(s, 12)))
            }
            let system = sqlite3_column_int(s, 10) != 0 || sqlite3_column_int(s, 11) != 0
            if text.isEmpty && system && attachments[id] == nil { text = "[Conversation event]" }
            if text.isEmpty && attachments[id] == nil { text = "[Non-text message]" }
            result.append(Message(id: id, guid: string(s, 1), date: Self.appleDate(sqlite3_column_int64(s, 2)),
                sender: string(s, 3), fromMe: sqlite3_column_int(s, 4) != 0, text: text,
                reactionType: type, associatedGUID: string(s, 8), replyGUID: string(s, 9), system: system,
                attachments: attachments[id] ?? [], unreadable: decoded.1))
        }
        return result
    }
}

struct ExportOptions: Equatable {
    var stripEmoji = false
    var removeReactions = true
    var removeSystem = true
    // Automatic for exports; disabled internally only to preserve original search context.
    var removeEmpty = true
    var anonymize = false
    var dateFilter = false
    var startDate = Calendar.current.date(byAdding: .year, value: -1, to: Date())!
    var endDate = Date()
}

enum ExportFormat: String, CaseIterable, Identifiable {
    case markdown = "Markdown", csv = "CSV", json = "JSON"
    var id: String { rawValue }
    var ext: String { switch self { case .markdown: return "md"; case .csv: return "csv"; case .json: return "json" } }
    var detail: String { switch self {
        case .markdown: return "A clean transcript: timestamp, sender, and message."
        case .csv: return "Three columns: timestamp, sender, text. One message per row."
        case .json: return "Timestamp, sender, and text as structured message records."
    } }
}

struct ExportRow: Codable, Identifiable {
    let id: Int64
    let guid: String
    let timestamp: String
    let sender: String
    let fromMe: Bool
    let type: String
    let text: String
    let attachments: [String]
    let replyTo: String?
    let reactionTo: String?
}

enum Exporter {
    /// Normalize layout artifacts without transliterating or guessing at the original words.
    static func cleanText(_ value: String) -> String {
        var text = value.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
            .replacingOccurrences(of: "\u{2028}", with: "\n").replacingOccurrences(of: "\u{2029}", with: "\n")
            .replacingOccurrences(of: "\u{FEFF}", with: "").replacingOccurrences(of: "\u{200B}", with: "")
        text = String(text.unicodeScalars.filter { $0.properties.generalCategory != .control || $0 == "\n" || $0 == "\t" })
        text = text.replacingOccurrences(of: "[\\p{Zs}\\t]+", with: " ", options: .regularExpression)
        let lines = text.components(separatedBy: "\n").map { $0.trimmingCharacters(in: .whitespaces) }
        return lines.joined(separator: "\n").replacingOccurrences(of: "\n{3,}", with: "\n\n", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
    static func isEmptyOrDots(_ text: String) -> Bool {
        text.unicodeScalars.allSatisfy { CharacterSet.whitespacesAndNewlines.contains($0) || ".…⋯·•".unicodeScalars.contains($0) }
    }
    static func singleLine(_ text: String) -> String {
        cleanText(text).replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
    }
    static func strippingEmoji(_ text: String) -> String {
        String(text.filter { char in
            let scalars = char.unicodeScalars
            return !scalars.contains { $0.properties.isEmojiPresentation || $0.value == 0xFE0F || $0.value == 0x20E3 || ($0.properties.isEmoji && $0.value > 127) }
        })
    }
    static func rows(_ messages: [Message], options: ExportOptions, names: [String: String] = [:]) -> [ExportRow] {
        let handles = Set(messages.filter { !$0.fromMe }.map(\.sender)).sorted()
        let aliases = Dictionary(uniqueKeysWithValues: handles.enumerated().map { ($0.element, "Person \($0.offset + 1)") })
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let start = Calendar.current.startOfDay(for: options.startDate)
        let end = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: options.endDate))!
        return messages.compactMap { message in
            if options.removeReactions && message.isReaction { return nil }
            if options.removeSystem && message.system && message.attachments.isEmpty { return nil }
            if options.dateFilter {
                guard let date = message.date, date >= start && date < end else { return nil }
            }
            var body = cleanText(options.stripEmoji ? strippingEmoji(message.text) : message.text)
            if options.removeEmpty && isEmptyOrDots(body) { body = "" }
            let attachments = message.attachments
            let text = ([body] + attachments).filter { !$0.isEmpty }.joined(separator: "\n")
            if text.isEmpty && attachments.isEmpty { return nil }
            let sender = message.fromMe ? "Me" : (options.anonymize ? aliases[message.sender]! : (names[message.sender] ?? (message.sender.isEmpty ? "Unknown" : message.sender)))
            return ExportRow(id: message.id, guid: message.guid, timestamp: message.date.map { iso.string(from: $0) } ?? "",
                sender: sender, fromMe: message.fromMe, type: message.isReaction ? "reaction" : (message.system ? "system" : "message"),
                text: text, attachments: attachments, replyTo: message.replyGUID.isEmpty ? nil : message.replyGUID,
                reactionTo: message.associatedGUID.isEmpty ? nil : message.associatedGUID)
        }
    }
    static func render(rows: [ExportRow], title: String, format: ExportFormat, timeZone: TimeZone = .current) throws -> Data {
        struct TranscriptRow: Codable { let timestamp: String; let sender: String; let text: String }
        let parser = ISO8601DateFormatter()
        parser.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let secondsParser = ISO8601DateFormatter()
        let display = DateFormatter()
        display.locale = Locale(identifier: "en_US_POSIX")
        display.calendar = Calendar(identifier: .gregorian)
        display.timeZone = timeZone
        display.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let transcript = rows.map { row in
            let date = parser.date(from: row.timestamp) ?? secondsParser.date(from: row.timestamp)
            return TranscriptRow(timestamp: date.map { display.string(from: $0) } ?? row.timestamp,
                                 sender: singleLine(row.sender), text: cleanText(row.text))
        }
        switch format {
        case .json:
            struct Document: Codable { let conversation: String; let timezone: String; let messages: [TranscriptRow] }
            let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
            return try encoder.encode(Document(conversation: singleLine(title), timezone: timeZone.identifier, messages: transcript))
        case .csv:
            func quote(_ value: String) -> String { "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\"" }
            let header = "timestamp,sender,text\r\n"
            let body = transcript.map { row in
                [row.timestamp, row.sender, singleLine(row.text)].map(quote).joined(separator: ",")
            }.joined(separator: "\r\n")
            // The BOM prevents spreadsheets from interpreting UTF-8 as Mac Roman / ANSI.
            var data = Data([0xEF, 0xBB, 0xBF])
            data.append(Data((header + body + (body.isEmpty ? "" : "\r\n")).utf8))
            return data
        case .markdown:
            var result = "# \(singleLine(title))\n\n\(transcript.count) messages · \(timeZone.identifier)\n\n"
            for row in transcript {
                result += "**\(row.timestamp) · \(row.sender)**\n\n"
                result += row.text.split(separator: "\n", omittingEmptySubsequences: false).map { "> " + $0 }.joined(separator: "\n") + "\n\n"
            }
            return Data(result.utf8)
        }
    }
}
