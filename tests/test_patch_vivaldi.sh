#!/bin/bash

# Test suite for the Vivaldi tab-binding patch (Bash)
# Run with: ./tests/test_patch_vivaldi.sh
#
# These tests build patched copies from a synthetic extension fixture, so they
# never touch a real browser profile.

set -euo pipefail

# =============================================================================
# Test Framework
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
PATCH_SCRIPT="$PROJECT_DIR/patch-vivaldi.sh"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

TEST_TMP_DIR=""
FIXTURE_DIR=""
DEST_DIR=""

# JSON backends to exercise. Populated by detect_json_backends().
JSON_BACKENDS=()

# =============================================================================
# Test Utilities
# =============================================================================

setup_test_environment() {
    TEST_TMP_DIR=$(mktemp -d)
    FIXTURE_DIR="$TEST_TMP_DIR/store/fcoeoabgfenejglbffodgkkbkcdhcgfn/1.0.84_0"
    DEST_DIR="$TEST_TMP_DIR/patched"
    mkdir -p "$FIXTURE_DIR/assets" "$FIXTURE_DIR/_metadata"

    # Minimal stand-in for the store copy of the Claude extension
    cat >"$FIXTURE_DIR/manifest.json" <<'JSON'
{
  "manifest_version": 3,
  "name": "Claude",
  "version": "1.0.84",
  "key": "MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8TESTKEY",
  "update_url": "https://clients2.google.com/service/update2/crx",
  "background": {
    "service_worker": "service-worker-loader.js",
    "type": "module"
  },
  "permissions": ["tabs", "storage", "sidePanel"]
}
JSON
    echo "import './assets/service-worker.ts-Db58OdRp.js';" >"$FIXTURE_DIR/service-worker-loader.js"
    echo "// stub" >"$FIXTURE_DIR/assets/service-worker.ts-Db58OdRp.js"
    echo "stub" >"$FIXTURE_DIR/_metadata/verified_contents.json"

    # An older version, to prove the highest one wins
    mkdir -p "$TEST_TMP_DIR/store/fcoeoabgfenejglbffodgkkbkcdhcgfn/1.0.9_0"
    sed 's/1\.0\.84/1.0.9/' "$FIXTURE_DIR/manifest.json" \
        >"$TEST_TMP_DIR/store/fcoeoabgfenejglbffodgkkbkcdhcgfn/1.0.9_0/manifest.json"

    echo "Test environment: $TEST_TMP_DIR"
}

cleanup_test_environment() {
    if [[ -n "$TEST_TMP_DIR" ]] && [[ -d "$TEST_TMP_DIR" ]]; then
        rm -rf "$TEST_TMP_DIR"
    fi
}

