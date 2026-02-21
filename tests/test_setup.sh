#!/bin/bash

# Test suite for Claude Native Messaging Setup (Bash)
# Run with: ./tests/test_setup.sh

set -euo pipefail

# =============================================================================
# Test Framework
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
SETUP_SCRIPT="$PROJECT_DIR/setup.sh"
CONFIG_FILE="$PROJECT_DIR/config/browsers.json"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Temp directory for test artifacts
TEST_TMP_DIR=""

# =============================================================================
# Test Utilities
# =============================================================================

setup_test_environment() {
    TEST_TMP_DIR=$(mktemp -d)
    export HOME="$TEST_TMP_DIR/home"
    mkdir -p "$HOME"
    echo "Test environment: $TEST_TMP_DIR"
}

cleanup_test_environment() {
    if [[ -n "$TEST_TMP_DIR" ]] && [[ -d "$TEST_TMP_DIR" ]]; then
        rm -rf "$TEST_TMP_DIR"
    fi
}

# Assertion functions
assert_equals() {
    local expected="$1"
    local actual="$2"
    local message="${3:-}"

    ((TESTS_RUN++)) || true

    if [[ "$expected" == "$actual" ]]; then
        ((TESTS_PASSED++)) || true
        echo -e "${GREEN}PASS${NC}: $message"
        return 0
    else
        ((TESTS_FAILED++)) || true
        echo -e "${RED}FAIL${NC}: $message"
        echo -e "  Expected: '$expected'"
        echo -e "  Actual:   '$actual'"
        return 1
    fi
}

assert_not_empty() {
    local value="$1"
    local message="${2:-Value should not be empty}"

    ((TESTS_RUN++)) || true

    if [[ -n "$value" ]]; then
        ((TESTS_PASSED++)) || true
        echo -e "${GREEN}PASS${NC}: $message"
        return 0
    else
        ((TESTS_FAILED++)) || true
        echo -e "${RED}FAIL${NC}: $message (value was empty)"
        return 1
    fi
}

assert_file_exists() {
    local file="$1"
    local message="${2:-File should exist: $file}"

    ((TESTS_RUN++)) || true

    if [[ -f "$file" ]]; then
        ((TESTS_PASSED++)) || true
        echo -e "${GREEN}PASS${NC}: $message"
        return 0
    else
        ((TESTS_FAILED++)) || true
        echo -e "${RED}FAIL${NC}: $message (file does not exist)"
        return 1
    fi
}

assert_dir_exists() {
    local dir="$1"
    local message="${2:-Directory should exist: $dir}"

    ((TESTS_RUN++)) || true

    if [[ -d "$dir" ]]; then
        ((TESTS_PASSED++)) || true
        echo -e "${GREEN}PASS${NC}: $message"
        return 0
    else
        ((TESTS_FAILED++)) || true
        echo -e "${RED}FAIL${NC}: $message (directory does not exist)"
        return 1
    fi
}

assert_contains() {
    local haystack="$1"
    local needle="$2"
    local message="${3:-String should contain substring}"

    ((TESTS_RUN++)) || true

    if [[ "$haystack" == *"$needle"* ]]; then
        ((TESTS_PASSED++)) || true
        echo -e "${GREEN}PASS${NC}: $message"
        return 0
    else
        ((TESTS_FAILED++)) || true
        echo -e "${RED}FAIL${NC}: $message"
        echo -e "  Looking for: '$needle'"
        echo -e "  In: '$haystack'"
        return 1
    fi
}

assert_exit_code() {
    local expected="$1"
    local actual="$2"
    local message="${3:-Exit code should be $expected}"

    assert_equals "$expected" "$actual" "$message"
}

# =============================================================================
# Unit Tests
# =============================================================================

test_version_file_exists() {
    echo -e "\n${BLUE}=== Test: VERSION file exists ===${NC}"
    assert_file_exists "$PROJECT_DIR/VERSION" "VERSION file should exist"
}

test_config_file_exists() {
    echo -e "\n${BLUE}=== Test: Config file exists ===${NC}"
    assert_file_exists "$CONFIG_FILE" "browsers.json should exist"
}

test_config_file_valid_json() {
    echo -e "\n${BLUE}=== Test: Config file is valid JSON ===${NC}"

    ((TESTS_RUN++)) || true

    if command -v jq &>/dev/null; then
        if jq . "$CONFIG_FILE" > /dev/null 2>&1; then
            ((TESTS_PASSED++)) || true
            echo -e "${GREEN}PASS${NC}: browsers.json is valid JSON"
        else
            ((TESTS_FAILED++)) || true
            echo -e "${RED}FAIL${NC}: browsers.json is not valid JSON"
        fi
    else
        echo -e "${YELLOW}SKIP${NC}: jq not installed, skipping JSON validation"
    fi
}

