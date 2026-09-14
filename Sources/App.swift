import SwiftUI
import AppKit
import Contacts
import UniformTypeIdentifiers

@main struct ChatHarvestApp: App {
    @StateObject private var store = Store()
    var body: some Scene {
        WindowGroup {
            ContentView().environmentObject(store)
                .frame(minWidth: 1050, minHeight: 690)
                .onAppear {
                    guard store.path.isEmpty, !store.isDemo else { return }
                    if CommandLine.arguments.contains("--demo") || Bundle.main.object(forInfoDictionaryKey: "ChatHarvestDemo") as? Bool == true { store.loadDemo(); return }
                    let desktop = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Desktop/chat.db").path
                    let saved = UserDefaults.standard.string(forKey: "databasePath") ?? desktop
                    if FileManager.default.fileExists(atPath: saved) { store.open(saved) }
                }
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1330, height: 850)
        .commands {
            CommandGroup(replacing: .newItem) { Button("Open Database…") { store.chooseDatabase() }.keyboardShortcut("o")
                Button("Try Demo Conversations") { store.loadDemo() }
            }
            CommandMenu("Conversation") {
                Button("Download Export…") { store.export() }.keyboardShortcut("e").disabled(store.rows.isEmpty)
                Button("Reload Database") { store.open(store.path) }.keyboardShortcut("r").disabled(store.path.isEmpty)
            }
        }
    }
}

private let accent = Color(red: 0.04, green: 0.48, blue: 0.99)
private let muted = Color(nsColor: .secondaryLabelColor)

