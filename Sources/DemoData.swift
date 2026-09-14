import Foundation

/// Fictional, deterministic conversations for trying the app and public screenshots.
enum DemoData {
    static let names = ["nora@example.invalid": "Nora Patel", "carolina@example.invalid": "Carolina Smith", "leo@example.invalid": "Leo Park", "sam@example.invalid": "Sam Rivera"]
    static let transcripts: [(String, [String], [(Bool, String)])] = [
        ("Carolina Smith", ["carolina@example.invalid"], [
            (false, "Sunday picnic? The forecast looks perfect ☀️"),
            (true, "Absolutely. Same park as last time?"),
            (false, "Yes! Meet by the lake at 2."),
            (true, "I'll bring a blanket and some apples."),
            (false, "Perfect. I'll make sandwiches and bring apple cider."),
            (true, "The little bakery on Maple Street was so good last time."),
            (false, "Their apple tart is worth the detour."),
            (true, "Adding it to the list 📝"),
            (false, "[photo]"),
            (false, "Found our picnic spot!"),
            (true, "Looks great. Apples, sandwiches, sunshine. Sorted.")
        ]),
        ("Weekend crew", ["leo@example.invalid", "sam@example.invalid"], [
            (false, "Anyone up for a trail walk on Sunday?"), (true, "Count me in. Easy route or ambitious route?"),
            (false, "Easy. With a very ambitious coffee stop."), (true, "That's my kind of plan."),
            (false, "[video]"), (false, "Here's the route. About an hour each way.")
        ]),
        ("Nora Patel", ["nora@example.invalid"], [
            (false, "Found a cabin with a lake view."),
            (true, "That sounds perfect for the weekend."),
            (false, "Booked the cabin for the 20th.")
        ]),
        ("Leo Park", ["leo@example.invalid"], [
            (true, "What was that book you recommended?"), (false, "The one about learning to draw?"),
            (true, "Yes! I finally have a free weekend."), (false, "I'll bring it to the cafe tomorrow."),
            (true, "Coffee's on me. Thanks!")
        ]),
        ("Sam Rivera", ["sam@example.invalid"], [
            (false, "Made a first draft of the poster."), (false, "[photo]"),
            (true, "Love the blue. Could the date be a little bigger?"), (false, "Done! Sending the new version shortly.")
        ])
    ]
    static func messages(chatID: Int64) -> [Message] {
        guard transcripts.indices.contains(Int(chatID) - 1) else { return [] }
        let transcript = transcripts[Int(chatID) - 1]
        let base = ISO8601DateFormatter().date(from: chatID == 1 ? "2026-09-13T17:00:00Z" : "2026-09-12T17:00:00Z")!
        return transcript.2.enumerated().map { offset, item in
            let media = ["[photo]", "[video]"].contains(item.1)
            let id = chatID * 100 + Int64(offset)
            return Message(id: id, guid: "demo-message-\(id)", date: base.addingTimeInterval(Double(offset * 180)),
                           sender: item.0 ? "Me" : transcript.1[0], fromMe: item.0, text: media ? "" : item.1,
                           reactionType: 0, associatedGUID: "", replyGUID: "", system: false,
                           attachments: media ? [item.1] : [], unreadable: false)
        }
    }
    static var chats: [Chat] {
        transcripts.enumerated().map { offset, transcript in
            let id = Int64(offset + 1), messages = messages(chatID: Int64(offset + 1))
            return Chat(id: id, guid: "demo-chat-\(id)", displayName: transcript.0, identifier: transcript.1[0],
                        handles: transcript.1, count: messages.count, lastDate: messages.last?.date, snippet: transcript.2.last!.1)
        }
    }
}
