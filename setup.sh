#!/bin/bash

# Claude Native Messaging Setup for Chromium Browsers
# This script configures Native Messaging Host for Claude extension
# in alternative Chromium-based browsers.

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Extension IDs
CLAUDE_EXTENSION_IDS=(
    "chrome-extension://fcoeoabgfenejglbffodgkkbkcdhcgfn/"
    "chrome-extension://dihbgbndebgnbjfmelmegjepbnkhlgni/"
    "chrome-extension://dngcpimnedloihjnnfngkgjoidhnaolf/"
)

# Primary extension ID (official Claude extension)
PRIMARY_EXTENSION_ID="fcoeoabgfenejglbffodgkkbkcdhcgfn"

print_header() {
    echo ""
    echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║  Claude Native Messaging Setup for Chromium Browsers       ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

# Detect OS
detect_os() {
    case "$(uname -s)" in
        Darwin*)    echo "macos";;
        Linux*)     echo "linux";;
        CYGWIN*|MINGW*|MSYS*) echo "windows";;
        *)          echo "unknown";;
    esac
}

OS=$(detect_os)

# Browser configurations: "Name|macOS Path|Linux Path"
declare -a BROWSER_CONFIGS=(
    "Brave|BraveSoftware/Brave-Browser|BraveSoftware/Brave-Browser"
    "Arc|Arc/User Data|Arc/User Data"
    "Vivaldi|Vivaldi|vivaldi"
    "Microsoft Edge|Microsoft Edge|microsoft-edge"
    "Chromium|Chromium|chromium"
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
    "Cent Browser|CentBrowser|cent-browser"
    "Maxthon|Maxthon|maxthon"
    "Iridium|Iridium|iridium-browser"
    "Falkon|falkon|falkon"
    "Colibri|Nickolabs/Colibri|colibri"
)

# Get Application Support base path
get_app_support_base() {
    if [[ "$OS" == "macos" ]]; then
        echo "$HOME/Library/Application Support"
    elif [[ "$OS" == "linux" ]]; then
        echo "$HOME/.config"
    else
        echo ""
    fi
}

# Get Claude native host path
get_claude_native_host_path() {
    if [[ "$OS" == "macos" ]]; then
        echo "/Applications/Claude.app/Contents/Helpers/chrome-native-host"
    elif [[ "$OS" == "linux" ]]; then
        # Linux paths vary - check common locations
        local paths=(
            "/opt/Claude/chrome-native-host"
            "/usr/lib/claude/chrome-native-host"
            "$HOME/.local/share/Claude/chrome-native-host"
        )
        for path in "${paths[@]}"; do
            if [[ -f "$path" ]]; then
                echo "$path"
                return
            fi
        done
        echo ""
    fi
}

# Get Claude Code native host path
get_claude_code_native_host_path() {
    echo "$HOME/.claude/chrome/chrome-native-host"
}

# Detect installed browsers
detect_browsers() {
    local base_path=$(get_app_support_base)
    local detected=()
    
    for config in "${BROWSER_CONFIGS[@]}"; do
        IFS='|' read -r name macos_path linux_path <<< "$config"
        
        local browser_path=""
        if [[ "$OS" == "macos" ]]; then
            browser_path="$base_path/$macos_path"
        elif [[ "$OS" == "linux" ]]; then
            browser_path="$base_path/$linux_path"
        fi
        
        if [[ -d "$browser_path" ]]; then
            detected+=("$name|$browser_path")
        fi
    done
    
    printf '%s\n' "${detected[@]}"
}

# Check if Claude extension is installed in browser
check_extension_installed() {
    local browser_path="$1"
    local extensions_path="$browser_path/Default/Extensions/$PRIMARY_EXTENSION_ID"
    
    if [[ -d "$extensions_path" ]]; then
        return 0
    fi
    
    # Check other profiles
    for profile_dir in "$browser_path"/Profile*/Extensions/"$PRIMARY_EXTENSION_ID"; do
        if [[ -d "$profile_dir" ]]; then
            return 0
        fi
    done
    
    return 1
}

# Create manifest files
create_manifests() {
    local browser_path="$1"
    local native_host_path="$2"
    local code_native_host_path="$3"
    
    local nmh_dir="$browser_path/NativeMessagingHosts"
    
    # Create directory if it doesn't exist
    mkdir -p "$nmh_dir"
    
    # Build allowed_origins array as JSON
    local origins_json=""
    for origin in "${CLAUDE_EXTENSION_IDS[@]}"; do
        if [[ -n "$origins_json" ]]; then
            origins_json="$origins_json,"
        fi
        origins_json="$origins_json
    \"$origin\""
    done
    
    # Create Claude Desktop manifest
    cat > "$nmh_dir/com.anthropic.claude_browser_extension.json" << EOF
{
  "name": "com.anthropic.claude_browser_extension",
  "description": "Claude Browser Extension Native Host",
  "path": "$native_host_path",
  "type": "stdio",
  "allowed_origins": [$origins_json
  ]
}
EOF
    
    # Create Claude Code manifest (only if Claude Code native host exists)
    if [[ -f "$code_native_host_path" ]]; then
        cat > "$nmh_dir/com.anthropic.claude_code_browser_extension.json" << EOF
{
  "name": "com.anthropic.claude_code_browser_extension",
  "description": "Claude Code Browser Extension Native Host",
  "path": "$code_native_host_path",
  "type": "stdio",
  "allowed_origins": [
    "chrome-extension://$PRIMARY_EXTENSION_ID/"
  ]
}
EOF
        return 0
    else
        return 1
    fi
}

