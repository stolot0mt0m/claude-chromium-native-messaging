# Linux Support Analysis

**Project:** claude-chromium-native-messaging
**Updated:** 2026-03-13
**Status:** Resolved — Linux support via Claude Code CLI

---

## Summary

Linux support is provided through **Claude Code CLI**, which installs a native messaging host at `~/.claude/chrome/chrome-native-host`. This tool extends Claude Code's browser registrations to additional Chromium browsers beyond Chrome and Edge.

### Previous Approach (Removed)

Earlier versions included a "Direct API Mode" — a custom Node.js native messaging host that called the Claude API directly using an API key. This was removed because:

1. **Claude Code CLI provides the native host** — no need for a separate implementation
2. **API key management added complexity** — users had to manage API keys separately
3. **Feature parity** — Claude Code's native host provides full functionality
4. **Maintenance burden** — keeping a separate API client in sync with Claude's API changes

### Current Approach

The Linux installer (`install-linux.sh`) simply:
1. Verifies Claude Code CLI is installed and its native host exists
2. Copies the native messaging manifest to additional browser directories

No build step, no API key, no Node.js dependencies beyond Claude Code itself.

---

## Architecture

```
Claude Code CLI
    └── ~/.claude/chrome/chrome-native-host (native host binary)
    └── Manifests for Chrome + Edge (auto-installed)

install-linux.sh
    └── Copies manifest to Brave, Vivaldi, Opera, Chromium, 25+ more browsers
    └── Points all manifests to Claude Code's native host

Browser
    └── Reads manifest from NativeMessagingHosts/
    └── Spawns native host via stdio
    └── Extension communicates with Claude Code
```

## Known Limitations

1. **Claude Code required** — Claude Desktop is not available for Linux
2. **`/chrome` browser detection** — Claude Code's `/chrome` command detects browsers by process name, which may not find non-Chrome browsers ([#14370](https://github.com/anthropics/claude-code/issues/14370))
3. **Native host initialization** — Users must run Claude Code at least once and use `/chrome` to create the native host before this tool can work
