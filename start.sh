#!/bin/bash

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
java -Xmx496M -Xms4096M -jar server.jar nogui &
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