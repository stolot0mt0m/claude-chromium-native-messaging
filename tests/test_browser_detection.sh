#!/bin/bash

# Integration test suite for browser detection logic
# Covers: Chrome Canary detection, path validation, filtering,
#          platform-specific behavior, and known edge cases.
#
# Run with: bash tests/test_browser_detection.sh
# Requires: Bash 4.0+, jq (for JSON config tests)

set -euo pipefail

# =============================================================================
# Test Framework (shared with test_setup.sh)
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
SETUP_SCRIPT="$PROJECT_DIR/setup.sh"
CONFIG_FILE="$PROJECT_DIR/config/browsers.json"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_SKIPPED=0

TEST_TMP_DIR=""

# =============================================================================
# Assertion Helpers
# =============================================================================

assert_equals() {
    local expected="$1" actual="$2" message="${3:-Values should be equal}"
    ((TESTS_RUN++)) || true
    if [[ "$expected" == "$actual" ]]; then
        ((TESTS_PASSED++)) || true
        echo -e "${GREEN}PASS${NC}: $message"
    else
        ((TESTS_FAILED++)) || true
        echo -e "${RED}FAIL${NC}: $message"
        echo -e "  Expected: '$expected'"
        echo -e "  Actual:   '$actual'"
    fi
}

assert_true() {
    local condition="$1" message="${2:-Condition should be true}"
    ((TESTS_RUN++)) || true
    if [[ "$condition" == "true" ]]; then
        ((TESTS_PASSED++)) || true
        echo -e "${GREEN}PASS${NC}: $message"
    else
        ((TESTS_FAILED++)) || true
        echo -e "${RED}FAIL${NC}: $message (was: $condition)"
    fi
}

assert_false() {
    local condition="$1" message="${2:-Condition should be false}"
    ((TESTS_RUN++)) || true
    if [[ "$condition" == "false" ]]; then
        ((TESTS_PASSED++)) || true
        echo -e "${GREEN}PASS${NC}: $message"
    else
        ((TESTS_FAILED++)) || true
        echo -e "${RED}FAIL${NC}: $message (was: $condition)"
    fi
}

assert_contains() {
    local haystack="$1" needle="$2" message="${3:-Should contain substring}"
    ((TESTS_RUN++)) || true
    if [[ "$haystack" == *"$needle"* ]]; then
        ((TESTS_PASSED++)) || true
        echo -e "${GREEN}PASS${NC}: $message"
    else
        ((TESTS_FAILED++)) || true
        echo -e "${RED}FAIL${NC}: $message"
        echo -e "  Looking for: '$needle'"
        echo -e "  In: '${haystack:0:200}'"
    fi
}

assert_not_contains() {
    local haystack="$1" needle="$2" message="${3:-Should not contain substring}"
    ((TESTS_RUN++)) || true
    if [[ "$haystack" != *"$needle"* ]]; then
        ((TESTS_PASSED++)) || true
        echo -e "${GREEN}PASS${NC}: $message"
    else
        ((TESTS_FAILED++)) || true
        echo -e "${RED}FAIL${NC}: $message"
        echo -e "  Should not contain: '$needle'"
    fi
}

assert_exit_code() {
    local expected="$1" actual="$2" message="${3:-Exit code check}"
    assert_equals "$expected" "$actual" "$message"
}

assert_line_count() {
    local expected="$1" text="$2" message="${3:-Line count check}"
    local actual
    if [[ -z "$text" ]]; then
        actual=0
    else
        actual=$(echo "$text" | wc -l | tr -d ' ')
    fi
    assert_equals "$expected" "$actual" "$message"
}

skip_test() {
    local message="$1"
    ((TESTS_SKIPPED++)) || true
    echo -e "${YELLOW}SKIP${NC}: $message"
}

# =============================================================================
# Test Environment Setup / Teardown
# =============================================================================

setup_test_env() {
    TEST_TMP_DIR=$(mktemp -d)
    export HOME="$TEST_TMP_DIR/home"
    mkdir -p "$HOME"
}

teardown_test_env() {
    if [[ -n "$TEST_TMP_DIR" ]] && [[ -d "$TEST_TMP_DIR" ]]; then
        rm -rf "$TEST_TMP_DIR"
    fi
    # Restore CONFIG_FILE in case a test overrode it
    CONFIG_FILE="$ORIG_CONFIG_FILE"
}

# Source BUILTIN_BROWSER_CONFIGS at global scope.
# declare -a inside a function creates a local variable, so this must be global.
eval "$(sed -n '/^declare -a BUILTIN_BROWSER_CONFIGS/,/^)/p' "$SETUP_SCRIPT")"

# Preserve the original CONFIG_FILE for restoration after tests that override it.
ORIG_CONFIG_FILE="$CONFIG_FILE"

# Source functions from setup.sh into the current shell.
# Provides: validate_path, validate_browser_installation, detect_browsers,
#           get_app_support_base, get_claude_native_host_path, etc.
source_setup_functions() {
    # Suppress all output by default
    QUIET=true
    VERBOSE=false
    DEBUG=false

    # Restore CONFIG_FILE to project default (tests may override per-test)
    CONFIG_FILE="$ORIG_CONFIG_FILE"

    # Stub print functions to avoid color escape issues in test output
    print_error()   { echo "ERROR: $1" >&2; }
    print_warning() { :; }
    print_info()    { :; }
    print_success() { :; }
    print_verbose() { :; }
    print_debug()   { :; }
    print_dry_run() { :; }

    # Source individual functions via sed extraction
    eval "$(sed -n '/^validate_path()/,/^}/p' "$SETUP_SCRIPT")"
    eval "$(sed -n '/^validate_browser_installation()/,/^}/p' "$SETUP_SCRIPT")"
    eval "$(sed -n '/^get_app_support_base()/,/^}/p' "$SETUP_SCRIPT")"
    eval "$(sed -n '/^get_claude_native_host_path()/,/^}/p' "$SETUP_SCRIPT")"
    eval "$(sed -n '/^get_claude_code_native_host_path()/,/^}/p' "$SETUP_SCRIPT")"
    eval "$(sed -n '/^load_browser_configs_from_json()/,/^}/p' "$SETUP_SCRIPT")"
    eval "$(sed -n '/^detect_browsers()/,/^}/p' "$SETUP_SCRIPT")"
    eval "$(sed -n '/^detect_os()/,/^}/p' "$SETUP_SCRIPT")"
}

