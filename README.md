# Fling

**Floating Input Sender for CLI & LLM**

*Write once, send anywhere.*

Fling is a tiny always-on-top input pad that solves **broken IME composition in terminals**. Type CJK (Korean, Japanese, Chinese) text naturally — with full emoji support — then fling it to any window: terminals, browsers, LLM chat UIs, anything.

Built with WPF (DirectWrite) for perfect text rendering. Zero install — pure PowerShell.

## The Problem

Every terminal on Windows mangles CJK input:
- Characters break during composition
- Editing mid-sentence corrupts surrounding text
- Cursor movement causes rendering glitches
- Emoji renders as squares

This isn't a specific terminal's bug — it's a fundamental conflict between cell-based terminal grids and IME composition. No terminal has fixed it. **Fling sidesteps the problem entirely.**

## How It Works

```
┌─────────────────────────┐
│  Any app (terminal,     │  ← reads output here
│  browser, LLM UI...)    │
└─────────────────────────┘
┌─────────────────────────┐
│  Fling                  │  ← type here (perfect IME + emoji)
│  Enter → sends text ↑   │
└─────────────────────────┘
```

1. Fling floats on top as a small input window
2. Type freely with full native IME and emoji support
3. Press **Enter** → text is pasted + submitted to the last active window
4. Focus returns to Fling automatically

## Multi-LLM / Multi-CLI Workflow

Modern AI workflows involve juggling multiple windows — Claude Code in one terminal, ChatGPT in a browser tab, Copilot in another. Fling becomes a **single input hub** for all of them:

```
┌──────────────┐  ┌──────────────┐  ┌──────────────┐
│ Claude Code  │  │   ChatGPT    │  │  Copilot CLI │
│  (terminal)  │  │  (browser)   │  │  (terminal)  │
└──────┬───────┘  └──────┬───────┘  └──────┬───────┘
       │                 │                 │
       └────────── Fling ──────────────────┘
              (write once, send anywhere)
```

