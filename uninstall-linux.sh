#!/bin/bash
# uninstall-linux.sh - Removes all files installed by install-linux.sh
#
# Reverses: host binary, manifests (user + system), and optionally the config.
#
# Usage: ./uninstall-linux.sh

set -euo pipefail

# ═══════════════════════════════════════════════════════════════════════════
# Constants — must mirror install-linux.sh exactly
# ═══════════════════════════════════════════════════════════════════════════

readonly MANIFEST_NAME="com.claude.chromium_native"
readonly HOST_INSTALL_DIR="${HOME}/.local/share/claude-chromium-native-messaging"
readonly CONFIG_DIR="${HOME}/.config/claude-chromium-native-messaging"
readonly CONFIG_FILE="${CONFIG_DIR}/config.json"

declare -ra USER_MANIFEST_DIRS=(
    "${HOME}/.config/google-chrome/NativeMessagingHosts"
    "${HOME}/.config/chromium/NativeMessagingHosts"
)

declare -ra SYSTEM_MANIFEST_DIRS=(
    "/etc/opt/chrome/native-messaging-hosts"
    "/etc/chromium/native-messaging-hosts"
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
warn() { echo -e "${YELLOW}⚠${NC} $*"; }
info() { echo -e "${BLUE}ℹ${NC} $*"; }
step() { echo -e "\n${BLUE}▶${NC} $*"; }

# ═══════════════════════════════════════════════════════════════════════════
# Removal helpers
# ═══════════════════════════════════════════════════════════════════════════

# Removes a file if it exists; reports status either way
remove_file() {
    local path="$1"
    if [[ -f "$path" ]]; then
        rm -f "$path"
        ok "Removed: ${path}"
    else
        info "Not found (skipping): ${path}"
    fi
}

# Removes a directory if it exists and is empty
remove_dir_if_empty() {
    local dir="$1"
    if [[ -d "$dir" ]] && [[ -z "$(ls -A "$dir" 2>/dev/null)" ]]; then
        rmdir "$dir"
        ok "Removed empty directory: ${dir}"
    fi
}

# Removes a system file using sudo; reports status
remove_system_file() {
    local path="$1"
    if sudo test -f "$path" 2>/dev/null; then
        sudo rm -f "$path"
        ok "Removed (system): ${path}"
    else
        info "Not found (skipping): ${path}"
    fi
}

# ═══════════════════════════════════════════════════════════════════════════
# Removal steps
# ═══════════════════════════════════════════════════════════════════════════

# Removes manifests from user-level NativeMessagingHosts directories
remove_user_manifests() {
    step "Removing user-level manifests..."
    for dir in "${USER_MANIFEST_DIRS[@]}"; do
        remove_file "${dir}/${MANIFEST_NAME}.json"
    done
}

# Removes manifests from system-wide directories (requires sudo)
remove_system_manifests() {
    step "Removing system-wide manifests..."

    if ! command -v sudo &>/dev/null; then
        info "sudo not available — skipping system-wide manifests"
        echo "  To remove manually:"
        for dir in "${SYSTEM_MANIFEST_DIRS[@]}"; do
            echo "    sudo rm -f ${dir}/${MANIFEST_NAME}.json"
        done
        return
    fi

    # Check if any system manifest exists before asking for sudo
    local found_any=false
    for dir in "${SYSTEM_MANIFEST_DIRS[@]}"; do
        if sudo test -f "${dir}/${MANIFEST_NAME}.json" 2>/dev/null; then
            found_any=true
            break
        fi
    done

    if [[ "$found_any" == false ]]; then
        info "No system-wide manifests found, skipping"
        return
    fi

    echo ""
    read -rp "Remove system-wide manifests? (requires sudo) [y/N] " remove_system
    if [[ "${remove_system,,}" == "y" ]]; then
        for dir in "${SYSTEM_MANIFEST_DIRS[@]}"; do
            remove_system_file "${dir}/${MANIFEST_NAME}.json"
        done
    else
        info "Keeping system-wide manifests"
    fi
}

# Removes the host binary and its install directory (if empty afterwards)
remove_host_binary() {
    step "Removing host binary..."
    remove_file "${HOST_INSTALL_DIR}/host"
    remove_dir_if_empty "${HOST_INSTALL_DIR}"
}

# Prompts the user before removing the config file (contains API key)
remove_config() {
    step "Handling config file..."

    if [[ ! -f "$CONFIG_FILE" ]]; then
        info "Config file not found, nothing to remove"
        return
    fi

    echo ""
    warn "Config file contains your Claude API key: ${CONFIG_FILE}"
    read -rp "Remove it? [y/N] " remove_cfg
    if [[ "${remove_cfg,,}" == "y" ]]; then
        rm -f "$CONFIG_FILE"
        ok "Removed: ${CONFIG_FILE}"
        remove_dir_if_empty "${CONFIG_DIR}"
    else
        info "Keeping config file"
    fi
}

# ═══════════════════════════════════════════════════════════════════════════
# Main
# ═══════════════════════════════════════════════════════════════════════════

main() {
    echo -e "${BLUE}Claude Native Messaging — Linux Uninstaller${NC}"
    echo ""

    remove_user_manifests
    remove_system_manifests
    remove_host_binary
    remove_config

    echo ""
    echo -e "${GREEN}Uninstall complete.${NC}"
    echo ""
    info "Restart Chrome/Chromium to apply changes."
    echo ""
}

main "$@"