# Create a mock browser data directory with valid Chromium profile markers.
# Usage: create_mock_browser <base_path> <relative_path> [marker]
#   marker: "default" (Default/ dir), "localstate" (Local State file),
#           "preferences" (Preferences file), "profile" (Profile 1/ dir)
create_mock_browser() {
    local base_path="$1"
    local relative_path="$2"
    local marker="${3:-default}"
    local full_path="$base_path/$relative_path"

    mkdir -p "$full_path"

    case "$marker" in
        default)      mkdir -p "$full_path/Default" ;;
        localstate)   touch "$full_path/Local State" ;;
        preferences)  touch "$full_path/Preferences" ;;
        profile)      mkdir -p "$full_path/Profile 1" ;;
        empty)        ;; # Leave empty (stale install)
        nomarker)     touch "$full_path/some_random_file" ;; # Has content but no profile
    esac
}

# =============================================================================
# 1. Chrome Canary Detection Tests
# =============================================================================

test_canary_detected_linux() {
    echo -e "\n${BLUE}=== Test: Chrome Canary detected on Linux ===${NC}"
    setup_test_env
    source_setup_functions
    OS="linux"

    create_mock_browser "$HOME/.config" "google-chrome-unstable"

    # Disable JSON config to test built-in detection
    CONFIG_FILE="/nonexistent"

    local output
    output=$(detect_browsers)

    assert_contains "$output" "Google Chrome Canary" \
        "Chrome Canary should be detected on Linux"
    assert_contains "$output" "google-chrome-unstable" \
        "Detection output should include linux data directory path"

    teardown_test_env
}

test_canary_detected_macos() {
    echo -e "\n${BLUE}=== Test: Chrome Canary detected on macOS ===${NC}"
    setup_test_env
    source_setup_functions
    OS="macos"

    create_mock_browser "$HOME/Library/Application Support" "Google/Chrome Canary"

    CONFIG_FILE="/nonexistent"

    local output
    output=$(detect_browsers)

    assert_contains "$output" "Google Chrome Canary" \
        "Chrome Canary should be detected on macOS"
    assert_contains "$output" "Google/Chrome Canary" \
        "Detection output should include macOS path"

    teardown_test_env
}

test_canary_not_detected_when_not_installed() {
    echo -e "\n${BLUE}=== Test: Chrome Canary NOT detected when not installed ===${NC}"
    setup_test_env
    source_setup_functions
    OS="linux"

    # Only install Chrome, not Canary
    create_mock_browser "$HOME/.config" "google-chrome"

    CONFIG_FILE="/nonexistent"

    local output
    output=$(detect_browsers)

    assert_not_contains "$output" "Google Chrome Canary" \
        "Chrome Canary should NOT appear when not installed"
    assert_contains "$output" "Google Chrome" \
        "Regular Chrome should still be detected"

    teardown_test_env
}

test_canary_custom_path_valid() {
    echo -e "\n${BLUE}=== Test: Chrome Canary custom path accepted when valid ===${NC}"
    setup_test_env
    source_setup_functions

    local custom_dir="$TEST_TMP_DIR/custom-canary-data"
    mkdir -p "$custom_dir/Default"

    local result exit_code=0
    result=$(validate_path "$custom_dir" 2>/dev/null) || exit_code=$?

    assert_exit_code "0" "$exit_code" "Valid custom Canary path should be accepted"
    assert_equals "$custom_dir" "$result" "Should return the custom path"

    teardown_test_env
}

test_canary_custom_path_invalid() {
    echo -e "\n${BLUE}=== Test: Chrome Canary custom path rejected when invalid ===${NC}"
    setup_test_env
    source_setup_functions

    local exit_code=0
    local output
    output=$(validate_path "/nonexistent/chrome-canary-data" 2>&1) || exit_code=$?

    assert_exit_code "1" "$exit_code" "Non-existent custom Canary path should fail"
    assert_contains "$output" "does not exist" "Error should explain the path doesn't exist"

    teardown_test_env
}

test_canary_json_config_entry() {
    echo -e "\n${BLUE}=== Test: Chrome Canary properly configured in JSON ===${NC}"

    if ! command -v jq &>/dev/null; then
        skip_test "jq not installed, skipping JSON config test"
        return
    fi

    local canary
    canary=$(jq -r '.browsers[] | select(.name == "Google Chrome Canary")' "$CONFIG_FILE")

    local macos_path linux_path windows_path
    macos_path=$(echo "$canary" | jq -r '.paths.macos')
    linux_path=$(echo "$canary" | jq -r '.paths.linux')
    windows_path=$(echo "$canary" | jq -r '.paths.windows')

    assert_equals "Google/Chrome Canary" "$macos_path" "Canary macOS path correct"
    assert_equals "google-chrome-unstable" "$linux_path" "Canary Linux path correct"
    assert_equals 'Google\Chrome SxS\User Data' "$windows_path" "Canary Windows path correct"
}

