# Contributing

Keep changes focused on local browsing, keyword search, and readable transcripts. Open an issue for larger changes before implementing them.

1. Build with `./build.sh` on macOS with Xcode Command Line Tools.
2. Run `./test.sh`. Tests create fictional data in temporary directories; they do not require access to Messages or Contacts.
3. Use **File → Try Demo Conversations** to verify UI changes. Check both light and dark appearance, keyboard navigation, and small supported window sizes.
4. Explain the problem, resulting behavior, and verification in your pull request.

Never commit real databases, exports, contact lists, or private screenshots. Use `.invalid` addresses and fictional messages in test fixtures. Do not include private data in public issues. Bug reports should include the app version, macOS version, processor architecture, reproduction steps, and a minimal fictional example when possible.

The static GitHub Pages site is in `docs/`. Preview it with `python3 -m http.server 8765 --directory docs` and open `http://localhost:8765`. It has no build dependencies, analytics, or external scripts. Keep demo data visibly labeled as fictional and claims supported by the app's behavior.

Public downloads are built by `./release.sh`, which runs verification and produces the app ZIP and checksum. They are currently ad-hoc signed, not notarized. Never publish signing keys or certificates in the repository.

The sharing image is `docs/assets/social-card.png`. Its source is `docs/social.html`, which reuses `preview.css`. Capture the complete artboard at a 1200 × 630 browser viewport; keep its fictional app illustration consistent with the landing page when updating either file.

The README image is `docs/assets/app-preview.jpg`, rendered from `docs/app-preview.html` at a 1200-pixel viewport width and the full illustration height. It contains fictional conversations only.
