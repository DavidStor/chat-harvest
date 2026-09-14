import SwiftUI
import AppKit
import Contacts
import UniformTypeIdentifiers

@MainActor final class Store: ObservableObject {
    @Published var isDemo = false
    @Published var chats: [Chat] = []
    @Published var messages: [Message] = []
    @Published var selection: Int64?
    @Published var search = ""
    @Published var messageSearch = ""
    @Published var options = ExportOptions()
    @Published var format = ExportFormat.markdown
    @Published var rows: [ExportRow] = []
    @Published var allRows: [ExportRow] = []
    @Published var keywordMatches: [KeywordMatch] = []
    @Published var activeMatch = 0
    @Published var searchResults: [MessageSearchEntry] = []
    @Published var indexing = false
    @Published var searching = false
    private var searchIndex: [MessageSearchEntry] = []
    private var indexTask: Task<[MessageSearchEntry], Error>?
    private var searchTask: Task<[MessageSearchEntry], Error>?
    private var matchTask: Task<[KeywordMatch], Error>?
    private var matchGeneration = UUID()
    private var globalSearchGeneration = UUID()
    @Published var appliedQuery = ""
    @Published var searchingConversation = false
    @Published var globalResultLimit = 100
    private var allRowPositions: [Int64: Int] = [:]
    var focusedRowPosition: Int? { focusedMatch.flatMap { allRowPositions[$0.messageID] } }
    var timelineHasQuery: Bool { !appliedQuery.isEmpty }
    var navigationID: String { appliedQuery + ":" + (focusedMatch?.id ?? "") }
    private var pendingJump: (Int64, String)?
    var hasQuery: Bool { !KeywordSearch.query(messageSearch).isEmpty }
    var hasGlobalQuery: Bool { !KeywordSearch.query(search).isEmpty }
    var timelineRows: [ExportRow] { timelineHasQuery ? allRows : rows }
    var focusedMatch: KeywordMatch? { keywordMatches.indices.contains(activeMatch) ? keywordMatches[activeMatch] : nil }
    @Published var loading = false
    @Published var loadingMessages = false
    @Published var matchingContacts = false
    @Published var contactsMatched = false
    @Published var error: String?
    @Published var status = "Choose your Messages database to get started."
    @Published var path = ""
    @Published var names: [String: String] = [:]
    @Published var aliases: [String: String] = UserDefaults.standard.dictionary(forKey: "chatAliases") as? [String: String] ?? [:]
    private var generation = UUID()
    private var messageGeneration = UUID()
    var chat: Chat? { chats.first { $0.id == selection } }
    var visibleChats: [Chat] { chats }
    func indexMessages(_ chats: [Chat], path: String, token: UUID) {
        indexing = true
        let job = Task.detached(priority: .utility) {
            let database = try Database(path: path)
            var entries: [MessageSearchEntry] = []
            for chat in chats {
                try Task.checkCancellation()
                entries += try database.messages(chatID: chat.id).map {
                    MessageSearchEntry(chatID: chat.id, messageID: $0.id, text: ([$0.text] + $0.attachments).filter { !$0.isEmpty }.joined(separator: "\n"), date: $0.date)
                }
            }
            return entries
        }
        indexTask = job
        Task {
            do {
                let entries = try await job.value
                guard generation == token else { return }
                searchIndex = entries; indexing = false; searchEverywhere()
            } catch {
                guard generation == token, !(error is CancellationError) else { return }
                indexing = false; self.error = "Could not search all messages: " + error.localizedDescription
            }
        }
    }
    func searchEverywhere() {
        searchTask?.cancel()
        let token = UUID(); globalSearchGeneration = token
        guard hasGlobalQuery else { searching = false; searchResults = []; return }
        searching = true
        let query = search, entries = searchIndex
        let job = Task.detached(priority: .userInitiated) {
            try await Task.sleep(nanoseconds: 180_000_000)
            let results = KeywordSearch.search(entries, query: query, cancelled: { Task.isCancelled })
            try Task.checkCancellation()
            return results
        }
        searchTask = job
        Task {
            guard let result = try? await job.value, globalSearchGeneration == token else { return }
            globalResultLimit = 100; searchResults = result; searching = false
        }
    }
    func updateMatches(target: Int64? = nil) {
        matchTask?.cancel()
        let token = UUID(); matchGeneration = token
        let query = KeywordSearch.query(messageSearch)
        guard !query.isEmpty else {
            searchingConversation = false; appliedQuery = ""; keywordMatches = []; activeMatch = 0
            return
        }
        searchingConversation = true
        let snapshot = allRows
        let job = Task.detached(priority: .userInitiated) {
            if target == nil { try await Task.sleep(nanoseconds: 180_000_000) }
            try Task.checkCancellation()
            let result = KeywordSearch.matches(rows: snapshot, query: query, cancelled: { Task.isCancelled })
            try Task.checkCancellation()
            return result
        }
        matchTask = job
        Task {
            guard let result = try? await job.value, matchGeneration == token else { return }
            keywordMatches = result
            activeMatch = target.flatMap { id in result.firstIndex { $0.messageID == id } } ?? 0
            appliedQuery = query; searchingConversation = false
        }
    }
    func moveMatch(_ step: Int) {
        guard !searchingConversation, !keywordMatches.isEmpty else { return }
        activeMatch = (activeMatch + step + keywordMatches.count) % keywordMatches.count
    }
    func openResult(_ result: MessageSearchEntry) {
        if selection == result.chatID {
            messageSearch = search; updateMatches(target: result.messageID)
        } else {
            pendingJump = (result.messageID, search)
            selection = result.chatID
        }
    }
    func title(_ chat: Chat) -> String {
        if let name = aliases[chat.guid], !name.isEmpty { return name }
        if !chat.displayName.trimmingCharacters(in: .whitespaces).isEmpty { return chat.displayName }
        if !chat.handles.isEmpty { return chat.handles.map { names[$0] ?? $0 }.joined(separator: ", ") }
        return chat.identifier.isEmpty ? "Conversation \(chat.id)" : chat.identifier
    }
    func relabel(_ value: String) {
        guard let chat else { return }
        aliases[chat.guid] = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if !isDemo { UserDefaults.standard.set(aliases, forKey: "chatAliases") }
    }
    func chooseDatabase() {
        let panel = NSOpenPanel()
        panel.title = "Open Messages database"
        panel.message = "Choose chat.db. Keep chat.db-wal and chat.db-shm beside a copied database."
        panel.canChooseDirectories = false; panel.allowsMultipleSelection = false
        panel.directoryURL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Desktop")
        if panel.runModal() == .OK, let url = panel.url { open(url.path) }
    }
    func loadDemo() {
        indexTask?.cancel(); searchTask?.cancel(); matchTask?.cancel()
        generation = UUID(); messageGeneration = UUID(); globalSearchGeneration = UUID(); matchGeneration = UUID()
        isDemo = true; path = ""; error = nil; names = DemoData.names; aliases = [:]
        loading = false; loadingMessages = false; indexing = false; searching = false
        search = ""; messageSearch = ""; appliedQuery = ""; searchResults = []; pendingJump = nil
        contactsMatched = true; options = ExportOptions(); format = .csv
        chats = DemoData.chats
        searchIndex = chats.flatMap { chat in
            DemoData.messages(chatID: chat.id).map {
                MessageSearchEntry(chatID: chat.id, messageID: $0.id, text: ([$0.text] + $0.attachments).joined(separator: "\n"), date: $0.date)
            }
        }
        status = "Demo · Fictional conversations · No personal data loaded"
        selection = chats.first?.id; loadSelection()
    }
    func open(_ newPath: String) {
        isDemo = false; names = [:]; contactsMatched = false
        aliases = UserDefaults.standard.dictionary(forKey: "chatAliases") as? [String: String] ?? [:]
        indexTask?.cancel(); searchTask?.cancel(); matchTask?.cancel()
        globalSearchGeneration = UUID(); matchGeneration = UUID(); appliedQuery = ""; searchingConversation = false
        searchIndex = []; searchResults = []; search = ""; messageSearch = ""; allRows = []; keywordMatches = []; pendingJump = nil
        let token = UUID(); generation = token; messageGeneration = UUID()
        loading = true; loadingMessages = false; messages = []; rows = []; chats = []; selection = nil; path = newPath
        status = "Reading conversations…"
        Task {
            do {
                let result = try await Task.detached(priority: .userInitiated) { try Database(path: newPath).chats() }.value
                guard generation == token else { return }
                chats = result; loading = false; status = "\(result.count.formatted()) conversations · Read-only"
                UserDefaults.standard.set(newPath, forKey: "databasePath")
                selection = result.first?.id
                indexMessages(result, path: newPath, token: token)
                if CNContactStore.authorizationStatus(for: .contacts) == .authorized { connectContacts() }
            } catch {
                guard generation == token else { return }
                loading = false; self.error = error.localizedDescription; status = "Unable to open database"
            }
        }
    }
    func loadSelection() {
        matchTask?.cancel(); matchGeneration = UUID(); appliedQuery = ""; searchingConversation = false
        let token = UUID(); messageGeneration = token
        messages = []; rows = []; allRows = []; keywordMatches = []
        let jump = pendingJump; pendingJump = nil
        messageSearch = jump?.1 ?? ""
        guard let id = selection else { loadingMessages = false; return }
        if isDemo {
            messages = DemoData.messages(chatID: id); loadingMessages = false; rebuild(target: jump?.0)
            return
        }
        let currentPath = path
        loadingMessages = true
        Task {
            do {
                let result = try await Task.detached(priority: .userInitiated) { try Database(path: currentPath).messages(chatID: id) }.value
                guard messageGeneration == token else { return }
                messages = result; loadingMessages = false; rebuild(target: jump?.0)
            } catch {
                guard messageGeneration == token else { return }
                loadingMessages = false; self.error = error.localizedDescription
            }
        }
    }
    func rebuild(target: Int64? = nil) {
        rows = Exporter.rows(messages, options: options, names: names)
        var unfiltered = options
        unfiltered.removeReactions = false; unfiltered.removeSystem = false; unfiltered.removeEmpty = false; unfiltered.stripEmoji = false; unfiltered.dateFilter = false
        allRows = Exporter.rows(messages, options: unfiltered, names: names)
        allRowPositions = Dictionary(uniqueKeysWithValues: allRows.enumerated().map { ($0.element.id, $0.offset) })
        updateMatches(target: target ?? focusedMatch?.messageID)
    }
    func connectContacts() {
        guard !isDemo else { return }
        guard !matchingContacts else { return }
        matchingContacts = true
        Task {
            defer { matchingContacts = false }
            do {
                let store = CNContactStore()
                guard try await store.requestAccess(for: .contacts) else {
                    error = "Contacts access was not granted. You can still rename any chat using the pencil beside its title."
                    return
                }
                let resolved = try await Task.detached(priority: .userInitiated) {
                    var result: [String: String] = [:]
                    let request = CNContactFetchRequest(keysToFetch: [CNContactFormatter.descriptorForRequiredKeys(for: .fullName), CNContactPhoneNumbersKey as CNKeyDescriptor, CNContactEmailAddressesKey as CNKeyDescriptor])
                    try CNContactStore().enumerateContacts(with: request) { contact, _ in
                        guard let name = CNContactFormatter.string(from: contact, style: .fullName), !name.isEmpty else { return }
                        for phone in contact.phoneNumbers { result[phone.value.stringValue.filter(\.isNumber)] = name }
                        for email in contact.emailAddresses { result[(email.value as String).lowercased()] = name }
                    }
                    return result
                }.value
                var mapped: [String: String] = [:]
                for handle in Set(chats.flatMap(\.handles) + messages.map(\.sender)) {
                    let key = handle.contains("@") ? handle.lowercased() : handle.filter(\.isNumber)
                    if let exact = resolved[key] { mapped[handle] = exact }
                    else if !handle.contains("@") && key.count >= 10 {
                        let matches = resolved.filter { !$0.key.contains("@") && $0.key.count >= 10 && $0.key.suffix(10) == key.suffix(10) }
                        if matches.count == 1 { mapped[handle] = matches.first!.value }
                    }
                }
                names = mapped; contactsMatched = true; rebuild(); status = "Matched \(mapped.count) contact addresses locally"
            } catch { self.error = error.localizedDescription }
        }
    }
    func export() {
        guard let chat, !rows.isEmpty else { return }
        let panel = NSSavePanel()
        panel.title = "Export conversation"
        let name = options.anonymize ? "Conversation" : title(chat)
        let safeName = String(name.map { "/\\:\n\r".contains($0) ? "-" : $0 }.prefix(100))
        panel.nameFieldStringValue = "\(safeName).\(format.ext)"
        panel.allowedContentTypes = [UTType(filenameExtension: format.ext) ?? .plainText]
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let destination = url.resolvingSymlinksInPath().standardizedFileURL.path
            let source = URL(fileURLWithPath: path).resolvingSymlinksInPath().standardizedFileURL.path
            guard ![source, source + "-wal", source + "-shm"].contains(destination) else {
                throw DatabaseError.failure("Choose a different filename. The Messages database and its companion files cannot be overwritten.")
            }
            let data = try Exporter.render(rows: rows, title: name, format: format)
            try data.write(to: url, options: .atomic)
            status = "Exported \(rows.count.formatted()) messages to \(url.lastPathComponent)"
            NSWorkspace.shared.activateFileViewerSelecting([url])
        } catch { self.error = error.localizedDescription }
    }
}