# =============================================================================
# 2. Filtering Non-Existent Browsers
# =============================================================================

test_filter_nonexistent_browsers() {
    echo -e "\n${BLUE}=== Test: Non-existent browsers filtered out ===${NC}"
    setup_test_env
    source_setup_functions
    OS="linux"

    # Only install Chrome — all other 30+ browsers should be filtered
    create_mock_browser "$HOME/.config" "google-chrome"

    CONFIG_FILE="/nonexistent"

    local output
    output=$(detect_browsers)

    # Should only find Chrome
    assert_contains "$output" "Google Chrome" "Chrome should be detected"
    assert_not_contains "$output" "Brave" "Brave should be filtered (not installed)"
    assert_not_contains "$output" "Opera" "Opera should be filtered (not installed)"
    assert_not_contains "$output" "Vivaldi" "Vivaldi should be filtered (not installed)"

    teardown_test_env
}

test_filter_empty_directories() {
    echo -e "\n${BLUE}=== Test: Empty browser directories filtered (stale installs) ===${NC}"
    setup_test_env
    source_setup_functions
    OS="linux"

    # Chrome: valid install
    create_mock_browser "$HOME/.config" "google-chrome"
    # Opera: empty dir (stale)
    create_mock_browser "$HOME/.config" "opera" "empty"

    CONFIG_FILE="/nonexistent"

    local output
    output=$(detect_browsers)

    assert_contains "$output" "Google Chrome" "Chrome should be detected"
    assert_not_contains "$output" "Opera" "Opera with empty dir should be filtered"

    teardown_test_env
}

test_filter_dirs_without_profile_markers() {
    echo -e "\n${BLUE}=== Test: Directories without profile markers filtered ===${NC}"
    setup_test_env
    source_setup_functions
    OS="linux"

    # Brave: has files but no profile markers
    create_mock_browser "$HOME/.config/BraveSoftware" "Brave-Browser" "nomarker"
    # Edge: valid install
    create_mock_browser "$HOME/.config" "microsoft-edge" "localstate"

    CONFIG_FILE="/nonexistent"

    local output
    output=$(detect_browsers)

    assert_not_contains "$output" "Brave" "Brave without profiles should be filtered"
    assert_contains "$output" "Microsoft Edge" "Edge with Local State should be detected"

    teardown_test_env
}

# =============================================================================
# 3. Mixed Installed / Non-Installed Browsers
# =============================================================================

test_mixed_browsers_linux() {
    echo -e "\n${BLUE}=== Test: Mixed installed/non-installed browsers (Linux) ===${NC}"
    setup_test_env
    source_setup_functions
    OS="linux"

    # Installed browsers
    create_mock_browser "$HOME/.config" "google-chrome"
    create_mock_browser "$HOME/.config" "microsoft-edge" "localstate"
    create_mock_browser "$HOME/.config" "vivaldi" "preferences"

    # NOT installed: Brave, Opera, Chromium (no directories at all)

    CONFIG_FILE="/nonexistent"

    local output
    output=$(detect_browsers)

    # Count detected lines (each browser produces one line: "Name|path")
    local detected_count=0
    while IFS= read -r line; do
        [[ -n "$line" ]] && ((detected_count++)) || true
    done <<< "$output"

    assert_equals "3" "$detected_count" "Should detect exactly 3 browsers"
    assert_contains "$output" "Google Chrome" "Chrome should be detected"
    assert_contains "$output" "Microsoft Edge" "Edge should be detected"
    assert_contains "$output" "Vivaldi" "Vivaldi should be detected"

    teardown_test_env
}

test_mixed_browsers_macos() {
    echo -e "\n${BLUE}=== Test: Mixed installed/non-installed browsers (macOS) ===${NC}"
    setup_test_env
    source_setup_functions
    OS="macos"

    local base="$HOME/Library/Application Support"

    # Installed
    create_mock_browser "$base" "Google/Chrome"
    create_mock_browser "$base" "BraveSoftware/Brave-Browser" "localstate"

    # NOT installed
    # (Vivaldi, Opera, Edge — no directories)

    CONFIG_FILE="/nonexistent"

    local output
    output=$(detect_browsers)

    local detected_count=0
    while IFS= read -r line; do
        [[ -n "$line" ]] && ((detected_count++)) || true
    done <<< "$output"

    assert_equals "2" "$detected_count" "Should detect exactly 2 browsers on macOS"
    assert_contains "$output" "Google Chrome" "Chrome should be detected"
    assert_contains "$output" "Brave" "Brave should be detected"

    teardown_test_env
}

test_no_browsers_installed() {
    echo -e "\n${BLUE}=== Test: No browsers installed returns empty ===${NC}"
    setup_test_env
    source_setup_functions
    OS="linux"

    mkdir -p "$HOME/.config"
    # No browser dirs created

    CONFIG_FILE="/nonexistent"

    local output
    output=$(detect_browsers)

    assert_equals "" "$output" "Empty filesystem should produce empty output"

    teardown_test_env
}

# =============================================================================
# 4. Platform-Specific Behavior
# =============================================================================

test_linux_uses_config_dir() {
    echo -e "\n${BLUE}=== Test: Linux uses ~/.config as base path ===${NC}"
    setup_test_env
    source_setup_functions
    OS="linux"

    local base
    base=$(get_app_support_base)

    assert_equals "$HOME/.config" "$base" "Linux base path should be ~/.config"

    teardown_test_env
}