# Uninstall function
uninstall() {
    local browser_path="$1"
    local nmh_dir="$browser_path/NativeMessagingHosts"
    
    if [[ -f "$nmh_dir/com.anthropic.claude_browser_extension.json" ]]; then
        rm "$nmh_dir/com.anthropic.claude_browser_extension.json"
        print_success "Removed claude_browser_extension manifest"
    fi
    
    if [[ -f "$nmh_dir/com.anthropic.claude_code_browser_extension.json" ]]; then
        rm "$nmh_dir/com.anthropic.claude_code_browser_extension.json"
        print_success "Removed claude_code_browser_extension manifest"
    fi
    
    # Remove directory if empty
    if [[ -d "$nmh_dir" ]] && [[ -z "$(ls -A "$nmh_dir")" ]]; then
        rmdir "$nmh_dir"
        print_success "Removed empty NativeMessagingHosts directory"
    fi
}

# Verify installation
verify_installation() {
    local browser_path="$1"
    local nmh_dir="$browser_path/NativeMessagingHosts"
    
    local success=true
    
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

# Main function
main() {
    local uninstall_mode=false
    local custom_path=""
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --uninstall|-u)
                uninstall_mode=true
                shift
                ;;
            --path|-p)
                custom_path="$2"
                shift 2
                ;;
            --help|-h)
                echo "Usage: $0 [OPTIONS]"
                echo ""
                echo "Options:"
                echo "  --uninstall, -u    Remove Claude native messaging configuration"
                echo "  --path, -p PATH    Specify custom browser Application Support path"
                echo "  --help, -h         Show this help message"
                exit 0
                ;;
            *)
                print_error "Unknown option: $1"
                exit 1
                ;;
        esac
    done
    
    print_header
    
    # Check OS
    if [[ "$OS" == "unknown" ]]; then
        print_error "Unsupported operating system"
        exit 1
    fi
    print_info "Detected OS: $OS"
    
    # Check Claude native host
    local native_host_path=$(get_claude_native_host_path)
    if [[ -z "$native_host_path" ]] || [[ ! -f "$native_host_path" ]]; then
        print_error "Claude Desktop not found. Please install Claude Desktop first."
        print_info "Download from: https://claude.ai/download"
        exit 1
    fi
    print_success "Found Claude Desktop native host: $native_host_path"
    
    local code_native_host_path=$(get_claude_code_native_host_path)
    if [[ -f "$code_native_host_path" ]]; then
        print_success "Found Claude Code native host: $code_native_host_path"
    else
        print_warning "Claude Code native host not found (optional)"
    fi

    echo ""
    
    # Handle custom path
    if [[ -n "$custom_path" ]]; then
        if [[ ! -d "$custom_path" ]]; then
            print_error "Specified path does not exist: $custom_path"
            exit 1
        fi
        
        if $uninstall_mode; then
            print_info "Uninstalling from: $custom_path"
            uninstall "$custom_path"
        else
            print_info "Installing to: $custom_path"
            create_manifests "$custom_path" "$native_host_path" "$code_native_host_path"
            echo ""
            verify_installation "$custom_path"
        fi
        
        echo ""
        print_info "Please restart your browser for changes to take effect."
        exit 0
    fi
    
    # Detect browsers
    print_info "Scanning for Chromium-based browsers..."
    echo ""
    
    mapfile -t browsers < <(detect_browsers)
    
    if [[ ${#browsers[@]} -eq 0 ]]; then
        print_error "No supported Chromium browsers found."
        print_info "You can specify a custom path with: $0 --path /path/to/browser/data"
        exit 1
    fi
    
    # Display found browsers
    echo "Found browsers:"
    echo ""
    
    local i=1
    local valid_browsers=()
    for browser in "${browsers[@]}"; do
        IFS='|' read -r name path <<< "$browser"
        
        local extension_status=""
        if check_extension_installed "$path"; then
            extension_status="${GREEN}[Extension installed]${NC}"
            valid_browsers+=("$browser")
        else
            extension_status="${YELLOW}[Extension not found]${NC}"
        fi
        
        echo -e "  $i) $name $extension_status"
        echo -e "     ${BLUE}$path${NC}"
        echo ""
        ((i++))
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
            selected_indices+=($j)
        done
    else
        IFS=',' read -ra selected_indices <<< "$selection"
    fi
    
    echo ""
    
    # Process selected browsers
    for idx in "${selected_indices[@]}"; do
        idx=$(echo "$idx" | tr -d ' ')
        
        if [[ ! "$idx" =~ ^[0-9]+$ ]] || [[ $idx -lt 1 ]] || [[ $idx -gt ${#browsers[@]} ]]; then
            print_warning "Invalid selection: $idx (skipping)"
            continue
        fi
        
        IFS='|' read -r name path <<< "${browsers[$((idx-1))]}"
        
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        print_info "Processing: $name"
        
        if $uninstall_mode; then
            uninstall "$path"
            print_success "Uninstalled from $name"
        else
            if create_manifests "$path" "$native_host_path" "$code_native_host_path"; then
                print_success "Created manifests for $name"
            else
                print_warning "Created Claude Desktop manifest only (Claude Code not installed)"
            fi
            verify_installation "$path"
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
