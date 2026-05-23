#!/usr/bin/env bash
# Quick version check script - shows current vs latest without updating

set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "Checking Antigravity versions..."

# Get current version
CURRENT_HUB=$(grep -oP 'version = "\K[^"]+' flake.nix | sed -n '1p')
CURRENT_IDE=$(grep -oP 'ide_version = "\K[^"]+' flake.nix | head -1)
CURRENT_CLI=$(grep -oP 'cli_version = "\K[^"]+' flake.nix | head -1)

echo -e "${GREEN}Current Hub version:${NC} $CURRENT_HUB"
echo -e "${GREEN}Current IDE version:${NC} $CURRENT_IDE"
echo -e "${GREEN}Current CLI version:${NC} $CURRENT_CLI"

echo "Fetching latest version from antigravity.google..."
if command -v node &>/dev/null && [[ -f "scripts/scrape-version.js" ]]; then
    cd scripts && npm install >/dev/null 2>&1 && cd ..
    if node -e "require('playwright-chromium')" >/dev/null 2>&1 || [ -d "scripts/node_modules/playwright-chromium" ] || [ -d "node_modules/playwright-chromium" ]; then
        LATEST_JSON=$(CHROME_BIN=${CHROME_BIN:-/run/current-system/sw/bin/google-chrome-stable} node scripts/scrape-version.js 2>/dev/null)

        LATEST_IDE=$(echo "$LATEST_JSON" | grep -oP '"ide":"\K[^"]+')
        LATEST_HUB=$(echo "$LATEST_JSON" | grep -oP '"hub":"\K[^"]+')
        LATEST_CLI=$(echo "$LATEST_JSON" | grep -oP '"cli":"\K[^"]+')

        echo -e "${GREEN}Latest Hub version:${NC}  $LATEST_HUB"
        echo -e "${GREEN}Latest IDE version:${NC}  $LATEST_IDE"
        echo -e "${GREEN}Latest CLI version:${NC}  $LATEST_CLI"

        UPDATE_NEEDED=0
        if [[ "$CURRENT_HUB" != "$LATEST_HUB" ]]; then
            echo -e "\n${YELLOW}⚠ Hub Update available!${NC} ($CURRENT_HUB -> $LATEST_HUB)"
            UPDATE_NEEDED=1
        fi
        if [[ "$CURRENT_IDE" != "$LATEST_IDE" ]]; then
            echo -e "\n${YELLOW}⚠ IDE Update available!${NC} ($CURRENT_IDE -> $LATEST_IDE)"
            UPDATE_NEEDED=1
        fi
        if [[ "$CURRENT_CLI" != "$LATEST_CLI" ]]; then
            echo -e "\n${YELLOW}⚠ CLI Update available!${NC} ($CURRENT_CLI -> $LATEST_CLI)"
            UPDATE_NEEDED=1
        fi

        if [ "$UPDATE_NEEDED" -eq 0 ]; then
             echo -e "\n${GREEN}✓ Already at latest versions!${NC}"
             exit 0
        else
             exit 1
        fi
    else
        echo "Error: playwright-chromium not installed"
        echo "Install with: cd scripts && npm install"
        exit 1
    fi
else
    echo "Error: Node.js or scrape-version.js not found"
    exit 1
fi
