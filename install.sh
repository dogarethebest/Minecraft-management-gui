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
# INSTALL USER
# ----------------------------

if [ "$(id -u)" -eq 0 ]; then
    INSTALL_USER=${SUDO_USER:-${MINECRAFT_MANAGER_USER:-}}
    if [ -z "$INSTALL_USER" ] || [ "$INSTALL_USER" = "root" ]; then
        echo "ERROR: Do not install the desktop copy as root unless SUDO_USER or MINECRAFT_MANAGER_USER is set."
        echo "Example: sudo MINECRAFT_MANAGER_USER=$USER ./install.sh"
        exit 1
    fi
    INSTALL_GROUP=$(id -gn "$INSTALL_USER")
else
    INSTALL_USER=$(id -un)
    INSTALL_GROUP=$(id -gn)
fi

echo "Continuing installation for $INSTALL_USER:$INSTALL_GROUP..."


# ----------------------------
# INSTALL DEPENDENCIES
# ----------------------------

echo "Installing dependencies..."

mkdir -p node_modules logs
chown -R "$INSTALL_USER:$INSTALL_GROUP" node_modules logs package-lock.json 2>/dev/null || true
if [ "$(id -u)" -eq 0 ]; then
    runuser -u "$INSTALL_USER" -- npm install
else
    npm install
fi


# ----------------------------
# CREATE MINECRAFT SERVER
# ----------------------------

echo "Creating Minecraft directory..."

mkdir -p mc


[ -f mc/paper.jar ] && chmod +x mc/paper.jar


chown -R "$INSTALL_USER:$INSTALL_GROUP" mc logs 2>/dev/null || true


echo "Minecraft files installed."

echo "Installing Dynmap plugin..."
mkdir -p mc/plugins
if [ -f preset/dynmap.jar ]; then
    cp preset/dynmap.jar mc/plugins/dynmap.jar
else
    echo "WARNING: preset/dynmap.jar not found; skipping Dynmap plugin copy."
fi
chown -R "$INSTALL_USER:$INSTALL_GROUP" mc logs 2>/dev/null || true

git clone https://github.com/Tiiffi/mcrcon.git
cd mcrcon
make
if [ "$(id -u)" -eq 0 ]; then
    make install
else
    sudo make install
fi
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