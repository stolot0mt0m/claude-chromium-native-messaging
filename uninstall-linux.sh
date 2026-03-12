#!/bin/bash
# uninstall-linux.sh - Removes manifests installed by install-linux.sh
#
# Only removes manifests from alternative browser directories.
# Does NOT touch Claude Code's own configuration.
#
# Usage: ./uninstall-linux.sh

set -euo pipefail

# ═══════════════════════════════════════════════════════════════════════════
# Constants — must mirror install-linux.sh exactly
# ═══════════════════════════════════════════════════════════════════════════

readonly CLAUDE_CODE_MANIFEST_NAME="com.anthropic.claude_code_browser_extension"

# Same browser directories as install-linux.sh
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
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

# ═══════════════════════════════════════════════════════════════════════════
# Output helpers
# ═══════════════════════════════════════════════════════════════════════════

ok()   { echo -e "${GREEN}✓${NC} $*"; }
info() { echo -e "${BLUE}ℹ${NC} $*"; }
step() { echo -e "\n${BLUE}▶${NC} $*"; }

# ═══════════════════════════════════════════════════════════════════════════
# Removal
# ═══════════════════════════════════════════════════════════════════════════

remove_manifests() {
    step "Removing manifests from alternative browser directories..."

    local removed=0

    for browser_dir in "${EXTRA_BROWSER_DIRS[@]}"; do
        local manifest_path="${browser_dir}/NativeMessagingHosts/${CLAUDE_CODE_MANIFEST_NAME}.json"
        if [[ -f "$manifest_path" ]]; then
            rm -f "$manifest_path"
            ok "Removed: ${manifest_path}"
            ((removed++)) || true
        fi
    done

    if [[ $removed -eq 0 ]]; then
        info "No manifests found to remove."
    fi
}

# ═══════════════════════════════════════════════════════════════════════════
# Main
# ═══════════════════════════════════════════════════════════════════════════

main() {
    echo -e "${BLUE}Claude Native Messaging — Linux Uninstaller${NC}"
    echo ""
    echo "This removes manifests installed by install-linux.sh."
    echo "Claude Code's own configuration is not affected."
    echo ""

    remove_manifests

    echo ""
    echo -e "${GREEN}Uninstall complete.${NC}"
    echo ""
    info "Restart your browser for changes to take effect."
    echo ""
}

main "$@"
