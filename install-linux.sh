#!/bin/bash
# install-linux.sh - Linux installer for claude-chromium-native-messaging
#
# Builds the Node.js native host and registers it as a Chrome/Chromium
# Native Messaging Host without requiring Claude Desktop.
#
# Usage: ./install-linux.sh

set -euo pipefail

# ═══════════════════════════════════════════════════════════════════════════
# Constants
# ═══════════════════════════════════════════════════════════════════════════

readonly MANIFEST_NAME="com.claude.chromium_native"
readonly HOST_INSTALL_DIR="${HOME}/.local/share/claude-chromium-native-messaging"
readonly CONFIG_DIR="${HOME}/.config/claude-chromium-native-messaging"
readonly CONFIG_FILE="${CONFIG_DIR}/config.json"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly MIN_NODE_MAJOR=18

# Extension IDs: official, dev, staging (from setup.sh)
readonly OFFICIAL_EXT_ID="fcoeoabgfenejglbffodgkkbkcdhcgfn"
readonly DEV_EXT_ID="dihbgbndebgnbjfmelmegjepbnkhlgni"
readonly STAGING_EXT_ID="dngcpimnedloihjnnfngkgjoidhnaolf"

# User-level manifest directories (written without sudo)
declare -ra USER_MANIFEST_DIRS=(
    "${HOME}/.config/google-chrome/NativeMessagingHosts"
    "${HOME}/.config/chromium/NativeMessagingHosts"
)

# System-wide manifest directories (require sudo)
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
err()  { echo -e "${RED}✗${NC} $*" >&2; }
warn() { echo -e "${YELLOW}⚠${NC} $*"; }
info() { echo -e "${BLUE}ℹ${NC} $*"; }
step() { echo -e "\n${BLUE}▶${NC} $*"; }

# ═══════════════════════════════════════════════════════════════════════════
# OS Detection
# ═══════════════════════════════════════════════════════════════════════════

# Returns a simplified OS family: debian | fedora | arch | generic
detect_os() {
    if [[ ! -f /etc/os-release ]]; then
        echo "generic"
        return
    fi

    local os_id=""
    # Read only the ID field to avoid polluting the environment
    os_id="$(grep -E '^ID=' /etc/os-release | cut -d= -f2 | tr -d '"' | tr '[:upper:]' '[:lower:]')"

    case "$os_id" in
        ubuntu|debian|linuxmint|pop|elementary|zorin|kali)
            echo "debian" ;;
        fedora|rhel|centos|rocky|almalinux|oracle)
            echo "fedora" ;;
        arch|manjaro|endeavouros|garuda|artix)
            echo "arch" ;;
        *)
            echo "generic" ;;
    esac
}

# ═══════════════════════════════════════════════════════════════════════════
# Node.js Check
# ═══════════════════════════════════════════════════════════════════════════

# Returns the node binary name ("node" or "nodejs"), or empty string if absent
find_node_cmd() {
    if command -v node &>/dev/null; then
        echo "node"
    elif command -v nodejs &>/dev/null; then
        echo "nodejs"
    else
        echo ""
    fi
}

# Returns the major version number of the given node binary
get_node_major_version() {
    local node_cmd="$1"
    "$node_cmd" -e 'process.stdout.write(String(process.versions.node.split(".")[0]))'
}

# Prints distro-specific install commands for Node.js >= 18
print_node_install_hint() {
    local os="$1"
    case "$os" in
        debian)
            echo "  sudo apt-get update && sudo apt-get install -y nodejs npm"
            echo "  # Or install the latest LTS via NodeSource:"
            echo "  curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -"
            echo "  sudo apt-get install -y nodejs"
            ;;
        fedora)
            echo "  sudo dnf install -y nodejs npm"
            echo "  # Or install the latest LTS via NodeSource:"
            echo "  curl -fsSL https://rpm.nodesource.com/setup_lts.x | sudo bash -"
            echo "  sudo dnf install -y nodejs"
            ;;
        arch)
            echo "  sudo pacman -S nodejs npm"
            ;;
        *)
            echo "  # Use your package manager, or install via nvm:"
            echo "  curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash"
            echo "  source ~/.bashrc && nvm install --lts"
            ;;
    esac
}

