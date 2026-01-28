# Claude Native Messaging for Chromium Browsers

Enable Claude in Chrome extension to work with alternative Chromium-based browsers like Brave, Arc, Vivaldi, Edge, Genspark, and others.

## The Problem

Claude's browser extension officially supports only Google Chrome. However, the extension itself works fine in other Chromium-based browsers — it's just the Native Messaging Host configuration that's missing. This prevents:

- Claude Desktop from connecting to the browser extension
- Claude Code's `/chrome` command from detecting the extension

## The Solution

This repository provides scripts to automatically configure the Native Messaging Host for your Chromium-based browser, enabling full Claude integration.

## Supported Browsers

| Browser | macOS | Linux | Windows |
|---------|-------|-------|---------|
| Brave | ✅ | ✅ | 🔜 |
| Arc | ✅ | N/A | N/A |
| Vivaldi | ✅ | ✅ | 🔜 |
| Microsoft Edge | ✅ | ✅ | 🔜 |
| Chromium | ✅ | ✅ | 🔜 |
| Genspark | ✅ | ✅ | 🔜 |
| Opera | ✅ | ✅ | 🔜 |
| Custom | ✅ | ✅ | 🔜 |

## Prerequisites

1. **Claude Desktop** installed (`/Applications/Claude.app` on macOS)
2. **Claude in Chrome extension** installed in your Chromium browser
3. The extension ID should be `fcoeoabgfenejglbffodgkkbkcdhcgfn` (official Claude extension)

## Quick Start

### macOS / Linux

```bash
# Clone the repository
git clone https://github.com/anthropics/claude-chromium-native-messaging.git
cd claude-chromium-native-messaging

# Run the setup script
./setup.sh
```

### Manual Installation

If you prefer to set things up manually, see [Manual Setup Guide](docs/manual-setup.md).

## How It Works

### Background

Chrome extensions can communicate with native applications through Chrome's [Native Messaging API](https://developer.chrome.com/docs/extensions/develop/concepts/native-messaging). This requires a JSON manifest file that tells the browser:

1. The name of the native messaging host
2. The path to the native host executable
3. Which extensions are allowed to communicate with it

### What the Script Does

1. **Detects installed Chromium browsers** by checking common installation paths
2. **Locates Claude's native host binary** at `/Applications/Claude.app/Contents/Helpers/chrome-native-host`
3. **Creates the NativeMessagingHosts directory** in your browser's application support folder
4. **Generates two manifest files**:
   - `com.anthropic.claude_browser_extension.json` - For Claude Desktop integration
   - `com.anthropic.claude_code_browser_extension.json` - For Claude Code integration

### Manifest File Structure

```json
{
  "name": "com.anthropic.claude_browser_extension",
  "description": "Claude Browser Extension Native Host",
  "path": "/Applications/Claude.app/Contents/Helpers/chrome-native-host",
  "type": "stdio",
  "allowed_origins": [
    "chrome-extension://fcoeoabgfenejglbffodgkkbkcdhcgfn/"
  ]
}
```

## Verification

After running the setup:

1. **Completely quit your browser** (check Activity Monitor/Task Manager)
2. **Restart the browser**
3. **Open the Claude extension** in the side panel
4. **For Claude Code**: Run `/chrome` in your terminal — it should detect the connection

## Troubleshooting

### Extension not connecting

1. Make sure you've completely restarted the browser (not just closed windows)
2. Verify the extension is installed and has the correct ID
3. Check that Claude Desktop is installed

### Claude Code doesn't detect the browser

Claude Code specifically looks for Google Chrome processes. Even with native messaging configured, you may need to:

1. Open your Chromium browser manually first
2. Then run `/chrome` in Claude Code

This is a known limitation — see [GitHub Issue #14370](https://github.com/anthropics/claude-code/issues/14370).

### Permission errors

```bash
# Make sure the script is executable
chmod +x setup.sh

# If you get permission errors on the manifest files
chmod 644 ~/Library/Application\ Support/YOUR_BROWSER/NativeMessagingHosts/*.json
```

### Finding your browser's Application Support path

```bash
# The script will auto-detect, but you can also check manually:
ls ~/Library/Application\ Support/ | grep -i "your-browser-name"
```

## Uninstall

To remove the configuration:

```bash
./setup.sh --uninstall
```

Or manually delete the `NativeMessagingHosts` folder from your browser's Application Support directory.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request. Areas where help is needed:

- [ ] Windows support (PowerShell script)
- [ ] Additional browser detection
- [ ] Automated testing

## Related Issues

- [#14370 - Detect Claude Chrome extension in other Chromium-based browsers](https://github.com/anthropics/claude-code/issues/14370)
- [#18075 - Add CLAUDE_CODE_CHROME_PATH env var](https://github.com/anthropics/claude-code/issues/18075)
- [#14536 - Allow browser selection instead of opening default browser](https://github.com/anthropics/claude-code/issues/14536)

## License

MIT License - See [LICENSE](LICENSE) for details.

## Disclaimer

This is an unofficial workaround. The official Claude in Chrome extension is designed for Google Chrome only. Use at your own risk. Anthropic may change the native messaging implementation at any time, which could break this workaround.
