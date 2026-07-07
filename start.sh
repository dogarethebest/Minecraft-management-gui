#!/bin/bash

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
        echo "./start.sh --BYRR"
        exit 1
    fi

    echo "RAM check passed."
fi


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

# Start API
npm run start_api &
API_PID=$!

# Start frontend
npm run start_static_ui &
FRONTEND_PID=$!

# Start Caddy
cd caddy
sudo ./caddy run --config ./Caddyfile &
CADDY_PID=$!
cd ..

#start minecraft server
cd mc

java -Xmx496M -Xms4096M -jar paper.jar nogui &
MC_PID=$!


echo "Running:"
echo "API PID: $API_PID"
echo "Frontend PID: $FRONTEND_PID"
echo "Caddy PID: $CADDY_PID"
echo "Minecraft Server PID: $MC_PID"

cleanup() {
    echo "Stopping services..."

    kill $API_PID
    kill $FRONTEND_PID
    kill $CADDY_PID
    kill $MC_PID

    exit
}

trap cleanup SIGINT SIGTERM

wait