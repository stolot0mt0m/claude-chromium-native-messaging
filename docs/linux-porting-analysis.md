# Linux Porting Analysis

**Project:** claude-chromium-native-messaging
**Analyzed:** 2026-03-13
**Scope:** Identify every Claude Desktop dependency and Linux-blocking issue; propose a concrete Linux-compatible approach.

---

## 1. Current Architecture Diagram

```
┌──────────────────────────────────────────────────────────────┐
│                    THIS REPOSITORY                           │
│                                                              │
│  setup.sh / setup.ps1                                        │
│  ┌───────────────────────────────────────────┐              │
│  │ 1. detect_os()                            │              │
│  │ 2. get_claude_native_host_path()  ──────────── EXIT if   │
│  │    (checks hardcoded filesystem paths)    │    not found  │
│  │ 3. detect_browsers()                      │              │
│  │    (scans ~/.config/<name>/ on Linux)     │              │
│  │ 4. create_manifests()                     │              │
│  │    → writes two JSON files per browser    │              │
│  └───────────────────────────────────────────┘              │
└──────────────────────────────────────────────────────────────┘
         │                              │
         ▼                              ▼
┌─────────────────┐          ┌──────────────────────┐
│ MANIFEST FILE 1 │          │ MANIFEST FILE 2       │
│ (Claude Desktop)│          │ (Claude Code)         │
│                 │          │                       │
│ com.anthropic.  │          │ com.anthropic.        │
│ claude_browser  │          │ claude_code_browser   │
│ _extension.json │          │ _extension.json       │
│                 │          │                       │
│ type: "stdio"   │          │ type: "stdio"         │
│ path: →         │          │ path: →               │
│  chrome-native  │          │  chrome-native-host   │
│  -host (binary) │          │  (binary, optional)   │
└────────┬────────┘          └──────────┬────────────┘
         │                              │
         ▼                              ▼
┌─────────────────┐          ┌──────────────────────┐
│ chrome-native-  │          │ ~/.claude/chrome/     │
│ host (binary)   │          │ chrome-native-host    │
│ SHIPS WITH      │          │ SHIPS WITH            │
│ Claude Desktop  │          │ Claude Code (/chrome) │
└────────┬────────┘          └──────────┬────────────┘
         │                              │
         │  stdin/stdout (stdio)        │  stdin/stdout (stdio)
         │  Chrome Native Messaging     │  Chrome Native Messaging
         │  Protocol (4-byte LE length  │  Protocol
         │  prefix + JSON payload)      │
         ▼                              ▼
┌──────────────────────────────────────────────────────────────┐
│                 CHROMIUM BROWSER                             │
│  Extension ID: fcoeoabgfenejglbffodgkkbkcdhcgfn             │
│  (reads manifests from <browser-data>/NativeMessagingHosts/) │
└──────────────────────────────────────────────────────────────┘
         │
         │  IPC (socket/pipe — internal to Claude Desktop)
         ▼
┌──────────────────┐
│  Claude Desktop  │
│  (or Claude Code │
│   daemon)        │
└──────────────────┘
```

### Data Flow Summary

1. `setup.sh` detects Claude Desktop's `chrome-native-host` binary on the local filesystem.
2. It writes JSON manifest files into each detected browser's `NativeMessagingHosts/` subdirectory.
3. When the browser launches, it reads these manifests and can spawn the native host binary via stdio when the extension requests it.
4. The native host binary communicates with Claude Desktop via its own IPC (platform socket/named pipe — not part of this repo).

This repository **only manages the manifest files**. It does not ship, wrap, or implement the native host binary itself.

---

## 2. Claude Desktop Dependency Points

### 2.1 Hard Blocking Exit

**File:** `setup.sh`
**Lines:** 830–835

```bash
local native_host_path
native_host_path=$(get_claude_native_host_path)
if [[ -z "$native_host_path" ]]; then
    print_error "Claude Desktop not found. Please install Claude Desktop first."
    print_info "Download from: https://claude.ai/download"
    exit 1
fi
```