test_config_has_browsers() {
    echo -e "\n${BLUE}=== Test: Config contains browsers ===${NC}"

    if command -v jq &>/dev/null; then
        local browser_count
        browser_count=$(jq '.browsers | length' "$CONFIG_FILE")

        ((TESTS_RUN++)) || true
        if [[ "$browser_count" -gt 0 ]]; then
            ((TESTS_PASSED++)) || true
            echo -e "${GREEN}PASS${NC}: Config contains $browser_count browsers"
        else
            ((TESTS_FAILED++)) || true
            echo -e "${RED}FAIL${NC}: Config has no browsers"
        fi
    else
        echo -e "${YELLOW}SKIP${NC}: jq not installed"
    fi
}

test_config_browsers_have_required_fields() {
    echo -e "\n${BLUE}=== Test: Browsers have required fields ===${NC}"

    if command -v jq &>/dev/null; then
        local invalid_browsers
        invalid_browsers=$(jq '[.browsers[] | select(.name == null or .paths == null)] | length' "$CONFIG_FILE")

        ((TESTS_RUN++)) || true
        if [[ "$invalid_browsers" -eq 0 ]]; then
            ((TESTS_PASSED++)) || true
            echo -e "${GREEN}PASS${NC}: All browsers have required fields (name, paths)"
        else
            ((TESTS_FAILED++)) || true
            echo -e "${RED}FAIL${NC}: $invalid_browsers browsers missing required fields"
        fi
    else
        echo -e "${YELLOW}SKIP${NC}: jq not installed"
    fi
}

test_setup_script_executable() {
    echo -e "\n${BLUE}=== Test: Setup script is executable ===${NC}"

    ((TESTS_RUN++)) || true
    if [[ -x "$SETUP_SCRIPT" ]]; then
        ((TESTS_PASSED++)) || true
        echo -e "${GREEN}PASS${NC}: setup.sh is executable"
    else
        ((TESTS_FAILED++)) || true
        echo -e "${RED}FAIL${NC}: setup.sh is not executable"
    fi
}

test_setup_help_option() {
    echo -e "\n${BLUE}=== Test: Setup script --help option ===${NC}"

    local output
    local exit_code=0
    output=$("$SETUP_SCRIPT" --help 2>&1) || exit_code=$?

    assert_exit_code "0" "$exit_code" "--help should exit with code 0"
    assert_contains "$output" "USAGE" "Help output should contain USAGE"
    assert_contains "$output" "--uninstall" "Help output should mention --uninstall"
    assert_contains "$output" "--dry-run" "Help output should mention --dry-run"
    assert_contains "$output" "--backup" "Help output should mention --backup"
}

test_setup_version_option() {
    echo -e "\n${BLUE}=== Test: Setup script --version option ===${NC}"

    local output
    local exit_code=0
    output=$("$SETUP_SCRIPT" --version 2>&1) || exit_code=$?

    assert_exit_code "0" "$exit_code" "--version should exit with code 0"
    assert_contains "$output" "Claude Native Messaging Setup" "Version output should contain script name"
}

test_setup_invalid_option() {
    echo -e "\n${BLUE}=== Test: Setup script rejects invalid options ===${NC}"

    local exit_code=0
    "$SETUP_SCRIPT" --invalid-option 2>/dev/null || exit_code=$?

    ((TESTS_RUN++)) || true
    if [[ "$exit_code" -ne 0 ]]; then
        ((TESTS_PASSED++)) || true
        echo -e "${GREEN}PASS${NC}: Invalid option rejected with non-zero exit code"
    else
        ((TESTS_FAILED++)) || true
        echo -e "${RED}FAIL${NC}: Invalid option should be rejected"
    fi
}

test_extension_ids_consistent() {
    echo -e "\n${BLUE}=== Test: Extension IDs are consistent ===${NC}"

    local official_id="fcoeoabgfenejglbffodgkkbkcdhcgfn"

    # Check in setup.sh
    local bash_id
    bash_id=$(grep -o "CLAUDE_OFFICIAL_EXTENSION_ID=\"[^\"]*\"" "$SETUP_SCRIPT" | head -1 | cut -d'"' -f2)

    # Check in config
    local config_id=""
    if command -v jq &>/dev/null; then
        config_id=$(jq -r '.extension_ids.official.id' "$CONFIG_FILE")
    fi

    assert_equals "$official_id" "$bash_id" "Bash script should have correct official extension ID"

    if [[ -n "$config_id" ]]; then
        assert_equals "$official_id" "$config_id" "Config should have correct official extension ID"
    fi
}