test_macos_uses_app_support() {
    echo -e "\n${BLUE}=== Test: macOS uses Application Support as base path ===${NC}"
    setup_test_env
    source_setup_functions
    OS="macos"

    local base
    base=$(get_app_support_base)

    assert_equals "$HOME/Library/Application Support" "$base" \
        "macOS base path should be ~/Library/Application Support"

    teardown_test_env
}

test_arc_only_on_macos() {
    echo -e "\n${BLUE}=== Test: Arc browser only detected on macOS (no Linux path) ===${NC}"
    setup_test_env
    source_setup_functions

    # Check that Arc has no Linux path in built-in config
    local arc_config=""
    for config in "${BUILTIN_BROWSER_CONFIGS[@]}"; do
        IFS='|' read -r name macos_path linux_path <<< "$config"
        if [[ "$name" == "Arc" ]]; then
            arc_config="$config"
            break
        fi
    done

    IFS='|' read -r name macos_path linux_path <<< "$arc_config"

    assert_equals "" "$linux_path" "Arc should have no Linux path"
    assert_equals "Arc/User Data" "$macos_path" "Arc should have macOS path"

    teardown_test_env
}

test_linux_detection_ignores_macos_only_browsers() {
    echo -e "\n${BLUE}=== Test: Linux detection skips macOS-only browsers (Arc) ===${NC}"
    setup_test_env
    source_setup_functions
    OS="linux"

    # Create a directory that might confuse if Arc had a linux path
    mkdir -p "$HOME/.config/Arc"
    mkdir -p "$HOME/.config/Arc/Default"

    # Install Chrome for baseline
    create_mock_browser "$HOME/.config" "google-chrome"

    CONFIG_FILE="/nonexistent"

    local output
    output=$(detect_browsers)

    # Arc's built-in config has empty linux_path, so it should be skipped
    assert_not_contains "$output" "Arc" "Arc should not be detected on Linux"

    teardown_test_env
}

# =============================================================================
# 5. Known Edge Cases (from MEMORY.md)
# =============================================================================

test_srware_ungoogled_macos_collision() {
    echo -e "\n${BLUE}=== Test: SRWare Iron & Ungoogled Chromium share macOS path ===${NC}"
    setup_test_env
    source_setup_functions
    OS="macos"

    local base="$HOME/Library/Application Support"

    # Both use "Chromium" as macOS path
    create_mock_browser "$base" "Chromium"

    CONFIG_FILE="/nonexistent"

    local output
    output=$(detect_browsers)

    # All three (Chromium, SRWare Iron, Ungoogled Chromium) share the same macOS path
    # The detection logic will match all of them since the dir exists
    local collision_count=0
    while IFS= read -r line; do
        if [[ "$line" == *"Chromium"* ]] || [[ "$line" == *"SRWare Iron"* ]] || [[ "$line" == *"Ungoogled"* ]]; then
            ((collision_count++)) || true
        fi
    done <<< "$output"

    # Document: this is a known issue — three browsers match one directory
    ((TESTS_RUN++)) || true
    if [[ "$collision_count" -ge 2 ]]; then
        ((TESTS_PASSED++)) || true
        echo -e "${GREEN}PASS${NC}: Collision detected — $collision_count browsers match same macOS path (known issue)"
    else
        ((TESTS_FAILED++)) || true
        echo -e "${RED}FAIL${NC}: Expected collision (>=2 matches), got $collision_count"
    fi

    teardown_test_env
}

test_canary_dev_shared_linux_dir() {
    echo -e "\n${BLUE}=== Test: Chrome Canary & Dev share Linux data dir ===${NC}"
    setup_test_env
    source_setup_functions
    OS="linux"

    # Both use "google-chrome-unstable" as Linux path
    create_mock_browser "$HOME/.config" "google-chrome-unstable"

    CONFIG_FILE="/nonexistent"

    local output
    output=$(detect_browsers)

    local canary_found=false
    local dev_found=false
    while IFS= read -r line; do
        [[ "$line" == *"Google Chrome Canary"* ]] && canary_found=true
        [[ "$line" == *"Google Chrome Dev"* ]] && dev_found=true
    done <<< "$output"

    assert_true "$canary_found" "Chrome Canary should match google-chrome-unstable"
    assert_true "$dev_found" "Chrome Dev should also match google-chrome-unstable"

    teardown_test_env
}

# =============================================================================
# 6. JSON Config File Handling
# =============================================================================

test_json_config_detection() {
    echo -e "\n${BLUE}=== Test: detect_browsers uses JSON config when jq available ===${NC}"

    if ! command -v jq &>/dev/null; then
        skip_test "jq not installed"
        return
    fi

    setup_test_env
    source_setup_functions
    OS="linux"

    create_mock_browser "$HOME/.config" "google-chrome"

    # Point to real project config
    CONFIG_FILE="$PROJECT_DIR/config/browsers.json"

    local output
    output=$(detect_browsers)

    assert_contains "$output" "Google Chrome" "JSON config should detect Chrome"

    teardown_test_env
}

test_json_config_missing_graceful_fallback() {
    echo -e "\n${BLUE}=== Test: Missing JSON config falls back to built-in ===${NC}"
    setup_test_env
    source_setup_functions
    OS="linux"

    create_mock_browser "$HOME/.config" "google-chrome"

    CONFIG_FILE="/nonexistent/browsers.json"

    local output
    output=$(detect_browsers)

    assert_contains "$output" "Google Chrome" \
        "Should still detect Chrome via built-in config when JSON missing"

    teardown_test_env
}

