# Linux Setup Guide

Complete step-by-step instructions for setting up Claude native messaging on Linux.

## Overview

On Linux, **Claude Code CLI** provides the native messaging host that connects your browser's Claude extension to Claude. This tool extends Claude Code's browser support to additional Chromium browsers beyond Chrome and Edge.

## Quick Start

```bash
# 1. Install Claude Code CLI (if not already installed)
npm install -g @anthropic-ai/claude-code

# 2. Run Claude Code once to initialize the native host
claude
# Inside Claude Code, run /chrome to set up the native host

# 3. Clone and run this tool
git clone https://github.com/stolot0mt0m/claude-chromium-native-messaging.git
cd claude-chromium-native-messaging
./install-linux.sh
```

## Prerequisites

### Claude Code CLI

Claude Code CLI is required on Linux. It provides the native messaging host binary at `~/.claude/chrome/chrome-native-host`.

**Install Claude Code:**

```bash
npm install -g @anthropic-ai/claude-code
```

**Initialize the native host:**

```bash
claude
# Inside Claude Code, use /chrome to set up browser integration
```

**Verify the native host exists:**

```bash
ls -la ~/.claude/chrome/chrome-native-host
# Should show the file exists and is executable
```

> **Note:** Claude Code requires Node.js 18+. If you don't have Node.js installed, see the [Node.js installation](#nodejs-18-or-later) section below.

### Chromium Browser

You need at least one Chromium-based browser installed:

- **Chrome**: Official Google Chrome (from google.com/chrome or your package manager)
- **Chromium**: Open-source Chromium (from chromium.org)
- **Brave**: Brave Browser (from brave.com)
- **Edge**: Microsoft Edge (from microsoft.com/edge)
- **Vivaldi**: Vivaldi Browser (from vivaldi.com)
- **Opera**: Opera Browser (from opera.com)
- Plus 25+ other supported Chromium variants

Launch the browser at least once so its data directory is created:

```bash
# For Google Chrome
google-chrome &

# For Chromium
chromium &

# For Brave
brave &

# For Microsoft Edge
microsoft-edge &
```

The browser creates a data directory in `~/.config/` on first launch. The setup script needs this directory to register the manifest.

### Node.js 18 or Later

Node.js is required for installing Claude Code CLI.

#### Ubuntu / Debian / Linux Mint / Pop!_OS

```bash
# Quick install with NodeSource (recommended for latest LTS)
curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
sudo apt-get install -y nodejs

# Verify
node --version  # Should be >= 18
npm --version
```

Or use your distro's package manager:
```bash
sudo apt-get update
sudo apt-get install -y nodejs npm
```

#### Fedora / RHEL / CentOS / Rocky Linux

```bash
# Quick install with NodeSource (recommended)
curl -fsSL https://rpm.nodesource.com/setup_lts.x | sudo bash -
sudo dnf install -y nodejs

# Verify
node --version
npm --version
```

Or use DNF:
```bash
sudo dnf install -y nodejs npm
```

#### Arch / Manjaro / EndeavourOS / Garuda

```bash
sudo pacman -S nodejs npm

# Verify
node --version
npm --version
```

#### Using nvm (Any Distro)

If you prefer a user-level install or need to manage multiple Node.js versions:

```bash
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
source ~/.bashrc
nvm install --lts

# Verify
node --version  # Should be >= 18
npm --version
```

---

## Installation Steps

### Step 1: Install and Initialize Claude Code

```bash
# Install Claude Code CLI
npm install -g @anthropic-ai/claude-code

# Run Claude Code to initialize
claude

# Inside Claude Code, run /chrome to set up the native host
```

### Step 2: Clone the Repository

```bash
git clone https://github.com/stolot0mt0m/claude-chromium-native-messaging.git
cd claude-chromium-native-messaging
```

### Step 3: Run the Installer

```bash
./install-linux.sh
```

The installer will:

1. **Verify Claude Code** — checks that the native host exists at `~/.claude/chrome/chrome-native-host`
2. **Detect browsers** — scans `~/.config/` for installed Chromium browsers
3. **Install manifests** — copies the native messaging manifest to each detected browser's `NativeMessagingHosts/` directory

### Step 4: Restart Your Browser

Make sure no browser processes are running:

```bash
# List any running Chrome/Chromium processes
ps aux | grep -i chrome | grep -v grep

# Kill them if found
pkill -9 chrome
pkill -9 chromium
pkill -9 brave
```

### Step 5: Install Extension and Verify