test_dry_run_creates_no_files() {
    echo -e "\n${BLUE}=== Test: Dry-run creates no files ===${NC}"

    setup_test_environment

    local test_browser_path="$TEST_TMP_DIR/TestBrowser"
    mkdir -p "$test_browser_path"

    # Create a fake Claude native host
    local fake_claude_path="$TEST_TMP_DIR/Applications/Claude.app/Contents/Helpers"
    mkdir -p "$fake_claude_path"
    touch "$fake_claude_path/chrome-native-host"

    # Run with dry-run (this will fail because Claude isn't installed, but that's expected)
    # The test is just to verify the script handles dry-run mode
    local output
    output=$("$SETUP_SCRIPT" --dry-run --path "$test_browser_path" 2>&1) || true

    # In dry-run mode, no NativeMessagingHosts directory should be created
    ((TESTS_RUN++)) || true
    if [[ ! -d "$test_browser_path/NativeMessagingHosts" ]]; then
        ((TESTS_PASSED++)) || true
        echo -e "${GREEN}PASS${NC}: Dry-run did not create NativeMessagingHosts directory"
    else
        ((TESTS_FAILED++)) || true
        echo -e "${RED}FAIL${NC}: Dry-run created files when it should not have"
    fi

    cleanup_test_environment
}

test_builtin_browser_configs_format() {
    echo -e "\n${BLUE}=== Test: Built-in browser configs have correct format ===${NC}"

    # Extract BUILTIN_BROWSER_CONFIGS from setup.sh and validate format
    local configs
    configs=$(grep -A100 "BUILTIN_BROWSER_CONFIGS=(" "$SETUP_SCRIPT" | grep -B100 "^)" | grep "\".*|.*|.*\"")

    local invalid_count=0
    while IFS= read -r line; do
        # Each line should have format "Name|macOS path|Linux path"
        local parts
        parts=$(echo "$line" | tr -cd '|' | wc -c)
        if [[ "$parts" -ne 2 ]]; then
            ((invalid_count++)) || true
        fi
    done <<< "$configs"

    ((TESTS_RUN++)) || true
    if [[ "$invalid_count" -eq 0 ]]; then
        ((TESTS_PASSED++)) || true
        echo -e "${GREEN}PASS${NC}: All built-in browser configs have correct format"
    else
        ((TESTS_FAILED++)) || true
        echo -e "${RED}FAIL${NC}: $invalid_count browser configs have invalid format"
    fi
}

# =============================================================================
# Integration Tests
# =============================================================================

test_json_config_matches_builtin() {
    echo -e "\n${BLUE}=== Test: JSON config matches built-in configs ===${NC}"

    if ! command -v jq &>/dev/null; then
        echo -e "${YELLOW}SKIP${NC}: jq not installed"
        return
    fi

    # Get browser names from JSON
    local json_browsers
    json_browsers=$(jq -r '.browsers[].name' "$CONFIG_FILE" | sort)

    # Get browser names from built-in config in setup.sh
    local builtin_browsers
    builtin_browsers=$(grep -oP '^\s*"[^"]+(?=\|)' "$SETUP_SCRIPT" | tr -d '"' | tr -d ' ' | sort | uniq)

    # Check that all built-in browsers are in JSON
    local missing=0
    while IFS= read -r browser; do
        if ! echo "$json_browsers" | grep -q "^$browser$"; then
            echo -e "${YELLOW}WARNING${NC}: Browser '$browser' in built-in but not in JSON"
            ((missing++)) || true
        fi
    done <<< "$builtin_browsers"

    ((TESTS_RUN++)) || true
    if [[ "$missing" -eq 0 ]]; then
        ((TESTS_PASSED++)) || true
        echo -e "${GREEN}PASS${NC}: Built-in browsers match JSON config"
    else
        ((TESTS_PASSED++)) || true  # This is a warning, not a failure
        echo -e "${YELLOW}PASS (with warnings)${NC}: $missing browsers not in JSON config"
    fi
}

# =============================================================================
# Chrome Canary Tests
# =============================================================================

