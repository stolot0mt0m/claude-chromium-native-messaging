#!/bin/bash

# Claude Extension Tab-Binding Patch for Vivaldi (macOS/Linux)
#
# Builds a patched, unpacked copy of the Claude extension for Chromium forks
# that ignore chrome.sidePanel.setOptions() — Vivaldi (VB-120826), Arc, and
# friends. Those browsers can only load the panel from a static URL, which
# leaves the panel with no target tab and makes every message fail with
# "No active tab".
#
# See docs/vivaldi-tab-binding.md for the full analysis.
#
# Usage: ./patch-vivaldi.sh [OPTIONS]
# Run ./patch-vivaldi.sh --help for more information.

set -euo pipefail

# =============================================================================
# Constants
# =============================================================================

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}")"
readonly VERSION_FILE="$SCRIPT_DIR/VERSION"

readonly CLAUDE_OFFICIAL_EXTENSION_ID="fcoeoabgfenejglbffodgkkbkcdhcgfn"

# Name of the wrapper service worker written into the patched copy
readonly WRAPPER_WORKER="tabbind.js"

# Metadata file recorded in the patched copy (used by --check)
readonly PATCH_INFO="patch-info.json"

# Query string the panel must be opened with (see docs/vivaldi-tab-binding.md)
readonly PANEL_QUERY="?mode=window&sessionId=vivaldi-panel"

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# =============================================================================
# Global State
# =============================================================================

BROWSER="vivaldi"
PROFILE="Default"
EXTENSION_ID="$CLAUDE_OFFICIAL_EXTENSION_ID"
SOURCE_DIR=""
DEST_DIR="$HOME/claude-vivaldi-patched"
CHECK_MODE=false
UNINSTALL_MODE=false
DRY_RUN=false
VERBOSE=false
QUIET=false
OS=""
JSON_TOOL=""
EXT_VERSION=""

# =============================================================================
# Utility Functions
# =============================================================================

get_version() {
    if [[ -f "$VERSION_FILE" ]]; then
        cat "$VERSION_FILE"
    else
        echo "unknown"
    fi
}

print_header() {
    if [[ "$QUIET" == true ]]; then return; fi
    echo ""
    echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║  Claude Extension Tab-Binding Patch (Vivaldi / Arc)        ║${NC}"
    echo -e "${BLUE}║  Version: $(get_version)                                            ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

print_success() {
    if [[ "$QUIET" == true ]]; then return; fi
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}" >&2
}

print_warning() {
    if [[ "$QUIET" == true ]]; then return; fi
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_info() {
    if [[ "$QUIET" == true ]]; then return; fi
    echo -e "${BLUE}ℹ $1${NC}"
}

print_verbose() {
    if [[ "$VERBOSE" == true ]]; then
        echo -e "${BLUE}  → $1${NC}"
    fi
}

print_dry_run() {
    echo -e "${YELLOW}[DRY-RUN] $1${NC}"
}

show_help() {
    cat <<EOF
Claude Extension Tab-Binding Patch v$(get_version)

Builds a patched, unpacked copy of the Claude extension so that the side panel
can resolve a target tab in browsers that ignore chrome.sidePanel.setOptions().

Without this patch the panel renders but every message fails with
"No active tab" (see docs/vivaldi-tab-binding.md).

USAGE:
    ./${SCRIPT_NAME} [OPTIONS]

OPTIONS:
    -b, --browser NAME     Browser to read the store copy from.
                           One of: vivaldi, vivaldi-snapshot, arc, brave,
                           chrome, chromium (default: vivaldi)
    -p, --profile NAME     Browser profile directory (default: Default)
    -s, --source DIR       Read the unpatched extension from DIR instead of
                           auto-detecting. DIR is the versioned extension
                           folder containing manifest.json.
    -d, --dest DIR         Where to write the patched copy
                           (default: ~/claude-vivaldi-patched)
    -e, --extension-id ID  Extension ID to patch
                           (default: ${CLAUDE_OFFICIAL_EXTENSION_ID})
    -c, --check            Report whether the patched copy is up to date with
                           the installed store copy, then exit.
                           Exit 0 = up to date, 1 = stale or missing.
    -u, --uninstall        Remove the patched copy
    -n, --dry-run          Show what would happen without writing anything
    -v, --verbose          Verbose output
    -q, --quiet            Suppress non-error output
    -h, --help             Show this help
        --version          Show version

EXAMPLES:
    # Patch the Vivaldi copy of the extension
    ./${SCRIPT_NAME}

    # Preview without writing
    ./${SCRIPT_NAME} --dry-run

    # Has the store copy updated since the last patch?
    ./${SCRIPT_NAME} --check

    # Patch a copy installed in a non-default profile
    ./${SCRIPT_NAME} --profile "Profile 1"

    # Remove the patched copy
    ./${SCRIPT_NAME} --uninstall

AFTER PATCHING:
    The patched copy must be loaded manually, and the panel must be opened at

        chrome-extension://<id>/sidepanel.html${PANEL_QUERY}

    The query string is what lets the panel find its tab — a bare
    sidepanel.html URL still fails with "No active tab". The script prints the
    full instructions on success; see also the README section
    "Vivaldi: No active tab".
EOF
}

# =============================================================================
# Environment Detection
# =============================================================================

detect_os() {
    case "$(uname -s)" in
        Darwin) OS="macos" ;;
        Linux)  OS="linux" ;;
        *)
            print_error "Unsupported OS: $(uname -s)"
            print_info "Windows users: run patch-vivaldi.ps1 instead"
            return 1
            ;;
    esac
    print_verbose "Detected OS: $OS"
}