struct ContentView: View {
    @EnvironmentObject var store: Store
    @State private var showRename = false
    @State private var rename = ""
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                sidebar.frame(width: 295)
                Divider()
                conversation.frame(maxWidth: .infinity, maxHeight: .infinity)
                Divider()
                exportPanel.frame(width: 285)
            }
            Divider()
            HStack {
                Image(systemName: "lock.shield").foregroundStyle(.green)
                Text(store.status).lineLimit(1)
                Spacer()
                HStack(spacing: 3) {
                    Text("Made by")
                    Link(destination: URL(string: "https://x.com/dava_star")!) {
                        HStack(spacing: 4) { XMark().fill(Color.secondary, style: FillStyle(eoFill: true)).frame(width: 10, height: 10); Text("@dava_star") }
                    }.accessibilityLabel("@dava_star on X")
                }.font(.system(size: 10)).foregroundStyle(muted)
            }.font(.system(size: 11)).foregroundStyle(muted).padding(.horizontal, 18).frame(height: 32)
                .background(Color(nsColor: .windowBackgroundColor))
        }
        .tint(accent)
        .onChange(of: store.selection) { _ in store.loadSelection() }
        .onChange(of: store.options) { _ in store.rebuild() }
        .onChange(of: store.search) { _ in store.searchEverywhere() }
        .alert("Chat Harvest", isPresented: Binding(get: { store.error != nil }, set: { if !$0 { store.error = nil } })) {
            Button("OK") { store.error = nil }
        } message: { Text(store.error ?? "") }
        .sheet(isPresented: $showRename) {
            VStack(alignment: .leading, spacing: 18) {
                Text("Name this conversation").font(.title2.bold())
                Text("A label just for Chat Harvest. Your Messages database stays unchanged.").foregroundStyle(muted)
                TextField("Conversation name", text: $rename).textFieldStyle(.roundedBorder)
                HStack { Button("Cancel") { showRename = false }; Spacer(); Button("Save label") { store.relabel(rename); showRename = false }.buttonStyle(.borderedProminent) }
            }.padding(28).frame(width: 410)
        }
    }
    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "bubble.left.and.text.bubble.right.fill").font(.system(size: 22)).foregroundStyle(accent)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Chat Harvest").font(.system(size: 19, weight: .bold))
                }
                Spacer()
            }.padding(.top, 38).padding(.horizontal, 20).padding(.bottom, 23)
            HStack {
                Image(systemName: "magnifyingglass").foregroundStyle(muted)
                TextField("Search all messages", text: $store.search).textFieldStyle(.plain)
                if !store.search.isEmpty { Button { store.search = "" } label: { Image(systemName: "xmark.circle.fill") }.buttonStyle(.plain).foregroundStyle(muted) }
            }.padding(9).background(.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 9)).padding(.horizontal, 16)
            VStack(alignment: .leading, spacing: 7) {
                Button { store.connectContacts() } label: {
                    Label(store.matchingContacts ? "Matching names…" : (store.contactsMatched ? "Refresh contact names" : "Match contact names"), systemImage: "person.crop.circle.badge.checkmark")
                        .font(.system(size: 12, weight: .semibold)).frame(maxWidth: .infinity).padding(.vertical, 5)
                }.buttonStyle(.borderedProminent).disabled(store.chats.isEmpty || store.matchingContacts || store.isDemo)
                if !store.contactsMatched { Text("Show names instead of phone numbers.").font(.system(size: 10)).foregroundStyle(muted) }
            }.padding(.horizontal, 16).padding(.top, 13)
            HStack {
                Text(store.hasGlobalQuery ? "MESSAGE RESULTS" : "CONVERSATIONS").font(.system(size: 10, weight: .semibold)).tracking(1.2)
                Spacer(); Text((store.hasGlobalQuery ? store.searchResults.count : store.chats.count).formatted()).font(.system(size: 11, design: .monospaced))
            }.foregroundStyle(muted).padding(.horizontal, 20).padding(.top, 22).padding(.bottom, 10)
            if store.loading {
                Spacer(); ProgressView("Reading chats…").frame(maxWidth: .infinity); Spacer()
            } else if store.hasGlobalQuery {
                if store.indexing || store.searching {
                    Spacer(); ProgressView(store.indexing ? "Preparing message search…" : "Searching…").frame(maxWidth: .infinity); Spacer()
                } else if store.searchResults.isEmpty {
                    Spacer(); Text("No messages contain “\(store.search)”.").foregroundStyle(muted).multilineTextAlignment(.center).padding(24); Spacer()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 4) {
                            ForEach(Array(store.searchResults.prefix(store.globalResultLimit)), id: \.id) { result in
                                Button { store.openResult(result) } label: {
                                    VStack(alignment: .leading, spacing: 7) {
                                        HStack {
                                            Text(store.chats.first { $0.id == result.chatID }.map { store.title($0) } ?? "Conversation").font(.system(size: 12, weight: .semibold)).lineLimit(1)
                                            Spacer(minLength: 2)
                                            if let date = result.date { Text(date, format: .dateTime.month(.abbreviated).day()).font(.system(size: 9)).foregroundStyle(muted) }
                                        }
                                        Text(highlighted(KeywordSearch.snippet(result.text, query: store.search), query: store.search))
                                            .font(.system(size: 11)).lineLimit(3).multilineTextAlignment(.leading)
                                    }.padding(12).frame(maxWidth: .infinity, alignment: .leading)
                                        .background(store.focusedMatch?.messageID == result.messageID ? accent.opacity(0.12) : .primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 10))
                                }.buttonStyle(.plain)
                            }
                            if store.searchResults.count > store.globalResultLimit {
                                Button("Show 100 more results") { store.globalResultLimit += 100 }.buttonStyle(.borderless).font(.caption).padding(12)
                            }
                        }.padding(.horizontal, 10).padding(.bottom, 12)
                    }
                }
            } else if store.visibleChats.isEmpty {
                Spacer(); Text(store.chats.isEmpty ? "Open a database to see your chats." : "No matching conversations.").foregroundStyle(muted).multilineTextAlignment(.center).padding(24); Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 3) {
                        ForEach(store.visibleChats) { chat in
                            Button { store.selection = chat.id } label: { ChatListRow(chat: chat, selected: store.selection == chat.id) }
                                .buttonStyle(.plain)
                        }
                    }.padding(.horizontal, 9).padding(.bottom, 12)
                }
            }
            Divider().padding(.horizontal, 16)
            VStack(alignment: .leading, spacing: 12) {
                Button { store.chooseDatabase() } label: { Label("Open database…", systemImage: "externaldrive") }
            }.buttonStyle(.plain).font(.system(size: 12)).foregroundStyle(muted).padding(20)
        }.background(Color(nsColor: .windowBackgroundColor))
    }
    private var conversation: some View {
        VStack(spacing: 0) {
            if let chat = store.chat {
                HStack(spacing: 12) {
                    Avatar(title: store.title(chat), seed: chat.id, group: chat.handles.count > 1, size: 42)
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(store.title(chat)).font(.system(size: 16, weight: .semibold)).lineLimit(1)
                            Button { rename = store.title(chat); showRename = true } label: { Image(systemName: "pencil").font(.system(size: 11)) }.buttonStyle(.plain).foregroundStyle(muted).help("Rename this chat")
                        }
                        Text("\(chat.handles.count > 1 ? "\(chat.handles.count + 1) participants · " : "")\(store.messages.count.formatted()) messages").font(.system(size: 11)).foregroundStyle(muted)
                    }
                    Spacer(minLength: 4)
                }.padding(.horizontal, 24).padding(.top, 32).padding(.bottom, 20)
                Divider()
                HStack {
                    Image(systemName: "magnifyingglass").foregroundStyle(muted)
                    TextField("Search keywords in this chat", text: Binding(get: { store.messageSearch }, set: { store.messageSearch = $0; store.updateMatches() })).textFieldStyle(.plain)
                        .onSubmit { store.moveMatch(1) }
                    if store.hasQuery {
                        Text(store.searchingConversation ? "Searching…" : (store.keywordMatches.isEmpty ? "No matches" : "\(store.activeMatch + 1) of \(store.keywordMatches.count)"))
                            .font(.system(size: 11, weight: .medium, design: .monospaced)).foregroundStyle(muted).fixedSize()
                        Button { store.moveMatch(-1) } label: { Image(systemName: "chevron.up") }
                            .help("Previous match (⇧⌘G)").keyboardShortcut("g", modifiers: [.command, .shift]).disabled(store.searchingConversation || store.keywordMatches.isEmpty)
                        Button { store.moveMatch(1) } label: { Image(systemName: "chevron.down") }
                            .help("Next match (⌘G)").keyboardShortcut("g", modifiers: .command).disabled(store.searchingConversation || store.keywordMatches.isEmpty)
                    }
                    if !store.messageSearch.isEmpty { Button { store.messageSearch = ""; store.updateMatches() } label: { Image(systemName: "xmark.circle.fill") }.buttonStyle(.plain) }
                }.font(.system(size: 12)).padding(.horizontal, 24).padding(.vertical, 13)
                Divider()
                if store.loadingMessages { Spacer(); ProgressView("Loading messages…"); Spacer() }
                else { ConversationTimeline().id(chat.id) }
                if !store.messageSearch.isEmpty {
                    Text("Searching the full conversation. Export filters still apply to downloads.")
                        .font(.system(size: 10)).foregroundStyle(muted).padding(10)
                }
            } else {
                Spacer()
                Image(systemName: "bubble.left.and.text.bubble.right").font(.system(size: 52, weight: .light)).foregroundStyle(accent).padding(.bottom, 14)
                Text("Your conversations, clearly.").font(.system(size: 24, weight: .semibold))
                Text("Browse your Messages and take a clean copy with you.").foregroundStyle(muted).padding(.top, 3)
                Button("Open chat.db…") { store.chooseDatabase() }.buttonStyle(.borderedProminent).controlSize(.large).padding(.top, 20)
                Spacer()
            }
        }.background(Color(nsColor: .textBackgroundColor))
    }
    private var exportPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack { Image(systemName: "square.and.arrow.down").foregroundStyle(accent); Text("Export conversation").font(.system(size: 15, weight: .semibold)) }.padding(.top, 39).padding(.bottom, 28)
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 10) {
                        sectionLabel("FILE FORMAT")
                        Picker("Format", selection: $store.format) { ForEach(ExportFormat.allCases) { Text($0.rawValue).tag($0) } }.pickerStyle(.segmented).labelsHidden()
                        Text(store.format.detail).font(.system(size: 11)).foregroundStyle(muted).fixedSize(horizontal: false, vertical: true).frame(minHeight: 42, alignment: .topLeading)
                        Text("Times: \(TimeZone.current.identifier)").font(.system(size: 10)).foregroundStyle(muted)
                    }
                    Divider()
                    VStack(alignment: .leading, spacing: 17) {
                        sectionLabel("CLEAN UP")
                        option("Remove reactions", subtitle: "Leave out Tapbacks and their removals", binding: $store.options.removeReactions)
                        option("Strip emojis", subtitle: "Keep the words, skip the emoji", binding: $store.options.stripEmoji)
                        option("Remove system events", subtitle: "Skip group and service updates", binding: $store.options.removeSystem)
                    }
                    Divider()
                    VStack(alignment: .leading, spacing: 14) {
                        sectionLabel("PRIVACY & RANGE")
                        option("Replace speaker names", subtitle: "Use Me, Person 1, Person 2…", binding: $store.options.anonymize)
                        if store.options.anonymize { Text("Message text is unchanged. Review it for personal details.").font(.system(size: 10)).foregroundStyle(muted) }
                        DateRangeControl(options: $store.options)

                    }
                }.padding(.bottom, 18)
            }.scrollIndicators(.hidden)
            Spacer(minLength: 12)
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    Text(store.rows.count.formatted()).font(.system(size: 28, weight: .semibold, design: .rounded))
                    Text("messages to export").font(.system(size: 11)).foregroundStyle(muted)
                }
                Text("\(max(0, store.messages.count - store.rows.count).formatted()) filtered out · Chronological order").font(.system(size: 10)).foregroundStyle(muted)
                if store.messages.contains(where: \.unreadable) { Text("Some bodies could not be decoded and have explicit placeholders.").font(.system(size: 10)).foregroundStyle(.orange) }
                Button { store.export() } label: {
                    HStack { Image(systemName: "arrow.down.to.line"); Text("Download .\(store.format.ext)").fontWeight(.semibold); Spacer(); Text("⌘E").opacity(0.6) }.padding(.vertical, 7).frame(maxWidth: .infinity)
                }.buttonStyle(.borderedProminent).controlSize(.large).disabled(store.rows.isEmpty || store.loadingMessages)
                Text("Saved locally. Nothing is uploaded.").font(.system(size: 10)).foregroundStyle(muted).frame(maxWidth: .infinity).padding(.top, 3)
            }.padding(15).background(accent.opacity(0.045), in: RoundedRectangle(cornerRadius: 13)).padding(.bottom, 20)
        }.padding(.horizontal, 20).background(Color(nsColor: .windowBackgroundColor).opacity(0.5))
    }
    private func sectionLabel(_ text: String) -> some View { Text(text).font(.system(size: 10, weight: .semibold)).tracking(1).foregroundStyle(muted) }
    private func option(_ title: String, subtitle: String, binding: Binding<Bool>) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) { Text(title).font(.system(size: 12, weight: .medium)); Text(subtitle).font(.system(size: 10)).foregroundStyle(muted).fixedSize(horizontal: false, vertical: true) }
            Spacer(minLength: 4)
            Toggle(title, isOn: binding).labelsHidden().toggleStyle(.switch).controlSize(.mini)
        }
    }
}

