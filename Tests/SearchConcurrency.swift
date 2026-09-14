import Foundation

@main struct SearchConcurrencyTests {
    @MainActor static func main() async {
        let store = Store()
        let large = (0..<50_000).map { id in
            ExportRow(id: Int64(id), guid: "g-\(id)", timestamp: "2026-09-14T12:00:00.000Z", sender: "Me", fromMe: true,
                type: "message", text: "Apple apples orange. " + String(repeating: "ordinary words ", count: 10), attachments: [], replyTo: nil, reactionTo: nil)
        }
        store.allRows = large
        var ticks = 0
        var maximumGap = 0.0
        let heartbeat = Task { @MainActor in
            var previous = Date()
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 10_000_000)
                let now = Date(); maximumGap = max(maximumGap, now.timeIntervalSince(previous)); previous = now; ticks += 1
            }
        }
        let start = Date()
        store.messageSearch = "apple"; store.updateMatches()
        while store.searchingConversation { try? await Task.sleep(nanoseconds: 10_000_000) }
        precondition(store.keywordMatches.count == 100_000)
        precondition(ticks > 5, "Main actor heartbeat must run while search executes")
        // Generous enough for a loaded machine, but catches the previous full synchronous scan.
        precondition(maximumGap < 0.250, "Search blocked the main actor for \(maximumGap) seconds")
        print("50,000-message search: \(Int(Date().timeIntervalSince(start) * 1000))ms including debounce; main-actor maximum scheduling gap \(Int(maximumGap * 1000))ms.")
        for query in ["a", "ap", "appl", "orange"] { store.messageSearch = query; store.updateMatches() }
        while store.searchingConversation { try? await Task.sleep(nanoseconds: 10_000_000) }
        precondition(store.appliedQuery == "orange" && store.keywordMatches.count == 50_000, "Only newest query may commit")
        store.messageSearch = "apple"; store.updateMatches()
        store.messageSearch = ""; store.updateMatches()
        try? await Task.sleep(nanoseconds: 250_000_000)
        precondition(store.appliedQuery.isEmpty && store.keywordMatches.isEmpty && !store.searchingConversation, "Clear must cancel pending results")
        store.messageSearch = "apple"; store.updateMatches()
        store.loadSelection()
        try? await Task.sleep(nanoseconds: 250_000_000)
        precondition(store.keywordMatches.isEmpty && store.appliedQuery.isEmpty, "Changing chats must reject stale search results")
        store.loadDemo()
        precondition(store.isDemo && store.path.isEmpty && store.chats.count == 5)
        precondition(store.rows.count == 11 && store.rows.contains { $0.text == "[photo]" })
        store.search = "apple"; store.searchEverywhere()
        while store.searching { try? await Task.sleep(nanoseconds: 10_000_000) }
        precondition(store.searchResults.count == 4, "Fictional demo must support global keyword search")
        store.messageSearch = "apple"; store.updateMatches()
        while store.searchingConversation { try? await Task.sleep(nanoseconds: 10_000_000) }
        precondition(store.keywordMatches.count == 4, "Fictional demo must support match navigation")
        heartbeat.cancel()
        print("Passed async search responsiveness, rapid typing, clear, and chat-switch checks.")
    }
}