# Verifies Node.js >= MIN_NODE_MAJOR is installed; exits with instructions if not
check_nodejs() {
    local os="$1"
    local node_cmd
    local major_version

    step "Checking Node.js >= ${MIN_NODE_MAJOR}..."

    node_cmd="$(find_node_cmd)"

    if [[ -z "$node_cmd" ]]; then
        warn "Node.js not found."
        echo ""
        echo "Install Node.js >= ${MIN_NODE_MAJOR} using one of these commands:"
        print_node_install_hint "$os"
        echo ""
        read -rp "After installing Node.js, press Enter to retry or Ctrl+C to abort: "
        # Retry once after user installs
        node_cmd="$(find_node_cmd)"
        if [[ -z "$node_cmd" ]]; then
            err "Node.js still not found. Install Node.js >= ${MIN_NODE_MAJOR} and re-run this script."
            exit 1
        fi
    fi

    major_version="$(get_node_major_version "$node_cmd")"

    if (( major_version < MIN_NODE_MAJOR )); then
        err "Node.js ${major_version} found, but >= ${MIN_NODE_MAJOR} is required."
        echo ""
        echo "Upgrade Node.js:"
        print_node_install_hint "$os"
        exit 1
    fi

    ok "Node.js ${major_version} (${node_cmd})"
}

# ═══════════════════════════════════════════════════════════════════════════
# Build
# ═══════════════════════════════════════════════════════════════════════════

# Runs npm install + npm run build in the project directory
build_project() {
    step "Building native host (npm install && npm run build)..."

    if ! command -v npm &>/dev/null; then
        err "npm not found. Install npm (it usually ships with Node.js) and re-run."
        exit 1
    fi

    cd "$SCRIPT_DIR"
    npm install --silent
    npm run build

    if [[ ! -f "${SCRIPT_DIR}/dist/host.js" ]]; then
        err "Build failed: dist/host.js not found after build."
        exit 1
    fi

    ok "Build complete"
}

# ═══════════════════════════════════════════════════════════════════════════
# Host Binary Deployment
# ═══════════════════════════════════════════════════════════════════════════

