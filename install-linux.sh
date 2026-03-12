#!/bin/bash
# install-linux.sh - Linux installer for claude-chromium-native-messaging
#
# Copies Claude Code's native messaging manifests to alternative Chromium
# browser directories (Brave, Vivaldi, etc.) that Claude Code doesn't
# configure automatically.
#
# Prerequisites: Claude Code CLI must be installed (provides the native host)
#
# Usage: ./install-linux.sh

set -euo pipefail

# ═══════════════════════════════════════════════════════════════════════════
# Constants
# ═══════════════════════════════════════════════════════════════════════════

# Claude Code's native host and manifest locations
readonly CLAUDE_CODE_HOST="$HOME/.claude/chrome/chrome-native-host"
readonly CLAUDE_CODE_MANIFEST_DIR="$HOME/.config/google-chrome/NativeMessagingHosts"
readonly CLAUDE_CODE_MANIFEST_NAME="com.anthropic.claude_code_browser_extension"

# Claude Desktop manifest name (for reference)
readonly CLAUDE_DESKTOP_MANIFEST_NAME="com.anthropic.claude_browser_extension"

# Extension IDs (from setup.sh)
readonly OFFICIAL_EXT_ID="fcoeoabgfenejglbffodgkkbkcdhcgfn"

# Browser directories where Claude Code doesn't install manifests by default
# (Claude Code only installs to google-chrome and microsoft-edge)
declare -ra EXTRA_BROWSER_DIRS=(
    "$HOME/.config/chromium"
    "$HOME/.config/BraveSoftware/Brave-Browser"
    "$HOME/.config/vivaldi"
    "$HOME/.config/opera"
    "$HOME/.config/opera-gx"
    "$HOME/.config/yandex-browser"
    "$HOME/.config/naver-whale"
    "$HOME/.config/coccoc"
    "$HOME/.config/slimjet"
    "$HOME/.config/ungoogled-chromium"
    "$HOME/.config/Sidekick"
    "$HOME/.config/GensparkSoftware/Genspark-Browser"
    "$HOME/.config/net.imput.helium"
    "$HOME/.config/iron"
    "$HOME/.config/cent-browser"
    "$HOME/.config/comodo-dragon"
    "$HOME/.config/avast-secure-browser"
    "$HOME/.config/avg-secure-browser"
    "$HOME/.config/epic"
    "$HOME/.config/torch"
    "$HOME/.config/Maxthon"
    "$HOME/.config/iridium"
    "$HOME/.config/Orion"
    "$HOME/.config/Falkon"
    "$HOME/.config/Colibri"
)

# Colors
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

# ═══════════════════════════════════════════════════════════════════════════
# Output helpers
# ═══════════════════════════════════════════════════════════════════════════

ok()   { echo -e "${GREEN}✓${NC} $*"; }
err()  { echo -e "${RED}✗${NC} $*" >&2; }
warn() { echo -e "${YELLOW}⚠${NC} $*"; }
info() { echo -e "${BLUE}ℹ${NC} $*"; }
step() { echo -e "\n${BLUE}▶${NC} $*"; }

# ═══════════════════════════════════════════════════════════════════════════
# Checks
# ═══════════════════════════════════════════════════════════════════════════

check_claude_code() {
    step "Checking for Claude Code CLI..."

    if [[ -f "$CLAUDE_CODE_HOST" ]]; then
        ok "Found Claude Code native host: $CLAUDE_CODE_HOST"
        return 0
    fi

    # Check if claude command exists
    if command -v claude &>/dev/null; then
        warn "Claude Code CLI is installed but native host not found at:"
        echo "  $CLAUDE_CODE_HOST"
        echo ""
        echo "Run Claude Code's browser integration once to create it:"
        echo "  claude"
        echo "  Then use /chrome in Claude Code"
        echo ""
        echo "After that, re-run this installer."
        exit 1
    fi

    err "Claude Code CLI is not installed."
    echo ""
    echo "Install Claude Code first:"
    echo "  npm install -g @anthropic-ai/claude-code"
    echo ""
    echo "Then run Claude Code once to set up the native host:"
    echo "  claude"
    echo "  Then use /chrome in Claude Code"
    echo ""
    echo "After that, re-run this installer."
    echo ""
    echo "More info: https://docs.anthropic.com/en/docs/claude-code"
    exit 1
}