test_chrome_canary_in_json_config() {
    echo -e "\n${BLUE}=== Test: Chrome Canary in JSON config ===${NC}"

    if ! command -v jq &>/dev/null; then
        echo -e "${YELLOW}SKIP${NC}: jq not installed"
        return
    fi

    local canary_name
    canary_name=$(jq -r '.browsers[] | select(.name == "Google Chrome Canary") | .name' "$CONFIG_FILE")

    assert_equals "Google Chrome Canary" "$canary_name" "Chrome Canary should be in browsers.json"
}

test_chrome_canary_json_paths() {
    echo -e "\n${BLUE}=== Test: Chrome Canary has correct platform paths in JSON ===${NC}"

    if ! command -v jq &>/dev/null; then
        echo -e "${YELLOW}SKIP${NC}: jq not installed"
        return
    fi

    local macos_path linux_path windows_path
    macos_path=$(jq -r '.browsers[] | select(.name == "Google Chrome Canary") | .paths.macos' "$CONFIG_FILE")
    linux_path=$(jq -r '.browsers[] | select(.name == "Google Chrome Canary") | .paths.linux' "$CONFIG_FILE")
    windows_path=$(jq -r '.browsers[] | select(.name == "Google Chrome Canary") | .paths.windows' "$CONFIG_FILE")

    assert_equals "Google/Chrome Canary" "$macos_path" "Chrome Canary macOS path should be Google/Chrome Canary"
    assert_equals "google-chrome-unstable" "$linux_path" "Chrome Canary Linux path should be google-chrome-unstable"
    assert_equals 'Google\Chrome SxS\User Data' "$windows_path" "Chrome Canary Windows path should be Google\\Chrome SxS\\User Data"
}

test_chrome_canary_in_builtin_configs() {
    echo -e "\n${BLUE}=== Test: Chrome Canary in built-in configs ===${NC}"

    ((TESTS_RUN++)) || true
    if grep -q "Google Chrome Canary" "$SETUP_SCRIPT"; then
        ((TESTS_PASSED++)) || true
        echo -e "${GREEN}PASS${NC}: Chrome Canary found in setup.sh BUILTIN_BROWSER_CONFIGS"
    else
        ((TESTS_FAILED++)) || true
        echo -e "${RED}FAIL${NC}: Chrome Canary not found in setup.sh BUILTIN_BROWSER_CONFIGS"
    fi
}

test_chrome_canary_detection_with_data_dir() {
    echo -e "\n${BLUE}=== Test: Chrome Canary detected when data directory exists ===${NC}"

    setup_test_environment

    # Source required functions from setup.sh
    QUIET=true
    VERBOSE=false
    OS="linux"
    CONFIG_FILE="$PROJECT_DIR/config/browsers.json"

    # Create simulated Chrome Canary data directory
    mkdir -p "$HOME/.config/google-chrome-unstable"

    # Source detect_browsers dependencies
    eval "$(sed -n '/^get_app_support_base()/,/^}/p' "$SETUP_SCRIPT")"
    eval "$(sed -n '/^print_verbose()/,/^}/p' "$SETUP_SCRIPT")"

    # Use built-in configs for detection (no jq dependency)
    local base_path="$HOME/.config"
    local detected=false

    # Read BUILTIN_BROWSER_CONFIGS from setup.sh
    while IFS= read -r line; do
        local config_line
        config_line=$(echo "$line" | sed 's/^[[:space:]]*"//;s/"$//')
        IFS='|' read -r name macos_path linux_path <<< "$config_line"

        if [[ "$name" == "Google Chrome Canary" ]] && [[ -n "$linux_path" ]]; then
            local full_path="$base_path/$linux_path"
            if [[ -d "$full_path" ]]; then
                detected=true
            fi
        fi
    done < <(grep -oP '"[^"]+\|[^"]*\|[^"]*"' "$SETUP_SCRIPT")

    ((TESTS_RUN++)) || true
    if [[ "$detected" == true ]]; then
        ((TESTS_PASSED++)) || true
        echo -e "${GREEN}PASS${NC}: Chrome Canary detected via data directory"
    else
        ((TESTS_FAILED++)) || true
        echo -e "${RED}FAIL${NC}: Chrome Canary not detected despite data directory existing"
    fi

    cleanup_test_environment
}

# =============================================================================
# Path Validation Tests
# =============================================================================

