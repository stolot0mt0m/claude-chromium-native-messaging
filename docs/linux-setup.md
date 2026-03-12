# Linux Setup Guide

Complete step-by-step instructions for setting up Claude native messaging on Linux.

## Quick Start

```bash
git clone https://github.com/stolot0mt0m/claude-chromium-native-messaging.git
cd claude-chromium-native-messaging
./install-linux.sh
```

The script will:
1. Check for Node.js 18+ (install if missing)
2. Build the native messaging host
3. Register manifests for Chrome, Chromium, Brave, Edge, and other Chromium browsers
4. Prompt for your Claude API key
5. Verify everything is working

## Prerequisites

### Node.js 18 or Later

The native host is written in Node.js. You need Node.js 18+ installed.

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

### Chromium Browser

You need at least one Chromium-based browser installed:

- **Chrome**: Official Google Chrome (from google.com/chrome or your package manager)
- **Chromium**: Open-source Chromium (from chromium.org)
- **Brave**: Brave Browser (from brave.com)
- **Edge**: Microsoft Edge (from microsoft.com/edge)
- **Vivaldi**: Vivaldi Browser (from vivaldi.com)
- **Opera**: Opera Browser (from opera.com)
- Plus 25+ other supported Chromium variants

To verify your browser is installed, launch it at least once:

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

### Claude API Key