struct Avatar: View {
    let title: String
    let seed: Int64
    let group: Bool
    var size: CGFloat = 42
    private var color: Color { [.blue, .purple, .orange, .teal, .pink, .indigo][Int(abs(seed) % 6)] }
    var body: some View {
        ZStack {
            Circle().fill(color.gradient)
            if group { Image(systemName: "person.2.fill").font(.system(size: size * 0.34, weight: .medium)) }
            else if title.first?.isNumber == true || title.hasPrefix("+") { Image(systemName: "person.fill").font(.system(size: size * 0.43)) }
            else { Text(String(title.split(separator: " ").prefix(2).compactMap(\.first)).uppercased()).font(.system(size: size * 0.32, weight: .semibold)) }
        }.foregroundStyle(.white).frame(width: size, height: size)
    }
}

struct ChatListRow: View {
    @EnvironmentObject var store: Store
    let chat: Chat
    let selected: Bool
    var body: some View {
        HStack(alignment: .top, spacing: 11) {
            Avatar(title: store.title(chat), seed: chat.id, group: chat.handles.count > 1)
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(store.title(chat)).font(.system(size: 12, weight: .semibold)).lineLimit(1)
                    Spacer(minLength: 2)
                    if let date = chat.lastDate { Text(date, format: .dateTime.month(.abbreviated).day()).font(.system(size: 9)).foregroundStyle(selected ? Color.white.opacity(0.75) : muted) }
                }
                Text(chat.snippet).font(.system(size: 11)).lineLimit(2).multilineTextAlignment(.leading).foregroundStyle(selected ? Color.white.opacity(0.85) : muted).frame(maxWidth: .infinity, alignment: .leading)
            }
        }.padding(.horizontal, 11).padding(.vertical, 12).frame(maxWidth: .infinity, alignment: .leading)
            .foregroundStyle(selected ? Color.white : Color.primary)
            .background(selected ? accent : Color.clear, in: RoundedRectangle(cornerRadius: 10))
            .contentShape(Rectangle())
    }
}