detect_json_tool() {
    # PATCH_JSON_TOOL forces a backend; the test suite uses it to exercise
    # both code paths on a machine that has python3 and jq installed.
    if [[ -n "${PATCH_JSON_TOOL:-}" ]]; then
        JSON_TOOL="$PATCH_JSON_TOOL"
        if ! command -v "$JSON_TOOL" &>/dev/null; then
            print_error "PATCH_JSON_TOOL=$JSON_TOOL is not installed"
            return 1
        fi
    elif command -v python3 &>/dev/null; then
        JSON_TOOL="python3"
    elif command -v jq &>/dev/null; then
        JSON_TOOL="jq"
    else
        print_error "Neither python3 nor jq found — one is required to edit manifest.json"
        print_info "Install with: brew install jq   (macOS)"
        print_info "              apt install jq    (Debian/Ubuntu)"
        return 1
    fi
    print_verbose "Using $JSON_TOOL for JSON editing"
}

# Directory that holds the per-extension folders for a browser profile.
get_extensions_root() {
    local browser="$1"
    local base=""

    if [[ "$OS" == "macos" ]]; then
        case "$browser" in
            vivaldi)          base="$HOME/Library/Application Support/Vivaldi" ;;
            vivaldi-snapshot) base="$HOME/Library/Application Support/Vivaldi Snapshot" ;;
            arc)              base="$HOME/Library/Application Support/Arc/User Data" ;;
            brave)            base="$HOME/Library/Application Support/BraveSoftware/Brave-Browser" ;;
            chrome)           base="$HOME/Library/Application Support/Google/Chrome" ;;
            chromium)         base="$HOME/Library/Application Support/Chromium" ;;
            *)
                print_error "Unknown browser: $browser"
                print_info "Use --source DIR to point at the extension folder directly"
                return 1
                ;;
        esac
    else
        case "$browser" in
            vivaldi)          base="$HOME/.config/vivaldi" ;;
            vivaldi-snapshot) base="$HOME/.config/vivaldi-snapshot" ;;
            brave)            base="$HOME/.config/BraveSoftware/Brave-Browser" ;;
            chrome)           base="$HOME/.config/google-chrome" ;;
            chromium)         base="$HOME/.config/chromium" ;;
            arc)
                print_error "Arc is not available on Linux"
                return 1
                ;;
            *)
                print_error "Unknown browser: $browser"
                print_info "Use --source DIR to point at the extension folder directly"
                return 1
                ;;
        esac
    fi

    echo "$base/$PROFILE/Extensions"
}

# Sortable numeric key for a Chrome extension version folder like "1.0.84_0"
version_key() {
    printf '%s' "$1" | tr '_' '.' | awk -F. '{printf "%05d%05d%05d%05d", $1+0, $2+0, $3+0, $4+0}'
}

