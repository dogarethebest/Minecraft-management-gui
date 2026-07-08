#!/bin/bash
MIN_RAM_GB=8
echo "Checking system requirements..."
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
        echo "./test.sh --BYRR"
        exit 1
    fi

    echo "RAM check passed."
fi


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

sudo ./start.sh --BYROOT --BYRR&
PID=$!
sleep 120 #Wait for the Minecraft server to fully start up

./tests/api_username_test.sh 
./tests/test_antixray.sh

cleanup() {
    echo "Stopping services..."

    kill $PID

    wait
    exit
}

trap cleanup SIGINT SIGTERM

wait