You need a Claude API key to use the native host. This is free to create at [console.anthropic.com](https://console.anthropic.com/):

1. Go to [console.anthropic.com/api/keys](https://console.anthropic.com/api/keys)
2. Sign in with your Anthropic account (or create one)
3. Click **+ Create Key**
4. Copy the key (starts with `sk-ant-`)
5. Keep it safe — treat it like a password

The `install-linux.sh` script will prompt you to paste this key during installation.

---

## Installation Steps

### Step 1: Clone the Repository

```bash
git clone https://github.com/stolot0mt0m/claude-chromium-native-messaging.git
cd claude-chromium-native-messaging
```

### Step 2: Run the Installer

```bash
./install-linux.sh
```

The installer will:

1. **Detect your OS** and suggest the right Node.js install command if needed
2. **Check Node.js** — verify it's version 18 or later
3. **Build the host** — run `npm install && npm run build`
4. **Deploy the binary** — copy the built host to `~/.local/share/claude-chromium-native-messaging/`
5. **Register manifests** — create `~/.config/chromium/NativeMessagingHosts/com.claude.chromium_native.json` (and others)
6. **Prompt for API key** — ask you to paste your Claude API key
7. **Save the config** — write the key to `~/.config/claude-chromium-native-messaging/config.json`

At the end, the script prints a summary showing exactly what was installed.

### Step 3: Completely Quit Your Browser

Make sure no browser processes are running:

```bash
# List any running Chrome/Chromium processes
ps aux | grep -i chrome | grep -v grep

# Kill them if found
pkill -9 chrome
pkill -9 chromium
pkill -9 brave
```

If you're using a different browser, kill its process the same way.

### Step 4: Restart the Browser and Install Extension

1. **Launch your browser**: `google-chrome`, `chromium`, `brave`, etc.
2. **Install the Claude extension** (if not already installed):
   - Go to [Chrome Web Store](https://chrome.google.com/webstore/detail/claude/fcoeoabgfenejglbffodgkkbkcdhcgfn)
   - Click **Add to Chrome** (works on all Chromium browsers)
3. **Open the Claude side panel**: Click the Claude icon in the top-right corner
4. **Verify it connects**: You should see the Claude interface in the side panel

If the extension doesn't connect, check the **Troubleshooting** section below.

---

## Verification

### Verify the Manifest is Registered

The manifest tells the browser where to find the native host. Check it:

```bash
cat ~/.config/chromium/NativeMessagingHosts/com.claude.chromium_native.json
```

You should see JSON like:

```json
{
  "name": "com.claude.chromium_native",
  "description": "Claude Native Messaging Host",
  "path": "/home/username/.local/share/claude-chromium-native-messaging/host",
  "type": "stdio",
  "allowed_origins": [
    "chrome-extension://fcoeoabgfenejglbffodgkkbkcdhcgfn/",
    "chrome-extension://dihbgbndebgnbjfmelmegjepbnkhlgni/",
    "chrome-extension://dngcpimnedloihjnnfngkgjoidhnaolf/"
  ]
}
```

If this file doesn't exist, re-run `./install-linux.sh`.

### Verify the API Key is Set

```bash
cat ~/.config/claude-chromium-native-messaging/config.json
```

You should see something like:

```json
{
  "apiKey": "sk-ant-...",
  "model": "claude-opus-4-6"
}
```

If the key is missing or empty, re-run `./install-linux.sh` or edit the config file directly.

### Verify the Host Binary Exists and is Executable

```bash
ls -la ~/.local/share/claude-chromium-native-messaging/host
```

You should see:

```
-rwxr-xr-x 1 username username 12345 Mar 13 10:00 /home/username/.local/share/claude-chromium-native-messaging/host
```

If it doesn't exist, re-run `./install-linux.sh`.

If it's not executable (no `x`), fix it:

```bash
chmod +x ~/.local/share/claude-chromium-native-messaging/host
```

---

## Testing the Native Host

You can test the native host directly without opening a browser. This is useful for debugging.

### Test Basic Functionality

The host expects JSON messages in the Chrome Native Messaging format (4-byte length prefix + JSON payload).

```bash
# Create a test message
TEST_MSG='{"action":"test","apiKey":"YOUR_API_KEY"}'
MSG_LEN=$(printf '%s' "$TEST_MSG" | wc -c)
printf "\\x$(printf '%02x' $((MSG_LEN & 0xFF)))\\x$(printf '%02x' $(((MSG_LEN >> 8) & 0xFF)))\\x$(printf '%02x' $(((MSG_LEN >> 16) & 0xFF)))\\x$(printf '%02x' $(((MSG_LEN >> 24) & 0xFF)))"
printf '%s' "$TEST_MSG"
```

Or use a simpler test (Python):

```bash
python3 << 'PYEOF'
import json
import struct
import subprocess
import sys

# Read config
import os
config_path = os.path.expanduser('~/.config/claude-chromium-native-messaging/config.json')
with open(config_path) as f:
    config = json.load(f)

# Create a test message
msg = {
    'action': 'echo',
    'text': 'Hello from test'
}
msg_json = json.dumps(msg)
msg_len = len(msg_json.encode('utf-8'))
msg_bytes = struct.pack('<I', msg_len) + msg_json.encode('utf-8')

# Send to host
host_path = os.path.expanduser('~/.local/share/claude-chromium-native-messaging/host')
proc = subprocess.Popen([host_path], stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
stdout, stderr = proc.communicate(msg_bytes)

# Parse response
if stdout:
    response_len = struct.unpack('<I', stdout[:4])[0]
    response_json = stdout[4:4+response_len].decode('utf-8')
    print('Response:', json.loads(response_json))
if stderr:
    print('Error:', stderr.decode('utf-8'))
PYEOF
```

### Check for Runtime Errors

Run the host directly and watch for errors:

```bash
~/.local/share/claude-chromium-native-messaging/host
```

The process will wait for input from stdin. Press `Ctrl+C` to exit.

If it crashes or prints errors, that will tell you what's wrong.

---

## Configuration

### Edit the API Key

If you need to change your API key:

```bash
# Option 1: Edit the file directly
nano ~/.config/claude-chromium-native-messaging/config.json

# Option 2: Re-run the installer
./install-linux.sh
```

The config file must have valid JSON:

```json
{
  "apiKey": "sk-ant-YOUR_KEY_HERE",
  "model": "claude-opus-4-6"
}
```

Restart the browser after changing the key.

### Change the Model

You can use different Claude models. Edit the config:

```json
{
  "apiKey": "sk-ant-...",
  "model": "claude-opus-4-6"
}
```

Available models:
- `claude-opus-4-6` — Most capable, recommended
- `claude-sonnet-4-6` — Balanced performance and speed
- `claude-haiku-4-5` — Fast, lower cost

See [Anthropic's model documentation](https://docs.anthropic.com/en/docs/about-claude/models/latest) for the latest models.

---

## Uninstall

To remove the native host and manifests:

```bash
./uninstall-linux.sh
```

This will:
- Delete the host binary at `~/.local/share/claude-chromium-native-messaging/`
- Remove manifests from `~/.config/*/NativeMessagingHosts/`
- Keep your config file at `~/.config/claude-chromium-native-messaging/config.json` (manual deletion if desired)

---

## Troubleshooting

### Extension Not Connecting

**Symptom:** The Claude extension side panel appears blank or shows an error.

**Solution:**

1. **Verify the manifest exists:**
   ```bash
   ls ~/.config/chromium/NativeMessagingHosts/com.claude.chromium_native.json
   ```

2. **Verify the host binary is executable:**
   ```bash
   chmod +x ~/.local/share/claude-chromium-native-messaging/host
   ```

3. **Verify the API key is set:**
   ```bash
   grep apiKey ~/.config/claude-chromium-native-messaging/config.json
   ```

4. **Completely quit and restart the browser:**
   ```bash
   pkill -9 chromium  # or chrome, brave, etc.
   chromium           # re-launch
   ```

5. **Check the browser console for errors:**
   - Open DevTools: `F12` or `Ctrl+Shift+I`
   - Go to **Console** tab
   - Look for red error messages mentioning "native messaging"

### Permission Denied Error

**Symptom:** Error like "Permission denied" when trying to run the host.

**Solution:**

Make the host executable:

```bash
chmod +x ~/.local/share/claude-chromium-native-messaging/host
```

Verify:

```bash
ls -la ~/.local/share/claude-chromium-native-messaging/host
# Should show: -rwxr-xr-x
```

### API Key Error

**Symptom:** Error like "Invalid API key" or "Unauthorized".

**Solution:**

1. **Verify your key starts with `sk-ant-`:**
   ```bash
   grep apiKey ~/.config/claude-chromium-native-messaging/config.json
   ```

2. **Create a new key if expired:**
   - Go to [console.anthropic.com/api/keys](https://console.anthropic.com/api/keys)
   - Create a new key
   - Update the config: `nano ~/.config/claude-chromium-native-messaging/config.json`
   - Restart the browser

3. **Verify you have API access:**
   - Go to [console.anthropic.com](https://console.anthropic.com/)
   - Check that your account is active and has credits/usage quota

### Browser Not Detected During Install

**Symptom:** `install-linux.sh` doesn't find your browser.

**Solution:**

1. **Make sure the browser has been launched at least once** to create the data directory:
   ```bash
   google-chrome &  # or chromium, brave, etc.
   ```

2. **Verify the data directory exists:**
   ```bash
   # For Chrome/Chromium
   ls ~/.config/google-chrome/

   # For Chromium
   ls ~/.config/chromium/

   # For Brave
   ls ~/.config/BraveSoftware/Brave-Browser/
   ```

3. **Re-run the installer:**
   ```bash
   ./install-linux.sh
   ```

4. **Manual manifest creation:**
   If auto-detection still fails, you can manually create the manifest. See the [Manual Setup Guide](manual-setup.md).

### Host Crashes with "Module not found"

**Symptom:** Error like "Cannot find module 'typescript'" when running the host.

**Solution:**

This means the build didn't complete. Re-run the installer:

```bash
./install-linux.sh
```

It will rebuild the host and reinstall dependencies.

### Extension Shows "Waiting for response..."

**Symptom:** The extension side panel shows "Waiting for response..." but never connects.

**Solution:**

1. **Verify the host is running:**
   ```bash
   ps aux | grep -E "(host|node)" | grep -v grep
   ```

2. **Check the host binary path in the manifest:**
   ```bash
   cat ~/.config/chromium/NativeMessagingHosts/com.claude.chromium_native.json | grep path
   # Should match: ~/.local/share/claude-chromium-native-messaging/host
   ```

3. **Verify the API key:**
   ```bash
   cat ~/.config/claude-chromium-native-messaging/config.json
   ```

4. **Check browser console for network errors** (F12 → Console tab)

5. **Try restarting everything:**
   ```bash
   pkill -9 chromium
   rm ~/.config/chromium/NativeMessagingHosts/com.claude.chromium_native.json
   ./install-linux.sh  # re-install manifest
   chromium
   ```

### No Permission to Write to Config Directory

**Symptom:** Error like "Permission denied" when creating the config directory.

**Solution:**

This shouldn't happen in normal circumstances, but if it does:

```bash
# Check permissions
ls -la ~/.config/
ls -la ~/.config/claude-chromium-native-messaging/

# Fix ownership
sudo chown -R $USER:$USER ~/.config/claude-chromium-native-messaging/
chmod -R 700 ~/.config/claude-chromium-native-messaging/
```

---

## How It Works

### Linux Direct API Mode

Unlike macOS/Windows (which use Claude Desktop's native host), Linux uses "Direct API Mode":

```
Browser Extension
        ↓
   (Native Messaging)
        ↓
   Native Host (~/.local/share/.../host)
        ↓
   (HTTP to Claude API)
        ↓
   Claude Backend
```

The native host is a Node.js program that:
1. Reads messages from the browser via stdin (Native Messaging Protocol)
2. Extracts the user's message
3. Calls Claude's API directly using your API key
4. Returns the response to the browser via stdout

This means **no Claude Desktop required** — the host handles everything.

### Manifest Registration

The manifest is a JSON file that tells the browser where to find the native host:

```json
{
  "name": "com.claude.chromium_native",
  "path": "~/.local/share/claude-chromium-native-messaging/host",
  "type": "stdio",
  "allowed_origins": [
    "chrome-extension://fcoeoabgfenejglbffodgkkbkcdhcgfn/"
  ]
}
```

Chromium browsers look for manifests in:
- **User-level:** `~/.config/chromium/NativeMessagingHosts/` (used by installer)
- **System-wide:** `/etc/opt/chromium/native-messaging-hosts/` (requires admin)

### Configuration

The host reads your API key from:

```
~/.config/claude-chromium-native-messaging/config.json
```

This file is created by `install-linux.sh` and must contain:

```json
{
  "apiKey": "sk-ant-YOUR_KEY",
  "model": "claude-opus-4-6"
}
```

---

## Differences: Linux vs macOS/Windows

| Aspect | Linux (install-linux.sh) | macOS/Windows (setup.sh) |
|--------|--------------------------|--------------------------|
| **Host Source** | Built from Node.js source in this repo | Shipped with Claude Desktop |
| **API Mode** | Direct to Claude API | Via Claude Desktop |
| **Dependency** | Node.js 18+, API key | Claude Desktop |
| **Setup Time** | ~2 min (includes build) | ~1 min (just manifests) |
| **Config Location** | `~/.config/claude-chromium-native-messaging/config.json` | Usually in Claude Desktop |
| **Uninstall** | `./uninstall-linux.sh` removes everything | Manual cleanup of manifests |

Both approaches use the same manifest format and browser registration process. The difference is:
- **Linux:** Host is a Node.js program you build locally
- **macOS/Windows:** Host is a binary shipped with Claude Desktop

---

## Support

If you encounter issues not covered here:

1. **Check the FAQ in the main [README.md](../README.md)**
2. **Review [GitHub Issues](https://github.com/stolot0mt0m/claude-chromium-native-messaging/issues)**
3. **Search the [Discussions](https://github.com/stolot0mt0m/claude-chromium-native-messaging/discussions)**
4. **Open a new issue** with:
   - Your Linux distribution (`cat /etc/os-release`)
   - Node.js version (`node --version`)
   - Browser and version (`chromium --version`)
   - Exact error message or symptoms
   - Output of: `./install-linux.sh --verbose` (without the API key in the output)

---

**Last updated:** 2026-03-13
