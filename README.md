**English** | [한국어](README.ko.md)

# StickyCast

Pop selected Markdown from MarkEdit onto your macOS desktop as a floating sticky note.

It has two parts:

- The **MarkEdit extension** (`extension/`) sends the current selection through a `sticky://` URL scheme.
- The **StickyCast companion app** (`app/`) catches that URL and draws it as a translucent sticky window. Only notes you pin with 📌 stay above other windows.

The two are coupled by exactly one thing: the custom `sticky://` URL scheme.

## Requirements

- **StickyCast app**: macOS 14 or later.
- **MarkEdit**: [MarkEdit](https://github.com/MarkEdit-app/MarkEdit). The Homebrew cask (`brew install --cask markedit`) currently needs macOS 15+, so on macOS 14 grab a compatible build from the [GitHub releases](https://github.com/MarkEdit-app/MarkEdit/releases) instead.
- **To build**: Swift 5.9+ (Xcode or the CLI toolchain) and Node 18+.

## Install

> **Start the app first.** It registers the `sticky://` URL handler when it launches. Until it does, any URL the extension fires just disappears.

### 1. Companion app

```bash
cd app
./make-app.sh      # build, assemble .app, register with Launch Services, run
```

This produces and launches `build/StickyCast.app`. It stays out of the Dock (`LSUIElement`) and sits in the menu bar as a `note.text` icon.

### 2. MarkEdit extension

> **Install MarkEdit and open it once before this step.** The first launch creates MarkEdit's script container, and a Homebrew install may need Gatekeeper approval ("Open") the first time. Without the container, `deploy` stops with a clear error instead of failing halfway.

```bash
cd extension
npm install
npm run deploy     # build, then copy to MarkEdit's scripts directory
```

Restart MarkEdit and you'll find **Extensions ▸ Pop as Sticky**.

## Using it

1. Select some Markdown in MarkEdit.
2. Click **Extensions ▸ Pop as Sticky**.
3. The selection appears as a sticky in the top-right of your screen.

Every sticky has a top bar with 📌 (pin), ⋯ (drag handle), and ✕ (close), plus an opacity slider along the bottom that darkens when you hover. Drag the body to move it; drag an edge to resize.

- **Unpinned stickies** drop behind whatever you switch to, so they never cover your work.
- **Pinned stickies** (📌) stay on top, in view while you work.
- **✕ deletes** the sticky.

Position, size, opacity, and pin state are saved and restored across restarts.

The menu bar icon gives you the sticky list, **Hide all / Show all** (stash and bring back, not delete), All to front, Close all, recent errors, About StickyCast, and Quit.

## Limits (v1)

- Viewer only. You can't edit a sticky or save it to a file.
- Up to 30 stickies, with a content cap of about 1 MB of source (enough for essentially any Markdown document). Anything larger is refused with a notice rather than silently truncated.
- Renders standard GFM only.

## Development

```bash
cd app && swift test          # unit tests for the core logic (parser, store)
cd extension && npm test      # unit tests for encoding
```

## License and credits

Released under the [MIT License](LICENSE).

- Markdown rendering: [swift-markdown-ui](https://github.com/gonzalezreal/swift-markdown-ui) (MIT)
- MarkEdit API types: [MarkEdit-api](https://github.com/MarkEdit-app/MarkEdit-api)
