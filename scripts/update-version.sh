#!/usr/bin/env bash
# Auto-update script for Google Antigravity

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $*" >&2
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $*" >&2
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
}

# Function to extract version from download page
get_latest_versions() {
    log_info "Fetching latest versions..."

    if command -v node &>/dev/null && [[ -f "$(dirname "$0")/scrape-version.js" ]]; then
        cd "$(dirname "$0")" && npm install >/dev/null 2>&1 && cd ..
        if node -e "require('playwright-chromium')" >/dev/null 2>&1 || [ -d "node_modules/playwright-chromium" ] || [ -d "scripts/node_modules/playwright-chromium" ]; then
            local versions
            versions=$(node "$(dirname "$0")/scrape-version.js" 2>/dev/null | tr -d '\n\r')

            if [[ -n "$versions" ]]; then
                echo "$versions"
                return 0
            else
                log_warn "Browser scraping returned invalid version data: [$versions]"
                return 1
            fi
        else
            log_warn "Playwright not available"
            return 1
        fi
    fi
    return 1
}

# Function to get current version from flake
get_current_hub_version() {
    grep -oP 'version = "\K[^"]+' flake.nix | head -1
}
get_current_ide_version() {
    grep -oP 'ide_version = "\K[^"]+' flake.nix | head -1
}
get_current_cli_version() {
    grep -oP 'cli_version = "\K[^"]+' flake.nix | head -1
}

# Function to update version in files
update_version() {
    local type="$1"
    local new_version="$2"

    log_info "Updating $type version to $new_version..."

    if [ "$type" == "hub" ]; then
        sed -i "0,/version = \".*\"/s/version = \".*\"/version = \"$new_version\"/" flake.nix
        sed -i "s/version = \".*\"/version = \"$new_version\"/" pkg/hub.nix
    elif [ "$type" == "ide" ]; then
        sed -i "s/ide_version = \".*\"/ide_version = \"$new_version\"/" flake.nix
        sed -i "s/version = \".*\"/version = \"$new_version\"/" pkg/ide.nix
    elif [ "$type" == "cli" ]; then
        sed -i "s/cli_version = \".*\"/cli_version = \"$new_version\"/" flake.nix
        sed -i "s/version = \".*\"/version = \"$new_version\"/" pkg/cli.nix
    fi
}

# Function to update hash
update_hash() {
    local type="$1"
    local new_version="$2"
    local url=""
    local file=""

    if [ "$type" == "hub" ]; then
        url="https://storage.googleapis.com/antigravity-public/antigravity-hub/${new_version}/linux-x64/Antigravity.tar.gz"
        file="pkg/hub.nix"
    elif [ "$type" == "ide" ]; then
        url="https://edgedl.me.gvt1.com/edgedl/release2/j0qc3/antigravity/stable/${new_version}/linux-x64/Antigravity%20IDE.tar.gz"
        file="pkg/ide.nix"
    elif [ "$type" == "cli" ]; then
        url="https://storage.googleapis.com/antigravity-public/antigravity-cli/${new_version}/linux-x64/cli_linux_x64.tar.gz"
        file="pkg/cli.nix"
    fi

    log_info "Fetching hash for new $type version..."

    # Use nix-prefetch-url to get the correct hash
    local hash
    hash=$(nix-prefetch-url --type sha256 "$url" 2>/dev/null || echo "")

    if [[ -z "$hash" ]]; then
        log_error "Could not fetch hash for new version from $url"
        return 1
    fi

    # Convert to SRI hash format
    local sri_hash
    sri_hash=$(nix hash to-sri --type sha256 "$hash")

    log_info "New $type hash: $sri_hash"

    # Update with new hash
    sed -i "s|sha256 = \"sha256-[^\"]*\"|sha256 = \"$sri_hash\"|" "$file"

    log_info "$type Hash updated"
}

# Main script
main() {
    cd "$(dirname "$0")/.."

    log_info "Starting Google Antigravity update check..."

    local current_hub=$(get_current_hub_version)
    local current_ide=$(get_current_ide_version)
    local current_cli=$(get_current_cli_version)

    local latest_json
    if ! latest_json=$(get_latest_versions); then
        log_error "Could not fetch latest versions."
        exit 1
    fi

    local latest_hub=$(echo "$latest_json" | grep -oP '"hub":"\K[^"]+')
    local latest_ide=$(echo "$latest_json" | grep -oP '"ide":"\K[^"]+')
    local latest_cli=$(echo "$latest_json" | grep -oP '"cli":"\K[^"]+')

    local updated=0

    if [[ "$current_hub" != "$latest_hub" ]]; then
        log_info "Updating Hub: $current_hub -> $latest_hub"
        update_version "hub" "$latest_hub"
        update_hash "hub" "$latest_hub"
        updated=1
    fi

    if [[ "$current_ide" != "$latest_ide" ]]; then
        log_info "Updating IDE: $current_ide -> $latest_ide"
        update_version "ide" "$latest_ide"
        update_hash "ide" "$latest_ide"
        updated=1
    fi

    if [[ "$current_cli" != "$latest_cli" ]]; then
        log_info "Updating CLI: $current_cli -> $latest_cli"
        update_version "cli" "$latest_cli"
        update_hash "cli" "$latest_cli"
        updated=1
    fi

    if [ "$updated" -eq 0 ]; then
        log_info "Already at latest versions. No update needed."
        exit 0
    fi

    log_info "Update complete!"

    # Optionally commit changes
    if command -v git &> /dev/null && [[ -d .git ]]; then
        log_info "Committing changes..."
        git add flake.nix pkg/
        git commit -m "chore: update Google Antigravity to latest versions"
        log_info "Changes committed. Don't forget to push!"
    fi
}

main "$@"