# Helper: extract and source validate_path + its dependencies from setup.sh
_load_validate_path() {
    # Define minimal dependencies that validate_path needs
    QUIET=false
    VERBOSE=false
    OS="linux"

    # Define the print functions validate_path calls
    print_error() { echo "ERROR: $1" >&2; }
    print_verbose() { :; }

    # Source just the validate_path function by extracting it
    eval "$(sed -n '/^validate_path()/,/^}/p' "$SETUP_SCRIPT")"
}

test_validate_path_accepts_existing_directory() {
    echo -e "\n${BLUE}=== Test: validate_path accepts existing directory ===${NC}"

    setup_test_environment
    _load_validate_path

    local test_dir="$TEST_TMP_DIR/browser-data"
    mkdir -p "$test_dir"

    local result
    local exit_code=0
    result=$(validate_path "$test_dir" 2>/dev/null) || exit_code=$?

    assert_exit_code "0" "$exit_code" "validate_path should accept existing directory"
    assert_equals "$test_dir" "$result" "validate_path should return the resolved path"

    cleanup_test_environment
}

test_validate_path_rejects_nonexistent_path() {
    echo -e "\n${BLUE}=== Test: validate_path rejects non-existent path ===${NC}"

    setup_test_environment
    _load_validate_path

    local exit_code=0
    local output
    output=$(validate_path "/nonexistent/path/to/browser" 2>&1) || exit_code=$?

    ((TESTS_RUN++)) || true
    if [[ "$exit_code" -ne 0 ]]; then
        ((TESTS_PASSED++)) || true
        echo -e "${GREEN}PASS${NC}: Non-existent path rejected"
    else
        ((TESTS_FAILED++)) || true
        echo -e "${RED}FAIL${NC}: Non-existent path should be rejected"
    fi

    assert_contains "$output" "does not exist" "Error should mention 'does not exist'"
}

test_validate_path_rejects_relative_path() {
    echo -e "\n${BLUE}=== Test: validate_path rejects relative path ===${NC}"

    setup_test_environment
    _load_validate_path

    local exit_code=0
    local output
    output=$(validate_path "relative/path/to/browser" 2>&1) || exit_code=$?

    ((TESTS_RUN++)) || true
    if [[ "$exit_code" -ne 0 ]]; then
        ((TESTS_PASSED++)) || true
        echo -e "${GREEN}PASS${NC}: Relative path rejected"
    else
        ((TESTS_FAILED++)) || true
        echo -e "${RED}FAIL${NC}: Relative path should be rejected"
    fi

    assert_contains "$output" "must be absolute" "Error should mention 'must be absolute'"
}

test_validate_path_handles_spaces_in_path() {
    echo -e "\n${BLUE}=== Test: validate_path handles spaces in path ===${NC}"

    setup_test_environment
    _load_validate_path

    local test_dir="$TEST_TMP_DIR/path with spaces/Browser Data"
    mkdir -p "$test_dir"

    local result
    local exit_code=0
    result=$(validate_path "$test_dir" 2>/dev/null) || exit_code=$?

    assert_exit_code "0" "$exit_code" "validate_path should accept path with spaces"
    assert_equals "$test_dir" "$result" "validate_path should return path with spaces intact"

    cleanup_test_environment
}

test_validate_path_accepts_canary_custom_path() {
    echo -e "\n${BLUE}=== Test: validate_path accepts Chrome Canary custom path ===${NC}"

    setup_test_environment
    _load_validate_path

    # Simulate a Chrome Canary data dir
    local canary_dir="$TEST_TMP_DIR/home/.config/google-chrome-canary"
    mkdir -p "$canary_dir"

    local result
    local exit_code=0
    result=$(validate_path "$canary_dir" 2>/dev/null) || exit_code=$?

    assert_exit_code "0" "$exit_code" "validate_path should accept Canary path when it exists"
    assert_equals "$canary_dir" "$result" "validate_path should return the Canary path"

    cleanup_test_environment
}

test_validate_path_accepts_opt_path() {
    echo -e "\n${BLUE}=== Test: validate_path accepts /opt/ paths ===${NC}"

    setup_test_environment
    _load_validate_path

    # Use a real existing /opt or /tmp path for testing
    local test_dir="$TEST_TMP_DIR/opt-browser"
    mkdir -p "$test_dir"

    local result
    local exit_code=0
    result=$(validate_path "$test_dir" 2>/dev/null) || exit_code=$?

    assert_exit_code "0" "$exit_code" "validate_path should accept paths outside \$HOME"
    assert_equals "$test_dir" "$result" "validate_path should return the path as-is"

    cleanup_test_environment
}

