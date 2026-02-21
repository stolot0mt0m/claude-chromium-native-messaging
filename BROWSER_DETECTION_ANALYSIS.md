# Browser Detection Analysis

Analysis of the browser detection logic in **claude-chromium-native-messaging**.

Date: 2026-02-22

---

## 1. Current Detection Flow

The browser detection follows a linear pipeline from script entry to manifest creation:

```
main() [setup.sh:641]
  |
  +-- Parse CLI arguments [setup.sh:643-687]
  |     Captures --path, --uninstall, --dry-run, etc.
  |
  +-- check_bash_version() [setup.sh:107-118]
  |     Requires Bash 4.0+
  |
  +-- detect_os() [setup.sh:162-169]
  |     Returns "macos", "linux", or "windows" based on uname -s
  |
  +-- get_claude_native_host_path() [setup.sh:185-211]
  |     Finds Claude Desktop native host binary (required)
  |     Checks 5 Linux paths, 1 macOS path with [[ -f "$path" ]]
  |     Exits with error if not found
  |
  +-- get_claude_code_native_host_path() [setup.sh:213-215]
  |     Returns $HOME/.claude/chrome/chrome-native-host
  |     ** No existence validation - just returns a hardcoded path **
  |     Existence checked later at manifest creation time [setup.sh:479]
  |
  +-- IF --path provided: Custom path flow [setup.sh:737-762]
  |     validate_path() -> existence check -> create_manifests()
  |
  +-- ELSE: Auto-detection flow [setup.sh:764-852]
        |
        +-- detect_browsers() [setup.sh:281-337]
        |     1. Try JSON config via load_browser_configs_from_json()
        |     2. Fall back to BUILTIN_BROWSER_CONFIGS array
        |     3. For each config: build path, check [[ -d "$full_path" ]]
        |     4. Return detected browsers as "Name|Path" lines
        |
        +-- Display found browsers with extension status [setup.sh:780-798]
        +-- Prompt user selection [setup.sh:801-816]
        +-- create_manifests() for each selected browser [setup.sh:821-852]
```

### JSON Config Loading: `load_browser_configs_from_json()` [setup.sh:254-279]

```
1. Check config file exists [setup.sh:255-257]
2. Check jq is installed [setup.sh:260-262]
3. Map OS to key ("macos" or "linux") [setup.sh:264-271]
4. Parse with jq: select browsers where .paths[$os] != null [setup.sh:274-278]
5. Output as "Name|RelativePath" pipe-delimited lines
```

### Path Construction in `detect_browsers()` [setup.sh:281-337]

```
base_path = get_app_support_base()
  - macOS: $HOME/Library/Application Support
  - Linux: $HOME/.config

full_path = base_path + "/" + browser_relative_path
  e.g. $HOME/.config/google-chrome

Check: [[ -d "$full_path" ]]  ->  detected if directory exists
```

---

## 2. Currently Supported Browsers

28 browsers are configured in `config/browsers.json` (lines 44-269). An identical fallback list exists in `BUILTIN_BROWSER_CONFIGS` (setup.sh lines 223-252).

| # | Browser | macOS Path | Linux Path | Windows Path |
|---|---------|-----------|------------|-------------|
| 1 | Brave | BraveSoftware/Brave-Browser | BraveSoftware/Brave-Browser | BraveSoftware\Brave-Browser\User Data |
| 2 | Arc | Arc/User Data | null | null |
| 3 | Vivaldi | Vivaldi | vivaldi | Vivaldi\User Data |
| 4 | Microsoft Edge | Microsoft Edge | microsoft-edge | Microsoft\Edge\User Data |
| 5 | Chromium | Chromium | chromium | Chromium\User Data |
| 6 | Google Chrome | Google/Chrome | google-chrome | Google\Chrome\User Data |
| 7 | Genspark | GensparkSoftware/Genspark-Browser | GensparkSoftware/Genspark-Browser | GensparkSoftware\Genspark-Browser\User Data |
| 8 | Opera | com.operasoftware.Opera | opera | Opera Software\Opera Stable |
| 9 | Opera GX | com.operasoftware.OperaGX | opera-gx | Opera Software\Opera GX Stable |
| 10 | Sidekick | Sidekick | Sidekick | Sidekick\User Data |
| 11 | Orion | Orion | Orion | null |
| 12 | Yandex | Yandex/YandexBrowser | yandex-browser | Yandex\YandexBrowser\User Data |
| 13 | Naver Whale | Naver/Whale | naver-whale | Naver\Whale\User Data |
| 14 | Coc Coc | CocCoc/Browser | coccoc | CocCoc\Browser\User Data |
| 15 | Comodo Dragon | Comodo/Dragon | comodo-dragon | Comodo\Dragon\User Data |
| 16 | Avast Secure Browser | AVAST Software/Browser | avast-secure-browser | AVAST Software\Browser\User Data |
| 17 | AVG Secure Browser | AVG/Browser | avg-secure-browser | AVG\Browser\User Data |
| 18 | Epic Privacy Browser | Epic Privacy Browser | epic | Epic Privacy Browser\User Data |
| 19 | Torch | Torch | torch | Torch\User Data |
| 20 | Slimjet | Slimjet | slimjet | Slimjet\User Data |
| 21 | SRWare Iron | Chromium | iron | Chromium\User Data |
| 22 | Ungoogled Chromium | Chromium | ungoogled-chromium | Chromium\User Data |
| 23 | Helium | net.imput.helium | net.imput.helium | imput\Helium\User Data |
| 24 | Cent Browser | CentBrowser | cent-browser | CentBrowser\User Data |
| 25 | Maxthon | Maxthon | maxthon | Maxthon\User Data |
| 26 | Iridium | Iridium | iridium-browser | Iridium\User Data |
| 27 | Falkon | falkon | falkon | null |
| 28 | Colibri | Nickolabs/Colibri | colibri | null |