func highlighted(_ text: String, query: String, active: NSRange? = nil) -> AttributedString {
    let value = NSMutableAttributedString(string: text)
    for range in KeywordSearch.ranges(in: text, query: query) {
        value.addAttributes([.backgroundColor: range == active ? NSColor.systemOrange : NSColor.systemYellow,
                             .foregroundColor: NSColor.black], range: range)
    }
    return AttributedString(value)
}

@MainActor enum MessageDateLabels {
    private static let parser: ISO8601DateFormatter = {
        let parser = ISO8601DateFormatter(); parser.formatOptions = [.withInternetDateTime, .withFractionalSeconds]; return parser
    }()
    private static var cache: [String: (day: String, time: String)] = [:]
    static func labels(_ value: String) -> (day: String, time: String) {
        if let cached = cache[value] { return cached }
        guard let date = parser.date(from: value) else { return ("Unknown date", "") }
        let labels = (date.formatted(date: .abbreviated, time: .omitted), date.formatted(date: .omitted, time: .shortened))
        if cache.count > 50_000 { cache.removeAll(keepingCapacity: true) }
        cache[value] = labels
        return labels
    }
}

struct ConversationTimeline: View {
    @EnvironmentObject var store: Store
    @State private var window: Range<Int> = 0..<0
    var body: some View {
        let all = store.timelineRows
        let range = TimelineWindow.clamped(window, count: all.count)
        let displayed = all[range]
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 16) {
                    if range.lowerBound > 0 {
                        Button("Show earlier messages (\(range.lowerBound.formatted()) more)") {
                            let anchor = all[range.lowerBound].id
                            window = TimelineWindow.page(range, direction: -1, count: all.count)
                            DispatchQueue.main.async { proxy.scrollTo(anchor, anchor: .top) }
                        }.buttonStyle(.borderless).font(.caption).padding(.top, 8)
                    }
                    if all.isEmpty { Text("No messages match these export filters.").font(.system(size: 13)).foregroundStyle(muted).padding(.top, 90) }
                    ForEach(Array(displayed.enumerated()), id: \.element.id) { index, row in
                        let day = MessageDateLabels.labels(row.timestamp).day
                        if index == 0 || MessageDateLabels.labels(all[range.lowerBound + index - 1].timestamp).day != day {
                            Text(day).font(.system(size: 10, weight: .medium)).foregroundStyle(muted).padding(.top, 14).padding(.bottom, 4)
                        }
                        MessageBubble(row: row, query: store.appliedQuery, active: store.focusedMatch?.messageID == row.id ? store.focusedMatch?.range : nil).id(row.id)
                    }
                    if range.upperBound < all.count {
                        Button("Show later messages (\((all.count - range.upperBound).formatted()) more)") {
                            let anchor = all[range.upperBound - 1].id
                            window = TimelineWindow.page(range, direction: 1, count: all.count)
                            DispatchQueue.main.async { proxy.scrollTo(anchor, anchor: .bottom) }
                        }.buttonStyle(.borderless).font(.caption).padding(.bottom, 8)
                    }
                    Color.clear.frame(height: 1).id("bottom")
                }.padding(.horizontal, 25).padding(.vertical, 20)
            }
            .task(id: store.navigationID) {
                if let position = store.focusedRowPosition, store.timelineHasQuery {
                    window = TimelineWindow.range(count: all.count, around: position)
                    await Task.yield()
                    guard !Task.isCancelled, let match = store.focusedMatch else { return }
                    proxy.scrollTo(match.messageID, anchor: .center)
                } else if !store.timelineHasQuery {
                    window = TimelineWindow.range(count: all.count)
                    await Task.yield()
                    guard !Task.isCancelled else { return }
                    proxy.scrollTo("bottom", anchor: .bottom)
                }
            }
        }
    }
}

