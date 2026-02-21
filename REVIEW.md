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

## Known Limitations
- `validate_path()` validates the path as an existing, readable directory — it does NOT verify it's actually a browser data directory. Intentional: `--path` is an expert option.
- Chrome Dev and Chrome Canary share `google-chrome-unstable` on Linux. Benign (manifests written to same `NativeMessagingHosts/` path).
- The `test_json_config_matches_builtin` integration test has pre-existing false warnings due to whitespace-stripping regex. Not addressed.

## Scalability Notes
No concerns. Adding browser entries is O(1) static config lookup. Detection loop (now 31 browsers) checks directory existence, negligible overhead.

## Security Review
- Path traversal (`..`) detection is maintained
- No command injection vectors — all paths are quoted and validated before use
- `realpath -m` handles symlinks safely
- The script runs as the current user; filesystem permissions are the primary access control