**Notably absent**: Chrome Canary, Chrome Beta, Chrome Dev, Thorium, Waterfox, Kiwi Browser.

---

## 3. Path Validation Logic

### `validate_path()` [setup.sh:131-156]

Used only for `--path` custom browser paths, not for auto-detected browsers.

```bash
validate_path(path):
  1. resolved_path = realpath -m "$path"       # Resolve symlinks, normalize
     -> Fail if realpath returns error

  2. Security whitelist check by OS:
     - macOS: path must match ^(/Users/|$HOME)
     - Linux: path must match ^(/home/|$HOME|/tmp/)
     -> Fail if outside allowed directories

  3. Return resolved path
```

### Claude Desktop Host Validation [setup.sh:185-211]

```bash
get_claude_native_host_path():
  - Checks each candidate path with [[ -f "$path" ]]
  - Returns first existing path
  - Returns empty string if none found
  -> main() exits if empty [setup.sh:719-722]
```

### Claude Code Host Validation [setup.sh:213-215]

```bash
get_claude_code_native_host_path():
  - Returns hardcoded path: $HOME/.claude/chrome/chrome-native-host
  - NO existence check in this function
  - Existence checked later in create_manifests() [setup.sh:479]
  - Manifest only created if file exists at that point
```

### Browser Directory Validation [setup.sh:307, 329]

```bash
detect_browsers():
  - Checks [[ -d "$full_path" ]] for each browser
  - Only adds to detected list if directory exists
  - No validation of directory contents or permissions
```

---

## 4. Identified Issues

### Issue 1: Chrome Canary Is Marked as Unsupported

**Root Cause**: Chrome Canary is simply not listed in the browser configuration.

**Evidence**:
- `config/browsers.json` (lines 44-269): Contains 28 browser entries. None of them is "Chrome Canary", "Chrome Beta", or "Chrome Dev".
- `BUILTIN_BROWSER_CONFIGS` (setup.sh lines 223-252): Same 28 browsers, no Canary variant.
- The detection logic in `detect_browsers()` (setup.sh:281-337) **only checks browsers that appear in the configuration**. It iterates through the config entries and checks if their known paths exist. There is no filesystem scanning or wildcard discovery.

**Chrome Canary's actual data directory paths**:
- macOS: `$HOME/Library/Application Support/Google/Chrome Canary`
- Linux: `$HOME/.config/google-chrome-unstable`
- Windows: `%LOCALAPPDATA%\Google\Chrome SxS\User Data`

These paths differ from stable Google Chrome (`Google/Chrome`, `google-chrome`, `Google\Chrome\User Data`), so even if Chrome Canary is installed, it will never be detected.

**Fix**: Add a Chrome Canary entry to `config/browsers.json` and `BUILTIN_BROWSER_CONFIGS`:
```json
{
  "name": "Chrome Canary",
  "paths": {
    "macos": "Google/Chrome Canary",
    "linux": "google-chrome-unstable",
    "windows": "Google\\Chrome SxS\\User Data"
  }
}
```

---

### Issue 2: Custom Executable Paths Are Rejected

**Root Cause**: The `validate_path()` function (setup.sh:131-156) enforces a security whitelist that only permits paths under user home directories.

**Evidence**:
- Lines 143-147 (macOS): Path must match `^(/Users/|$HOME)`
- Lines 148-152 (Linux): Path must match `^(/home/|$HOME|/tmp/)`

**Rejection scenarios**:
1. A browser data directory under `/opt/` (e.g., `/opt/chromium/data`) is rejected on Linux because it doesn't start with `/home/` or `$HOME`.
2. A browser installed system-wide at `/usr/share/` or `/var/` is rejected.
3. On macOS, a path under `/Applications/` is rejected (only `/Users/` is allowed).
4. On Linux, XDG paths like `$XDG_DATA_HOME` pointing to non-home locations are rejected.

**The `--path` flag documentation** (setup.sh:600) says "Specify custom browser Application Support path", implying it accepts arbitrary paths, but the validation contradicts this.

