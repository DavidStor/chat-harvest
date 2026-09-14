import Foundation
import SQLite3

func csvPlaceholderCheck(_ rows: [ExportRow]) -> Bool {
    guard let data = try? Exporter.render(rows: rows, title: "Test", format: .csv), let text = String(data: data, encoding: .utf8) else { return false }
    return text.contains("\"[photo]\"") && !text.contains("\"[photo]\",\"[photo]\"")
}
var checks = 0
func expect(_ condition: @autoclosure () -> Bool, _ label: String) {
    checks += 1
    if !condition() { fputs("FAIL: \(label)\n", stderr); exit(1) }
}
let instant = Date(timeIntervalSince1970: 1_700_000_000)
func message(_ id: Int64, _ text: String, sender: String = "+15550001", reaction: Int = 0, system: Bool = false, files: [String] = [], date: Date? = instant) -> Message {
    Message(id: id, guid: "guid-\(id)", date: date, sender: sender, fromMe: sender == "Me", text: text, reactionType: reaction, associatedGUID: reaction == 0 ? "" : "p:0/guid-1", replyGUID: id == 2 ? "guid-1" : "", system: system, attachments: files, unreadable: false)
}
expect(Exporter.strippingEmoji("Hello 👨‍👩‍👧‍👦 👍🏽 🇨🇦 1️⃣ ❤️ 123 # * café 中文") == "Hello      123 # * café 中文", "emoji grapheme handling preserves digits, punctuation, accents and CJK")
expect(MediaPlaceholder.label(name: "IMG.HEIC") == "[photo]", "photo extension fallback")
expect(MediaPlaceholder.label(name: "unknown", mime: "video/quicktime") == "[video]", "video MIME classification")
expect(MediaPlaceholder.label(name: "unknown", uti: "com.apple.coreaudio-format") == "[audio]", "audio UTI classification")
expect(MediaPlaceholder.label(name: "sticker.heic", mime: "image/heic", sticker: true) == "[sticker]", "sticker flag wins over image MIME")
expect(MediaPlaceholder.label(name: "report.pdf") == "[attachment]", "generic file fallback")
let original = [message(1, "Hello, \"friend\"\nHow are you? 😀"), message(2, "Great", sender: "Me"), message(3, "Loved", reaction: 2000), message(4, "Removed", reaction: 3000), message(5, "Custom", reaction: 2007), message(6, "Joined", system: true), message(7, "", files: ["[photo]"]), message(8, "👍🏽")]
var options = ExportOptions()
let standard = Exporter.rows(original, options: options)
expect(standard.count == 4, "default filters preserve messages and attachment-only rows")
options.removeReactions = false; options.removeSystem = false
expect(Exporter.rows(original, options: options).count == 8, "disabled filters preserve all rows")
options = ExportOptions(); options.stripEmoji = true
let clean = Exporter.rows(original, options: options)
expect(clean.count == 3, "emoji-only rows omitted and media-only rows retained")
expect(!clean[0].text.contains("😀"), "emoji removal")
options.anonymize = true
let anonymous = Exporter.rows(original, options: options)
expect(anonymous[0].sender == "Person 1" && anonymous[1].sender == "Me", "speaker aliases")
options.dateFilter = true; options.startDate = instant; options.endDate = instant
expect(Exporter.rows(original, options: options).count == 3, "inclusive same-day filter")
options.startDate = instant.addingTimeInterval(86400)
expect(Exporter.rows(original, options: options).isEmpty, "reversed date range")
let json = try Exporter.render(rows: standard, title: "Test", format: .json)
let object = try JSONSerialization.jsonObject(with: json) as! [String: Any]
let jsonRows = object["messages"] as! [[String: Any]]
expect(jsonRows.count == 4, "JSON count")
expect(jsonRows[2]["text"] as? String == "[photo]", "JSON media-only row has readable body")
expect(csvPlaceholderCheck(standard), "CSV media placeholder in text column")
expect(jsonRows[0]["text"] as? String == original[0].text, "JSON exact multiline Unicode roundtrip")
expect(Set(jsonRows[1].keys) == ["timestamp", "sender", "text"], "JSON exposes only readable message fields")
let csv = String(data: try Exporter.render(rows: standard, title: "Test", format: .csv), encoding: .utf8)!
expect(csv.contains("\"Hello, \"\"friend\"\" How are you? 😀\""), "CSV quotes and paragraph flattening")
let markdown = String(data: try Exporter.render(rows: standard, title: "Test", format: .markdown), encoding: .utf8)!
expect(markdown.contains("> How are you? 😀") && markdown.contains("> [photo]"), "Markdown body and attachment labels")
expect(Database.appleDate(0) == nil, "unknown dates stay unknown")
expect(Database.appleDate(700_000_000) == Database.appleDate(700_000_000_000_000_000), "seconds and nanoseconds normalized")
let attributed = NSAttributedString(string: "Archived café 👋\nSecond line")
let legacy = NSArchiver.archivedData(withRootObject: attributed)
expect(DecodeMessageBody(legacy) == attributed.string, "typedstream body decoded")
let keyed = try NSKeyedArchiver.archivedData(withRootObject: attributed, requiringSecureCoding: true)
expect(DecodeMessageBody(keyed) == attributed.string, "keyed body decoded")
expect(DecodeMessageBody(Data([0, 1, 2, 3])) == nil, "malformed body does not crash")