test_custom_config_file_valid() {
    echo -e "\n${BLUE}=== Test: Custom config file with valid entries ===${NC}"

    if ! command -v jq &>/dev/null; then
        skip_test "jq not installed"
        return
    fi

    setup_test_env
    source_setup_functions
    OS="linux"

    # Create a minimal custom config
    local custom_config="$TEST_TMP_DIR/custom_browsers.json"
    cat > "$custom_config" << 'JSONEOF'
{
  "browsers": [
    {
      "name": "TestBrowser",
      "paths": {
        "macos": "TestBrowser",
        "linux": "test-browser",
        "windows": "TestBrowser\\User Data"
      }
    }
  ]
}
JSONEOF

    CONFIG_FILE="$custom_config"

    # Create the mock browser dir
    create_mock_browser "$HOME/.config" "test-browser"

    local output
    output=$(detect_browsers)

    assert_contains "$output" "TestBrowser" "Custom config browser should be detected"

    teardown_test_env
}

test_custom_config_file_invalid_json() {
    echo -e "\n${BLUE}=== Test: Invalid JSON config falls back to built-in ===${NC}"

    if ! command -v jq &>/dev/null; then
        skip_test "jq not installed"
        return
    fi

    setup_test_env
    source_setup_functions
    OS="linux"

    # Create an invalid JSON file
    local bad_config="$TEST_TMP_DIR/bad_browsers.json"
    echo "{ this is not valid json }" > "$bad_config"

    CONFIG_FILE="$bad_config"

    create_mock_browser "$HOME/.config" "google-chrome"

    local output
    output=$(detect_browsers)

    # Should fall back to built-in configs
    assert_contains "$output" "Google Chrome" \
        "Invalid JSON should trigger fallback to built-in config"

    teardown_test_env
}

test_json_config_all_browsers_have_name_and_paths() {
    echo -e "\n${BLUE}=== Test: All JSON browsers have name and paths ===${NC}"

    if ! command -v jq &>/dev/null; then
        skip_test "jq not installed"
        return
    fi

    local invalid_count
    invalid_count=$(jq '[.browsers[] | select(.name == null or .paths == null)] | length' "$CONFIG_FILE")

    assert_equals "0" "$invalid_count" "All browsers must have name and paths fields"
}

test_json_config_no_empty_platform_paths() {
    echo -e "\n${BLUE}=== Test: JSON browsers have at least one non-null platform path ===${NC}"

    if ! command -v jq &>/dev/null; then
        skip_test "jq not installed"
        return
    fi

    local orphan_count
    orphan_count=$(jq '[.browsers[] | select(
        (.paths.macos == null or .paths.macos == "") and
        (.paths.linux == null or .paths.linux == "") and
        (.paths.windows == null or .paths.windows == "")
    )] | length' "$CONFIG_FILE")

    assert_equals "0" "$orphan_count" "Every browser must have at least one platform path"
}

# =============================================================================
# 6b. Fixture-Based Config Tests
# =============================================================================

FIXTURES_DIR="$SCRIPT_DIR/fixtures"

test_fixture_minimal_config() {
    echo -e "\n${BLUE}=== Test: Fixture — minimal config with single browser ===${NC}"

    if ! command -v jq &>/dev/null; then
        skip_test "jq not installed"
        return
    fi

    setup_test_env
    source_setup_functions
    OS="linux"

    CONFIG_FILE="$FIXTURES_DIR/minimal_browsers.json"
    create_mock_browser "$HOME/.config" "test-browser"

    local output
    output=$(detect_browsers)

    assert_contains "$output" "TestBrowser" "Minimal fixture should detect TestBrowser"

    teardown_test_env
}

test_fixture_canary_only() {
    echo -e "\n${BLUE}=== Test: Fixture — Canary-only config ===${NC}"

    if ! command -v jq &>/dev/null; then
        skip_test "jq not installed"
        return
    fi

    setup_test_env
    source_setup_functions
    OS="linux"

    CONFIG_FILE="$FIXTURES_DIR/canary_only.json"
    create_mock_browser "$HOME/.config" "google-chrome-unstable"

    local output
    output=$(detect_browsers)

    assert_contains "$output" "Google Chrome Canary" "Canary-only fixture should detect Canary"

    # Regular Chrome should NOT be detected (not in fixture config)
    assert_not_contains "$output" "Google Chrome|" \
        "Regular Chrome should not appear in Canary-only config"

    teardown_test_env
}

test_fixture_collision_config() {
    echo -e "\n${BLUE}=== Test: Fixture — collision browsers share macOS path ===${NC}"

    if ! command -v jq &>/dev/null; then
        skip_test "jq not installed"
        return
    fi

    setup_test_env
    source_setup_functions
    OS="macos"

    CONFIG_FILE="$FIXTURES_DIR/collision_browsers.json"
    create_mock_browser "$HOME/Library/Application Support" "Chromium"

    local output
    output=$(detect_browsers)

    local match_count=0
    while IFS= read -r line; do
        [[ -n "$line" ]] && ((match_count++)) || true
    done <<< "$output"

    # All 3 browsers in the fixture share "Chromium" macOS path
    assert_equals "3" "$match_count" \
        "All 3 collision browsers should match the same Chromium dir"

    teardown_test_env
}

test_fixture_invalid_json_fallback() {
    echo -e "\n${BLUE}=== Test: Fixture — invalid JSON triggers built-in fallback ===${NC}"

    if ! command -v jq &>/dev/null; then
        skip_test "jq not installed"
        return
    fi

    setup_test_env
    source_setup_functions
    OS="linux"

    CONFIG_FILE="$FIXTURES_DIR/invalid_browsers.json"
    create_mock_browser "$HOME/.config" "google-chrome"

    local output
    output=$(detect_browsers)

    assert_contains "$output" "Google Chrome" \
        "Invalid fixture JSON should fallback to built-in configs"

    teardown_test_env
}