struct MessageBubble: View {
    let row: ExportRow
    let query: String
    let active: NSRange?
    @MainActor private var time: String { MessageDateLabels.labels(row.timestamp).time }
    var body: some View {
        HStack(alignment: .bottom, spacing: 12) {
            if row.fromMe { Spacer(minLength: 60) }
            VStack(alignment: row.fromMe ? .trailing : .leading, spacing: 5) {
                Text(row.sender).font(.system(size: 10, weight: .medium)).foregroundStyle(muted).lineLimit(1)
                VStack(alignment: .leading, spacing: 7) {
                    if row.replyTo != nil { Label("Reply", systemImage: "arrowshape.turn.up.left").font(.system(size: 10)).opacity(0.75) }
                    if row.type == "reaction" { Label("Reaction", systemImage: "face.smiling").font(.system(size: 10)).opacity(0.75) }
                    if !row.text.isEmpty { Text(highlighted(row.text, query: query, active: active)).font(.system(size: 13)).lineSpacing(3).textSelection(.enabled) }
                }.padding(.horizontal, 14).padding(.vertical, 10)
                    .foregroundStyle(row.fromMe ? Color.white : Color.primary)
                    .background(row.fromMe ? accent : Color.gray.opacity(0.20), in: RoundedRectangle(cornerRadius: 17))
                    .overlay(RoundedRectangle(cornerRadius: 17).stroke(active == nil ? Color.clear : Color.orange, lineWidth: 2))
                Text(time).font(.system(size: 9)).foregroundStyle(muted)
            }.frame(maxWidth: 440, alignment: row.fromMe ? .trailing : .leading)
            if !row.fromMe { Spacer(minLength: 60) }
        }.frame(maxWidth: .infinity, alignment: row.fromMe ? .trailing : .leading)
    }
}

struct XMark: Shape {
    func path(in rect: CGRect) -> Path {
        let points: [[CGPoint]] = [
            [CGPoint(x: 18.9,y: 2),CGPoint(x: 22,y: 2),CGPoint(x: 15.2,y: 9.8),CGPoint(x: 23.2,y: 22),CGPoint(x: 16.9,y: 22),CGPoint(x: 12,y: 14.6),CGPoint(x: 5.5,y: 22),CGPoint(x: 2.3,y: 22),CGPoint(x: 10.2,y: 13),CGPoint(x: 0.8,y: 2),CGPoint(x: 7.3,y: 2),CGPoint(x: 11.8,y: 8.7)],
            [CGPoint(x: 17.8,y: 20),CGPoint(x: 4.6,y: 3.9),CGPoint(x: 6.4,y: 3.9),CGPoint(x: 19.5,y: 20)]
        ]
        var path = Path()
        for polygon in points {
            path.addLines(polygon.map { CGPoint(x: $0.x / 24 * rect.width, y: $0.y / 24 * rect.height) })
            path.closeSubpath()
        }
        return path
    }
}
