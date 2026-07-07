#!/usr/bin/env bash

MIN_RAM_GB=8

# Check for RAM bypass flag
if [[ " $* " == *" --BYRR "* ]]; then
    echo "RAM check bypassed with --BYRR"
    echo "this is a unsupported config run at your own risk"

else
    MIN_RAM_BYTES=$((MIN_RAM_GB * 1024 * 1024 * 1024))

    TOTAL_RAM_BYTES=$(awk '/MemTotal/ {print $2 * 1024}' /proc/meminfo)

    if [ "$TOTAL_RAM_BYTES" -lt "$MIN_RAM_BYTES" ]; then
        TOTAL_RAM_GB=$((TOTAL_RAM_BYTES / 1024 / 1024 / 1024))

        echo "ERROR: Not enough RAM."
        echo "Required: ${MIN_RAM_GB}GB"
        echo "Detected: ${TOTAL_RAM_GB}GB"
        echo ""
        echo "If you want to bypass this check, run:"
        echo "./install.sh --BYRR"
        exit 1
    fi

    echo "RAM check passed."
fi

echo "Continuing installation..."

echo "RAM check passed: ${TOTAL_RAM_GB}GB available"

if [[ " $* " == *" --BYROOT "* ]]; then
    echo "Root check bypassed with --BYROOT"
else
    if [ "$(id -u)" -ne 0 ]; then
        echo "ERROR: This script must be run as root."
        echo "Run with sudo or use --BYROOT to bypass this check."
        exit 1
    fi

    echo "Running as root."
fi

sudo add-apt-repository universe -y
sudo apt update
sudo apt install openjdk-21-jre

# Add cloudflare gpg key
sudo mkdir -p --mode=0755 /usr/share/keyrings
curl -fsSL https://pkg.cloudflare.com/cloudflare-main.gpg | sudo tee /usr/share/keyrings/cloudflare-main.gpg >/dev/null

# Add this repo to your apt repositories
echo 'deb [signed-by=/usr/share/keyrings/cloudflare-main.gpg] https://pkg.cloudflare.com/cloudflared any main' | sudo tee /etc/apt/sources.list.d/cloudflared.list

# install cloudflared
sudo apt-get update && sudo apt-get install cloudflared

set -e

API="https://fill.papermc.io/v3/projects/paper"

MC_VERSION=$(
    curl -fsSL "$API" |
    jq -r '
        .versions
        | keys
        | map(select(startswith("1.")))
        | sort_by(split(".") | map(tonumber))
        | last
    '
)

echo "Minecraft version: $MC_VERSION"

echo "Finding latest Paper build..."

curl -fsSL "$API/versions/$MC_VERSION/builds" -o response.json

DOWNLOAD_URL=$(jq -r '.. | objects | .url? // empty' response.json | head -n1)
echo "Downloading:"
echo "$DOWNLOAD_URL"

curl -L \
    -A "MinecraftManagement/1.0" \
    -o paper.jar \
    "$DOWNLOAD_URL"

rm response.json

mkdir -p mc
chmod +x mc/paper.jar
mv paper.jar mc/paper.jar

cp preset/eula.txt mc/eula.txt
cp preset/server.properties mc/server.properties

echo "Final configuration will be in gui"
chown -R nicholas:nicholas mc
./start.sh