# Highest-versioned folder under an extension directory that has a manifest.
find_latest_version_dir() {
    local ext_dir="$1"
    local dir name key best="" best_key=""

    for dir in "$ext_dir"/*/; do
        [[ -f "$dir/manifest.json" ]] || continue
        name="$(basename "$dir")"
        key="$(version_key "$name")"
        if [[ -z "$best_key" || "$key" > "$best_key" ]]; then
            best_key="$key"
            best="${dir%/}"
        fi
    done

    [[ -n "$best" ]] || return 1
    echo "$best"
}

resolve_source_dir() {
    if [[ -n "$SOURCE_DIR" ]]; then
        if [[ ! -f "$SOURCE_DIR/manifest.json" ]]; then
            print_error "No manifest.json in --source directory: $SOURCE_DIR"
            return 1
        fi
        print_verbose "Using explicit source: $SOURCE_DIR"
        return 0
    fi

    local ext_root
    ext_root="$(get_extensions_root "$BROWSER")" || return 1
    print_verbose "Extensions root: $ext_root"

    if [[ ! -d "$ext_root/$EXTENSION_ID" ]]; then
        print_error "Claude extension not found for $BROWSER (profile: $PROFILE)"
        print_info "Looked in: $ext_root/$EXTENSION_ID"
        print_info "Install the Claude extension from the Chrome Web Store first,"
        print_info "or pass --profile / --source to point at the right location."
        return 1
    fi

    if ! SOURCE_DIR="$(find_latest_version_dir "$ext_root/$EXTENSION_ID")"; then
        print_error "No versioned extension folder with a manifest.json in $ext_root/$EXTENSION_ID"
        return 1
    fi

    print_verbose "Source: $SOURCE_DIR"
}

# =============================================================================
# JSON Helpers
# =============================================================================

# json_field FILE DOTTED.PATH  → value, or empty string
json_field() {
    local file="$1" path="$2"

    if [[ "$JSON_TOOL" == "python3" ]]; then
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
print(node if not isinstance(node, (dict, list)) else "")
PY
    else
        jq -r --arg p "$path" 'getpath($p | split(".")) // "" | if type == "object" or type == "array" then "" else . end' \
            "$file" 2>/dev/null || true
    fi
}

# Rewrite the patched manifest: point the worker at the wrapper, make it a
# module, and drop update_url so the browser never tries to auto-update an
# unpacked extension.
rewrite_manifest() {
    local file="$1" worker="$2"

    if [[ "$JSON_TOOL" == "python3" ]]; then
        JSON_FILE="$file" JSON_WORKER="$worker" python3 - <<'PY'
import json, os
path = os.environ["JSON_FILE"]
with open(path) as fh:
    manifest = json.load(fh)
manifest.setdefault("background", {})
manifest["background"]["service_worker"] = os.environ["JSON_WORKER"]
manifest["background"]["type"] = "module"
manifest.pop("update_url", None)
with open(path, "w") as fh:
    json.dump(manifest, fh, indent=2)
    fh.write("\n")
PY
    else
        local tmp="$file.tmp"
        jq --arg w "$worker" \
            '.background.service_worker = $w | .background.type = "module" | del(.update_url)' \
            "$file" >"$tmp"
        mv "$tmp" "$file"
    fi
}

write_patch_info() {
    local file="$1"

    if [[ "$JSON_TOOL" == "python3" ]]; then
        JSON_FILE="$file" \
        INFO_SOURCE="$SOURCE_DIR" \
        INFO_VERSION="$EXT_VERSION" \
        INFO_BROWSER="$BROWSER" \
        INFO_PROFILE="$PROFILE" \
        INFO_EXT_ID="$EXTENSION_ID" \
        INFO_PATCHER="$(get_version)" \
        python3 - <<'PY'
import json, os
info = {
    "extensionId": os.environ["INFO_EXT_ID"],
    "extensionVersion": os.environ["INFO_VERSION"],
    "sourceDir": os.environ["INFO_SOURCE"],
    "browser": os.environ["INFO_BROWSER"],
    "profile": os.environ["INFO_PROFILE"],
    "patcherVersion": os.environ["INFO_PATCHER"],
}
with open(os.environ["JSON_FILE"], "w") as fh:
    json.dump(info, fh, indent=2)
    fh.write("\n")
PY
    else
        jq -n \
            --arg id "$EXTENSION_ID" \
            --arg version "$EXT_VERSION" \
            --arg source "$SOURCE_DIR" \
            --arg browser "$BROWSER" \
            --arg profile "$PROFILE" \
            --arg patcher "$(get_version)" \
            '{extensionId: $id, extensionVersion: $version, sourceDir: $source,
              browser: $browser, profile: $profile, patcherVersion: $patcher}' \
            >"$file"
    fi
}

# =============================================================================
# Patch Generation
# =============================================================================

# The wrapper service worker. MV3 allows exactly one service worker, so the
# wrapper imports the original untouched and appends listeners to it.
write_wrapper_worker() {
    local dest_file="$1" original_worker="$2"

    cat >"$dest_file" <<EOF
// Tab binding for the Claude extension in Chromium forks that ignore
// chrome.sidePanel.setOptions() — Vivaldi (VB-120826), Arc, and others.
//
// Generated by patch-vivaldi.sh. Do not edit by hand; re-run the script
// after the store copy updates.
//
// Chrome gives the panel its tab through the panel URL
// (sidepanel.html?tabId=N). Browsers that ignore setOptions() can only load
// a static URL, so the panel falls back to reading chrome.storage.local
// "targetTabId" when opened with ?mode=window. Nothing in the stock worker
// keeps that key current outside the scheduled-task launcher, so it is either
// missing or stale and every send throws "No active tab".
//
// This wrapper loads the original worker unmodified and adds the listeners
// needed to keep "targetTabId" pointing at the active web tab.

import './${original_worker}';

const TARGET_TAB_ID = 'targetTabId';

const isWebTab = (tab) =>
  !!tab && typeof tab.url === 'string' && /^https?:/i.test(tab.url);

const bind = async (tabId) => {
  try {
    const stored = await chrome.storage.local.get(TARGET_TAB_ID);
    if (stored[TARGET_TAB_ID] === tabId) return;
    await chrome.storage.local.set({ [TARGET_TAB_ID]: tabId });
  } catch {
    // Storage can be unavailable while the worker is shutting down.
  }
};

const bindIfWebTab = async (tabId) => {
  try {
    const tab = await chrome.tabs.get(tabId);
    if (isWebTab(tab)) await bind(tabId);
  } catch {
    // Tab closed between the event and the lookup.
  }
};

// Used on worker wake and window focus, when there is no event tab to use.
const bindActiveTab = async () => {
  try {
    let [tab] = await chrome.tabs.query({ active: true, lastFocusedWindow: true });
    if (!isWebTab(tab)) {
      [tab] = (await chrome.tabs.query({ active: true })).filter(isWebTab);
    }
    if (isWebTab(tab)) await bind(tab.id);
  } catch {
    // No windows open yet.
  }
};

chrome.tabs.onActivated.addListener(({ tabId }) => {
  void bindIfWebTab(tabId);
});

chrome.tabs.onUpdated.addListener((tabId, changeInfo, tab) => {
  if (tab.active && (changeInfo.status === 'complete' || changeInfo.url)) {
    void bindIfWebTab(tabId);
  }
});

chrome.windows.onFocusChanged.addListener((windowId) => {
  if (windowId !== chrome.windows.WINDOW_ID_NONE) void bindActiveTab();
});

// Tab IDs are regenerated on browser restart, so re-bind on every cold start
// rather than waiting for the first tab switch.
chrome.runtime.onStartup.addListener(() => {
  void bindActiveTab();
});
chrome.runtime.onInstalled.addListener(() => {
  void bindActiveTab();
});

void bindActiveTab();
EOF
}

do_patch() {
    resolve_source_dir || return 1
    detect_json_tool || return 1

    EXT_VERSION="$(json_field "$SOURCE_DIR/manifest.json" "version")"
    local original_worker
    original_worker="$(json_field "$SOURCE_DIR/manifest.json" "background.service_worker")"

    if [[ -z "$original_worker" ]]; then
        print_error "manifest.json has no background.service_worker — nothing to wrap"
        print_info "Manifest: $SOURCE_DIR/manifest.json"
        return 1
    fi

    if [[ "$original_worker" == "$WRAPPER_WORKER" ]]; then
        print_error "Source is already patched (service_worker is $WRAPPER_WORKER)"
        print_info "Point --source at the unmodified store copy."
        return 1
    fi

    print_info "Source:      $SOURCE_DIR"
    print_info "Version:     ${EXT_VERSION:-unknown}"
    print_info "Worker:      $original_worker"
    print_info "Destination: $DEST_DIR"
    echo ""

    if [[ "$DRY_RUN" == true ]]; then
        print_dry_run "Would remove existing $DEST_DIR"
        print_dry_run "Would copy $SOURCE_DIR → $DEST_DIR"
        print_dry_run "Would remove $DEST_DIR/_metadata"
        print_dry_run "Would write $DEST_DIR/$WRAPPER_WORKER importing ./$original_worker"
        print_dry_run "Would set background.service_worker=$WRAPPER_WORKER, background.type=module"
        print_dry_run "Would remove update_url from manifest.json"
        print_dry_run "Would write $DEST_DIR/$PATCH_INFO"
        echo ""
        print_info "Dry run complete — nothing was written"
        return 0
    fi

    if [[ -e "$DEST_DIR" ]]; then
        if [[ ! -d "$DEST_DIR" ]]; then
            print_error "Destination exists and is not a directory: $DEST_DIR"
            return 1
        fi
        if [[ ! -f "$DEST_DIR/manifest.json" ]]; then
            print_error "Destination exists but does not look like an extension: $DEST_DIR"
            print_info "Refusing to delete it. Choose another --dest or remove it yourself."
            return 1
        fi
        print_verbose "Removing previous patched copy: $DEST_DIR"
        rm -rf "$DEST_DIR"
    fi

    mkdir -p "$(dirname "$DEST_DIR")"
    cp -R "$SOURCE_DIR" "$DEST_DIR"
    print_success "Copied extension ($(du -sh "$DEST_DIR" | cut -f1) )"

    # _metadata holds Web Store signatures that do not apply to an unpacked copy
    rm -rf "$DEST_DIR/_metadata"

    write_wrapper_worker "$DEST_DIR/$WRAPPER_WORKER" "$original_worker"
    print_success "Wrote $WRAPPER_WORKER (wraps $original_worker)"

    rewrite_manifest "$DEST_DIR/manifest.json" "$WRAPPER_WORKER"
    print_success "Patched manifest.json"

    # "key" must survive so the unpacked copy keeps extension ID
    # $EXTENSION_ID and the native messaging manifests written by setup.sh
    # keep matching it.
    if [[ -z "$(json_field "$DEST_DIR/manifest.json" "key")" ]]; then
        print_warning "manifest.json has no \"key\" — the unpacked copy will get a different"
        print_warning "extension ID, and native messaging will need to be re-registered."
    fi

    write_patch_info "$DEST_DIR/$PATCH_INFO"
    print_verbose "Wrote $PATCH_INFO"

    echo ""
    print_next_steps
}

print_next_steps() {
    if [[ "$QUIET" == true ]]; then return; fi

    local browser_label="Vivaldi"
    [[ "$BROWSER" == "vivaldi" ]] || browser_label="$BROWSER"

    cat <<EOF
${GREEN}Patched copy ready:${NC} $DEST_DIR

Remaining steps have to be done in the browser:

  1. Open ${browser_label}'s extensions page (vivaldi://extensions) and
     ${YELLOW}disable${NC} — do not remove — the Web Store copy of Claude.
     Both copies claim ID ${EXTENSION_ID}, so leaving the store
     copy enabled causes a duplicate-ID error. Keeping it installed but
     disabled lets it keep auto-updating as the source for re-patching.

  2. Turn on ${YELLOW}Developer mode${NC}, click ${YELLOW}Load unpacked${NC}, and select:
       $DEST_DIR

  3. Add the panel with this URL — the query string is required:
       ${BLUE}chrome-extension://${EXTENSION_ID}/sidepanel.html${PANEL_QUERY}${NC}

     In Vivaldi: click ${YELLOW}+${NC} in the sidebar (Add Web Panel) and paste it.

Verify from the extension's service worker console:

    chrome.storage.local.get('targetTabId').then(console.log)

The value should change as you switch tabs. The panel reads it once, when the
panel document loads, so reload the panel to re-bind it to the current tab.

Re-run this script after the store copy updates:

    ./${SCRIPT_NAME} --check    # is the patched copy stale?
    ./${SCRIPT_NAME}            # rebuild it
EOF
}

# =============================================================================
# Check / Uninstall
# =============================================================================

do_check() {
    detect_json_tool || return 1

    if [[ ! -d "$DEST_DIR" ]]; then
        print_warning "No patched copy at $DEST_DIR"
        print_info "Run ./${SCRIPT_NAME} to create one"
        return 1
    fi

    local patched_version=""
    if [[ -f "$DEST_DIR/$PATCH_INFO" ]]; then
        patched_version="$(json_field "$DEST_DIR/$PATCH_INFO" "extensionVersion")"
    fi
    if [[ -z "$patched_version" ]]; then
        patched_version="$(json_field "$DEST_DIR/manifest.json" "version")"
    fi

    if ! resolve_source_dir; then
        print_warning "Patched copy is version ${patched_version:-unknown}, but the store copy could not be found"
        return 1
    fi

    local store_version
    store_version="$(json_field "$SOURCE_DIR/manifest.json" "version")"

    print_info "Store copy:   ${store_version:-unknown}  ($SOURCE_DIR)"
    print_info "Patched copy: ${patched_version:-unknown}  ($DEST_DIR)"

    if [[ -n "$store_version" && "$store_version" == "$patched_version" ]]; then
        print_success "Patched copy is up to date"
        return 0
    fi

    print_warning "Patched copy is stale — re-run ./${SCRIPT_NAME} to rebuild it"
    return 1
}

do_uninstall() {
    if [[ ! -d "$DEST_DIR" ]]; then
        print_info "Nothing to remove — no patched copy at $DEST_DIR"
        return 0
    fi

    if [[ ! -f "$DEST_DIR/manifest.json" ]]; then
        print_error "Refusing to remove $DEST_DIR — it does not look like an extension"
        return 1
    fi

    if [[ "$DRY_RUN" == true ]]; then
        print_dry_run "Would remove $DEST_DIR"
        return 0
    fi

    rm -rf "$DEST_DIR"
    print_success "Removed $DEST_DIR"
    print_info "Remember to remove the unpacked extension from the browser's"
    print_info "extensions page and re-enable the Web Store copy."
}

# =============================================================================
# Argument Parsing
# =============================================================================

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -b|--browser)
                [[ $# -ge 2 ]] || { print_error "--browser requires a value"; return 1; }
                BROWSER="$(printf '%s' "$2" | tr '[:upper:]' '[:lower:]')"
                shift 2
                ;;
            -p|--profile)
                [[ $# -ge 2 ]] || { print_error "--profile requires a value"; return 1; }
                PROFILE="$2"
                shift 2
                ;;
            -s|--source)
                [[ $# -ge 2 ]] || { print_error "--source requires a value"; return 1; }
                SOURCE_DIR="${2%/}"
                shift 2
                ;;
            -d|--dest)
                [[ $# -ge 2 ]] || { print_error "--dest requires a value"; return 1; }
                DEST_DIR="${2%/}"
                shift 2
                ;;
            -e|--extension-id)
                [[ $# -ge 2 ]] || { print_error "--extension-id requires a value"; return 1; }
                EXTENSION_ID="$2"
                shift 2
                ;;
            -c|--check)     CHECK_MODE=true; shift ;;
            -u|--uninstall) UNINSTALL_MODE=true; shift ;;
            -n|--dry-run)   DRY_RUN=true; shift ;;
            -v|--verbose)   VERBOSE=true; shift ;;
            -q|--quiet)     QUIET=true; shift ;;
            -h|--help)      show_help; exit 0 ;;
            --version)      get_version; exit 0 ;;
            *)
                print_error "Unknown option: $1"
                print_info "Run ./${SCRIPT_NAME} --help for usage"
                return 1
                ;;
        esac
    done

    if [[ "$CHECK_MODE" == true && "$UNINSTALL_MODE" == true ]]; then
        print_error "--check and --uninstall are mutually exclusive"
        return 1
    fi
}

# =============================================================================
# Main
# =============================================================================

main() {
    parse_args "$@" || exit 1

    if [[ "$CHECK_MODE" != true ]]; then
        print_header
    fi

    detect_os || exit 1

    if [[ "$UNINSTALL_MODE" == true ]]; then
        do_uninstall || exit 1
    elif [[ "$CHECK_MODE" == true ]]; then
        do_check || exit 1
    else
        do_patch || exit 1
    fi
}

# Only run main when executed, so tests can source this file
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