// Use a disposable SQLite fixture to exercise joins, blobs, timestamps, and read-only access.
let fixture = NSTemporaryDirectory() + "chat-harvest-test-\(UUID().uuidString).db"
defer { try? FileManager.default.removeItem(atPath: fixture) }
var db: OpaquePointer?
sqlite3_open(fixture, &db)
let schema = """
CREATE TABLE chat (ROWID INTEGER PRIMARY KEY, guid TEXT, display_name TEXT, chat_identifier TEXT);
CREATE TABLE handle (ROWID INTEGER PRIMARY KEY, id TEXT);
CREATE TABLE chat_handle_join (chat_id INTEGER, handle_id INTEGER);
CREATE TABLE chat_message_join (chat_id INTEGER, message_id INTEGER);
CREATE TABLE message (ROWID INTEGER PRIMARY KEY, guid TEXT, date INTEGER, handle_id INTEGER, is_from_me INTEGER, text TEXT, attributedBody BLOB, associated_message_type INTEGER, associated_message_guid TEXT);
CREATE TABLE attachment (ROWID INTEGER PRIMARY KEY, transfer_name TEXT, filename TEXT);
CREATE TABLE message_attachment_join (message_id INTEGER, attachment_id INTEGER);
INSERT INTO chat VALUES(1,'chat-guid','Fixture group','group');
INSERT INTO handle VALUES(1,'+15550001');
INSERT INTO chat_handle_join VALUES(1,1);
INSERT INTO message VALUES(1,'guid-1',700000000000000000,1,0,'First',NULL,0,NULL);
INSERT INTO message VALUES(2,'guid-2',700000001000000000,0,1,NULL,X'\(legacy.map { String(format: "%02x", $0) }.joined())',0,NULL);
INSERT INTO chat_message_join VALUES(1,2),(1,1);
INSERT INTO attachment VALUES(1,'photo.png','/local/photo.png');
INSERT INTO message_attachment_join VALUES(2,1);
ALTER TABLE attachment ADD COLUMN mime_type TEXT;
ALTER TABLE attachment ADD COLUMN uti TEXT;
ALTER TABLE attachment ADD COLUMN is_sticker INTEGER DEFAULT 0;
INSERT INTO attachment VALUES(2,'unknown',NULL,'video/quicktime','com.apple.quicktime-movie',0);
INSERT INTO attachment VALUES(3,'sticker.heic',NULL,'image/heic','public.heic',1);
INSERT INTO message_attachment_join VALUES(2,2),(2,3);
ALTER TABLE message ADD COLUMN cache_has_attachments INTEGER DEFAULT 0;
ALTER TABLE message ADD COLUMN item_type INTEGER DEFAULT 0;
UPDATE message SET item_type=3 WHERE ROWID=2;
INSERT INTO message (ROWID,guid,date,handle_id,is_from_me,cache_has_attachments) VALUES(3,'guid-3',699999999000000000,1,0,1);
INSERT INTO chat_message_join VALUES(1,3);
"""
expect(sqlite3_exec(db, schema, nil, nil, nil) == SQLITE_OK, "fixture created")
sqlite3_close(db)
let before = try Data(contentsOf: URL(fileURLWithPath: fixture))
do {
    let database = try Database(path: fixture)
    let chats = try database.chats()
    expect(chats.count == 1 && chats[0].count == 3 && chats[0].handles == ["+15550001"], "chat join counts and participants")
    expect(chats[0].snippet == attributed.string + " [photo] [video] [sticker]", "latest blob preview")
    let messages = try database.messages(chatID: 1)
    expect(messages.map(\.id) == [3,1,2], "chronological database order")
    expect(messages[2].text == attributed.string && messages[2].attachments == ["[photo]", "[video]", "[sticker]"], "body and attachment database join")
    expect(messages[0].attachments == ["[attachment]"], "missing attachment metadata gets fallback")
    let exported = Exporter.rows(messages, options: ExportOptions())
    expect(exported.count == 3, "system filtering preserves media and missing-file rows")
    expect(exported[0].text == "[attachment]", "missing media produces readable body")
    expect(exported[2].text.hasSuffix("[photo]\n[video]\n[sticker]"), "all media placeholders appear in body")
    let missing = try database.messages(chatID: 999)
    expect(missing.isEmpty, "unknown chat empty")
}
let after = try Data(contentsOf: URL(fileURLWithPath: fixture))
expect(before == after, "source database unchanged")
// Keyword matching uses substring semantics and UTF-16 ranges for native highlighting.
let keywordText = "🍎 Apple apples PINEAPPLE café CAFÉ"
let appleRanges = KeywordSearch.ranges(in: keywordText, query: " apple ")
expect(appleRanges.count == 3, "substring search includes plurals and mixed case")
expect(appleRanges.allSatisfy { (keywordText as NSString).substring(with: $0).lowercased() == "apple" }, "highlight ranges remain correct after emoji")
expect(KeywordSearch.ranges(in: keywordText, query: "cafe").count == 2, "search ignores accents and Unicode normalization")
expect(KeywordSearch.ranges(in: "apple", query: " ").isEmpty, "blank query has no matches")
expect(KeywordSearch.ranges(in: "a.b a*b", query: ".").count == 1, "punctuation is literal, not a wildcard")
let entries = [MessageSearchEntry(chatID: 1, messageID: 1, text: "apples", date: instant),
               MessageSearchEntry(chatID: 2, messageID: 2, text: "APPLE", date: instant.addingTimeInterval(1)),
               MessageSearchEntry(chatID: 3, messageID: 3, text: "orange", date: instant)]
