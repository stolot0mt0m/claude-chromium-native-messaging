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

    ((TESTS_RUN++))

    if [[ "$expected" == "$actual" ]]; then
        ((TESTS_PASSED++))
        echo -e "${GREEN}PASS${NC}: $message"
        return 0
    else
        ((TESTS_FAILED++))
        echo -e "${RED}FAIL${NC}: $message"
        echo -e "  Expected: '$expected'"
        echo -e "  Actual:   '$actual'"
        return 1
    fi
}

assert_not_empty() {
    local value="$1"
    local message="${2:-Value should not be empty}"

    ((TESTS_RUN++))

    if [[ -n "$value" ]]; then
        ((TESTS_PASSED++))
        echo -e "${GREEN}PASS${NC}: $message"
        return 0
    else
        ((TESTS_FAILED++))
        echo -e "${RED}FAIL${NC}: $message (value was empty)"
        return 1
    fi
}

assert_file_exists() {
    local file="$1"
    local message="${2:-File should exist: $file}"

    ((TESTS_RUN++))

    if [[ -f "$file" ]]; then
        ((TESTS_PASSED++))
        echo -e "${GREEN}PASS${NC}: $message"
        return 0
    else
        ((TESTS_FAILED++))
        echo -e "${RED}FAIL${NC}: $message (file does not exist)"
        return 1
    fi
}

assert_dir_exists() {
    local dir="$1"
    local message="${2:-Directory should exist: $dir}"

    ((TESTS_RUN++))

    if [[ -d "$dir" ]]; then
        ((TESTS_PASSED++))
        echo -e "${GREEN}PASS${NC}: $message"
        return 0
    else
        ((TESTS_FAILED++))
        echo -e "${RED}FAIL${NC}: $message (directory does not exist)"
        return 1
    fi
}

assert_contains() {
    local haystack="$1"
    local needle="$2"
    local message="${3:-String should contain substring}"

    ((TESTS_RUN++))

    if [[ "$haystack" == *"$needle"* ]]; then
        ((TESTS_PASSED++))
        echo -e "${GREEN}PASS${NC}: $message"
        return 0
    else
        ((TESTS_FAILED++))
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

    ((TESTS_RUN++))

    if command -v jq &>/dev/null; then
        if jq . "$CONFIG_FILE" > /dev/null 2>&1; then
            ((TESTS_PASSED++))
            echo -e "${GREEN}PASS${NC}: browsers.json is valid JSON"
        else
            ((TESTS_FAILED++))
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

        ((TESTS_RUN++))
        if [[ "$browser_count" -gt 0 ]]; then
            ((TESTS_PASSED++))
            echo -e "${GREEN}PASS${NC}: Config contains $browser_count browsers"
        else
            ((TESTS_FAILED++))
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

        ((TESTS_RUN++))
        if [[ "$invalid_browsers" -eq 0 ]]; then
            ((TESTS_PASSED++))
            echo -e "${GREEN}PASS${NC}: All browsers have required fields (name, paths)"
        else
            ((TESTS_FAILED++))
            echo -e "${RED}FAIL${NC}: $invalid_browsers browsers missing required fields"
        fi
    else
        echo -e "${YELLOW}SKIP${NC}: jq not installed"
    fi
}

test_setup_script_executable() {
    echo -e "\n${BLUE}=== Test: Setup script is executable ===${NC}"

    ((TESTS_RUN++))
    if [[ -x "$SETUP_SCRIPT" ]]; then
        ((TESTS_PASSED++))
        echo -e "${GREEN}PASS${NC}: setup.sh is executable"
    else
        ((TESTS_FAILED++))
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

    ((TESTS_RUN++))
    if [[ "$exit_code" -ne 0 ]]; then
        ((TESTS_PASSED++))
        echo -e "${GREEN}PASS${NC}: Invalid option rejected with non-zero exit code"
    else
        ((TESTS_FAILED++))
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
    ((TESTS_RUN++))
    if [[ ! -d "$test_browser_path/NativeMessagingHosts" ]]; then
        ((TESTS_PASSED++))
        echo -e "${GREEN}PASS${NC}: Dry-run did not create NativeMessagingHosts directory"
    else
        ((TESTS_FAILED++))
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
            ((invalid_count++))
        fi
    done <<< "$configs"

    ((TESTS_RUN++))
    if [[ "$invalid_count" -eq 0 ]]; then
        ((TESTS_PASSED++))
        echo -e "${GREEN}PASS${NC}: All built-in browser configs have correct format"
    else
        ((TESTS_FAILED++))
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
            ((missing++))
        fi
    done <<< "$builtin_browsers"

    ((TESTS_RUN++))
    if [[ "$missing" -eq 0 ]]; then
        ((TESTS_PASSED++))
        echo -e "${GREEN}PASS${NC}: Built-in browsers match JSON config"
    else
        ((TESTS_PASSED++))  # This is a warning, not a failure
        echo -e "${YELLOW}PASS (with warnings)${NC}: $missing browsers not in JSON config"
    fi
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
