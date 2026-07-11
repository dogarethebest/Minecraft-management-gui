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
# CREATE MINECRAFT SERVER
# ----------------------------

echo "Creating Minecraft directory..."

mkdir -p mc


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