expect(KeywordSearch.search(entries, query: "apple").map(\.messageID) == [2,1], "global results span chats and sort newest first")
let repeated = Exporter.rows([message(44, "Apple and apples")], options: ExportOptions())
let occurrences = KeywordSearch.matches(rows: repeated, query: "apple")
expect(occurrences.count == 2 && occurrences[0].id != occurrences[1].id, "navigation counts repeated occurrences separately")
expect(KeywordSearch.snippet(String(repeating: "x", count: 300) + " apples", query: "apple").contains("apples"), "result snippets include old/deep matches")
let reverseRange = CalendarRange.normalized(instant.addingTimeInterval(86400), instant)
expect(reverseRange.0 < reverseRange.1, "reverse calendar selections normalize to valid range")
let sameDay = CalendarRange.normalized(instant, instant)
expect(sameDay.0 == sameDay.1, "one-day calendar range")
var toronto = Calendar(identifier: .gregorian)
toronto.timeZone = TimeZone(identifier: "America/Toronto")!
let dst = toronto.date(from: DateComponents(year: 2026, month: 3, day: 10))!
let sevenDays = CalendarRange.lastDays(7, endingAt: dst, calendar: toronto)
expect(toronto.dateComponents([.day], from: sevenDays.0, to: sevenDays.1).day == 6, "seven-day preset is inclusive across daylight saving")

let unicodeBody = "I’m happy… café 中文 👨‍👩‍👧‍👦"
let unicodeRows = Exporter.rows([message(101, unicodeBody, sender: "Мария"),
    message(102, " . "), message(103, "\n… • ·\n"), message(104, "\n\t"),
    message(105, " . ", files: ["[photo]"]), message(106, "?"),
    message(107, "  First\t  paragraph\r\n  \r\n  Second  paragraph  ")], options: ExportOptions())
expect(unicodeRows.count == 4, "blank and dot-only rows skipped while questions and media remain")
expect(unicodeRows[0].text == unicodeBody, "real Unicode, emoji joiners and punctuation preserved")
expect(unicodeRows[1].text == "[photo]", "media-only body appears once")
expect(unicodeRows[3].text == "First paragraph\n\nSecond paragraph", "indentation and whitespace normalized while preserving paragraphs")
var keepDots = ExportOptions(); keepDots.removeEmpty = false
expect(Exporter.rows([message(108, ".")], options: keepDots).count == 1, "unfiltered search context can retain original dot-only text")
var stripForCleanup = ExportOptions(); stripForCleanup.stripEmoji = true
let cleanupInputs = [message(109, "😂."), message(110, "😂 …"), message(111, "😂"),
    message(112, "😂.", files: ["[photo]", "[video]", "[sticker]"]),
    message(113, "😂?"), message(114, "Hello 😂."),
    message(115, "[Message body could not be decoded]"), message(116, "[Non-text message]")]
let cleanedAfterEmoji = Exporter.rows(cleanupInputs, options: stripForCleanup)
expect(cleanedAfterEmoji.map(\.text) == ["[photo]\n[video]\n[sticker]", "?", "Hello .", "[Message body could not be decoded]", "[Non-text message]"],
       "automatic cleanup removes emoji leftovers without dropping media, words, questions or diagnostic placeholders")
