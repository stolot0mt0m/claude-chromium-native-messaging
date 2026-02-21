#!/bin/bash

# Claude Native Messaging Setup for Chromium Browsers
# This script configures Native Messaging Host for Claude extension
# in alternative Chromium-based browsers.
#
# Usage: ./setup.sh [OPTIONS]
# Run ./setup.sh --help for more information.

set -euo pipefail

# =============================================================================
# Constants
# =============================================================================

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}")"
readonly VERSION_FILE="$SCRIPT_DIR/VERSION"
readonly CONFIG_FILE="$SCRIPT_DIR/config/browsers.json"

# Extension IDs with descriptions
readonly CLAUDE_OFFICIAL_EXTENSION_ID="fcoeoabgfenejglbffodgkkbkcdhcgfn"
readonly CLAUDE_DEV_EXTENSION_ID="dihbgbndebgnbjfmelmegjepbnkhlgni"
readonly CLAUDE_STAGING_EXTENSION_ID="dngcpimnedloihjnnfngkgjoidhnaolf"

# All allowed extension origins (official first)
readonly CLAUDE_EXTENSION_ORIGINS=(
    "chrome-extension://${CLAUDE_OFFICIAL_EXTENSION_ID}/"
    "chrome-extension://${CLAUDE_DEV_EXTENSION_ID}/"
    "chrome-extension://${CLAUDE_STAGING_EXTENSION_ID}/"
)

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# =============================================================================
# Global State
# =============================================================================

UNINSTALL_MODE=false
CUSTOM_PATH=""
DRY_RUN=false
VERBOSE=false
DEBUG=false
QUIET=false
BACKUP=false
OS=""

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
    echo -e "${BLUE}║  Claude Native Messaging Setup for Chromium Browsers       ║${NC}"
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

print_debug() {
    if [[ "$DEBUG" == true ]]; then
        echo -e "${BLUE}  [DEBUG] $1${NC}"
    fi
}

print_dry_run() {
    echo -e "${YELLOW}[DRY-RUN] $1${NC}"
}

# =============================================================================
# Validation Functions
# =============================================================================

check_bash_version() {
    local required_major=4
    local current_major="${BASH_VERSINFO[0]}"

    if [[ "$current_major" -lt "$required_major" ]]; then
        print_error "Bash ${required_major}.0+ required. Current: ${BASH_VERSION}"
        print_info "macOS users: Install newer Bash with 'brew install bash'"
        print_info "Then run with: /opt/homebrew/bin/bash $SCRIPT_NAME"
        exit 1
    fi
    print_verbose "Bash version ${BASH_VERSION} OK"
}

check_dependencies() {
    # Check for jq (optional but recommended for JSON parsing)
    if command -v jq &>/dev/null; then
        print_verbose "jq found - using JSON config"
        return 0
    else
        print_verbose "jq not found - using built-in config"
        return 1
    fi
}

