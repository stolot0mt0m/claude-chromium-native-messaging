# Review: Custom Path Validation Fix + Chrome Canary/Beta/Dev Support

## Architecture Decisions

### validate_path() Redesign
- **Old**: Path whitelist checking if resolved path starts with `/home/`, `/Users/`, or `/tmp/`. Rejected legitimate paths like `/opt/`, `/usr/local/`, `/snap/`.
- **New**: Filesystem-based validation — checks that path is absolute, exists as a directory, and is readable. No path prefix whitelist.
- **Why**: The whitelist approach was fundamentally broken for users with browsers installed outside `$HOME`. Filesystem checks are the correct validation — if the directory exists and is readable, it's a valid target for manifest installation.

### Security: Path Traversal Prevention
- Retained: rejects paths containing `..` when realpath resolves to a different location.
- Dropped: the `/home/` and `/Users/` prefix whitelist. An attacker with shell access already has more powerful tools than `--path`. The real protection is filesystem permissions.

### Data directory paths vs executable paths
This project detects browsers by their **data directories** (e.g. `~/.config/google-chrome-unstable`), not executable paths. The `--path` flag accepts a data directory, and `validate_path()` validates it exists as a directory.

### Chrome Canary/Beta/Dev Addition
- Added to both `browsers.json` and `BUILTIN_BROWSER_CONFIGS` for consistency.
- Chrome Canary on Linux uses `google-chrome-unstable` (same as Chrome Dev — correct, as Canary is the nightly build of the unstable channel on Linux).

### Arithmetic Bug Fix (`set -e` + `((var++))`)
- Fixed `((var++))` under `set -e`. When var=0, bash arithmetic returns exit code 1 (falsy), which `set -e` treats as failure. Added `|| true` to all counter increments in tests and setup.sh.
- This was a pre-existing bug that prevented the test suite from running.

### Browser Installation Validation (`validate_browser_installation()`)
- **Problem**: `detect_browsers()` previously only checked `[[ -d "$full_path" ]]` — any existing directory was considered a valid browser. Stale/leftover directories from uninstalled browsers (empty dirs, dirs without Chromium profile data) would appear in the browser list.
- **Solution**: New `validate_browser_installation()` function that checks for Chromium profile markers: `Default/` directory, `Preferences` file, `Local State` file, or `Profile N` directories. A data directory must contain at least one of these to be considered a valid installation.
- **Why markers instead of executables**: This project detects browsers by data directories, not executables. The markers are the data-directory equivalent of "executable exists" — they prove the browser has actually been used, not just that a directory was created.

### `--debug` Flag
- **New**: `--debug` / `-d` flag that enables `--verbose` plus additional debug output showing all checked paths with skip reasons (e.g., "Skipped Opera: directory is empty").
- **Why separate from `--verbose`**: `--verbose` shows operational progress (found browsers, loaded configs). `--debug` adds diagnostic detail about why browsers were skipped — useful for troubleshooting but noisy for normal use.

## Known Limitations
- `validate_path()` validates the path as an existing, readable directory — it does NOT verify it's actually a browser data directory. Intentional: `--path` is an expert option.
- `validate_browser_installation()` relies on Chromium profile markers (Default/, Preferences, Local State, Profile N). Non-Chromium browsers using different directory structures would be incorrectly rejected. All 31 configured browsers are Chromium-based, so this is safe.
- Chrome Dev and Chrome Canary share `google-chrome-unstable` on Linux. Benign (manifests written to same `NativeMessagingHosts/` path).
- The `test_json_config_matches_builtin` integration test has pre-existing false warnings due to whitespace-stripping regex. Not addressed.

## Scalability Notes
No concerns. Adding browser entries is O(1) static config lookup. Detection loop (now 31 browsers) checks directory existence + profile markers, negligible overhead (filesystem stat calls only, no I/O).

## Security Review
- Path traversal (`..`) detection is maintained
- No command injection vectors — all paths are quoted and validated before use
- `realpath -m` handles symlinks safely
- `validate_browser_installation()` uses only `-d`, `-f`, and nullglob — no command execution, no string interpolation risk
- The script runs as the current user; filesystem permissions are the primary access control

---

# Review: Documentation Update (v1.2.0)

## Architecture Decisions

### FAQ Placement
FAQ section placed between Troubleshooting and Uninstall in README, mirroring the user journey: hit a problem (Troubleshooting), need deeper understanding (FAQ), want to remove (Uninstall).

### Custom Path Documentation Approach
Rather than listing every possible browser location, the README teaches users to find their own browser's data directory via `chrome://version`. This scales to any Chromium browser without maintaining an exhaustive path list.

### browsers.json `_documentation` Field
Added a top-level `_documentation` object explaining path conventions and custom path usage. Follows the existing `_comment` pattern on individual entries and uses underscore-prefixed keys (conventional JSON metadata) to avoid breaking parsers.

## Known Limitations
- FAQ notes Chrome Canary and Chrome Dev share `google-chrome-unstable` on Linux — platform constraint, documented explicitly.
- `docs/manual-setup.md` may need a corresponding update for custom paths (not in scope for this change).
- `_documentation` in browsers.json is informal metadata with no JSON Schema enforcement.

## Security Review
- No security-relevant changes. Documentation accurately describes existing filesystem validation without exposing exploitable implementation details