1. **Launch your browser**: `google-chrome`, `chromium`, `brave`, etc.
2. **Install the Claude extension** (if not already installed):
   - Go to [Chrome Web Store](https://chrome.google.com/webstore/detail/claude/fcoeoabgfenejglbffodgkkbkcdhcgfn)
   - Click **Add to Chrome** (works on all Chromium browsers)
3. **Open the Claude side panel**: Click the Claude icon in the top-right corner
4. **Verify it connects**: You should see the Claude interface in the side panel

---

## Verification

### Verify the Native Host Exists

```bash
ls -la ~/.claude/chrome/chrome-native-host
# Should show the file exists and is executable (-rwxr-xr-x)
```

### Verify the Manifest is Registered

Check the manifest in your browser's directory:

```bash
# For Chromium
cat ~/.config/chromium/NativeMessagingHosts/com.anthropic.claude_code_browser_extension.json

# For Brave
cat ~/.config/BraveSoftware/Brave-Browser/NativeMessagingHosts/com.anthropic.claude_code_browser_extension.json
```

You should see JSON like:

```json
{
  "name": "com.anthropic.claude_code_browser_extension",
  "description": "Claude Code Browser Extension Native Host",
  "path": "/home/username/.claude/chrome/chrome-native-host",
  "type": "stdio",
  "allowed_origins": [
    "chrome-extension://fcoeoabgfenejglbffodgkkbkcdhcgfn/"
  ]
}
```

---

## Uninstall

To remove the manifests installed by this tool:

```bash
./uninstall-linux.sh
```

This removes only the manifests created by `install-linux.sh`. It does **not** touch Claude Code's own configuration or native host.

---

## Troubleshooting

### Extension Not Connecting

**Symptom:** The Claude extension side panel appears blank or shows an error.

**Solution:**

1. **Verify the native host exists:**
   ```bash
   ls ~/.claude/chrome/chrome-native-host
   ```
   If it doesn't exist, run `claude` and use `/chrome` inside Claude Code.

2. **Verify the manifest exists for your browser:**
   ```bash
   ls ~/.config/YOUR_BROWSER/NativeMessagingHosts/com.anthropic.claude_code_browser_extension.json
   ```
   If it doesn't exist, re-run `./install-linux.sh`.

3. **Completely quit and restart the browser:**
   ```bash
   pkill -9 chromium  # or chrome, brave, etc.
   chromium           # re-launch
   ```

4. **Check the browser console for errors:**
   - Open DevTools: `F12` or `Ctrl+Shift+I`
   - Go to **Console** tab
   - Look for red error messages mentioning "native messaging"

### Claude Code Not Found

**Symptom:** `install-linux.sh` says Claude Code is not installed.

**Solution:**

```bash
# Install Claude Code
npm install -g @anthropic-ai/claude-code

# Verify installation
which claude
claude --version

# Initialize the native host
claude
# Use /chrome inside Claude Code
```

### Native Host Exists But Extension Doesn't Connect

**Symptom:** The native host file exists but the extension still doesn't work.

**Solution:**

1. Check file permissions:
   ```bash
   ls -la ~/.claude/chrome/chrome-native-host
   # Should be executable (rwx)
   ```

2. Verify the manifest points to the correct path:
   ```bash
   cat ~/.config/YOUR_BROWSER/NativeMessagingHosts/com.anthropic.claude_code_browser_extension.json
   ```
   The `path` field should match the actual location of `chrome-native-host`.

3. Try running the native host directly:
   ```bash
   ~/.claude/chrome/chrome-native-host
   # It should wait for input (Ctrl+C to exit)
   # If it crashes, the error message will tell you what's wrong
   ```

### Browser Not Detected During Install

**Symptom:** `install-linux.sh` doesn't find your browser.

**Solution:**

1. **Make sure the browser has been launched at least once:**
   ```bash
   google-chrome &  # or chromium, brave, etc.
   ```

2. **Verify the data directory exists:**
   ```bash
   ls ~/.config/google-chrome/      # Chrome
   ls ~/.config/chromium/            # Chromium
   ls ~/.config/BraveSoftware/       # Brave
   ```

3. **Use the interactive setup for custom paths:**
   ```bash
   ./setup.sh --path "$HOME/.config/your-browser-directory"
   ```

---

## How It Works

### Architecture

Claude Code CLI provides the native messaging host on Linux:

```
Claude Code CLI
    └── Installs: ~/.claude/chrome/chrome-native-host (native host binary)
    └── Registers: ~/.config/google-chrome/NativeMessagingHosts/ (Chrome)
    └── Registers: ~/.config/microsoft-edge/NativeMessagingHosts/ (Edge)

This tool (install-linux.sh)
    └── Copies manifest to: ~/.config/chromium/NativeMessagingHosts/
    └── Copies manifest to: ~/.config/BraveSoftware/Brave-Browser/NativeMessagingHosts/
    └── Copies manifest to: ~/.config/vivaldi/NativeMessagingHosts/
    └── ... (25+ additional browsers)
```

### Manifest Format

The manifest is a JSON file that tells the browser where to find the native host:

```json
{
  "name": "com.anthropic.claude_code_browser_extension",
  "description": "Claude Code Browser Extension Native Host",
  "path": "/home/username/.claude/chrome/chrome-native-host",
  "type": "stdio",
  "allowed_origins": [
    "chrome-extension://fcoeoabgfenejglbffodgkkbkcdhcgfn/"
  ]
}
```

Chromium browsers look for manifests in:
- **User-level:** `~/.config/<browser>/NativeMessagingHosts/` (used by this tool)
- **System-wide:** `/etc/opt/chromium/native-messaging-hosts/` (requires admin)

### Differences: Linux vs macOS/Windows

| Aspect | Linux | macOS/Windows |
|--------|-------|---------------|
| **Native Host** | Claude Code CLI (`~/.claude/chrome/chrome-native-host`) | Claude Desktop (`chrome-native-host`) |
| **Requirement** | Claude Code CLI | Claude Desktop |
| **Auto-configured Browsers** | Chrome, Edge (by Claude Code) | Chrome (by Claude Desktop) |
| **This Tool's Role** | Extends to additional browsers | Extends to additional browsers |

---

## Support

If you encounter issues not covered here:

1. **Check the FAQ in the main [README.md](../README.md)**
2. **Review [GitHub Issues](https://github.com/stolot0mt0m/claude-chromium-native-messaging/issues)**
3. **Search the [Discussions](https://github.com/stolot0mt0m/claude-chromium-native-messaging/discussions)**
4. **Open a new issue** with:
   - Your Linux distribution (`cat /etc/os-release`)
   - Node.js version (`node --version`)
   - Claude Code version (`claude --version`)
   - Browser and version (`chromium --version`)
   - Output of `ls -la ~/.claude/chrome/`
   - Exact error message or symptoms
