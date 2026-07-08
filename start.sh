#!/bin/bash
cd "$(dirname "$0")"
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


# Root check
if [[ " $* " == *" --BYROOT "* ]]; then
    echo "Root check bypassed with --BYROOT"
    echo "this is a unsupported config run at your own risk"
else
    if [ "$(id -u)" -ne 0 ]; then
        echo "ERROR: This script must be run as root."
        echo "Run with sudo or use --BYROOT to bypass this check."
        exit 1
    fi

    echo "Running as root."
fi


PIDS=()

cleanup() {
    echo ""
    echo "Stopping services..."

    for PID in "${PIDS[@]}"; do
        if kill -0 "$PID" 2>/dev/null; then
            echo "Stopping process group $PID..."
            kill -- "-$PID" 2>/dev/null
        fi
    done

    echo "Waiting for services to exit..."

    for PID in "${PIDS[@]}"; do
        wait "$PID" 2>/dev/null
    done

    echo "All services stopped."
}

trap cleanup SIGINT SIGTERM EXIT


echo "Starting services..."

sleep 2


# Install mode
if [[ " $* " == *" --install "* ]]; then
    sleep 100
else

    # Start Minecraft as nicholas
    echo "Starting Minecraft..."

    setsid sudo -u nicholas bash -c '
        cd mc
        exec java -Xmx4096M -Xms4096M -jar paper.jar nogui
    ' &

    MC_PID=$!
    PIDS+=("$MC_PID")

    echo "$MC_PID" > tmp/pid
fi



# Domain mode
if [[ " $* " == *" --Domain "* ]]; then
    echo ""
    exit 1

else

    CADDYFILE="./caddy/Caddyfile"

    # Get current server IP
    SERVER_IP=$(hostname -I | awk '{print $1}')

    if [ -z "$SERVER_IP" ]; then
        echo "Could not detect server IP"
        exit 1
    fi


    # Replace any IPv4 address before :443
    sed -i -E "s/[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+:443/$SERVER_IP:443/g" "$CADDYFILE"

    echo "Updated Caddyfile to use $SERVER_IP:443"

fi


sleep 50


# Start API as nicholas
echo "Starting API..."

setsid sudo -u nicholas bash -c '
    exec npm run start_api
' &

API_PID=$!
PIDS+=("$API_PID")


# Start frontend as nicholas
echo "Starting frontend..."

setsid sudo -u nicholas bash -c '
    exec npm run start_static_ui
' &

FRONTEND_PID=$!
PIDS+=("$FRONTEND_PID")


sleep 5


# Start Caddy as root
echo "Starting Caddy..."

setsid ./caddy/caddy run --config ./caddy/Caddyfile &

CADDY_PID=$!
PIDS+=("$CADDY_PID")



echo ""
echo "Running:"
echo "Minecraft PID: $MC_PID"
echo "API PID:       $API_PID"
echo "Frontend PID:  $FRONTEND_PID"
echo "Caddy PID:     $CADDY_PID"



wait