detect_json_backends() {
    command -v python3 &>/dev/null && JSON_BACKENDS+=("python3")
    command -v jq &>/dev/null && JSON_BACKENDS+=("jq")

    if [[ ${#JSON_BACKENDS[@]} -eq 0 ]]; then
        echo -e "${RED}Neither python3 nor jq available — cannot run tests${NC}" >&2
        exit 1
    fi
}

# Run the patch script with the fixture as source
run_patch() {
    "$PATCH_SCRIPT" --source "$FIXTURE_DIR" --dest "$DEST_DIR" "$@" 2>&1
}

# Read a top-level field out of a JSON file, backend-independently
json_value() {
    local file="$1" path="$2"
    if command -v python3 &>/dev/null; then
        JSON_FILE="$file" JSON_PATH="$path" python3 - <<'PY'
import json, os, sys
try:
    with open(os.environ["JSON_FILE"]) as fh:
        node = json.load(fh)
except (OSError, ValueError):
    sys.exit(0)
for part in os.environ["JSON_PATH"].split("."):
    if not isinstance(node, dict) or part not in node:
        sys.exit(0)
    node = node[part]
print(node)
PY
    else
        jq -r --arg p "$path" 'getpath($p | split(".")) // ""' "$file"
    fi
}

# Assertions
assert_equals() {
    local expected="$1" actual="$2" message="${3:-}"
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

assert_file_exists() {
    local file="$1"
    local message="${2:-File should exist: $file}"
    ((TESTS_RUN++)) || true
    if [[ -f "$file" ]]; then
        ((TESTS_PASSED++)) || true
        echo -e "${GREEN}PASS${NC}: $message"
    else
        ((TESTS_FAILED++)) || true
        echo -e "${RED}FAIL${NC}: $message (file does not exist)"
    fi
}

assert_not_exists() {
    local path="$1"
    local message="${2:-Path should not exist: $path}"
    ((TESTS_RUN++)) || true
    if [[ ! -e "$path" ]]; then
        ((TESTS_PASSED++)) || true
        echo -e "${GREEN}PASS${NC}: $message"
    else
        ((TESTS_FAILED++)) || true
        echo -e "${RED}FAIL${NC}: $message (path exists)"
    fi
}

assert_contains() {
    local haystack="$1" needle="$2" message="${3:-String should contain substring}"
    ((TESTS_RUN++)) || true
    if [[ "$haystack" == *"$needle"* ]]; then
        ((TESTS_PASSED++)) || true
        echo -e "${GREEN}PASS${NC}: $message"
    else
        ((TESTS_FAILED++)) || true
        echo -e "${RED}FAIL${NC}: $message"
        echo -e "  Looking for: '$needle'"
        echo -e "  In: '$haystack'"
    fi
}

assert_exit_code() {
    local expected="$1" actual="$2" message="${3:-}"
    ((TESTS_RUN++)) || true
    if [[ "$expected" == "$actual" ]]; then
        ((TESTS_PASSED++)) || true
        echo -e "${GREEN}PASS${NC}: $message"
    else
        ((TESTS_FAILED++)) || true
        echo -e "${RED}FAIL${NC}: $message (expected exit $expected, got $actual)"
    fi
}

# =============================================================================
# Script Sanity Tests
# =============================================================================

test_script_exists_and_is_executable() {
    assert_file_exists "$PATCH_SCRIPT" "patch-vivaldi.sh exists"
    ((TESTS_RUN++)) || true
    if [[ -x "$PATCH_SCRIPT" ]]; then
        ((TESTS_PASSED++)) || true
        echo -e "${GREEN}PASS${NC}: patch-vivaldi.sh is executable"
    else
        ((TESTS_FAILED++)) || true
        echo -e "${RED}FAIL${NC}: patch-vivaldi.sh is not executable"
    fi
}

test_help_lists_options() {
    local output
    output=$("$PATCH_SCRIPT" --help)
    assert_contains "$output" "--check" "Help documents --check"
    assert_contains "$output" "--uninstall" "Help documents --uninstall"
    assert_contains "$output" "--dry-run" "Help documents --dry-run"
    assert_contains "$output" "mode=window" "Help or usage references the panel URL mode"
}

test_unknown_option_fails() {
    local code=0
    "$PATCH_SCRIPT" --not-a-real-option >/dev/null 2>&1 || code=$?
    assert_exit_code "1" "$code" "Unknown option exits 1"
}

test_check_and_uninstall_are_exclusive() {
    local code=0
    "$PATCH_SCRIPT" --check --uninstall >/dev/null 2>&1 || code=$?
    assert_exit_code "1" "$code" "--check with --uninstall exits 1"
}

test_missing_source_fails() {
    local code=0
    "$PATCH_SCRIPT" --source "$TEST_TMP_DIR/nonexistent" --dest "$DEST_DIR" >/dev/null 2>&1 || code=$?
    assert_exit_code "1" "$code" "Nonexistent --source exits 1"
}

# =============================================================================
# Dry-Run Tests
# =============================================================================

test_dry_run_writes_nothing() {
    rm -rf "$DEST_DIR"
    local output
    output=$(run_patch --dry-run)
    assert_contains "$output" "[DRY-RUN]" "Dry run is labelled"
    assert_not_exists "$DEST_DIR" "Dry run creates no destination directory"
}

# =============================================================================
# Patch Output Tests (run against every available JSON backend)
# =============================================================================

test_patch_output() {
    local backend="$1"
    rm -rf "$DEST_DIR"

    PATCH_JSON_TOOL="$backend" run_patch --quiet >/dev/null

    assert_file_exists "$DEST_DIR/manifest.json" "[$backend] manifest.json copied"
    assert_file_exists "$DEST_DIR/tabbind.js" "[$backend] tabbind.js written"
    assert_file_exists "$DEST_DIR/service-worker-loader.js" "[$backend] original worker preserved"
    assert_not_exists "$DEST_DIR/_metadata" "[$backend] _metadata removed"

    assert_equals "tabbind.js" \
        "$(json_value "$DEST_DIR/manifest.json" "background.service_worker")" \
        "[$backend] service_worker points at the wrapper"
    assert_equals "module" \
        "$(json_value "$DEST_DIR/manifest.json" "background.type")" \
        "[$backend] background.type is module"
    assert_equals "" \
        "$(json_value "$DEST_DIR/manifest.json" "update_url")" \
        "[$backend] update_url removed"
    assert_equals "MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8TESTKEY" \
        "$(json_value "$DEST_DIR/manifest.json" "key")" \
        "[$backend] key preserved (extension ID is stable)"
    assert_equals "1.0.84" \
        "$(json_value "$DEST_DIR/manifest.json" "version")" \
        "[$backend] version untouched"

    local wrapper
    wrapper=$(cat "$DEST_DIR/tabbind.js")
    assert_contains "$wrapper" "import './service-worker-loader.js';" \
        "[$backend] wrapper imports the original worker by its manifest name"
    assert_contains "$wrapper" "chrome.tabs.onActivated" \
        "[$backend] wrapper listens for tab activation"
    assert_contains "$wrapper" "chrome.runtime.onStartup" \
        "[$backend] wrapper re-binds on browser start"
    assert_contains "$wrapper" "targetTabId" \
        "[$backend] wrapper writes the targetTabId key"

    assert_equals "1.0.84" \
        "$(json_value "$DEST_DIR/patch-info.json" "extensionVersion")" \
        "[$backend] patch-info records the source version"
}

test_repatch_is_idempotent() {
    rm -rf "$DEST_DIR"
    run_patch --quiet >/dev/null
    local first
    first=$(cat "$DEST_DIR/tabbind.js")

    run_patch --quiet >/dev/null
    assert_equals "$first" "$(cat "$DEST_DIR/tabbind.js")" \
        "Re-running the patch over an existing copy produces the same wrapper"
    assert_equals "tabbind.js" \
        "$(json_value "$DEST_DIR/manifest.json" "background.service_worker")" \
        "Re-running does not double-wrap the worker"
}

test_patched_copy_is_rejected_as_source() {
    rm -rf "$DEST_DIR"
    run_patch --quiet >/dev/null

    local code=0 output
    output=$("$PATCH_SCRIPT" --source "$DEST_DIR" --dest "$TEST_TMP_DIR/twice" 2>&1) || code=$?
    assert_exit_code "1" "$code" "Using an already-patched copy as source exits 1"
    assert_contains "$output" "already patched" "Error explains the copy is already patched"
}

test_refuses_to_delete_non_extension_dest() {
    local junk="$TEST_TMP_DIR/junk"
    mkdir -p "$junk"
    echo "important" >"$junk/notes.txt"

    local code=0
    "$PATCH_SCRIPT" --source "$FIXTURE_DIR" --dest "$junk" >/dev/null 2>&1 || code=$?
    assert_exit_code "1" "$code" "Refuses a destination that is not an extension"
    assert_file_exists "$junk/notes.txt" "Non-extension destination left untouched"
}

# =============================================================================
# Version Selection / Check / Uninstall Tests
# =============================================================================

test_picks_highest_version() {
    rm -rf "$DEST_DIR"
    local output
    output=$("$PATCH_SCRIPT" \
        --source "$TEST_TMP_DIR/store/fcoeoabgfenejglbffodgkkbkcdhcgfn/1.0.84_0" \
        --dest "$DEST_DIR" --dry-run)
    assert_contains "$output" "1.0.84" "Explicit source reports its own version"

    # 1.0.84_0 must sort above 1.0.9_0 (numeric, not lexicographic)
    ((TESTS_RUN++)) || true
    local key_84 key_9
    key_84=$(printf '%s' "1.0.84_0" | tr '_' '.' | awk -F. '{printf "%05d%05d%05d%05d", $1+0, $2+0, $3+0, $4+0}')
    key_9=$(printf '%s' "1.0.9_0" | tr '_' '.' | awk -F. '{printf "%05d%05d%05d%05d", $1+0, $2+0, $3+0, $4+0}')
    if [[ "$key_84" > "$key_9" ]]; then
        ((TESTS_PASSED++)) || true
        echo -e "${GREEN}PASS${NC}: Version 1.0.84 sorts above 1.0.9"
    else
        ((TESTS_FAILED++)) || true
        echo -e "${RED}FAIL${NC}: Version 1.0.84 should sort above 1.0.9"
    fi
}

test_check_reports_up_to_date() {
    rm -rf "$DEST_DIR"
    run_patch --quiet >/dev/null

    local code=0 output
    output=$("$PATCH_SCRIPT" --source "$FIXTURE_DIR" --dest "$DEST_DIR" --check 2>&1) || code=$?
    assert_exit_code "0" "$code" "--check exits 0 when the patched copy matches"
    assert_contains "$output" "up to date" "--check says the copy is up to date"
}

test_check_detects_drift() {
    rm -rf "$DEST_DIR"
    run_patch --quiet >/dev/null

    # Simulate the store copy updating underneath the patched copy
    local newer="$TEST_TMP_DIR/store/fcoeoabgfenejglbffodgkkbkcdhcgfn/1.0.85_0"
    mkdir -p "$newer"
    sed 's/1\.0\.84/1.0.85/' "$FIXTURE_DIR/manifest.json" >"$newer/manifest.json"
    cp "$FIXTURE_DIR/service-worker-loader.js" "$newer/"

    local code=0 output
    output=$("$PATCH_SCRIPT" --source "$newer" --dest "$DEST_DIR" --check 2>&1) || code=$?
    assert_exit_code "1" "$code" "--check exits 1 when the store copy is newer"
    assert_contains "$output" "stale" "--check says the copy is stale"
}

test_check_without_patched_copy() {
    local code=0
    "$PATCH_SCRIPT" --source "$FIXTURE_DIR" --dest "$TEST_TMP_DIR/absent" --check >/dev/null 2>&1 || code=$?
    assert_exit_code "1" "$code" "--check exits 1 when there is no patched copy"
}

test_uninstall_removes_patched_copy() {
    rm -rf "$DEST_DIR"
    run_patch --quiet >/dev/null

    "$PATCH_SCRIPT" --dest "$DEST_DIR" --uninstall --quiet >/dev/null
    assert_not_exists "$DEST_DIR" "--uninstall removes the patched copy"
}

test_uninstall_refuses_non_extension_dir() {
    local junk="$TEST_TMP_DIR/junk2"
    mkdir -p "$junk"
    echo "important" >"$junk/notes.txt"

    local code=0
    "$PATCH_SCRIPT" --dest "$junk" --uninstall >/dev/null 2>&1 || code=$?
    assert_exit_code "1" "$code" "--uninstall refuses a non-extension directory"
    assert_file_exists "$junk/notes.txt" "Non-extension directory left untouched"
}

# =============================================================================
# Test Runner
# =============================================================================

run_tests() {
    echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  Vivaldi Tab-Binding Patch Test Suite${NC}"
    echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"

    detect_json_backends
    echo "JSON backends under test: ${JSON_BACKENDS[*]}"
    setup_test_environment
    trap cleanup_test_environment EXIT

    echo -e "\n${BLUE}Running Script Sanity Tests...${NC}"
    test_script_exists_and_is_executable
    test_help_lists_options
    test_unknown_option_fails
    test_check_and_uninstall_are_exclusive
    test_missing_source_fails

    echo -e "\n${BLUE}Running Dry-Run Tests...${NC}"
    test_dry_run_writes_nothing

    echo -e "\n${BLUE}Running Patch Output Tests...${NC}"
    local backend
    for backend in "${JSON_BACKENDS[@]}"; do
        test_patch_output "$backend"
    done
    test_repatch_is_idempotent
    test_patched_copy_is_rejected_as_source
    test_refuses_to_delete_non_extension_dest

    echo -e "\n${BLUE}Running Version / Check / Uninstall Tests...${NC}"
    test_picks_highest_version
    test_check_reports_up_to_date
    test_check_detects_drift
    test_check_without_patched_copy
    test_uninstall_removes_patched_copy
    test_uninstall_refuses_non_extension_dir

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

run_tests