# Copies all dist/*.js files to HOST_INSTALL_DIR/ and sets host as executable (idempotent)
deploy_host() {
    local dist_dir="${SCRIPT_DIR}/dist"
    local host_src="${dist_dir}/host.js"
    local host_dst="${HOST_INSTALL_DIR}/host"

    step "Deploying host binary to ${HOST_INSTALL_DIR}/..."

    mkdir -p "${HOST_INSTALL_DIR}"

    # Copy all JS module files that host.js requires
    local changed=0
    for js_file in "${dist_dir}"/*.js; do
        local dest="${HOST_INSTALL_DIR}/$(basename "$js_file")"
        if [[ ! -f "$dest" ]] || ! diff -q "$js_file" "$dest" &>/dev/null; then
            cp "$js_file" "$dest"
            changed=1
        fi
    done

    # The manifest points to HOST_INSTALL_DIR/host (no extension, executable)
    if [[ ! -f "$host_dst" ]] || ! diff -q "$host_src" "$host_dst" &>/dev/null; then
        cp "$host_src" "$host_dst"
        changed=1
    fi
    chmod 755 "$host_dst"

    if [[ $changed -eq 0 ]]; then
        ok "Host binary already up-to-date"
    else
        ok "Deployed: ${host_dst} (+ module files)"
    fi
}

# ═══════════════════════════════════════════════════════════════════════════
# Manifest Creation
# ═══════════════════════════════════════════════════════════════════════════

# Outputs the manifest JSON for the given host path
build_manifest_json() {
    local host_path="$1"
    cat <<EOF
{
  "name": "${MANIFEST_NAME}",
  "description": "Claude Native Messaging Host",
  "path": "${host_path}",
  "type": "stdio",
  "allowed_origins": [
    "chrome-extension://${OFFICIAL_EXT_ID}/",
    "chrome-extension://${DEV_EXT_ID}/",
    "chrome-extension://${STAGING_EXT_ID}/"
  ]
}
EOF
}

# Writes the manifest to a user-accessible directory (idempotent)
install_manifest() {
    local dir="$1"
    local manifest_path="${dir}/${MANIFEST_NAME}.json"
    local new_content
    new_content="$(build_manifest_json "${HOST_INSTALL_DIR}/host")"

    # Skip if already identical
    if [[ -f "$manifest_path" ]] && [[ "$new_content" == "$(cat "$manifest_path")" ]]; then
        ok "Already up-to-date: ${manifest_path}"
        return
    fi

    mkdir -p "$dir"
    printf '%s\n' "$new_content" > "$manifest_path"
    ok "Installed: ${manifest_path}"
}

# Writes the manifest to a system directory using sudo
install_system_manifest() {
    local dir="$1"
    local manifest_path="${dir}/${MANIFEST_NAME}.json"
    local new_content
    new_content="$(build_manifest_json "${HOST_INSTALL_DIR}/host")"

    # Check idempotency (reading system file requires sudo)
    if sudo test -f "$manifest_path" 2>/dev/null; then
        local existing_content
        existing_content="$(sudo cat "$manifest_path" 2>/dev/null || echo "")"
        if [[ "$new_content" == "$existing_content" ]]; then
            ok "Already up-to-date (system): ${manifest_path}"
            return
        fi
    fi

    sudo mkdir -p "$dir"
    printf '%s\n' "$new_content" | sudo tee "$manifest_path" > /dev/null
    ok "Installed (system): ${manifest_path}"
}

# Installs manifests in user dirs, and optionally system dirs with sudo
install_all_manifests() {
    step "Installing Native Messaging manifests..."

    # User-level (no sudo needed)
    for dir in "${USER_MANIFEST_DIRS[@]}"; do
        install_manifest "$dir"
    done

    # System-wide (optional, requires sudo)
    if command -v sudo &>/dev/null; then
        echo ""
        read -rp "Install system-wide manifests too? (requires sudo) [y/N] " install_system
        if [[ "${install_system,,}" == "y" ]]; then
            for dir in "${SYSTEM_MANIFEST_DIRS[@]}"; do
                install_system_manifest "$dir"
            done
        else
            info "Skipping system-wide manifests"
        fi
    else
        info "sudo not available — skipping system-wide manifests (optional)"
    fi
}

# ═══════════════════════════════════════════════════════════════════════════
# Configuration
# ═══════════════════════════════════════════════════════════════════════════

# Returns true if the config file already contains a non-empty apiKey
config_has_api_key() {
    [[ -f "$CONFIG_FILE" ]] && grep -qE '"apiKey"\s*:\s*"[^"]+"' "$CONFIG_FILE" 2>/dev/null
}

# Returns true if the value looks like a Claude API key
is_valid_api_key() {
    [[ "$1" =~ ^sk-ant- ]]
}

# Creates the config file, prompting for the API key (idempotent: skips if key exists)
create_config() {
    step "Setting up config file..."

    if config_has_api_key; then
        ok "Config already exists with API key: ${CONFIG_FILE}"
        return
    fi

    mkdir -p "$CONFIG_DIR"

    echo ""
    echo "Enter your Claude API key (find it at https://console.anthropic.com/)"
    echo "It starts with 'sk-ant-'"
    echo ""

    local api_key=""
    while true; do
        read -rsp "API Key: " api_key
        echo ""  # newline after silent input

        if [[ -z "$api_key" ]]; then
            warn "API key cannot be empty. Press Ctrl+C to abort."
            continue
        fi

        if ! is_valid_api_key "$api_key"; then
            warn "Key does not look like a Claude API key (expected 'sk-ant-...')."
            read -rp "Use it anyway? [y/N] " override
            if [[ "${override,,}" != "y" ]]; then
                continue
            fi
        fi

        break
    done

    # Write config with secure permissions
    cat > "$CONFIG_FILE" <<JSONEOF
{
  "apiKey": "${api_key}",
  "model": "claude-opus-4-6"
}
JSONEOF
    chmod 600 "$CONFIG_FILE"
    ok "Config saved: ${CONFIG_FILE} (permissions: 600)"
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
    echo "What was installed:"
    echo "  Host binary : ${HOST_INSTALL_DIR}/host"
    echo "  Config file : ${CONFIG_FILE}"
    echo ""
    echo "Manifests registered in:"
    for dir in "${USER_MANIFEST_DIRS[@]}"; do
        echo "  ${dir}/${MANIFEST_NAME}.json"
    done
    echo ""
    echo "Next steps:"
    echo "  1. Install the Claude browser extension (if not already installed):"
    echo "     https://chrome.google.com/webstore/detail/claude/${OFFICIAL_EXT_ID}"
    echo "  2. Completely quit Chrome/Chromium (no background processes)"
    echo "  3. Restart the browser"
    echo "  4. Open the Claude extension — it should now connect via the native host"
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

    local os
    os="$(detect_os)"
    info "OS family: ${os}"

    check_nodejs "$os"
    build_project
    deploy_host
    install_all_manifests
    create_config
    print_next_steps
}

main "$@"