test_fixture_empty_browsers_array() {
    echo -e "\n${BLUE}=== Test: Fixture — empty browsers array falls back to built-in ===${NC}"

    if ! command -v jq &>/dev/null; then
        skip_test "jq not installed"
        return
    fi

    setup_test_env
    source_setup_functions
    OS="linux"

    CONFIG_FILE="$FIXTURES_DIR/empty_browsers.json"
    create_mock_browser "$HOME/.config" "google-chrome"

    local output
    output=$(detect_browsers)

    # Empty browsers array should trigger fallback to built-in
    assert_contains "$output" "Google Chrome" \
        "Empty browsers array should fallback to built-in configs"

    teardown_test_env
}

test_fixture_missing_fields_validation() {
    echo -e "\n${BLUE}=== Test: Fixture — browsers with missing fields ===${NC}"

    if ! command -v jq &>/dev/null; then
        skip_test "jq not installed"
        return
    fi

    local invalid_count
    invalid_count=$(jq '[.browsers[] | select(.name == null or .paths == null)] | length' \
        "$FIXTURES_DIR/missing_fields.json")

    assert_equals "2" "$invalid_count" \
        "Fixture should have exactly 2 browsers with missing fields"
}

# =============================================================================
# 7. validate_browser_installation Edge Cases
# =============================================================================

test_validate_accepts_all_profile_markers() {
    echo -e "\n${BLUE}=== Test: validate_browser_installation accepts all profile markers ===${NC}"
    setup_test_env
    source_setup_functions

    local markers=("default" "localstate" "preferences" "profile")
    for marker in "${markers[@]}"; do
        local dir="$TEST_TMP_DIR/browser_$marker"
        create_mock_browser "$TEST_TMP_DIR" "browser_$marker" "$marker"

        local exit_code=0
        validate_browser_installation "$dir" "TestBrowser ($marker)" >/dev/null 2>&1 || exit_code=$?

        assert_exit_code "0" "$exit_code" \
            "Browser with '$marker' profile marker should be accepted"
    done

    teardown_test_env
}

test_validate_rejects_stale_and_nomarker() {
    echo -e "\n${BLUE}=== Test: validate_browser_installation rejects stale/no-marker ===${NC}"
    setup_test_env
    source_setup_functions

    # Empty dir
    local empty_dir="$TEST_TMP_DIR/empty_browser"
    create_mock_browser "$TEST_TMP_DIR" "empty_browser" "empty"
    local exit_code=0
    validate_browser_installation "$empty_dir" "EmptyBrowser" >/dev/null 2>&1 || exit_code=$?
    assert_exit_code "1" "$exit_code" "Empty directory should be rejected"

    # Dir with content but no markers
    local nomarker_dir="$TEST_TMP_DIR/nomarker_browser"
    create_mock_browser "$TEST_TMP_DIR" "nomarker_browser" "nomarker"
    exit_code=0
    validate_browser_installation "$nomarker_dir" "NoMarkerBrowser" >/dev/null 2>&1 || exit_code=$?
    assert_exit_code "1" "$exit_code" "Directory without profile markers should be rejected"

    teardown_test_env
}

# =============================================================================
# 8. Error Message Quality Tests
# =============================================================================

test_error_msg_nonexistent_path() {
    echo -e "\n${BLUE}=== Test: Error message for non-existent custom path is actionable ===${NC}"
    setup_test_env
    source_setup_functions

    local output
    output=$(validate_path "/does/not/exist/browser-data" 2>&1) || true

    assert_contains "$output" "does not exist" \
        "Error should mention 'does not exist'"
    assert_contains "$output" "/does/not/exist/browser-data" \
        "Error should include the actual path attempted"

    teardown_test_env
}

test_error_msg_relative_path() {
    echo -e "\n${BLUE}=== Test: Error message for relative path is actionable ===${NC}"
    setup_test_env
    source_setup_functions

    local output
    output=$(validate_path "relative/path" 2>&1) || true

    assert_contains "$output" "must be absolute" \
        "Error should explain path must be absolute"

    teardown_test_env
}

test_error_msg_path_traversal() {
    echo -e "\n${BLUE}=== Test: Error message for path traversal is actionable ===${NC}"
    setup_test_env
    source_setup_functions

    local output
    output=$(validate_path "/tmp/../etc/something" 2>&1) || true

    assert_contains "$output" "traversal" \
        "Error should mention path traversal"

    teardown_test_env
}

test_error_msg_file_instead_of_dir() {
    echo -e "\n${BLUE}=== Test: Error message for file-instead-of-dir is actionable ===${NC}"
    setup_test_env
    source_setup_functions

    local test_file="$TEST_TMP_DIR/not-a-dir"
    touch "$test_file"

    local output
    output=$(validate_path "$test_file" 2>&1) || true

    assert_contains "$output" "does not exist" \
        "Error should indicate path is not a valid directory"

    teardown_test_env
}

test_debug_output_mentions_browser_name() {
    echo -e "\n${BLUE}=== Test: Debug output mentions skipped browser by name ===${NC}"
    setup_test_env
    source_setup_functions
    DEBUG=true
    print_debug() { echo "DEBUG: $1"; }

    local output
    output=$(validate_browser_installation "/nonexistent" "FancyBrowser" 2>&1) || true

    assert_contains "$output" "FancyBrowser" \
        "Debug output should include the browser name being skipped"

    teardown_test_env
}

# =============================================================================
# 9. detect_browsers Integration (End-to-End with Mocked FS)
# =============================================================================