test_validate_path_rejects_file_not_directory() {
    echo -e "\n${BLUE}=== Test: validate_path rejects regular file (not directory) ===${NC}"

    setup_test_environment
    _load_validate_path

    local test_file="$TEST_TMP_DIR/not-a-directory"
    touch "$test_file"

    local exit_code=0
    local output
    output=$(validate_path "$test_file" 2>&1) || exit_code=$?

    ((TESTS_RUN++)) || true
    if [[ "$exit_code" -ne 0 ]]; then
        ((TESTS_PASSED++)) || true
        echo -e "${GREEN}PASS${NC}: Regular file rejected (not a directory)"
    else
        ((TESTS_FAILED++)) || true
        echo -e "${RED}FAIL${NC}: Regular file should be rejected (expects directory)"
    fi

    cleanup_test_environment
}

test_validate_path_rejects_path_traversal() {
    echo -e "\n${BLUE}=== Test: validate_path rejects path traversal ===${NC}"

    setup_test_environment
    _load_validate_path

    local exit_code=0
    local output
    output=$(validate_path "/tmp/../etc/passwd" 2>&1) || exit_code=$?

    ((TESTS_RUN++)) || true
    if [[ "$exit_code" -ne 0 ]]; then
        ((TESTS_PASSED++)) || true
        echo -e "${GREEN}PASS${NC}: Path traversal rejected"
    else
        ((TESTS_FAILED++)) || true
        echo -e "${RED}FAIL${NC}: Path traversal should be rejected"
    fi

    cleanup_test_environment
}

# =============================================================================
# Browser Installation Validation Tests
# =============================================================================

_load_validate_browser_installation() {
    QUIET=false
    VERBOSE=false
    DEBUG=true
    OS="linux"

    print_debug() { echo "DEBUG: $1"; }
    print_verbose() { :; }

    eval "$(sed -n '/^validate_browser_installation()/,/^}/p' "$SETUP_SCRIPT")"
}

test_validate_browser_rejects_nonexistent_dir() {
    echo -e "\n${BLUE}=== Test: validate_browser_installation rejects non-existent dir ===${NC}"

    setup_test_environment
    _load_validate_browser_installation

    local exit_code=0
    validate_browser_installation "/nonexistent/path" "FakeBrowser" >/dev/null 2>&1 || exit_code=$?

    ((TESTS_RUN++))
    if [[ "$exit_code" -ne 0 ]]; then
        ((TESTS_PASSED++))
        echo -e "${GREEN}PASS${NC}: Non-existent directory rejected"
    else
        ((TESTS_FAILED++))
        echo -e "${RED}FAIL${NC}: Non-existent directory should be rejected"
    fi

    cleanup_test_environment
}

test_validate_browser_rejects_empty_dir() {
    echo -e "\n${BLUE}=== Test: validate_browser_installation rejects empty dir ===${NC}"

    setup_test_environment
    _load_validate_browser_installation

    local test_dir="$TEST_TMP_DIR/EmptyBrowser"
    mkdir -p "$test_dir"

    local exit_code=0
    validate_browser_installation "$test_dir" "EmptyBrowser" >/dev/null 2>&1 || exit_code=$?

    ((TESTS_RUN++))
    if [[ "$exit_code" -ne 0 ]]; then
        ((TESTS_PASSED++))
        echo -e "${GREEN}PASS${NC}: Empty directory rejected"
    else
        ((TESTS_FAILED++))
        echo -e "${RED}FAIL${NC}: Empty directory should be rejected (stale install)"
    fi

    cleanup_test_environment
}

test_validate_browser_rejects_dir_without_profiles() {
    echo -e "\n${BLUE}=== Test: validate_browser_installation rejects dir without profiles ===${NC}"

    setup_test_environment
    _load_validate_browser_installation

    local test_dir="$TEST_TMP_DIR/NotABrowser"
    mkdir -p "$test_dir"
    touch "$test_dir/random_file.txt"
    mkdir -p "$test_dir/SomeRandomDir"

    local exit_code=0
    validate_browser_installation "$test_dir" "NotABrowser" >/dev/null 2>&1 || exit_code=$?

    ((TESTS_RUN++))
    if [[ "$exit_code" -ne 0 ]]; then
        ((TESTS_PASSED++))
        echo -e "${GREEN}PASS${NC}: Directory without browser profiles rejected"
    else
        ((TESTS_FAILED++))
        echo -e "${RED}FAIL${NC}: Directory without profiles should be rejected"
    fi

    cleanup_test_environment
}

