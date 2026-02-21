# Claude Native Messaging for Chromium Browsers

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](http://makeapullrequest.com)
[![macOS](https://img.shields.io/badge/macOS-supported-brightgreen.svg)](https://www.apple.com/macos/)
[![Linux](https://img.shields.io/badge/Linux-supported-brightgreen.svg)](https://www.linux.org/)
[![Windows](https://img.shields.io/badge/Windows-supported-brightgreen.svg)](https://www.microsoft.com/windows)

> **Use Claude AI browser extension with Brave, Arc, Vivaldi, Edge, Opera, Genspark, Helium, and other Chromium-based browsers**

Enable [Claude in Chrome](https://claude.ai/download) extension to work with alternative Chromium-based browsers. Connect Claude Desktop and Claude Code to your favorite browser!

## Quick Start

**macOS / Linux:**
```bash
git clone https://github.com/stolot0mt0m/claude-chromium-native-messaging.git
cd claude-chromium-native-messaging
./setup.sh
```

**Windows (PowerShell):**
```powershell
git clone https://github.com/stolot0mt0m/claude-chromium-native-messaging.git
cd claude-chromium-native-messaging
.\setup.ps1
```

## Features

- **31+ Supported Browsers** - Brave, Arc, Vivaldi, Edge, Opera, and more
- **Cross-Platform** - Works on macOS, Linux, and Windows
- **Safe by Default** - Dry-run mode, backup support, and path validation
- **Interactive Setup** - Select which browsers to configure
- **JSON Configuration** - Easy to extend with new browsers
- **Test Suite** - Automated tests for reliability

## The Problem

Claude's official browser extension only supports Google Chrome. But many developers prefer browsers like **Brave**, **Arc**, **Vivaldi**, or **Microsoft Edge**.

The extension actually works fine in these browsers — it's just the **Native Messaging Host** configuration that's missing. Without it:

- Claude Desktop can't connect to the browser extension
- Claude Code's `/chrome` command doesn't detect the extension
- No browser automation capabilities

## The Solution

This tool automatically configures Native Messaging Host for your Chromium browser, enabling:

- Full Claude Desktop integration
- Claude Code browser automation (`/chrome`)
- Side panel functionality
- All Claude in Chrome features

## Supported Browsers

| Browser | macOS | Linux | Windows |
|---------|:-----:|:-----:|:-------:|
| **Brave** | ✅ | ✅ | ✅ |
| **Arc** | ✅ | — | ✅ |
| **Vivaldi** | ✅ | ✅ | ✅ |
| **Microsoft Edge** | ✅ | ✅ | ✅ |
| **Google Chrome** | ✅ | ✅ | ✅ |
| **Google Chrome Canary** | ✅ | ✅ | ✅ |
| **Google Chrome Beta** | ✅ | ✅ | ✅ |
| **Google Chrome Dev** | ✅ | ✅ | ✅ |
| **Opera / Opera GX** | ✅ | ✅ | ✅ |
| **Chromium** | ✅ | ✅ | ✅ |
| **Ungoogled Chromium** | ✅ | ✅ | ✅ |
| **Yandex Browser** | ✅ | ✅ | ✅ |
| **Naver Whale** | ✅ | ✅ | ✅ |
| **Coc Coc** | ✅ | ✅ | ✅ |
| **Comodo Dragon** | ✅ | ✅ | ✅ |
| **Avast Secure Browser** | ✅ | ✅ | ✅ |
| **AVG Secure Browser** | ✅ | ✅ | ✅ |
| **Epic Privacy Browser** | ✅ | ✅ | ✅ |
| **SRWare Iron** | ✅ | ✅ | ✅ |
| **Torch** | ✅ | ✅ | ✅ |
| **Slimjet** | ✅ | ✅ | ✅ |
| **Cent Browser** | ✅ | ✅ | ✅ |
| **Maxthon** | ✅ | ✅ | ✅ |
| **Iridium** | ✅ | ✅ | ✅ |
| **Sidekick** | ✅ | ✅ | ✅ |
| **Genspark** | ✅ | ✅ | ✅ |
| **Helium** | ✅ | ✅ | ✅ |
| **Orion** | ✅ | ✅ | — |
| **Falkon** | ✅ | ✅ | — |
| **Colibri** | ✅ | ✅ | — |

Your browser not listed? The script supports [custom paths](#custom-browser-paths) — any Chromium-based browser should work.

## Prerequisites

Before running the setup:

1. **Claude Desktop** installed ([Download here](https://claude.ai/download))
2. **Claude in Chrome extension** installed in your browser ([Chrome Web Store](https://chrome.google.com/webstore/detail/claude/fcoeoabgfenejglbffodgkkbkcdhcgfn))
3. **Bash 4.0+** (macOS users may need to install via Homebrew: `brew install bash`)

## Installation

### macOS / Linux

```bash
# Clone the repository
git clone https://github.com/stolot0mt0m/claude-chromium-native-messaging.git
cd claude-chromium-native-messaging

# Run the interactive setup
./setup.sh
```

### Windows

```powershell
# Clone the repository
git clone https://github.com/stolot0mt0m/claude-chromium-native-messaging.git
cd claude-chromium-native-messaging

# Run the interactive setup
.\setup.ps1
```

The script will:
1. Detect installed Chromium browsers
2. Show which ones have the Claude extension
3. Let you select which browser(s) to configure
4. Create the necessary manifest files

### Command Line Options

| Option | Bash | PowerShell | Description |
|--------|------|------------|-------------|
| Uninstall | `--uninstall`, `-u` | `-Uninstall` | Remove configuration |
| Custom Path | `--path PATH`, `-p` | `-Path PATH` | Specify browser path |
| Dry Run | `--dry-run`, `-n` | `-DryRun` | Preview without changes |
| Verbose | `--verbose`, `-v` | `-Verbose` | Detailed output |
| Quiet | `--quiet`, `-q` | `-Quiet` | Minimal output |
| Backup | `--backup`, `-b` | `-Backup` | Backup before overwrite |
| Version | `--version`, `-V` | `-Version` | Show version |
| Help | `--help`, `-h` | `-Help` | Show help |

### Examples

```bash
# Preview what would be changed (dry-run)
./setup.sh --dry-run

# Install with automatic backups
./setup.sh --backup

# Install for a specific browser path
./setup.sh --path ~/Library/Application\ Support/MyBrowser

# Uninstall with verbose output
./setup.sh --uninstall --verbose
```

### Custom Browser Paths

If your browser stores its data in a non-standard location, use the `--path` / `-Path` flag to point the setup script directly at the browser's **data directory** (not the executable).

The data directory is where the browser stores profiles, preferences, and extensions. Common locations:

| Platform | Base Directory | Example |
|----------|---------------|---------|
| macOS | `~/Library/Application Support/` | `~/Library/Application Support/Google/Chrome Canary` |
| Linux | `~/.config/` | `~/.config/google-chrome-unstable` |
| Windows | `%LOCALAPPDATA%\` | `%LOCALAPPDATA%\Google\Chrome SxS\User Data` |

**macOS example — Chrome Canary:**
```bash
./setup.sh --path "$HOME/Library/Application Support/Google/Chrome Canary"
```

**Linux example — Chrome Canary (dev channel):**
```bash
./setup.sh --path "$HOME/.config/google-chrome-unstable"
```

**Windows example — Chrome Canary:**
```powershell
.\setup.ps1 -Path "$env:LOCALAPPDATA\Google\Chrome SxS\User Data"
```

**Custom Chromium build:**
```bash
# Point to wherever your Chromium stores its user data
./setup.sh --path "/opt/my-chromium/user-data"
```

> **Tip:** To find your browser's data directory, navigate to `chrome://version` in the address bar and look at the **Profile Path**. The data directory is the parent of the profile folder (e.g., if Profile Path is `~/.config/google-chrome-unstable/Default`, the data directory is `~/.config/google-chrome-unstable`).

### Manual Setup

See the detailed [Manual Setup Guide](docs/manual-setup.md) if you prefer to configure things yourself.

## Verification

After running the setup:

1. **Completely quit your browser** (check Activity Monitor / Task Manager)
2. **Restart the browser**
3. **Open Claude extension** in the side panel
4. **For Claude Code**: Run `/chrome` in your terminal

## How It Works

Chrome extensions communicate with native applications through the [Native Messaging API](https://developer.chrome.com/docs/extensions/develop/concepts/native-messaging). This requires JSON manifest files that tell the browser where to find Claude's native host binary.

The script creates these manifests in your browser's data directory:

**macOS:**
```
~/Library/Application Support/YOUR_BROWSER/NativeMessagingHosts/
```

**Linux:**
```
~/.config/YOUR_BROWSER/NativeMessagingHosts/
```

**Windows:**
```
%LOCALAPPDATA%\YOUR_BROWSER\User Data\NativeMessagingHosts\
```

## Project Structure

```
claude-chromium-native-messaging/
├── setup.sh              # macOS/Linux setup script
├── setup.ps1             # Windows setup script
├── config/
│   └── browsers.json     # Browser configuration (shared)
├── tests/
│   ├── test_setup.sh     # Bash test suite
│   └── test_setup.ps1    # PowerShell test suite
├── docs/
│   └── manual-setup.md   # Manual setup guide
├── CHANGELOG.md          # Version history
├── CONTRIBUTING.md       # Contribution guidelines
├── VERSION               # Current version
├── LICENSE               # MIT License
└── README.md             # This file
```

## Troubleshooting

**Extension not connecting after restart**

1. Make sure you completely quit the browser (not just closed windows)
2. Check Activity Monitor / Task Manager for remaining browser processes
3. Verify the extension ID is `fcoeoabgfenejglbffodgkkbkcdhcgfn`

**Claude Code `/chrome` doesn't detect browser**

This is a known limitation. Claude Code looks for Google Chrome processes specifically. Workaround:
1. Open your Chromium browser manually first
2. Then run `/chrome` in Claude Code

See [Issue #14370](https://github.com/anthropics/claude-code/issues/14370) for updates.

**Bash version error on macOS**

macOS ships with Bash 3.2. Install a newer version:
```bash
brew install bash
/opt/homebrew/bin/bash ./setup.sh
```

**Permission errors (macOS/Linux)**

```bash
chmod +x setup.sh
chmod 644 ~/Library/Application\ Support/YOUR_BROWSER/NativeMessagingHosts/*.json
```

**Browser not detected**

The setup script detects browsers by checking for **data directories** (not executables) and validating that they contain Chromium profile markers (e.g., a `Default/` folder, `Local State` file, or `Preferences` file). If your browser is installed but not detected:

1. **Verify the browser has been launched at least once** — the data directory is only created after the first run
2. **Check that the data directory exists** — see [Custom Browser Paths](#custom-browser-paths) for expected locations
3. **Use the custom path option** to specify the data directory manually:

macOS/Linux:
```bash
./setup.sh --path "/path/to/your/browser/data"
```

Windows:
```powershell
.\setup.ps1 -Path "C:\path\to\browser\User Data"
```

> **Tip:** Use `--dry-run --verbose` to see exactly which paths the script checks and why a browser might be skipped.

## FAQ

### Why is my installed browser not showing up?

The setup script uses **filesystem-based validation** to detect browsers. It does not search for browser executables — instead, it looks for the browser's **data directory** (where profiles and settings are stored) and checks for Chromium-specific markers like `Default/`, `Local State`, or `Preferences`.

A browser won't be detected if:
- It has **never been launched** (the data directory is only created on first run)
- The data directory is in a **non-standard location** (e.g., installed via a different package manager)
- The data directory **exists but is empty** (incomplete installation)

**Solution:** Launch the browser at least once, then re-run the setup script. If the browser still isn't detected, use the `--path` flag to specify the data directory manually (see [Custom Browser Paths](#custom-browser-paths)).

### How do I use Chrome Canary?

Chrome Canary is fully supported. The script auto-detects it at these locations:

| Platform | Data Directory |
|----------|---------------|
| macOS | `~/Library/Application Support/Google/Chrome Canary` |
| Linux | `~/.config/google-chrome-unstable` |
| Windows | `%LOCALAPPDATA%\Google\Chrome SxS\User Data` |

If auto-detection doesn't find it, specify the path manually:

```bash
# macOS
./setup.sh --path "$HOME/Library/Application Support/Google/Chrome Canary"

# Linux (Canary uses the dev channel package "google-chrome-unstable")
./setup.sh --path "$HOME/.config/google-chrome-unstable"
```

```powershell
# Windows (Canary is stored under "Chrome SxS")
.\setup.ps1 -Path "$env:LOCALAPPDATA\Google\Chrome SxS\User Data"
```

> **Note:** On Linux, Chrome Canary and Chrome Dev share the same data directory (`google-chrome-unstable`) because they both use the `google-chrome-unstable` package. The setup script will configure the directory once for whichever is detected first.

### How do I use a custom browser location?

Use the `--path` flag (Bash) or `-Path` parameter (PowerShell) to point the script at your browser's data directory:

```bash
# macOS/Linux
./setup.sh --path "/absolute/path/to/browser/data-directory"

# Windows
.\setup.ps1 -Path "C:\path\to\browser\User Data"
```

The path must be:
- **Absolute** (no relative paths like `./browser` or `../data`)
- An **existing directory** that is readable
- A valid **Chromium data directory** (the script verifies this)

To find the correct path, open your browser and navigate to `chrome://version` — the **Profile Path** shows where data is stored. Use the parent directory of the profile folder.

## Uninstall

**macOS / Linux:**
```bash
./setup.sh --uninstall
```

**Windows:**
```powershell
.\setup.ps1 -Uninstall
```

## Running Tests

```bash
# Bash tests
./tests/test_setup.sh

# PowerShell tests
.\tests\test_setup.ps1
```

## Contributing

Contributions are welcome! Please read our [Contributing Guide](CONTRIBUTING.md) for details.

Areas where help is needed:

- [ ] Homebrew formula
- [ ] Chocolatey package
- [ ] AUR package for Arch Linux
- [ ] Additional browser support

## Related Resources

- [Claude Desktop](https://claude.ai/download) - Official Claude desktop app
- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) - CLI tool for agentic coding
- [Chrome Native Messaging](https://developer.chrome.com/docs/extensions/develop/concepts/native-messaging) - Chrome documentation

### Related GitHub Issues

- [#14370](https://github.com/anthropics/claude-code/issues/14370) - Detect extension in Chromium browsers
- [#18075](https://github.com/anthropics/claude-code/issues/18075) - Add `CLAUDE_CODE_CHROME_PATH` env var
- [#14536](https://github.com/anthropics/claude-code/issues/14536) - Browser selection option

## License

MIT License - See [LICENSE](LICENSE) for details.

## Disclaimer

This is an **unofficial workaround**. The official Claude in Chrome extension is designed for Google Chrome only. Anthropic may change the native messaging implementation at any time. Use at your own risk.

---

<p align="center">
  <a href="https://github.com/stolot0mt0m/claude-chromium-native-messaging/issues">Report Bug</a> ·
  <a href="https://github.com/stolot0mt0m/claude-chromium-native-messaging/issues">Request Feature</a>
</p>

<!-- Keywords for SEO: claude ai, anthropic, claude browser extension, brave browser claude, arc browser claude, vivaldi claude, edge claude, chromium claude, native messaging host, claude desktop, claude code, browser automation, ai assistant, llm, windows, powershell -->