**Note**: Auto-detected browsers bypass `validate_path()` entirely. The function is only called when `--path` is used (setup.sh:740). Auto-detection constructs paths from `get_app_support_base()` which is always under `$HOME`, so this restriction only affects the custom path feature.

**Fix**: Either relax the path validation to allow common system directories (`/opt/`, `/usr/lib/`, `/snap/`, `/var/`), or document the restriction clearly in the help text. A more nuanced approach would be to validate the path is a real directory containing Chromium profile data (e.g., check for a `Default/` subdirectory) rather than restricting by parent directory.

---

### Issue 3: Non-Existent Browser Paths Are Being Returned

**Root Cause**: The `get_claude_code_native_host_path()` function (setup.sh:213-215) returns a hardcoded path **without checking if it exists**.

**Evidence**:
```bash
get_claude_code_native_host_path() {
    echo "$HOME/.claude/chrome/chrome-native-host"
}
```

This always returns `$HOME/.claude/chrome/chrome-native-host` regardless of whether the file exists. Compare with `get_claude_native_host_path()` (setup.sh:185-211), which explicitly checks `[[ -f "$path" ]]` before returning each candidate path.

**Where the non-existent path surfaces**:
1. `main()` line 727: `code_native_host_path=$(get_claude_code_native_host_path)` — always gets a path string.
2. `main()` line 728: `if [[ -f "$code_native_host_path" ]]` — checks existence here, prints a warning if missing (line 731). This is **correct behavior** but the function itself still returns a non-existent path.
3. `create_manifests()` line 479: `if [[ -f "$code_native_host_path" ]]` — guards manifest creation. This is **correct**.

**Impact**: While the code is functionally safe (manifests are only created when the file exists), the function API is misleading. Callers must always verify the returned path exists, unlike `get_claude_native_host_path()` which guarantees a valid path or empty string.

**Secondary concern — browser data directory paths**: The `detect_browsers()` function (setup.sh:307) correctly checks `[[ -d "$full_path" ]]` before adding browsers to the detected list. However, there is a **TOCTOU (Time-Of-Check-Time-Of-Use) race condition**: the directory could be removed between detection and manifest creation. This is unlikely in practice but violates the principle of checking existence at point of use.

**Fix**: Make `get_claude_code_native_host_path()` consistent with `get_claude_native_host_path()` by checking file existence before returning:
```bash
get_claude_code_native_host_path() {
    local path="$HOME/.claude/chrome/chrome-native-host"
    if [[ -f "$path" ]]; then
        echo "$path"
    else
        echo ""
    fi
}
```

---

## 5. Key File Locations Reference

| Component | File | Lines |
|-----------|------|-------|
| Browser JSON config | `config/browsers.json` | 44-269 |
| Built-in browser fallback | `setup.sh` | 223-252 |
| Path validation | `setup.sh` → `validate_path()` | 131-156 |
| OS detection | `setup.sh` → `detect_os()` | 162-169 |
| Base path resolution | `setup.sh` → `get_app_support_base()` | 171-179 |
| Desktop host detection | `setup.sh` → `get_claude_native_host_path()` | 185-211 |
| Code host detection | `setup.sh` → `get_claude_code_native_host_path()` | 213-215 |
| JSON config loader | `setup.sh` → `load_browser_configs_from_json()` | 254-279 |
| Browser auto-detection | `setup.sh` → `detect_browsers()` | 281-337 |
| Extension check | `setup.sh` → `check_extension_installed()` | 343-361 |
| Manifest creation | `setup.sh` → `create_manifests()` | 394-510 |
| Custom path handling | `setup.sh` → `main()` | 737-762 |
| Auto-detect flow | `setup.sh` → `main()` | 764-852 |
| PowerShell equivalent | `setup.ps1` | Full file |

---

## 6. Architecture Notes

### Design Decisions
- **Dual config strategy**: JSON config with jq for flexibility, hardcoded fallback for portability. Good for environments without jq, but creates maintenance burden (two lists to keep in sync).
- **Directory-based detection**: Browsers are detected by the existence of their user data directory, not by checking for executables. This works well since the tool creates native messaging manifests inside these directories.
- **Security-restricted custom paths**: The `validate_path()` whitelist prevents writing manifests to system directories. This is intentionally conservative but overly restrictive for legitimate use cases.

### Potential Improvements Beyond the Three Issues
1. **Config drift risk**: `BUILTIN_BROWSER_CONFIGS` (setup.sh:223-252) and `config/browsers.json` must be manually kept in sync. A CI check or generation script would prevent drift.
2. **SRWare Iron / Ungoogled Chromium collision**: Both use `Chromium` as their macOS path (browsers.json lines 208, 216). If both are installed, they map to the same directory and only one will effectively be configured.
3. **No browser executable validation**: The script checks for user data directories but never verifies the browser binary is actually installed and runnable. A data directory could exist from a previously uninstalled browser.