**Effect:** The script **exits unconditionally** if `chrome-native-host` is not found. There is no way to proceed using only Claude Code on Linux without modifying the script.

---

### 2.2 Hardcoded Linux Desktop Paths (Speculative)

**File:** `setup.sh`
**Lines:** 209–226 (`get_claude_native_host_path()`)

```bash
elif [[ "$OS" == "linux" ]]; then
    local paths=(
        "/opt/Claude/chrome-native-host"
        "/usr/lib/claude/chrome-native-host"
        "$HOME/.local/share/Claude/chrome-native-host"
        "/snap/claude/current/chrome-native-host"
        "$HOME/.var/app/ai.anthropic.claude/chrome-native-host"
    )
```

**Effect:** These five paths are guesses — no official Anthropic documentation confirms them. If Claude Desktop ships for Linux with a different layout (e.g. AppImage, different snap ID, different `.local` structure), all five checks fail and the script exits.

**Also referenced in:** `config/browsers.json` lines 29–37 (same five paths in the `claude_paths.linux.desktop` array, but the JSON array is **not actually read by the script** — only `get_claude_native_host_path()` in `setup.sh` is called).

---

### 2.3 Hardcoded macOS Desktop Path

**File:** `setup.sh`
**Line:** 204

```bash
local path="/Applications/Claude.app/Contents/Helpers/chrome-native-host"
```

This is macOS-only and works because Claude Desktop has a fixed `.app` layout on macOS. Linux has no equivalent fixed installation convention.

---

### 2.4 Claude Code Native Host (Cross-Platform, Non-Blocking)

**File:** `setup.sh`
**Lines:** 230–232 (`get_claude_code_native_host_path()`)

```bash
get_claude_code_native_host_path() {
    echo "$HOME/.claude/chrome/chrome-native-host"
}
```

**File:** `setup.ps1`
**Lines:** 181–183 (`Get-ClaudeCodeNativeHostPath`)

```powershell
function Get-ClaudeCodeNativeHostPath {
    return "$env:USERPROFILE\.claude\chrome\chrome-native-host.exe"
}
```

**Effect:** The Claude Code path is cross-platform (`~/.claude/chrome/chrome-native-host`) and already valid on Linux. **Critically, this check is non-fatal** — if the file doesn't exist, the script continues and creates only the Desktop manifest (return code 2 = partial success).

**Known issue:** `get_claude_code_native_host_path()` returns a path **without validating existence**, unlike `get_claude_native_host_path()`. The existence check happens at the call site (`setup.sh:579`: `if [[ -f "$code_native_host_path" ]]`).

---

### 2.5 Manifest Names and Extension IDs

**File:** `setup.sh`
**Lines:** 22–31

```bash
readonly CLAUDE_OFFICIAL_EXTENSION_ID="fcoeoabgfenejglbffodgkkbkcdhcgfn"
readonly CLAUDE_DEV_EXTENSION_ID="dihbgbndebgnbjfmelmegjepbnkhlgni"
readonly CLAUDE_STAGING_EXTENSION_ID="dngcpimnedloihjnnfngkgjoidhnaolf"
```

These are Anthropic-controlled extension IDs embedded in the `allowed_origins` of both manifests. They are not platform-specific.

**Manifest names** (referenced in both scripts and `docs/manual-setup.md`):
- `com.anthropic.claude_browser_extension` → Claude Desktop host
- `com.anthropic.claude_code_browser_extension` → Claude Code host

---

### 2.6 Windows-Specific Paths (setup.ps1)

**File:** `setup.ps1`
**Lines:** 147–178 (`Get-ClaudeNativeHostPath`)

```powershell
$possiblePaths = @(
    "$env:APPDATA\Claude\ChromeNativeHost\chrome-native-host.exe",
    "$env:LOCALAPPDATA\Programs\claude\resources\chrome-native-host.exe",
    "$env:LOCALAPPDATA\Claude\chrome-native-host.exe",
    "$env:PROGRAMFILES\Claude\chrome-native-host.exe",
    "${env:PROGRAMFILES(x86)}\Claude\chrome-native-host.exe"
)
```

