# Chat Harvest guide

A native, local Mac app for browsing Messages conversations and exporting a readable transcript for an AI. No account, server, third-party packages, or uploads.

## Prepare your database

The source database is normally at `~/Library/Messages/chat.db` on your Mac. In Finder, use **Go → Go to Folder** to open `~/Library/Messages/`. macOS privacy controls may restrict access. Use your own database or a copy you trust.

Prefer a consistent SQLite backup. If Terminal already has the necessary access, you can create a separate snapshot with the built-in SQLite command below. It reads the source and creates a new export file; it does not alter your messages. Use a new destination filename each time.

```sh
mkdir -p "$HOME/Desktop/Chat Harvest Data"
/usr/bin/sqlite3 -readonly "$HOME/Library/Messages/chat.db" ".backup '$HOME/Desktop/Chat Harvest Data/messages-snapshot.db'"
```

If access is denied, macOS may require granting Terminal **Full Disk Access** in System Settings → Privacy & Security before making the backup. The Chat Harvest app can then open the snapshot using **Open database…**. You can revoke Terminal's access afterward. If copying files manually, keep `chat.db`, `chat.db-wal`, and `chat.db-shm` together when present; separate copies made during writes may be inconsistent.

Only messages already present locally can be exported. This process does not download missing messages or attachments from iCloud. Keep a separate backup if preservation matters.

## Open it

