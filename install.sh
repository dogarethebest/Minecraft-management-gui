#!/usr/bin/env bash

set -e

MIN_RAM_GB=7


# ----------------------------
# RAM CHECK
# ----------------------------

TOTAL_RAM_BYTES=$(awk '/MemTotal/ {print $2 * 1024}' /proc/meminfo)
TOTAL_RAM_GB=$((TOTAL_RAM_BYTES / 1024 / 1024 / 1024))

if [[ " $* " == *" --BYRR "* ]]; then
    echo "RAM check bypassed with --BYRR"
    echo "This is an unsupported config. Run at your own risk."
else

    MIN_RAM_BYTES=$((MIN_RAM_GB * 1024 * 1024 * 1024))

    if [ "$TOTAL_RAM_BYTES" -lt "$MIN_RAM_BYTES" ]; then
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

echo "Detected RAM: ${TOTAL_RAM_GB}GB"


# ----------------------------
# ROOT CHECK
# ----------------------------

if [[ " $* " == *" --BYROOT "* ]]; then

    echo "Root check bypassed with --BYROOT"
    echo "This is an unsupported config. Run at your own risk."

else

    if [ "$(id -u)" -ne 0 ]; then
        echo "ERROR: This script must be run as root."
        echo "Run with sudo or use --BYROOT to bypass this check."
        exit 1
    fi

    echo "Running as root."

fi


echo "Continuing installation..."


# ----------------------------
# INSTALL DEPENDENCIES
# ----------------------------

echo "Installing dependencies..."

npm install

# ----------------------------
# DOWNLOAD PAPER
# ----------------------------

echo "Finding latest Paper version..."

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


curl -fsSL \
"$API/versions/$MC_VERSION/builds" \
-o response.json


DOWNLOAD_URL=$(jq -r '.. | objects | .url? // empty' response.json | head -n1)


if [ -z "$DOWNLOAD_URL" ]; then
    echo "ERROR: Could not find Paper download URL"
    exit 1
fi


echo "Downloading:"
echo "$DOWNLOAD_URL"


curl -L \
-A "MinecraftManagement/1.0" \
-o paper.jar \
"$DOWNLOAD_URL"


rm response.json


# ----------------------------
# CREATE MINECRAFT SERVER
# ----------------------------

echo "Creating Minecraft directory..."

mkdir -p mc


mv paper.jar mc/paper.jar


cp preset/eula.txt mc/eula.txt
cp preset/server.properties mc/server.properties


chmod +x mc/paper.jar


chown -R nicholas:nicholas mc


echo "Minecraft files installed."

echo "Installing Dynmap plugin..."
mkdir -p mc/plugins
cp preset/dynmap.jar mc/plugins/dynmap.jar

git clone https://github.com/Tiiffi/mcrcon.git
cd mcrcon
make
sudo make install
cd ..
rm -rf mcrcon


echo ""
echo "================================="
echo "Installation complete."
echo "================================="
echo ""
echo "Check status:"
echo "systemctl status minecraft-manager"
echo ""
echo "View logs:"
echo "journalctl -u minecraft-manager -f"