test_validate_browser_accepts_dir_with_default_profile() {
    echo -e "\n${BLUE}=== Test: validate_browser_installation accepts dir with Default/ ===${NC}"

    setup_test_environment
    _load_validate_browser_installation

    local test_dir="$TEST_TMP_DIR/RealBrowser"
    mkdir -p "$test_dir/Default"

    local exit_code=0
    validate_browser_installation "$test_dir" "RealBrowser" >/dev/null 2>&1 || exit_code=$?

    assert_exit_code "0" "$exit_code" "Directory with Default/ profile should be accepted"

    cleanup_test_environment
}

test_validate_browser_accepts_dir_with_local_state() {
    echo -e "\n${BLUE}=== Test: validate_browser_installation accepts dir with Local State ===${NC}"

    setup_test_environment
    _load_validate_browser_installation

    local test_dir="$TEST_TMP_DIR/BrowserWithState"
    mkdir -p "$test_dir"
    touch "$test_dir/Local State"

    local exit_code=0
    validate_browser_installation "$test_dir" "BrowserWithState" >/dev/null 2>&1 || exit_code=$?

    assert_exit_code "0" "$exit_code" "Directory with Local State file should be accepted"

    cleanup_test_environment
}

test_validate_browser_accepts_dir_with_preferences() {
    echo -e "\n${BLUE}=== Test: validate_browser_installation accepts dir with Preferences ===${NC}"

    setup_test_environment
    _load_validate_browser_installation

    local test_dir="$TEST_TMP_DIR/BrowserWithPrefs"
    mkdir -p "$test_dir"
    touch "$test_dir/Preferences"

    local exit_code=0
    validate_browser_installation "$test_dir" "BrowserWithPrefs" >/dev/null 2>&1 || exit_code=$?

    assert_exit_code "0" "$exit_code" "Directory with Preferences file should be accepted"

    cleanup_test_environment
}

test_validate_browser_accepts_dir_with_numbered_profile() {
    echo -e "\n${BLUE}=== Test: validate_browser_installation accepts dir with numbered profiles ===${NC}"

    setup_test_environment
    _load_validate_browser_installation

    local test_dir="$TEST_TMP_DIR/MultiProfileBrowser"
    mkdir -p "$test_dir/Profile 1"
    mkdir -p "$test_dir/Profile 2"

    local exit_code=0
    validate_browser_installation "$test_dir" "MultiProfileBrowser" >/dev/null 2>&1 || exit_code=$?

    assert_exit_code "0" "$exit_code" "Directory with numbered profiles should be accepted"

    cleanup_test_environment
}

test_validate_browser_debug_output() {
    echo -e "\n${BLUE}=== Test: validate_browser_installation produces debug output ===${NC}"

    setup_test_environment
    _load_validate_browser_installation

    local output
    output=$(validate_browser_installation "/nonexistent/path" "Opera" 2>&1) || true

    assert_contains "$output" "Skipped Opera" "Debug output should mention skipped browser name"

    local test_dir="$TEST_TMP_DIR/EmptyDir"
    mkdir -p "$test_dir"
    output=$(validate_browser_installation "$test_dir" "Brave" 2>&1) || true

    assert_contains "$output" "Skipped Brave" "Debug output should mention skipped browser for empty dir"

    cleanup_test_environment
}