Plus MSIX/Windows Store detection via `$env:LOCALAPPDATA\Packages\Claude_*`. Entirely Windows-specific.

---

## 3. Linux Blocking Issues

### Issue 1: Hard Exit on Missing Claude Desktop (CRITICAL)

**Where:** `setup.sh:831–834`
**Severity:** Blocker — script cannot complete without Claude Desktop.

Claude Desktop was not officially available for Linux at the time this analysis was written. Even if it ships for Linux, the five speculative paths (Issue 2) may not match.

### Issue 2: Speculative Linux Installation Paths (HIGH)

**Where:** `setup.sh:211–225`
**Severity:** High — even when Claude Desktop exists, it may not be found.

The five paths were written without reference to an official Linux release. Real Linux packages commonly use:
- Debian/Ubuntu (`.deb`): could install to `/opt/claude/`, `/usr/lib/claude/`, or AppArmor-sandboxed locations
- Arch (AUR): typically `/opt/` or `/usr/lib/`
- Flatpak: `~/.var/app/<appid>/` — but the appid `ai.anthropic.claude` is unverified
- Snap: `/snap/claude/current/` — but the snap name `claude` is unverified
- AppImage: user-chosen location — no canonical path

### Issue 3: Claude Code `/chrome` Command Does Not Detect Non-Chrome Browsers (MEDIUM)

**Where:** Documented in `README.md:260–263`, `docs/manual-setup.md:223–226`

Claude Code's `/chrome` command detects browsers by process name (`chrome`), not by manifest files. This is a **Claude Code limitation** unrelated to this repository, but it affects the value proposition on Linux where Chrome is less dominant.