validate_path() {
    local path="$1"

    # Path must be absolute (no relative paths)
    if [[ "$path" != /* ]]; then
        print_error "Custom browser path must be absolute: $path"
        return 1
    fi

    # Resolve the path (follow symlinks, normalize ./ and ../)
    local resolved_path
    if ! resolved_path="$(realpath -m "$path" 2>/dev/null)"; then
        print_error "Custom browser path does not exist: $path"
        return 1
    fi

    # Security: reject path traversal attempts (resolved path should not escape via ..)
    if [[ "$resolved_path" != "$path" ]] && [[ "$path" == *..* ]]; then
        print_error "Path traversal not allowed: $path"
        return 1
    fi

    # Check that the path actually exists as a directory
    if [[ ! -d "$resolved_path" ]]; then
        print_error "Custom browser path does not exist: $resolved_path"
        return 1
    fi

    # Check the directory is readable
    if [[ ! -r "$resolved_path" ]]; then
        print_error "Custom browser path is not readable: $resolved_path"
        return 1
    fi

    echo "$resolved_path"
}

# =============================================================================
# OS Detection
# =============================================================================

detect_os() {
    case "$(uname -s)" in
        Darwin*)    echo "macos";;
        Linux*)     echo "linux";;
        CYGWIN*|MINGW*|MSYS*) echo "windows";;
        *)          echo "unknown";;
    esac
}

get_app_support_base() {
    if [[ "$OS" == "macos" ]]; then
        echo "$HOME/Library/Application Support"
    elif [[ "$OS" == "linux" ]]; then
        echo "$HOME/.config"
    else
        echo ""
    fi
}

# =============================================================================
# Claude Path Detection
# =============================================================================

get_claude_native_host_path() {
    if [[ "$OS" == "macos" ]]; then
        local path="/Applications/Claude.app/Contents/Helpers/chrome-native-host"
        if [[ -f "$path" ]]; then
            echo "$path"
            return 0
        fi
    elif [[ "$OS" == "linux" ]]; then
        # Check multiple possible installation locations
        local paths=(
            "/opt/Claude/chrome-native-host"
            "/usr/lib/claude/chrome-native-host"
            "$HOME/.local/share/Claude/chrome-native-host"
            # Snap packages
            "/snap/claude/current/chrome-native-host"
            # Flatpak
            "$HOME/.var/app/ai.anthropic.claude/chrome-native-host"
        )
        for path in "${paths[@]}"; do
            if [[ -f "$path" ]]; then
                echo "$path"
                return 0
            fi
        done
    fi
    echo ""
}

get_claude_code_native_host_path() {
    echo "$HOME/.claude/chrome/chrome-native-host"
}

# =============================================================================
# Browser Configuration
# =============================================================================

# Built-in browser configurations (used when jq is not available)
# Format: "Name|macOS Path|Linux Path"
declare -a BUILTIN_BROWSER_CONFIGS=(
    "Brave|BraveSoftware/Brave-Browser|BraveSoftware/Brave-Browser"
    "Arc|Arc/User Data|"
    "Vivaldi|Vivaldi|vivaldi"
    "Microsoft Edge|Microsoft Edge|microsoft-edge"
    "Chromium|Chromium|chromium"
    "Google Chrome|Google/Chrome|google-chrome"
    "Google Chrome Canary|Google/Chrome Canary|google-chrome-unstable"
    "Google Chrome Beta|Google/Chrome Beta|google-chrome-beta"
    "Google Chrome Dev|Google/Chrome Dev|google-chrome-unstable"
    "Genspark|GensparkSoftware/Genspark-Browser|GensparkSoftware/Genspark-Browser"
    "Opera|com.operasoftware.Opera|opera"
    "Opera GX|com.operasoftware.OperaGX|opera-gx"
    "Sidekick|Sidekick|Sidekick"
    "Orion|Orion|Orion"
    "Yandex|Yandex/YandexBrowser|yandex-browser"
    "Naver Whale|Naver/Whale|naver-whale"
    "Coc Coc|CocCoc/Browser|coccoc"
    "Comodo Dragon|Comodo/Dragon|comodo-dragon"
    "Avast Secure Browser|AVAST Software/Browser|avast-secure-browser"
    "AVG Secure Browser|AVG/Browser|avg-secure-browser"
    "Epic Privacy Browser|Epic Privacy Browser|epic"
    "Torch|Torch|torch"
    "Slimjet|Slimjet|slimjet"
    "SRWare Iron|Chromium|iron"
    "Ungoogled Chromium|Chromium|ungoogled-chromium"
    "Helium|net.imput.helium|net.imput.helium"
    "Cent Browser|CentBrowser|cent-browser"
    "Maxthon|Maxthon|maxthon"
    "Iridium|Iridium|iridium-browser"
    "Falkon|falkon|falkon"
    "Colibri|Nickolabs/Colibri|colibri"
)

load_browser_configs_from_json() {
    if [[ ! -f "$CONFIG_FILE" ]]; then
        print_verbose "Config file not found: $CONFIG_FILE"
        return 1
    fi

    if ! command -v jq &>/dev/null; then
        return 1
    fi

    local os_key=""
    if [[ "$OS" == "macos" ]]; then
        os_key="macos"
    elif [[ "$OS" == "linux" ]]; then
        os_key="linux"
    else
        return 1
    fi

    # Parse JSON and output in our format
    jq -r --arg os "$os_key" '
        .browsers[] |
        select(.paths[$os] != null) |
        "\(.name)|\(.paths[$os])"
    ' "$CONFIG_FILE" 2>/dev/null
}

validate_browser_installation() {
    local browser_path="$1"
    local name="$2"

    # Directory must exist
    if [[ ! -d "$browser_path" ]]; then
        print_debug "Skipped $name: directory does not exist ($browser_path)"
        return 1
    fi

    # Directory must not be empty (catches leftover/stale directories)
    shopt -s nullglob
    local contents=("$browser_path"/*)
    shopt -u nullglob

    if [[ ${#contents[@]} -eq 0 ]]; then
        print_debug "Skipped $name: directory is empty ($browser_path)"
        return 1
    fi

    # Check for Chromium profile markers: Default/, Preferences, Local State
    # A real Chromium data dir has at least one of these
    if [[ -d "$browser_path/Default" ]] || \
       [[ -f "$browser_path/Preferences" ]] || \
       [[ -f "$browser_path/Local State" ]]; then
        return 0
    fi

    # Check for numbered profiles (Profile 1, Profile 2, etc.)
    shopt -s nullglob
    local profiles=("$browser_path"/Profile\ *)
    shopt -u nullglob

    if [[ ${#profiles[@]} -gt 0 ]]; then
        return 0
    fi

    print_debug "Skipped $name: no browser profile data found ($browser_path)"
    return 1
}

detect_browsers() {
    local base_path
    base_path=$(get_app_support_base)
    local detected=()
    local skipped_count=0

    # Try to load from JSON config first
    local use_json=false
    local json_configs=()

    if command -v jq &>/dev/null && [[ -f "$CONFIG_FILE" ]]; then
        while IFS= read -r line; do
            [[ -n "$line" ]] && json_configs+=("$line")
        done < <(load_browser_configs_from_json)

        if [[ ${#json_configs[@]} -gt 0 ]]; then
            use_json=true
            print_verbose "Loaded ${#json_configs[@]} browser configs from JSON"
        fi
    fi

    if [[ "$use_json" == true ]]; then
        for config in "${json_configs[@]}"; do
            IFS='|' read -r name browser_path <<< "$config"
            local full_path="$base_path/$browser_path"

            if validate_browser_installation "$full_path" "$name"; then
                detected+=("$name|$full_path")
                print_verbose "Found: $name at $full_path"
            else
                ((skipped_count++)) || true
            fi
        done
    else
        print_verbose "Using built-in browser configurations"
        for config in "${BUILTIN_BROWSER_CONFIGS[@]}"; do
            IFS='|' read -r name macos_path linux_path <<< "$config"

            local browser_path=""
            if [[ "$OS" == "macos" ]]; then
                browser_path="$macos_path"
            elif [[ "$OS" == "linux" ]]; then
                browser_path="$linux_path"
            fi

            [[ -z "$browser_path" ]] && continue

            local full_path="$base_path/$browser_path"
            if validate_browser_installation "$full_path" "$name"; then
                detected+=("$name|$full_path")
                print_verbose "Found: $name at $full_path"
            else
                ((skipped_count++)) || true
            fi
        done
    fi

    if [[ "$skipped_count" -gt 0 ]]; then
        print_verbose "Skipped $skipped_count browser(s) without valid installation"
    fi

    if [[ ${#detected[@]} -gt 0 ]]; then
        printf '%s\n' "${detected[@]}"
    fi
}

# =============================================================================
# Extension Detection
# =============================================================================

check_extension_installed() {
    local browser_path="$1"
    local extensions_path="$browser_path/Default/Extensions/$CLAUDE_OFFICIAL_EXTENSION_ID"

    if [[ -d "$extensions_path" ]]; then
        return 0
    fi

    # Check other profiles (using nullglob to handle no matches)
    shopt -s nullglob
    local profile_dirs=("$browser_path"/Profile*/Extensions/"$CLAUDE_OFFICIAL_EXTENSION_ID")
    shopt -u nullglob

    if [[ ${#profile_dirs[@]} -gt 0 ]]; then
        return 0
    fi

    return 1
}

# =============================================================================
# Backup Functions
# =============================================================================

create_backup() {
    local file="$1"

    if [[ ! -f "$file" ]]; then
        return 0
    fi

    local backup_file="${file}.backup.$(date +%Y%m%d_%H%M%S)"

    if [[ "$DRY_RUN" == true ]]; then
        print_dry_run "Would create backup: $backup_file"
        return 0
    fi

    if cp "$file" "$backup_file"; then
        print_verbose "Created backup: $backup_file"
        return 0
    else
        print_error "Failed to create backup: $backup_file"
        return 1
    fi
}

# =============================================================================
# Manifest Creation
# =============================================================================

create_manifests() {
    local browser_path="$1"
    local native_host_path="$2"
    local code_native_host_path="$3"

    local nmh_dir="$browser_path/NativeMessagingHosts"
    local desktop_manifest="$nmh_dir/com.anthropic.claude_browser_extension.json"
    local code_manifest="$nmh_dir/com.anthropic.claude_code_browser_extension.json"

    # Check for existing files and prompt for overwrite
    if [[ -f "$desktop_manifest" ]] && [[ "$BACKUP" == false ]] && [[ "$DRY_RUN" == false ]]; then
        print_warning "Manifest already exists: $desktop_manifest"
        read -p "Overwrite? [y/N] " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_info "Skipped (use --backup to auto-backup existing files)"
            return 1
        fi
    fi

    # Create backups if requested
    if [[ "$BACKUP" == true ]]; then
        create_backup "$desktop_manifest"
        create_backup "$code_manifest"
    fi

    # Build allowed_origins array as JSON
    local origins_json=""
    for origin in "${CLAUDE_EXTENSION_ORIGINS[@]}"; do
        if [[ -n "$origins_json" ]]; then
            origins_json="$origins_json,"
        fi
        origins_json="$origins_json
    \"$origin\""
    done

    # Prepare desktop manifest content
    local desktop_content
    desktop_content=$(cat << EOF
{
  "name": "com.anthropic.claude_browser_extension",
  "description": "Claude Browser Extension Native Host",
  "path": "$native_host_path",
  "type": "stdio",
  "allowed_origins": [$origins_json
  ]
}
EOF
)

    if [[ "$DRY_RUN" == true ]]; then
        print_dry_run "Would create directory: $nmh_dir"
        print_dry_run "Would create file: $desktop_manifest"
        print_verbose "Content:\n$desktop_content"

        if [[ -f "$code_native_host_path" ]]; then
            print_dry_run "Would create file: $code_manifest"
        fi
        return 0
    fi

    # Create directory
    if ! mkdir -p "$nmh_dir"; then
        print_error "Failed to create directory: $nmh_dir"
        return 1
    fi

    # Use temp file for atomic creation
    local temp_file
    temp_file=$(mktemp) || {
        print_error "Failed to create temp file"
        return 1
    }
    trap "rm -f '$temp_file'" RETURN

    # Write desktop manifest
    echo "$desktop_content" > "$temp_file"
    if ! mv "$temp_file" "$desktop_manifest"; then
        print_error "Failed to create manifest: $desktop_manifest"
        return 1
    fi
    chmod 644 "$desktop_manifest"

    # Create Claude Code manifest (only if Claude Code native host exists)
    local code_created=false
    if [[ -f "$code_native_host_path" ]]; then
        temp_file=$(mktemp) || {
            print_error "Failed to create temp file"
            return 1
        }

        cat > "$temp_file" << EOF
{
  "name": "com.anthropic.claude_code_browser_extension",
  "description": "Claude Code Browser Extension Native Host",
  "path": "$code_native_host_path",
  "type": "stdio",
  "allowed_origins": [
    "chrome-extension://$CLAUDE_OFFICIAL_EXTENSION_ID/"
  ]
}
EOF

        if mv "$temp_file" "$code_manifest"; then
            chmod 644 "$code_manifest"
            code_created=true
        else
            print_error "Failed to create manifest: $code_manifest"
        fi
    fi

    if [[ "$code_created" == true ]]; then
        return 0
    else
        return 2  # Partial success (desktop only)
    fi
}

# =============================================================================
# Uninstall Function
# =============================================================================

uninstall() {
    local browser_path="$1"
    local nmh_dir="$browser_path/NativeMessagingHosts"
    local desktop_manifest="$nmh_dir/com.anthropic.claude_browser_extension.json"
    local code_manifest="$nmh_dir/com.anthropic.claude_code_browser_extension.json"

    if [[ "$DRY_RUN" == true ]]; then
        [[ -f "$desktop_manifest" ]] && print_dry_run "Would remove: $desktop_manifest"
        [[ -f "$code_manifest" ]] && print_dry_run "Would remove: $code_manifest"
        return 0
    fi

    if [[ -f "$desktop_manifest" ]]; then
        if [[ "$BACKUP" == true ]]; then
            create_backup "$desktop_manifest"
        fi
        rm "$desktop_manifest"
        print_success "Removed claude_browser_extension manifest"
    fi

    if [[ -f "$code_manifest" ]]; then
        if [[ "$BACKUP" == true ]]; then
            create_backup "$code_manifest"
        fi
        rm "$code_manifest"
        print_success "Removed claude_code_browser_extension manifest"
    fi

    # Remove directory if empty
    if [[ -d "$nmh_dir" ]]; then
        shopt -s nullglob
        local remaining_files=("$nmh_dir"/*)
        shopt -u nullglob

        if [[ ${#remaining_files[@]} -eq 0 ]]; then
            rmdir "$nmh_dir"
            print_success "Removed empty NativeMessagingHosts directory"
        fi
    fi
}

# =============================================================================
# Verification
# =============================================================================

verify_installation() {
    local browser_path="$1"
    local nmh_dir="$browser_path/NativeMessagingHosts"
    local success=true

    if [[ "$DRY_RUN" == true ]]; then
        print_dry_run "Would verify installation in: $nmh_dir"
        return 0
    fi

    if [[ -f "$nmh_dir/com.anthropic.claude_browser_extension.json" ]]; then
        print_success "Claude Desktop manifest exists"
    else
        print_error "Claude Desktop manifest missing"
        success=false
    fi

    if [[ -f "$nmh_dir/com.anthropic.claude_code_browser_extension.json" ]]; then
        print_success "Claude Code manifest exists"
    else
        print_warning "Claude Code manifest missing (Claude Code may not be installed)"
    fi

    $success
}

# =============================================================================
# Help and Usage
# =============================================================================

show_help() {
    cat << EOF
Claude Native Messaging Setup for Chromium Browsers

USAGE:
    $SCRIPT_NAME [OPTIONS]

OPTIONS:
    -u, --uninstall     Remove Claude native messaging configuration
    -p, --path PATH     Specify custom browser data directory (absolute path).
                        Use this for browsers not auto-detected or installed
                        in non-standard locations. The path must exist and
                        be readable.
    -n, --dry-run       Show what would be done without making changes
    -v, --verbose       Enable verbose output
    -d, --debug         Show all checked browser paths (including skipped)
    -q, --quiet         Suppress non-error output
    -b, --backup        Create backups before overwriting existing files
    -V, --version       Show version information
    -h, --help          Show this help message

EXAMPLES:
    # Interactive setup
    $SCRIPT_NAME

    # Preview changes without making them
    $SCRIPT_NAME --dry-run

    # Setup with automatic backups
    $SCRIPT_NAME --backup

    # Setup for a custom browser path
    $SCRIPT_NAME --path "/path/to/browser/data"

    # Show all checked paths for troubleshooting
    $SCRIPT_NAME --debug

    # Uninstall with verbose output
    $SCRIPT_NAME --uninstall --verbose

SUPPORTED BROWSERS:
    Brave, Arc, Vivaldi, Microsoft Edge, Chromium, Google Chrome,
    Google Chrome Canary, Opera, Opera GX, Genspark, Sidekick,
    Yandex, Naver Whale, and many more Chromium-based browsers.

For more information, see: https://github.com/stolot0mt0m/claude-chromium-native-messaging
EOF
}

show_version() {
    echo "Claude Native Messaging Setup v$(get_version)"
}

# =============================================================================
# Main Function
# =============================================================================

main() {
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --uninstall|-u)
                UNINSTALL_MODE=true
                shift
                ;;
            --path|-p)
                if [[ -z "${2:-}" ]]; then
                    print_error "Option $1 requires an argument"
                    exit 1
                fi
                CUSTOM_PATH="$2"
                shift 2
                ;;
            --dry-run|-n)
                DRY_RUN=true
                shift
                ;;
            --verbose|-v)
                VERBOSE=true
                shift
                ;;
            --debug|-d)
                DEBUG=true
                VERBOSE=true
                shift
                ;;
            --quiet|-q)
                QUIET=true
                shift
                ;;
            --backup|-b)
                BACKUP=true
                shift
                ;;
            --version|-V)
                show_version
                exit 0
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            *)
                print_error "Unknown option: $1"
                echo "Run '$SCRIPT_NAME --help' for usage information."
                exit 1
                ;;
        esac
    done

    # Check Bash version first
    check_bash_version

    # Detect OS
    OS=$(detect_os)

    # Check for Windows (redirect to PowerShell)
    if [[ "$OS" == "windows" ]]; then
        print_error "Please use setup.ps1 for Windows"
        print_info "Run: powershell -ExecutionPolicy Bypass -File setup.ps1"
        exit 1
    fi

    print_header

    # Check OS
    if [[ "$OS" == "unknown" ]]; then
        print_error "Unsupported operating system"
        exit 1
    fi
    print_info "Detected OS: $OS"

    if [[ "$DRY_RUN" == true ]]; then
        print_warning "DRY-RUN MODE: No changes will be made"
        echo ""
    fi

    # Check Claude native host
    local native_host_path
    native_host_path=$(get_claude_native_host_path)
    if [[ -z "$native_host_path" ]]; then
        print_error "Claude Desktop not found. Please install Claude Desktop first."
        print_info "Download from: https://claude.ai/download"
        exit 1
    fi
    print_success "Found Claude Desktop native host: $native_host_path"

    local code_native_host_path
    code_native_host_path=$(get_claude_code_native_host_path)
    if [[ -f "$code_native_host_path" ]]; then
        print_success "Found Claude Code native host: $code_native_host_path"
    else
        print_warning "Claude Code native host not found (optional)"
    fi

    echo ""

    # Handle custom path
    if [[ -n "$CUSTOM_PATH" ]]; then
        # Validate the custom path
        local validated_path
        if ! validated_path=$(validate_path "$CUSTOM_PATH"); then
            exit 1
        fi

        if [[ ! -d "$validated_path" ]]; then
            print_error "Specified path does not exist: $validated_path"
            exit 1
        fi

        if [[ "$UNINSTALL_MODE" == true ]]; then
            print_info "Uninstalling from: $validated_path"
            uninstall "$validated_path"
        else
            print_info "Installing to: $validated_path"
            create_manifests "$validated_path" "$native_host_path" "$code_native_host_path"
            echo ""
            verify_installation "$validated_path"
        fi

        echo ""
        print_info "Please restart your browser for changes to take effect."
        exit 0
    fi

    # Detect browsers
    print_info "Scanning for Chromium-based browsers..."
    echo ""

    local browsers=()
    while IFS= read -r line; do
        [[ -n "$line" ]] && browsers+=("$line")
    done < <(detect_browsers)

    if [[ ${#browsers[@]} -eq 0 ]]; then
        print_error "No supported Chromium browsers found."
        print_info "You can specify a custom path with: $SCRIPT_NAME --path /path/to/browser/data"
        exit 1
    fi

    # Display found browsers
    echo "Found browsers:"
    echo ""

    local i=1
    for browser in "${browsers[@]}"; do
        IFS='|' read -r name path <<< "$browser"

        local extension_status=""
        if check_extension_installed "$path"; then
            extension_status="${GREEN}[Extension installed]${NC}"
        else
            extension_status="${YELLOW}[Extension not found]${NC}"
        fi

        echo -e "  $i) $name $extension_status"
        echo -e "     ${BLUE}$path${NC}"
        echo ""
        ((i++)) || true
    done

    # Prompt user for selection
    echo -n "Select browser(s) to configure (comma-separated, or 'all'): "
    read -r selection

    if [[ -z "$selection" ]]; then
        print_error "No selection made. Exiting."
        exit 1
    fi

    local selected_indices=()
    if [[ "$selection" == "all" ]]; then
        for ((j=1; j<=${#browsers[@]}; j++)); do
            selected_indices+=("$j")
        done
    else
        IFS=',' read -ra selected_indices <<< "$selection"
    fi

    echo ""

    # Process selected browsers
    for idx in "${selected_indices[@]}"; do
        idx=$(echo "$idx" | tr -d ' ')

        if [[ ! "$idx" =~ ^[0-9]+$ ]] || [[ "$idx" -lt 1 ]] || [[ "$idx" -gt ${#browsers[@]} ]]; then
            print_warning "Invalid selection: $idx (skipping)"
            continue
        fi

        IFS='|' read -r name path <<< "${browsers[$((idx-1))]}"

        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        print_info "Processing: $name"

        if [[ "$UNINSTALL_MODE" == true ]]; then
            uninstall "$path"
            print_success "Uninstalled from $name"
        else
            local result=0
            create_manifests "$path" "$native_host_path" "$code_native_host_path" || result=$?

            case $result in
                0) print_success "Created all manifests for $name" ;;
                1) print_warning "Skipped $name" ;;
                2) print_warning "Created Claude Desktop manifest only (Claude Code not installed)" ;;
            esac

            if [[ $result -ne 1 ]]; then
                verify_installation "$path"
            fi
        fi
        echo ""
    done

    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    print_success "Setup complete!"
    echo ""
    print_info "Next steps:"
    echo "  1. Completely quit your browser (check Activity Monitor/Task Manager)"
    echo "  2. Restart the browser"
    echo "  3. Open the Claude extension in the side panel"
    echo "  4. For Claude Code: Run '/chrome' in your terminal"
    echo ""
}

# Run main function
main "$@"