Double-click **Chat Harvest.app** in Applications after following the [installation notes](README.md#download--install). It automatically opens `~/Desktop/chat.db` on first launch if that file exists, then remembers your last database.

To try the app with fictional messages, choose **File → Try Demo Conversations**. Demo mode does not load your database or Contacts and does not save demo labels. Choose **Open database…** to return to your own data.

1. Select a conversation, or use **Search all messages** to search message text across the entire database. Results include older messages and archived text bodies. Click a result to jump to that message in its conversation.
2. Click the blue **Match contact names** button above the chat list to optionally allow macOS Contacts access. Click the pencil beside a conversation title to give it a custom label.
3. Choose Markdown, CSV, or JSON and adjust the cleanup switches. The conversation preview reflects those switches.
4. Click **Download**, or press **⌘E**, and choose where to save.

Both searches use case-insensitive, accent-insensitive substring matching: `apple` matches `Apple`, `apples`, and `pineapple`. Matches are highlighted yellow; the current occurrence is orange. **Search keywords in this chat** keeps surrounding messages visible. Use the up/down arrows, **⌘G** / **⇧⌘G**, or Enter to jump between occurrences (including multiple occurrences in one message). Navigation wraps at either end.

Search examines the full original conversation, including messages outside the current export filters. Search does not change what gets downloaded. With no search active, the timeline reflects your export filters. The timeline displays at most 160 nearby messages at a time; **Show earlier messages** and **Show later messages** page through the complete conversation with overlapping context. Exports include the entire conversation after cleanup and date filters. The all-message index is built locally in memory after opening a database and refreshed on reload.

## Formats and filters

- **Markdown:** chronological transcript with readable timestamps, speaker names, and quoted message bodies. No internal IDs or reply GUIDs.
- **CSV:** exactly three columns: `timestamp`, `sender`, `text`. Timestamps use `yyyy-mm-dd hh:mm:ss` in the Mac’s local timezone (shown beside the format controls). Paragraphs and repeated whitespace are collapsed to single spaces so each message occupies one physical CSV row. Quotes and commas are escaped correctly. Files include a UTF-8 byte-order mark so spreadsheet apps recognize names, accents, emoji, and curly punctuation instead of opening them as Mac Roman or ANSI.
- **JSON:** conversation title, timezone, and message records containing only `timestamp`, `sender`, and `text`. Paragraphs remain readable line breaks.
- **Remove reactions:** omits Tapback additions and removals, including custom reaction types in the 2000–3999 range. When retained, they are separate messages containing the reaction text.
- **Strip emojis:** removes whole emoji characters/sequences from message text, preserving ordinary digits, punctuation, and non-English text. Emoji-only messages become empty and are omitted.
- **Remove system events:** skips group and service event rows.
- **Automatic cleanup:** omits blank or dot-only messages, including leftovers after emoji stripping. Attachment placeholders and other punctuation such as questions are preserved. There is no extra switch to configure. Layout cleanup removes indentation, excessive whitespace, and invisible control artifacts; it does not translate or transliterate genuine non-English text.
- **Media placeholders:** photos, videos, stickers, audio, and contact cards appear as `[photo]`, `[video]`, `[sticker]`, `[audio]`, and `[contact]` in the message body. Unknown files or missing metadata use `[attachment]`. These rows are always retained (unless excluded by date or reaction filters), even if the original file is unavailable. Media files are not copied or uploaded.
- **Replace speaker names:** uses Me and stable Person 1 / Person 2 labels within the selected conversation and uses a generic export title. This does not redact personal information from message text.
- **Date range:** click **All time** to open a two-month calendar. Select a first and last day (in either order), or choose All time, Last 7 days, Last 30 days, or This year. Month/year menus allow large jumps. Changes take effect only after **Apply range**; Cancel discards the draft. Days are inclusive in the Mac's local timezone. Export timestamps and the on-screen timeline use local time. Date filtering uses the same timezone.

## Database access

The app opens SQLite with `SQLITE_OPEN_READONLY` and `PRAGMA query_only = ON`. It does not edit, delete, or send Messages. Labels and the most recent database path are saved in the app's local preferences; Contacts matches stay in memory and refresh automatically when a database opens if Contacts access is already authorized.

Use **Open database…** / **⌘O** for an existing copy. Keep `chat.db-wal` and `chat.db-shm` beside a copied database when they are present: the WAL can contain recent messages. A SQLite backup is preferable to copying a database while Messages is writing to it.

A copied database is a **snapshot**, not a live connection to Messages. Messages sent or received after that copy was made will not appear in it. To include newer messages, make a fresh SQLite backup using a new destination filename, then choose it with **Open database…**.

**Conversation → Reload Database** / **⌘R** rereads the selected file and rebuilds the search index. It does not refresh a snapshot from the original Messages database or fetch anything from iCloud. If you opened the original database directly and macOS permits access, reload can read newly stored messages from that file. The app does not watch for changes or sync continuously.

## Scope

Reads the messages currently linked to chats in the selected database. It is a transcript tool, not a forensic archive: deleted content, edit histories, rich app payloads/polls, and media contents are not reconstructed. Unsupported bodies are explicitly marked rather than silently omitted. Custom labels and contact names are local to this app; participant photos are represented by generated initials/icons.

## Build and test

Built for Apple Silicon on this Mac with the installed Xcode tools. No third-party Swift packages are needed. A build on another Mac targets that Mac's architecture. The app has a local ad-hoc signature, not a notarized distribution signature.

```sh
./build.sh
./test.sh
# Optional full read-only validation, printing aggregate counts only:
./test.sh ~/Desktop/chat.db
```

Source lives in `Sources/`. `Decode.m` uses Foundation's legacy NSUnarchiver for Apple's typedstream bodies and a restricted NSKeyedUnarchiver for keyed archives, with Objective-C exception handling. The database's archive format determines which decoder is used ([Apple NSUnarchiver documentation](https://developer.apple.com/documentation/foundation/nsunarchiver)).

Verification includes emoji sequences, date boundaries, reaction filters, speaker labels, JSON/CSV escaping, reply links, archive decoding, malformed archives, database joins, ordering, attachment labels, and unchanged database bytes after reads.

Made by [@dava_star on X](https://x.com/dava_star).

If a CSV importer overrides automatic encoding detection, choose UTF-8.

## Search responsiveness

Matching runs off the main UI thread after a brief 180 ms typing debounce. Editing the query cancels obsolete searches, and stale results cannot replace a newer query or appear in another chat. The match counter always covers the entire conversation; jumps load a bounded 160-message section around the selected occurrence. The all-chat result list initially shows 100 results, with a button to reveal more. Neither display limit truncates search results or exports.

The test suite includes cancellation, bounded viewport coverage, and a 50,000-message asynchronous search with a main-thread responsiveness check.