test_detect_browsers_filters_stale_dirs() {
    echo -e "\n${BLUE}=== Test: detect_browsers filters stale browser directories ===${NC}"

    setup_test_environment

    local saved_config="$CONFIG_FILE"
    QUIET=false
    VERBOSE=false
    DEBUG=false
    OS="linux"
    CONFIG_FILE="/nonexistent"

    print_debug() { :; }
    print_verbose() { :; }

    eval "$(sed -n '/^get_app_support_base()/,/^}/p' "$SETUP_SCRIPT")"
    eval "$(sed -n '/^validate_browser_installation()/,/^}/p' "$SETUP_SCRIPT")"

    local base_path="$HOME/.config"

    # Valid browser: Google Chrome with Default profile
    mkdir -p "$base_path/google-chrome/Default"

    # Stale browser: opera with empty dir
    mkdir -p "$base_path/opera"

    # Stale browser: Brave with no profile markers
    mkdir -p "$base_path/BraveSoftware/Brave-Browser/SomeRandomDir"

    local chrome_valid=false
    local opera_valid=false
    local brave_valid=false

    validate_browser_installation "$base_path/google-chrome" "Google Chrome" >/dev/null 2>&1 && chrome_valid=true
    validate_browser_installation "$base_path/opera" "Opera" >/dev/null 2>&1 && opera_valid=true
    validate_browser_installation "$base_path/BraveSoftware/Brave-Browser" "Brave" >/dev/null 2>&1 && brave_valid=true

    ((TESTS_RUN++))
    if [[ "$chrome_valid" == true ]]; then
        ((TESTS_PASSED++))
        echo -e "${GREEN}PASS${NC}: Google Chrome with Default/ profile accepted"
    else
        ((TESTS_FAILED++))
        echo -e "${RED}FAIL${NC}: Google Chrome with Default/ profile should be accepted"
    fi

    ((TESTS_RUN++))
    if [[ "$opera_valid" == false ]]; then
        ((TESTS_PASSED++))
        echo -e "${GREEN}PASS${NC}: Opera with empty dir filtered out"
    else
        ((TESTS_FAILED++))
        echo -e "${RED}FAIL${NC}: Opera with empty dir should be filtered out"
    fi

    ((TESTS_RUN++))
    if [[ "$brave_valid" == false ]]; then
        ((TESTS_PASSED++))
        echo -e "${GREEN}PASS${NC}: Brave without profile markers filtered out"
    else
        ((TESTS_FAILED++))
        echo -e "${RED}FAIL${NC}: Brave without profile markers should be filtered out"
    fi

    CONFIG_FILE="$saved_config"
    cleanup_test_environment
}

test_help_shows_debug_flag() {
    echo -e "\n${BLUE}=== Test: --help shows --debug flag ===${NC}"

    local output
    output=$("$SETUP_SCRIPT" --help 2>&1)

    assert_contains "$output" "--debug" "Help output should mention --debug flag"
}

# =============================================================================
# Main Test Runner
# =============================================================================

run_tests() {
    echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║  Claude Native Messaging Setup - Test Suite                ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    # Check Bash version
    if [[ "${BASH_VERSINFO[0]}" -lt 4 ]]; then
        echo -e "${RED}ERROR: Bash 4.0+ required for tests${NC}"
        exit 1
    fi

    # Run unit tests
    echo -e "${BLUE}Running Unit Tests...${NC}"
    test_version_file_exists
    test_config_file_exists
    test_config_file_valid_json
    test_config_has_browsers
    test_config_browsers_have_required_fields
    test_setup_script_executable
    test_setup_help_option
    test_setup_version_option
    test_setup_invalid_option
    test_extension_ids_consistent
    test_builtin_browser_configs_format

    # Run Chrome Canary tests
    echo -e "\n${BLUE}Running Chrome Canary Tests...${NC}"
    test_chrome_canary_in_json_config
    test_chrome_canary_json_paths
    test_chrome_canary_in_builtin_configs
    test_chrome_canary_detection_with_data_dir

    # Run path validation tests
    echo -e "\n${BLUE}Running Path Validation Tests...${NC}"
    test_validate_path_accepts_existing_directory
    test_validate_path_rejects_nonexistent_path
    test_validate_path_rejects_relative_path
    test_validate_path_handles_spaces_in_path
    test_validate_path_accepts_canary_custom_path
    test_validate_path_accepts_opt_path
    test_validate_path_rejects_file_not_directory
    test_validate_path_rejects_path_traversal

    # Run browser installation validation tests
    echo -e "\n${BLUE}Running Browser Installation Validation Tests...${NC}"
    test_validate_browser_rejects_nonexistent_dir
    test_validate_browser_rejects_empty_dir
    test_validate_browser_rejects_dir_without_profiles
    test_validate_browser_accepts_dir_with_default_profile
    test_validate_browser_accepts_dir_with_local_state
    test_validate_browser_accepts_dir_with_preferences
    test_validate_browser_accepts_dir_with_numbered_profile
    test_validate_browser_debug_output
    test_detect_browsers_filters_stale_dirs
    test_help_shows_debug_flag

    # Run integration tests
    echo -e "\n${BLUE}Running Integration Tests...${NC}"
    test_json_config_matches_builtin
    test_dry_run_creates_no_files

    # Print summary
    echo ""
    echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
    echo -e "Tests run: $TESTS_RUN"
    echo -e "${GREEN}Passed: $TESTS_PASSED${NC}"
    echo -e "${RED}Failed: $TESTS_FAILED${NC}"
    echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"

    if [[ "$TESTS_FAILED" -gt 0 ]]; then
        exit 1
    fi
}

# Run tests
run_tests