**Upstream issue:** [anthropics/claude-code#14370](https://github.com/anthropics/claude-code/issues/14370)

### Issue 4: No Claude Code Native Host Existence Validation (LOW)

**Where:** `setup.sh:230–232` (`get_claude_code_native_host_path()`)
**Severity:** Low — already documented in project MEMORY.md.

The function returns a path without checking if it exists, unlike `get_claude_native_host_path()`. This is an inconsistency but not a blocker since the caller (`setup.sh:579`) does the existence check.

### Issue 5: macOS Hint in Error Message (COSMETIC)

**Where:** `setup.sh:121`

```bash
print_info "macOS users: Install newer Bash with 'brew install bash'"
```

This is inside `check_bash_version()` which runs on Linux too. On Linux this message is irrelevant (Homebrew is not the package manager). Minor UX issue only.

### Issue 6: No System-Wide Manifest Support (LOW)

The script only places manifests in user-level browser data directories (`~/.config/<browser>/NativeMessagingHosts/`). On Linux, system-wide native messaging manifests go to `/etc/opt/chromium/native-messaging-hosts/` (Chromium) or `/etc/opt/chrome/native-messaging-hosts/` (Chrome). This is intentional design (per-user is safer), but worth noting.

---

## 4. Proposed Linux-Compatible Approach

### Strategy A: Make Claude Desktop Optional (Recommended for Short Term)

The simplest change: **decouple the Claude Desktop check from the fatal exit**. This allows Linux users who only have Claude Code (and not Claude Desktop) to still configure their browser.

**Changes to `setup.sh`:**

```bash
# Replace the fatal exit (lines 831–835) with a soft warning:
local native_host_path
native_host_path=$(get_claude_native_host_path)
if [[ -z "$native_host_path" ]]; then
    print_warning "Claude Desktop not found — Desktop manifest will be skipped."
    print_info "Install Claude Desktop from: https://claude.ai/download"
fi

# Then in create_manifests(), skip the Desktop manifest if native_host_path is empty:
if [[ -n "$native_host_path" ]]; then
    # write com.anthropic.claude_browser_extension.json
fi
```

**Add a new flag:** `--require-desktop` to restore the old fatal behavior for users who explicitly need Claude Desktop.

**Impact:** Linux users with only Claude Code can configure `com.anthropic.claude_code_browser_extension.json` immediately. This is already fully functional (`~/.claude/chrome/chrome-native-host` exists after first `/chrome` run).

---

### Strategy B: Improve Linux Path Discovery

Add dynamic discovery on Linux to supplement the five hardcoded paths. Run after all static paths fail:

```bash
# Try: locate chrome-native-host via PATH / which / find in common prefixes
local discovered
discovered=$(find /opt /usr/lib "$HOME/.local" -name "chrome-native-host" -type f 2>/dev/null | head -1)
if [[ -n "$discovered" && -f "$discovered" ]]; then
    echo "$discovered"
    return 0
fi

# Try: Flatpak with correct appid once confirmed by Anthropic
# Try: Snap with correct snap name once confirmed by Anthropic
```

This is best-effort and should only run if the static paths all fail.

---

### Strategy C: Support User-Provided Desktop Path

Add a `--desktop-path` flag (separate from `--path` which specifies browser data directory):

```bash
--desktop-path PATH    Path to Claude Desktop's chrome-native-host binary
                       (for non-standard installations)
```

This lets Linux users with uncommon install paths (AppImage, custom prefix) point directly to the binary without waiting for autodetection support.

---

### Strategy D: Document the Linux Status Clearly

Until Claude Desktop ships officially for Linux, add a **Linux Status** section to the README and `docs/manual-setup.md`:

```markdown
## Linux Status

**Claude Code:** Fully supported. The `~/.claude/chrome/chrome-native-host`
binary is created by Claude Code when you run `/chrome`. Browser manifest
setup works on Linux without Claude Desktop.

**Claude Desktop:** In limited availability on Linux. If you have Claude Desktop
installed and the script does not find it automatically, use:

```bash
./setup.sh --desktop-path /path/to/chrome-native-host
```

Known installation paths (community-verified):
- `/opt/Claude/chrome-native-host` (manual/DEB installs)
- `~/.local/share/Claude/chrome-native-host` (user installs)
```

---

### Concrete Implementation Priority

| Priority | Action | Effort | Impact |
|----------|--------|--------|--------|
| **P0** | Make Claude Desktop check non-fatal; allow Claude Code-only mode | Low (5 lines) | Unblocks all Linux Claude Code users |
| **P1** | Add `--desktop-path` flag for custom binary location | Low (20 lines) | Unblocks Linux Claude Desktop early adopters |
| **P2** | Improve Linux path discovery with `find`-based fallback | Medium | Reduces manual intervention |
| **P3** | Fix bash version error message to remove macOS-only hint | Trivial | Cosmetic |
| **P4** | Document Linux status in README | Low | Reduces support burden |

---

## 5. Communication Protocol Reference

### Chrome Native Messaging Protocol

- **Transport:** `stdio` (stdin/stdout of the native host process)
- **Message format:** 4-byte little-endian unsigned integer (message length) followed by JSON payload
- **Direction:** bidirectional; browser extension sends JSON, native host replies JSON
- **Lifecycle:** browser spawns native host process on demand; process exits when connection closes

### Manifest Schema

```json
{
  "name": "com.anthropic.claude_browser_extension",
  "description": "Human-readable description",
  "path": "/absolute/path/to/chrome-native-host",
  "type": "stdio",
  "allowed_origins": [
    "chrome-extension://EXTENSION_ID/"
  ]
}
```

- `name` must match the `name` field used by the extension when calling `chrome.runtime.connectNative(name)`
- `path` must be an **absolute path** to an executable
- `type` is always `"stdio"` for Chrome Native Messaging
- `allowed_origins` is the allowlist of extension IDs that can connect

### Manifest Registration Location (Linux)

| Scope | Location |
|-------|----------|
| Per-user (used by this script) | `~/.config/<browser>/NativeMessagingHosts/<name>.json` |
| System-wide (not used) | `/etc/opt/chromium/native-messaging-hosts/<name>.json` |

The per-user location is browser-specific and must match the browser's data directory name exactly.