- **Click any window** → it becomes the send target (shown in Fling's status bar)
- **Type your prompt** in Fling with perfect IME + emoji
- **Enter** → sent. Fling is ready for the next one.
- **Quick Paste** (`Ctrl+Alt+V`) → send Fling text to current window without even opening Fling
- **Drag a file or web link** → attach context to your prompt before sending

No copy-paste juggling. No switching keyboard focus back and forth. Just type and fling.

## Features

| Feature | Description |
|---------|-------------|
| **Native IME** | WPF TextBox with DirectWrite — perfect CJK composition |
| **Emoji support** | Emoji rendering via DirectWrite font fallback |
| **Send anywhere** | Pastes to whatever window was last active — terminals, browsers, LLM UIs |
| **Target hint** | Status bar shows where text will go (e.g., `→ WindowsTerminal (Claude Code)`) |
| **Global hotkey** | `Ctrl+`` to show/hide from anywhere. Customizable in settings |
| **Quick Paste** | `Ctrl+Alt+V` — paste Fling text to current window without showing Fling. Follows Auto Enter toggle |
| **Key Mode** | `Ctrl+K` — type keystrokes as `«tokens»` and send them as real key events (e.g., `«Down»«Enter»` for CLI autocomplete) |
| **Auto Enter** | Optionally sends Enter after paste (toggle) |
| **Auto Hide** | Optionally hides Fling after sending (toggle) |
| **Clear after send** | Optionally clears input (Ctrl+Z to undo) |
| **File drop** | Drag `.md`/`.txt` to insert content, or **any file** to insert path |
| **Web drop** | Drag links or images from browsers — URL is automatically extracted |
| **Clipboard safe** | Backs up and restores your clipboard |
| **True transparency** | Background fades, text stays opaque (30–100%) |
| **Always on top** | Toggle on/off from the bottom bar |
| **Ctrl+Wheel zoom** | Font size control (8–36pt) |
| **Remember layout** | Window position, size, and all settings persist across sessions |
| **Settings (⚙)** | Customize hotkeys, opacity — gear button in bottom-right |
| **Custom window** | Borderless with rounded corners, drag-to-move title bar |
| **Dark theme** | Easy on the eyes |
| **Zero install** | Pure PowerShell — no dependencies |

## Quick Start

### Run directly

```powershell
powershell -ExecutionPolicy Bypass -STA -File fling.ps1
```

> **Note:** `-STA` flag is required for WPF.

### Create a shortcut (pin to taskbar)

```powershell
$ws = New-Object -ComObject WScript.Shell
$sc = $ws.CreateShortcut("$HOME\Desktop\Fling.lnk")
$sc.TargetPath = 'powershell.exe'
$sc.Arguments = '-ExecutionPolicy Bypass -WindowStyle Hidden -STA -File "C:\path\to\fling.ps1"'
$sc.WindowStyle = 7
$sc.Save()
```

Then right-click the shortcut → **Pin to taskbar**.

## Controls

| Key | Action |
|-----|--------|
| `Enter` | Send text to last active window |
| `Shift+Enter` | New line |
| `Ctrl+K` | Toggle Key Mode (insert keystrokes as `«tokens»`) |
| `Escape` | Exit Key Mode |
| `Ctrl+Z` | Undo (works even after clear) |
| `Ctrl+A` | Select all |
| `Ctrl+V` | Paste as plain text |
| `Ctrl+Wheel` | Font size zoom (8–36pt) |
| Drag `.md`/`.txt` | Insert file content |
| Drag any file (path mode) | Insert file path |
| Drag web link/image | Insert URL |

## Key Mode

Press `Ctrl+K` to enter Key Mode. Every keystroke is recorded as a `«token»` instead of typing text:

```
«Down»«Down»«Enter»          ← select 2nd item in autocomplete
hello «Tab»«Enter»           ← type "hello", tab-complete, submit
«Ctrl+Z»«Ctrl+Z»«Ctrl+S»    ← undo twice, save
```

- Title bar turns orange with "KEY MODE" indicator
- `Escape` exits Key Mode (customizable)
- `Ctrl+Z` (in normal mode) to undo/edit tokens
- On send, `«tokens»` become real keystrokes, plain text becomes clipboard paste
- Uses `«»` delimiters (not `{}`) to avoid conflicts with code

### Why?

CLI tools like Claude Code use arrow keys + Enter for autocomplete suggestions. You can't type those in a text box — Key Mode lets you compose a full key sequence visually, then replay it to the target window.

## Toggle Options

| Option | Default | Description |
|--------|---------|-------------|
| **Clear after send** | ON | Clears input after sending. Ctrl+Z to undo |
| **Auto Enter** | ON | Sends Enter key after paste. Turn off to just paste |
| **Auto Hide** | OFF | Hides Fling after sending. Show again with `Ctrl+`` |
| **File: path only** | OFF | When ON, dropped files insert path instead of content (accepts all file types) |
| **Always on top** | ON | Keep Fling above other windows |

## Settings (⚙)

Click the gear icon in the bottom-right corner to open settings:

| Setting | Type | Default | Description |
|---------|------|---------|-------------|
| **Show / Hide** | Global | `Ctrl+`` | Show/hide Fling from anywhere |
| **Quick Paste** | Global | `Ctrl+Alt+V` | Paste Fling text to current window |
| **Key Mode** | In-app | `Ctrl+K` | Toggle Key Mode |
| **Key Mode Exit** | In-app | `Escape` | Exit Key Mode |
| **Toggle Clear** | In-app | *(unset)* | Toggle "Clear after send" |
| **Toggle Auto Enter** | In-app | *(unset)* | Toggle "Auto Enter" |
| **Send Enter Only** | In-app | *(unset)* | Send just Enter to target (no text) |
| **Opacity** | — | 95% | Background transparency slider (30–100%) |

All settings are saved to `fling-settings.json` next to the script.

## Drop Behavior

| Source | Result | path only toggle |
|--------|--------|-----------------|
| Text selection drag | Text as-is | Ignored (always text) |
| Web link drag | URL extracted | Ignored (always URL) |
| Web image drag | Image URL extracted | Ignored (always URL) |
| Local file drag | path only ON → path, OFF → content (.md/.txt) or path | Applies |

## Timing

Fling uses carefully tuned delays for reliable delivery:

| Step | Delay | Why |
|------|-------|-----|
| Focus → Paste | 150ms | Window needs time to become active |
| Paste → Enter | 250ms | Terminal needs time to process paste |
| Enter → Refocus | 40ms | Quick return to Fling |
| Key token → next | 80ms | Keystroke spacing for target app |

Total: ~440ms for simple sends — feels instant, works reliably.

## Architecture

Fling v2 uses **WPF (Windows Presentation Foundation)** instead of WinForms:

| | WinForms (v1) | WPF (v2+) |
|---|---|---|
| Text renderer | GDI | **DirectWrite** |
| IME support | ✅ | ✅ |
| Emoji | ❌ Squares | ✅ **Supported** |
| Transparency | Whole window | **Background only** |
| Window style | System chrome | **Custom borderless** |

The switch to DirectWrite solved the fundamental GDI limitation where emoji glyphs couldn't render alongside CJK text.

### Hotkey Architecture

| Type | Scope | How |
|------|-------|-----|
| **Global** | Works from any app | `RegisterHotKey` Win32 API (Show/Hide, Quick Paste) |
| **In-app** | Works when Fling has focus | `PreviewKeyDown` WPF event (Key Mode, toggles) |

Global hotkeys are limited to 2 to minimize conflicts with other applications.

## Requirements

- Windows 10/11
- PowerShell 5.1+ (pre-installed on Windows)
- That's it. No Python, no Node, no install.

## Who Is This For?

- Developers who use **CLI tools** (Claude Code, GitHub Copilot CLI, etc.) and type in Korean/Japanese/Chinese
- Anyone who talks to **LLMs in terminals** and is tired of broken IME
- Power users who want a **universal paste pad** across any application
- Anyone who uses emoji in terminal workflows

## License

MIT

## Author

[MirrorLab](https://github.com/mirrorlabdev) — Built out of pure frustration with terminal IME, refined through daily use with Claude Code.