# ═══════════════════════════════════════════════════════════════════════════
# Manifest Installation
# ═══════════════════════════════════════════════════════════════════════════

# Build the manifest JSON pointing to Claude Code's native host
build_manifest_json() {
    local manifest_name="$1"
    local host_path="$2"
    cat <<EOF
{
  "name": "${manifest_name}",
  "description": "Claude Code Browser Extension Native Host",
  "path": "${host_path}",
  "type": "stdio",
  "allowed_origins": [
    "chrome-extension://${OFFICIAL_EXT_ID}/"
  ]
}
EOF
}

# Install manifest to a browser's NativeMessagingHosts directory (idempotent)
install_manifest() {
    local browser_dir="$1"
    local manifest_name="$2"
    local host_path="$3"

    local nmh_dir="${browser_dir}/NativeMessagingHosts"
    local manifest_path="${nmh_dir}/${manifest_name}.json"
    local new_content
    new_content="$(build_manifest_json "$manifest_name" "$host_path")"

    # Skip if already identical
    if [[ -f "$manifest_path" ]] && [[ "$new_content" == "$(cat "$manifest_path")" ]]; then
        ok "Already up-to-date: ${manifest_path}"
        return
    fi

    mkdir -p "$nmh_dir"
    printf '%s\n' "$new_content" > "$manifest_path"
    chmod 644 "$manifest_path"
    ok "Installed: ${manifest_path}"
}

# Install manifests to all detected browser directories
install_all_manifests() {
    step "Installing Native Messaging manifests to alternative browsers..."

    local installed=0

    for browser_dir in "${EXTRA_BROWSER_DIRS[@]}"; do
        # Only install if the browser directory exists (browser is installed)
        if [[ -d "$browser_dir" ]]; then
            local browser_name
            browser_name="$(basename "$browser_dir")"
            info "Found browser: $browser_name"
            install_manifest "$browser_dir" "$CLAUDE_CODE_MANIFEST_NAME" "$CLAUDE_CODE_HOST"
            ((installed++)) || true
        fi
    done

    if [[ $installed -eq 0 ]]; then
        warn "No additional browsers found."
        echo ""
        echo "This installer only configures browsers that Claude Code doesn't"
        echo "set up automatically. Claude Code already covers:"
        echo "  - Google Chrome (~/.config/google-chrome/)"
        echo "  - Microsoft Edge (~/.config/microsoft-edge/)"
        echo ""
        echo "If your browser is installed in a non-standard location,"
        echo "use setup.sh with --path instead:"
        echo "  ./setup.sh --path ~/.config/your-browser"
    fi
}

# ═══════════════════════════════════════════════════════════════════════════
# Next Steps Summary
# ═══════════════════════════════════════════════════════════════════════════

print_next_steps() {
    echo ""
    echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║  Installation complete!                                      ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo "What was configured:"
    echo "  Native host : $CLAUDE_CODE_HOST (provided by Claude Code)"
    echo "  Manifests   : Installed to all detected browser directories"
    echo ""
    echo "Next steps:"
    echo "  1. Install the Claude browser extension (if not already installed):"
    echo "     https://chrome.google.com/webstore/detail/claude/${OFFICIAL_EXT_ID}"
    echo "  2. Completely quit your browser (no background processes)"
    echo "  3. Restart the browser"
    echo "  4. Open the Claude extension — it should now connect via Claude Code"
    echo ""
    echo "To uninstall: ./uninstall-linux.sh"
    echo ""
}

# ═══════════════════════════════════════════════════════════════════════════
# Main
# ═══════════════════════════════════════════════════════════════════════════

main() {
    echo -e "${BLUE}Claude Native Messaging — Linux Installer${NC}"
    echo ""
    echo "This script extends Claude Code's native messaging to additional"
    echo "Chromium browsers (Brave, Vivaldi, Opera, etc.)."
    echo ""

    check_claude_code
    install_all_manifests
    print_next_steps
}

main "$@"
