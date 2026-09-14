# Why Chat Harvest exists

Research checked September 14, 2026. These are public requests and alternatives, not endorsements of Chat Harvest. They demonstrate individual experiences, not how often a problem occurs for everyone.

## What people are asking for

| Need | Public discussion | Implication for this app |
| --- | --- | --- |
| A straightforward way to export a long conversation | [Export a Very Long iMessage Conversation? — r/iphone, January 2026](https://www.reddit.com/r/iphone/comments/1q5mtwr/export_a_very_long_imessage_conversation/) describes an hour of scrolling, a stalled PDF print, and difficulty using a command-line tool. The author later reports success with iMazing. | Let someone pick a chat visually and save a readable transcript, with no terminal required after database setup. Explain that only locally available history can be read. |
| Less friction getting a readable copy | [An iMessage export complaint — r/applesucks, March 2026](https://www.reddit.com/r/applesucks/comments/1s1avhv/you_cannot_export_your_own_imessage_history_in/) describes repeated unsuccessful attempts to export history. | Keep the export choices small: CSV, Markdown, and JSON. Be clear about the local-database requirement rather than promising complete iCloud retrieval. |
| Finding older messages | [Apple Support Community: iOS 26 search not pulling up older messages](https://discussions.apple.com/thread/256197498) reports missing older search results. This is an iOS report, and the thread includes a synchronization workaround. | Search the selected local database directly; show highlighted matches and navigation. Do not claim that Apple's search is universally broken or that Chat Harvest can find data absent from the database. |
| Keeping a conversation that matters | [An open-source exporter built to preserve conversations with loved ones — r/apple, January 2023](https://www.reddit.com/r/apple/comments/10cp8dh/i_wanted_to_be_able_to_exportbackup_imessage/) introduces an existing tool motivated by preservation. | Make transcripts easy to read outside Messages. A transcript with media placeholders is not a complete archival backup. |

## Existing alternatives

There is **not** an empty market. Exporters and visual tools already exist:

- [imessage-exporter](https://github.com/ReagentX/imessage-exporter): an established open-source command-line project for exporting Messages data and diagnostics.
- [iExporter](https://iexporterapp.com/): a Mac app offering message exports, including CSV and HTML.
- [iMazing](https://imazing.com/): a broader Apple-device management product; it was the successful solution reported by the long-conversation poster above.
- [SummonIQ/iMessageExporter](https://github.com/SummonIQ/iMessageExporter): another open-source native Mac interface for browsing and exporting iMessages.

These links are for comparison and credit, not a feature ranking. Capabilities, pricing, and compatibility may change.

## The positioning

**A small, free, local Mac app to find messages and take a clean conversation with you.**

The useful combination is a familiar chat interface, visible keyword matches with previous/next navigation, a bounded timeline for large conversations, and exports containing just readable timestamps, speakers, and text. The project is transparent about its limitations and does not claim exclusive features or superiority to every alternative.

Practical uses:

- Find a forgotten restaurant, book recommendation, address, or plan.
- Save a transcript of an important conversation for personal reference.
- Turn a project or trip conversation into a clean input for notes or an AI the user chooses.

The website uses fictional conversations throughout. It includes no invented testimonials, user counts, performance comparisons with Apple, or promises of recovering deleted/cloud-only content. No messages were sent to the authors of these discussions.

## Search scope

[Apple’s current Mac guide](https://support.apple.com/en-gb/guide/messages/icht6d66aae3/mac) describes searching from the sidebar, combining filters, and opening a result in its conversation. We distinguish that from a dedicated search box inside the open chat; we do not claim Apple offers no search or filtering. [This macOS 15.1 user report](https://www.reddit.com/r/applehelp/comments/1gfqb6m/) describes global search returning photos but no text results. This supports the wording “users report missing global results,” not a claim that every Mac is affected.
