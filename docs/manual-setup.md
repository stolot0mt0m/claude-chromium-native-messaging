# Manual Setup Guide

This guide walks you through manually configuring Native Messaging Host for Claude in your Chromium-based browser.

## Overview

The setup involves creating two JSON manifest files in your browser's `NativeMessagingHosts` directory. These files tell the browser how to communicate with Claude's native applications.

## Step 1: Locate Your Browser's Application Support Directory

### macOS

Open Terminal and run:

```bash
ls ~/Library/Application\ Support/
```

Look for your browser's folder. Common paths:

| Browser | Path |
|---------|------|
| Brave | `~/Library/Application Support/BraveSoftware/Brave-Browser` |
| Arc | `~/Library/Application Support/Arc/User Data` |
| Vivaldi | `~/Library/Application Support/Vivaldi` |
| Microsoft Edge | `~/Library/Application Support/Microsoft Edge` |
| Chromium | `~/Library/Application Support/Chromium` |
| Genspark | `~/Library/Application Support/GensparkSoftware/Genspark-Browser` |
| Opera | `~/Library/Application Support/com.operasoftware.Opera` |

### Linux

Browser data is typically in `~/.config/`:

| Browser | Path |
|---------|------|
| Brave | `~/.config/BraveSoftware/Brave-Browser` |
| Vivaldi | `~/.config/vivaldi` |
| Microsoft Edge | `~/.config/microsoft-edge` |
| Chromium | `~/.config/chromium` |

## Step 2: Create the NativeMessagingHosts Directory

```bash
mkdir -p "/path/to/your/browser/NativeMessagingHosts"
```

Example for Genspark on macOS:
```bash
mkdir -p ~/Library/Application\ Support/GensparkSoftware/Genspark-Browser/NativeMessagingHosts
```


## Step 3: Verify Claude Installation Paths

Before creating the manifest files, verify that Claude's native host binaries exist:

### Claude Desktop Native Host

**macOS:**
```bash
ls -la /Applications/Claude.app/Contents/Helpers/chrome-native-host
```

**Linux (check these locations):**
```bash
ls -la /opt/Claude/chrome-native-host
ls -la /usr/lib/claude/chrome-native-host
ls -la ~/.local/share/Claude/chrome-native-host
```

### Claude Code Native Host (Optional)

```bash
ls -la ~/.claude/chrome/chrome-native-host
```

This file is created when you first run `/chrome` in Claude Code. If it doesn't exist yet, you can skip the Claude Code manifest.

## Step 4: Verify Claude Extension is Installed

Check if the Claude extension is installed in your browser:

```bash
ls "/path/to/your/browser/Default/Extensions/fcoeoabgfenejglbffodgkkbkcdhcgfn"
```

If this directory exists, the extension is installed. The ID `fcoeoabgfenejglbffodgkkbkcdhcgfn` is the official Claude extension.

## Step 5: Create the Manifest Files

### File 1: Claude Desktop Manifest

Create `com.anthropic.claude_browser_extension.json`:

```bash
cat > "/path/to/your/browser/NativeMessagingHosts/com.anthropic.claude_browser_extension.json" << 'EOF'
{
  "name": "com.anthropic.claude_browser_extension",
  "description": "Claude Browser Extension Native Host",
  "path": "/Applications/Claude.app/Contents/Helpers/chrome-native-host",
  "type": "stdio",
  "allowed_origins": [
    "chrome-extension://dihbgbndebgnbjfmelmegjepbnkhlgni/",
    "chrome-extension://fcoeoabgfenejglbffodgkkbkcdhcgfn/",
    "chrome-extension://dngcpimnedloihjnnfngkgjoidhnaolf/"
  ]
}
EOF
```

> **Note:** On Linux, replace the `path` value with your actual Claude native host path.


### File 2: Claude Code Manifest (Optional)

Create `com.anthropic.claude_code_browser_extension.json`:

