# Testing Guide

## Overview

The test suite validates browser detection, path validation, config file handling, and manifest creation for the Claude Native Messaging setup scripts. Tests run in CI without real browser installations by mocking the filesystem.

## Running Tests

### Bash Tests (Linux / macOS)

```bash
# Run all tests
bash tests/test_setup.sh && bash tests/test_browser_detection.sh

# Run only the core test suite
bash tests/test_setup.sh

# Run only browser detection integration tests
bash tests/test_browser_detection.sh
```

### PowerShell Tests (Windows)

```powershell
powershell -ExecutionPolicy Bypass -File tests\test_setup.ps1
```

### Requirements

- **Bash 4.0+** (macOS: `brew install bash`)
- **jq** (optional, but required for JSON config tests; install with `apt install jq` or `brew install jq`)

## Test Suites

### `tests/test_setup.sh` (52 tests)

Core unit and integration tests covering:

| Category | Tests | What It Covers |
|----------|-------|----------------|
| File validation | 3 | VERSION file, config file existence, valid JSON |
| Config structure | 2 | Browser count, required fields |
| Script behavior | 4 | --help, --version, invalid options, executable flag |
| Extension IDs | 1 | Consistency across script and config |
| Chrome Canary | 4 | JSON entry, paths, built-in config, data dir detection |
| Path validation | 8 | Absolute/relative paths, spaces, traversal, file-vs-dir |
| Browser validation | 8 | Profile markers (Default/, Local State, Preferences, Profile N), empty dirs, debug output |
| Integration | 3 | JSON-vs-builtin config match, dry-run safety, stale dir filtering |

### `tests/test_browser_detection.sh` (76 tests)

Comprehensive integration tests for browser detection logic:

| Category | Tests | What It Covers |
|----------|-------|----------------|
| Chrome Canary detection | 11 | Linux/macOS detection, custom paths (valid/invalid), JSON config |
| Non-existent browser filtering | 6 | Missing dirs, empty dirs, dirs without profile markers |
| Mixed installed/non-installed | 5 | Linux/macOS mixed scenarios, zero browsers |
| Platform-specific behavior | 4 | Base path per-OS, Arc macOS-only, platform skipping |
| Known edge cases | 2 | SRWare/Ungoogled macOS collision, Canary/Dev shared Linux dir |
| JSON config handling | 6 | JSON detection, missing/invalid JSON fallback, custom configs |
| Fixture-based config tests | 7 | Minimal, Canary-only, collision, invalid, empty, missing-fields fixtures |
| Browser validation edge cases | 6 | All 4 profile markers, stale dirs, no-marker dirs |
| Error message quality | 5 | Actionable messages for each error type, debug output |
| End-to-end detection | 4 | Full detect_browsers on Linux/macOS, output format |
| Chrome Beta/Dev | 2 | Beta and Dev channel detection |
| Config completeness | 3 | Built-in count, JSON/built-in match, non-empty names |
| Claude Code host path | 2 | Path return without existence check (documented issue) |

### `tests/test_setup.ps1` (12 tests)

PowerShell-specific tests for Windows support.

## Test Architecture

### Filesystem Mocking

Tests create temporary directories (`mktemp -d`) with a mocked `$HOME` to simulate browser installations without requiring real browsers. Each test:

1. Calls `setup_test_env()` to create an isolated temp directory
2. Uses `create_mock_browser()` to simulate browser data directories with specific profile markers
3. Sources functions from `setup.sh` via `sed` extraction (avoids running the full script)
4. Runs assertions against the function output
5. Calls `teardown_test_env()` to clean up

### Mock Browser Creation

```bash
create_mock_browser <base_path> <relative_path> [marker]
```

Markers:
- `default` — Creates `Default/` directory (standard Chromium profile)
- `localstate` — Creates `Local State` file
- `preferences` — Creates `Preferences` file
- `profile` — Creates `Profile 1/` directory (numbered profile)
- `empty` — Empty directory (simulates stale/uninstalled browser)
- `nomarker` — Has content but no recognized Chromium profile markers

### Platform Simulation

Tests simulate different platforms by setting `OS="linux"` or `OS="macos"` and creating appropriate directory structures under the mocked `$HOME`.

## Test Fixtures

Test fixture config files are in `tests/fixtures/`:

| Fixture | Purpose |
|---------|---------|
| `minimal_browsers.json` | Single custom browser entry |
| `canary_only.json` | Chrome Canary only (verifies isolated detection) |
| `collision_browsers.json` | Three browsers sharing the same macOS path |
| `invalid_browsers.json` | Malformed JSON (tests graceful fallback) |
| `empty_browsers.json` | Valid JSON with empty browsers array |
| `missing_fields.json` | Browsers with missing name or paths fields |

## Known Issues Covered by Tests

1. **Chrome Canary & Dev share Linux data dir**: Both use `google-chrome-unstable`. Tests verify both are detected (benign duplication).

2. **SRWare Iron & Ungoogled Chromium share macOS path**: Both use `Chromium` as the macOS data path, colliding with standard Chromium. Tests document this as a known issue.

3. **`get_claude_code_native_host_path()` no existence check**: Returns a path unconditionally (inconsistent with Desktop variant which validates existence). Test documents this behavior.

## CI Integration

Tests can run in any CI environment with Bash 4.0+ and jq. No real browser installations are needed.

```yaml
# Example GitHub Actions step
- name: Run tests
  run: |
    bash tests/test_setup.sh
    bash tests/test_browser_detection.sh
```

Tests that require `jq` will be skipped (not failed) if jq is unavailable.

## Coverage

The test suites cover the following functions from `setup.sh`:

| Function | Coverage |
|----------|----------|
| `validate_path()` | Full (all branches) |
| `validate_browser_installation()` | Full (all 4 markers + reject cases) |
| `detect_browsers()` | Full (JSON path, built-in path, empty result) |
| `get_app_support_base()` | Full (Linux + macOS) |
| `get_claude_native_host_path()` | Partial (returns empty in test env) |
| `get_claude_code_native_host_path()` | Full |
| `load_browser_configs_from_json()` | Full (valid, invalid, missing config) |
| `detect_os()` | Indirect (via OS variable override) |
| `create_manifests()` | Indirect (via dry-run test in test_setup.sh) |
| `BUILTIN_BROWSER_CONFIGS` | Full (format, count, names, platform paths) |

Estimated code coverage for browser detection logic: **>90%**.