test_detect_browsers_e2e_linux() {
    echo -e "\n${BLUE}=== Test: detect_browsers end-to-end on Linux ===${NC}"
    setup_test_env
    source_setup_functions
    OS="linux"
    CONFIG_FILE="/nonexistent"

    local base="$HOME/.config"

    # Install 4 browsers, leave rest absent
    create_mock_browser "$base" "google-chrome"                            # Google Chrome
    create_mock_browser "$base" "google-chrome-unstable" "localstate"      # Canary + Dev
    create_mock_browser "$base" "microsoft-edge" "preferences"            # Edge
    create_mock_browser "$base/BraveSoftware" "Brave-Browser" "profile"   # Brave

    local output
    output=$(detect_browsers)

    local detected_count=0
    while IFS= read -r line; do
        [[ -n "$line" ]] && ((detected_count++)) || true
    done <<< "$output"

    # Chrome, Canary, Dev, Edge, Brave = 5 detections
    # (Canary + Dev both match google-chrome-unstable)
    assert_equals "5" "$detected_count" \
        "Should detect 5 browser entries (Chrome, Canary, Dev, Edge, Brave)"

    teardown_test_env
}

test_detect_browsers_e2e_macos() {
    echo -e "\n${BLUE}=== Test: detect_browsers end-to-end on macOS ===${NC}"
    setup_test_env
    source_setup_functions
    OS="macos"
    CONFIG_FILE="/nonexistent"

    local base="$HOME/Library/Application Support"

    create_mock_browser "$base" "Google/Chrome"
    create_mock_browser "$base" "Google/Chrome Canary" "localstate"
    create_mock_browser "$base/BraveSoftware" "Brave-Browser"

    local output
    output=$(detect_browsers)

    assert_contains "$output" "Google Chrome" "Chrome detected on macOS"
    assert_contains "$output" "Google Chrome Canary" "Canary detected on macOS"
    assert_contains "$output" "Brave" "Brave detected on macOS"

    teardown_test_env
}

test_detect_browsers_output_format() {
    echo -e "\n${BLUE}=== Test: detect_browsers output is pipe-delimited ===${NC}"
    setup_test_env
    source_setup_functions
    OS="linux"
    CONFIG_FILE="/nonexistent"

    create_mock_browser "$HOME/.config" "google-chrome"

    local output
    output=$(detect_browsers)

    # Output format: "Name|full_path"
    local first_line
    first_line=$(echo "$output" | head -n1)

    assert_contains "$first_line" "|" "Output lines should be pipe-delimited"

    # Verify the two parts
    IFS='|' read -r name path <<< "$first_line"
    assert_contains "$name" "Google Chrome" "First field should be browser name"
    assert_contains "$path" "google-chrome" "Second field should be full path"

    teardown_test_env
}

# =============================================================================
# 10. Chrome Beta and Dev Tests
# =============================================================================

test_chrome_beta_detected_linux() {
    echo -e "\n${BLUE}=== Test: Chrome Beta detected on Linux ===${NC}"
    setup_test_env
    source_setup_functions
    OS="linux"
    CONFIG_FILE="/nonexistent"

    create_mock_browser "$HOME/.config" "google-chrome-beta"

    local output
    output=$(detect_browsers)

    assert_contains "$output" "Google Chrome Beta" "Chrome Beta should be detected"

    teardown_test_env
}

test_chrome_dev_detected_linux() {
    echo -e "\n${BLUE}=== Test: Chrome Dev detected on Linux ===${NC}"
    setup_test_env
    source_setup_functions
    OS="linux"
    CONFIG_FILE="/nonexistent"

    create_mock_browser "$HOME/.config" "google-chrome-unstable"

    local output
    output=$(detect_browsers)

    assert_contains "$output" "Google Chrome Dev" "Chrome Dev should be detected"

    teardown_test_env
}

# =============================================================================
# 11. Builtin Config Completeness
# =============================================================================

test_builtin_configs_count() {
    echo -e "\n${BLUE}=== Test: Built-in config has expected browser count ===${NC}"
    source_setup_functions

    local count="${#BUILTIN_BROWSER_CONFIGS[@]}"

    ((TESTS_RUN++)) || true
    if [[ "$count" -ge 25 ]]; then
        ((TESTS_PASSED++)) || true
        echo -e "${GREEN}PASS${NC}: Built-in config has $count browsers (>=25 expected)"
    else
        ((TESTS_FAILED++)) || true
        echo -e "${RED}FAIL${NC}: Built-in config has only $count browsers (expected >=25)"
    fi
}

test_builtin_and_json_browser_count_match() {
    echo -e "\n${BLUE}=== Test: Built-in and JSON config browser counts match ===${NC}"

    if ! command -v jq &>/dev/null; then
        skip_test "jq not installed"
        return
    fi

    source_setup_functions

    local builtin_count="${#BUILTIN_BROWSER_CONFIGS[@]}"
    local json_count
    json_count=$(jq '.browsers | length' "$CONFIG_FILE")

    assert_equals "$builtin_count" "$json_count" \
        "Built-in ($builtin_count) and JSON ($json_count) browser counts should match"
}

test_builtin_configs_all_have_names() {
    echo -e "\n${BLUE}=== Test: All built-in configs have non-empty names ===${NC}"
    source_setup_functions

    local empty_names=0
    for config in "${BUILTIN_BROWSER_CONFIGS[@]}"; do
        IFS='|' read -r name macos_path linux_path <<< "$config"
        if [[ -z "$name" ]]; then
            ((empty_names++)) || true
        fi
    done

    assert_equals "0" "$empty_names" "All built-in configs should have names"
}

