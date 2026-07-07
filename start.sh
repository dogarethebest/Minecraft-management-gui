#!/bin/bash

MIN_RAM_GB=8

echo "Checking system requirements..."

# RAM check
if [[ " $* " == *" --BYRR "* ]]; then
    echo "RAM check bypassed with --BYRR"
    echo "This is an unsupported config. Run at your own risk."
else
    MIN_RAM_BYTES=$((MIN_RAM_GB * 1024 * 1024 * 1024))
    TOTAL_RAM_BYTES=$(awk '/MemTotal/ {print $2 * 1024}' /proc/meminfo)

    if [ "$TOTAL_RAM_BYTES" -lt "$MIN_RAM_BYTES" ]; then
        TOTAL_RAM_GB=$((TOTAL_RAM_BYTES / 1024 / 1024 / 1024))

        echo "ERROR: Not enough RAM."
        echo "Required: ${MIN_RAM_GB}GB"
        echo "Detected: ${TOTAL_RAM_GB}GB"
        echo "Use ./start.sh --BYRR to bypass."
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

echo "Starting services..."
sleep 2


# Fix ownership before starting
chown -R nicholas:nicholas mc


# Start Minecraft as nicholas
echo "Starting Minecraft..."

sudo -u nicholas bash -c '
cd mc
java -Xmx4096M -Xms4096M -jar paper.jar nogui
' &

MC_PID=$!


sleep 60


# Start API as nicholas
echo "Starting API..."

sudo -u nicholas npm run start_api &
API_PID=$!


# Start frontend as nicholas
echo "Starting frontend..."

sudo -u nicholas npm run start_static_ui &
FRONTEND_PID=$!


sleep 5


# Start Caddy as root
echo "Starting Caddy..."

./caddy/caddy run --config ./caddy/Caddyfile &
CADDY_PID=$!


echo ""
echo "Running:"
echo "Minecraft PID: $MC_PID"
echo "API PID:       $API_PID"
echo "Frontend PID:  $FRONTEND_PID"
echo "Caddy PID:     $CADDY_PID"


cleanup() {
    echo "Stopping services..."

    kill "$API_PID" 2>/dev/null
    kill "$FRONTEND_PID" 2>/dev/null
    kill "$CADDY_PID" 2>/dev/null
    kill "$MC_PID" 2>/dev/null

    wait

    echo "All services stopped."
}


trap cleanup SIGINT SIGTERM

wait