expect(Exporter.rows([message(117, "😂.")], options: ExportOptions()).first?.text == "😂.",
       "emoji messages remain when emoji stripping is off")
let cleanCSV = try Exporter.render(rows: unicodeRows, title: "Example", format: .csv, timeZone: toronto.timeZone)
expect(Array(cleanCSV.prefix(3)) == [0xEF,0xBB,0xBF], "CSV has explicit UTF-8 BOM for spreadsheet detection")
let csvText = String(data: cleanCSV.dropFirst(3), encoding: .utf8)!
expect(csvText.hasPrefix("timestamp,sender,text\r\n"), "CSV has exactly three headers")
expect(csvText.contains("Мария") && csvText.contains("I’m happy…"), "UTF-8 names and punctuation survive serialization")
expect(csvText.components(separatedBy: "\r\n").count == unicodeRows.count + 2, "one physical CSV row per message")
expect(csvText.contains("2023-11-14 17:13:20"), "CSV uses exact requested date format and Toronto timezone")
expect(!csvText.contains("guid-") && !csvText.contains("from_me"), "CSV has no internal identifiers")
let cleanMarkdown = String(data: try Exporter.render(rows: unicodeRows, title: "Example", format: .markdown), encoding: .utf8)!
expect(!cleanMarkdown.contains("Message ID") && !cleanMarkdown.contains("guid-"), "Markdown omits internal identifiers")
let dstRows = [message(109, "Before", date: toronto.date(from: DateComponents(year: 2026, month: 3, day: 8, hour: 1, minute: 59))!),
               message(110, "After", date: toronto.date(from: DateComponents(year: 2026, month: 3, day: 8, hour: 3, minute: 1))!)]
let dstCSV = String(data: try Exporter.render(rows: Exporter.rows(dstRows, options: ExportOptions()), title: "DST", format: .csv, timeZone: toronto.timeZone), encoding: .utf8)!
expect(dstCSV.contains("2026-03-08 01:59:00") && dstCSV.contains("2026-03-08 03:01:00"), "timestamps apply daylight saving correctly")
let boundary = ISO8601DateFormatter().date(from: "2025-05-23T03:07:23Z")!
let boundaryCSV = String(data: try Exporter.render(rows: Exporter.rows([message(111, "Boundary", date: boundary)], options: ExportOptions()), title: "Boundary", format: .csv, timeZone: toronto.timeZone), encoding: .utf8)!
expect(boundaryCSV.contains("2025-05-22 23:07:23"), "local timezone correctly crosses midnight")
if let directory = ProcessInfo.processInfo.environment["CHAT_HARVEST_QA_DIR"] {
    try cleanCSV.write(to: URL(fileURLWithPath: directory).appendingPathComponent("unicode.csv"))
}

expect(KeywordSearch.matches(rows: standard, query: "a", cancelled: { true }).isEmpty, "cancelled in-chat search stops without partial matches")
expect(KeywordSearch.search(entries, query: "apple", cancelled: { true }).isEmpty, "cancelled global search stops without partial results")
expect(KeywordSearch.ranges(in: String(repeating: "apple ", count: 1000), query: "apple", cancelled: { true }).isEmpty, "long message highlighting supports cancellation")
for count in [0, 1, 159, 160, 161, 12_167] {
    let latest = TimelineWindow.range(count: count)
    expect(latest.upperBound == count && latest.count <= 160, "latest viewport is bounded for \(count) messages")
    if count > 0 {
        for position in [0, count / 2, count - 1] {
            let window = TimelineWindow.range(count: count, around: position)
            expect(window.contains(position) && window.count <= 160, "distant match stays inside bounded viewport")
        }
    }
}
var page = TimelineWindow.range(count: 1000, around: 0)
var covered = Set(page)
while page.upperBound < 1000 {
    let next = TimelineWindow.page(page, direction: 1, count: 1000)
    expect(next.lowerBound < page.upperBound && next.count <= 160, "context pages overlap without growing")
    covered.formUnion(next); page = next
}
expect(covered.count == 1000, "paging can reach every message without gaps")
expect(TimelineWindow.clamped(900..<1060, count: 100).count == 100, "filtering clamps old viewport safely")

print("Passed \(checks) checks.")

if CommandLine.arguments.count > 1 {
    let database = try Database(path: CommandLine.arguments[1])
    let chats = try database.chats()
    var total = 0; var unreadable = 0; var reactions = 0
    for chat in chats {
        let messages = try database.messages(chatID: chat.id)
        total += messages.count
        unreadable += messages.filter(\.unreadable).count
        reactions += messages.filter(\.isReaction).count
    }
    print("Read-only validation: \(chats.count) chats, \(total) joined messages, \(unreadable) undecodable bodies, \(reactions) reactions. No message content printed.")
}
