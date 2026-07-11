#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
LOG_DIR=${MINECRAFT_MANAGER_LOG_DIR:-/var/log/minecraft-management-gui}
STARTUP_LOG="$LOG_DIR/startup.log"

if ! mkdir -p "$LOG_DIR" 2>/dev/null; then
    LOG_DIR="$SCRIPT_DIR/logs"
    STARTUP_LOG="$LOG_DIR/startup.log"
    mkdir -p "$LOG_DIR"
fi
touch "$STARTUP_LOG"
chmod 0755 "$LOG_DIR" 2>/dev/null || true
chmod 0644 "$STARTUP_LOG" 2>/dev/null || true
exec > >(tee -a "$STARTUP_LOG") 2>&1

echo "==== Minecraft Management GUI startup started at $(date -Is) ===="
cd "$SCRIPT_DIR"
MIN_RAM_GB=8

echo "Checking system requirements..."

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

if [ "$(id -u)" -eq 0 ]; then
    echo "WARNING: Running as root is not recommended. The Debian service uses the minecraft-manager user."
else
    echo "Running as user $(id -un)."
fi

ensure_writable() {
    local path="$1"
    if [ ! -e "$path" ]; then
        mkdir -p "$path"
    fi
    if [ ! -w "$path" ]; then
        echo "ERROR: $path is not writable by $(id -un)."
        echo "Fix ownership with: sudo chown -R $(id -u):$(id -g) '$path'"
        exit 1
    fi
}

ensure_writable "$SCRIPT_DIR/mc"
[ -d "$SCRIPT_DIR/caddy" ] && ensure_writable "$SCRIPT_DIR/caddy"

PIDS=()

cleanup() {
    echo ""
    echo "Stopping services..."
    for PID in "${PIDS[@]}"; do
        if kill -0 "$PID" 2>/dev/null; then
            echo "Stopping process group $PID..."
            kill -- "-$PID" 2>/dev/null || kill "$PID" 2>/dev/null || true
        fi
    done
    echo "Waiting for services to exit..."
    for PID in "${PIDS[@]}"; do
        wait "$PID" 2>/dev/null || true
    done
    echo "All services stopped."
}

trap cleanup SIGINT SIGTERM EXIT
echo "Starting services..."

cd mc
setsid java -Xmx4096M -Xms4096M -jar paper.jar nogui &
MC_PID=$!
PIDS+=("$MC_PID")
cd ..

if [[ " $* " == *" --Domain "* ]]; then
    echo "Domain mode selected; leaving Caddyfile unchanged."
else
    CADDYFILE="./caddy/Caddyfile"
    SERVER_IP=$(hostname -I | awk '{print $1}')
    if [ -z "$SERVER_IP" ]; then
        echo "Could not detect server IP"
        exit 1
    fi
    if [ -w "$CADDYFILE" ]; then
        sed -i -E "s/[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+:443/$SERVER_IP:443/g" "$CADDYFILE"
        echo "Updated Caddyfile to use $SERVER_IP:443"
    else
        echo "WARNING: $CADDYFILE is not writable; skipping automatic IP update."
    fi
fi

sleep 40

echo "Starting API..."
npm run start_api &
API_PID=$!
PIDS+=("$API_PID")

echo "Starting frontend..."
npm run start_static_ui &
FRONTEND_PID=$!
PIDS+=("$FRONTEND_PID")

sleep 5

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
