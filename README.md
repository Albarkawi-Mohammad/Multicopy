# Multicopy

A native macOS clipboard manager that makes copied text easy to find and reuse.

Multicopy runs in the menu bar and keeps a searchable history of text you copy. Open it with **Command + Shift + V**, find a previous copy, and use it again without returning to the original document or website.

## What it can do

- Keep up to 200 unpinned text entries, with the newest copies first.
- Search history without worrying about capitalization.
- Pin frequently used snippets so they stay at the top and survive cleanup.
- Avoid duplicate entries when you copy the same text again.
- Copy an entry back to the clipboard or paste it into the previously active app.
- Navigate with arrow keys, use Enter to paste, and Escape to close.
- Delete individual entries or clear unpinned history.
- Restore saved history after restarting and optionally launch at login.

## How it helps

Use Multicopy to reuse code snippets while programming, collect text while researching, or keep common responses and document fragments within reach. It reduces repeated copying and switching between apps when working with several pieces of text.

## Requirements

- macOS 14 Sonoma or later.
- Swift 5.9 or later and the macOS developer tools to build from source.
- Accessibility access is optional and enables automatic pasting. Without it, you can copy an entry and paste manually.

This is a macOS app; it does not run on Windows or Linux. Clipboard history currently supports text, not images or files.

## Build and install

From the project directory on a Mac:

```sh
chmod +x scripts/*.sh
./scripts/build.sh
```

The app bundle is created at `build/Multicopy.app`. To build, install to your user Applications folder, and launch:

```sh
./scripts/install.sh
```

The installer replaces an existing Multicopy app in that folder and applies an ad-hoc code signature. This is a source build, not a notarized release.

## Usage

1. Launch Multicopy and copy some text.
2. Click its menu-bar icon or press **Command + Shift + V**.
3. Search or browse your previous copies.
4. Select an entry to reuse it. Enable Auto-Paste in the app if you want automatic pasting.
5. Pin items you want to keep. Right-click an entry for copy, pin, and delete actions.

## Local storage and privacy

History is stored locally at `~/Library/Application Support/Multicopy/history.json`. The app does not implement cloud sync or a network service. The history file is JSON, not encrypted storage. Clipboard content marked as concealed or transient by supported pasteboard types is skipped, but ordinary copied sensitive text can still be saved. Avoid copying secrets while recording history and remove sensitive entries when necessary.

Clipboard history, credentials, local configuration, and generated build outputs are excluded from this repository.

## Development

The app uses SwiftUI and AppKit, with clipboard storage in `Sources/MulticopyCore` and the app interface in `Sources/Multicopy`. No third-party Swift package dependencies are declared.

Run the included storage tests on macOS:

```sh
swift test
```

Tests cover sorting, deduplication, pinning, search, persistence, deletion, and blank input. Build and tests were not run during repository preparation on Windows.