```bash
cat > "/path/to/your/browser/NativeMessagingHosts/com.anthropic.claude_code_browser_extension.json" << EOF
{
  "name": "com.anthropic.claude_code_browser_extension",
  "description": "Claude Code Browser Extension Native Host",
  "path": "$HOME/.claude/chrome/chrome-native-host",
  "type": "stdio",
  "allowed_origins": [
    "chrome-extension://fcoeoabgfenejglbffodgkkbkcdhcgfn/"
  ]
}
EOF
```

> **Important:** The `$HOME` variable will be expanded when you run this command. Make sure it resolves to your actual home directory path.

## Step 6: Verify File Permissions

Ensure the manifest files are readable:

```bash
chmod 644 "/path/to/your/browser/NativeMessagingHosts/"*.json
```

## Step 7: Restart Your Browser

1. **Completely quit your browser** - not just close windows, but fully quit the application
2. On macOS, check Activity Monitor to ensure no browser processes are running
3. On Linux, use `ps aux | grep -i yourbrowser` to verify
4. Start your browser fresh

## Step 8: Test the Connection

### Test Claude Desktop Integration

1. Open your browser
2. Click the Claude extension icon to open the side panel
3. The extension should connect to Claude Desktop

### Test Claude Code Integration

1. Open your terminal
2. Run `claude` to start Claude Code
3. Type `/chrome` to check the connection status
4. If connected, you should see a success message


## Complete Example: Genspark Browser on macOS

Here's a complete walkthrough for Genspark Browser:

```bash
# 1. Create the NativeMessagingHosts directory
mkdir -p ~/Library/Application\ Support/GensparkSoftware/Genspark-Browser/NativeMessagingHosts

# 2. Create Claude Desktop manifest
cat > ~/Library/Application\ Support/GensparkSoftware/Genspark-Browser/NativeMessagingHosts/com.anthropic.claude_browser_extension.json << 'EOF'
{
  "name": "com.anthropic.claude_browser_extension",
  "description": "Claude Browser Extension Native Host",
  "path": "/Applications/Claude.app/Contents/Helpers/chrome-native-host",
  "type": "stdio",
  "allowed_origins": [
    "chrome-extension://dihbgbndebgnbjfmelmegjepbnkhlgni/",
    "chrome-extension://fcoeoabgfenejglbffodgkkbkcdhcgfn/",
    "chrome-extension://dngcpimnedloihjnnfngkgjoidhnaolf/"
  ]
}
EOF

# 3. Create Claude Code manifest
cat > ~/Library/Application\ Support/GensparkSoftware/Genspark-Browser/NativeMessagingHosts/com.anthropic.claude_code_browser_extension.json << EOF
{
  "name": "com.anthropic.claude_code_browser_extension",
  "description": "Claude Code Browser Extension Native Host",
  "path": "$HOME/.claude/chrome/chrome-native-host",
  "type": "stdio",
  "allowed_origins": [
    "chrome-extension://fcoeoabgfenejglbffodgkkbkcdhcgfn/"
  ]
}
EOF

# 4. Verify the files were created
ls -la ~/Library/Application\ Support/GensparkSoftware/Genspark-Browser/NativeMessagingHosts/

# 5. View the contents
cat ~/Library/Application\ Support/GensparkSoftware/Genspark-Browser/NativeMessagingHosts/*.json
```

## Troubleshooting

### "Native messaging host not found" error

1. Verify the manifest file exists in the correct location
2. Check that the `path` in the manifest points to an existing executable
3. Ensure the JSON is valid (no trailing commas, proper quotes)

### Extension doesn't connect after restart

1. Make sure the browser was fully quit (not just windows closed)
2. Check the extension ID matches what's in `allowed_origins`
3. Verify file permissions are readable (644)

### Claude Code `/chrome` doesn't detect browser

This is a known limitation. Claude Code specifically looks for Google Chrome processes. You may need to:

1. Open your Chromium browser manually first
2. Then run `/chrome` in Claude Code

See [Related Issues](../README.md#related-issues) for updates on this.

## Uninstalling

To remove the configuration:

```bash
rm "/path/to/your/browser/NativeMessagingHosts/com.anthropic.claude_browser_extension.json"
rm "/path/to/your/browser/NativeMessagingHosts/com.anthropic.claude_code_browser_extension.json"
```