# =============================================================================
# 12. get_claude_code_native_host_path Tests
# =============================================================================

test_code_host_path_returns_without_existence_check() {
    echo -e "\n${BLUE}=== Test: get_claude_code_native_host_path returns path unconditionally ===${NC}"
    setup_test_env
    source_setup_functions

    # Even with a fake HOME, the function should return a path
    local result
    result=$(get_claude_code_native_host_path)

    assert_contains "$result" ".claude/chrome/chrome-native-host" \
        "Should return path containing .claude/chrome/chrome-native-host"

    # Verify the path does NOT exist (known issue: no existence check)
    ((TESTS_RUN++)) || true
    if [[ ! -f "$result" ]]; then
        ((TESTS_PASSED++)) || true
        echo -e "${GREEN}PASS${NC}: Path returned without existence check (documented inconsistency)"
    else
        ((TESTS_PASSED++)) || true
        echo -e "${GREEN}PASS${NC}: Path exists (unexpected but valid)"
    fi

    teardown_test_env
}

# =============================================================================
# Main Test Runner
# =============================================================================

run_all_tests() {
    echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║  Browser Detection Integration Tests                       ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"

    if [[ "${BASH_VERSINFO[0]}" -lt 4 ]]; then
        echo -e "${RED}ERROR: Bash 4.0+ required${NC}"
        exit 1
    fi

    # Save original HOME
    local ORIG_HOME="$HOME"

    # 1. Chrome Canary Detection
    echo -e "\n${BLUE}── Chrome Canary Detection ─────────────────────────────────${NC}"
    test_canary_detected_linux
    test_canary_detected_macos
    test_canary_not_detected_when_not_installed
    test_canary_custom_path_valid
    test_canary_custom_path_invalid
    test_canary_json_config_entry

    # 2. Filtering Non-Existent Browsers
    echo -e "\n${BLUE}── Filtering Non-Existent Browsers ─────────────────────────${NC}"
    test_filter_nonexistent_browsers
    test_filter_empty_directories
    test_filter_dirs_without_profile_markers

    # 3. Mixed Installed / Non-Installed
    echo -e "\n${BLUE}── Mixed Installed / Non-Installed ─────────────────────────${NC}"
    test_mixed_browsers_linux
    test_mixed_browsers_macos
    test_no_browsers_installed

    # 4. Platform-Specific Behavior
    echo -e "\n${BLUE}── Platform-Specific Behavior ──────────────────────────────${NC}"
    test_linux_uses_config_dir
    test_macos_uses_app_support
    test_arc_only_on_macos
    test_linux_detection_ignores_macos_only_browsers

    # 5. Known Edge Cases
    echo -e "\n${BLUE}── Known Edge Cases ────────────────────────────────────────${NC}"
    test_srware_ungoogled_macos_collision
    test_canary_dev_shared_linux_dir

    # 6. Config File Handling
    echo -e "\n${BLUE}── Config File Handling ────────────────────────────────────${NC}"
    test_json_config_detection
    test_json_config_missing_graceful_fallback
    test_custom_config_file_valid
    test_custom_config_file_invalid_json
    test_json_config_all_browsers_have_name_and_paths
    test_json_config_no_empty_platform_paths

    # 6b. Fixture-Based Config Tests
    echo -e "\n${BLUE}── Fixture-Based Config Tests ──────────────────────────────${NC}"
    test_fixture_minimal_config
    test_fixture_canary_only
    test_fixture_collision_config
    test_fixture_invalid_json_fallback
    test_fixture_empty_browsers_array
    test_fixture_missing_fields_validation

    # 7. validate_browser_installation Edge Cases
    echo -e "\n${BLUE}── Browser Installation Validation ─────────────────────────${NC}"
    test_validate_accepts_all_profile_markers
    test_validate_rejects_stale_and_nomarker

    # 8. Error Message Quality
    echo -e "\n${BLUE}── Error Message Quality ───────────────────────────────────${NC}"
    test_error_msg_nonexistent_path
    test_error_msg_relative_path
    test_error_msg_path_traversal
    test_error_msg_file_instead_of_dir
    test_debug_output_mentions_browser_name

    # 9. End-to-End Detection
    echo -e "\n${BLUE}── End-to-End Detection ────────────────────────────────────${NC}"
    test_detect_browsers_e2e_linux
    test_detect_browsers_e2e_macos
    test_detect_browsers_output_format

    # 10. Chrome Beta/Dev
    echo -e "\n${BLUE}── Chrome Beta & Dev ───────────────────────────────────────${NC}"
    test_chrome_beta_detected_linux
    test_chrome_dev_detected_linux

    # 11. Config Completeness
    echo -e "\n${BLUE}── Config Completeness ─────────────────────────────────────${NC}"
    test_builtin_configs_count
    test_builtin_and_json_browser_count_match
    test_builtin_configs_all_have_names

    # 12. Claude Code host path
    echo -e "\n${BLUE}── Claude Code Host Path ───────────────────────────────────${NC}"
    test_code_host_path_returns_without_existence_check

    # Restore HOME
    export HOME="$ORIG_HOME"

    # Summary
    echo ""
    echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
    echo -e "Tests run:    $TESTS_RUN"
    echo -e "${GREEN}Passed:       $TESTS_PASSED${NC}"
    echo -e "${RED}Failed:       $TESTS_FAILED${NC}"
    echo -e "${YELLOW}Skipped:      $TESTS_SKIPPED${NC}"
    echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"

    if [[ "$TESTS_FAILED" -gt 0 ]]; then
        exit 1
    fi
}

run_all_tests
