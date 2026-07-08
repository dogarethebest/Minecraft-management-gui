#!/usr/bin/env bash

API="http://127.0.0.1:3001/api/antixray"

echo "================================="
echo " Paper Anti-Xray API Test"
echo "================================="
echo

# Check API availability
echo "[1] Checking current Anti-Xray status..."

curl -s "$API" | jq .

echo
echo "---------------------------------"

# Enable Anti-Xray
echo "[2] Enabling Anti-Xray..."

curl -s -X PUT "$API" \
    -H "Content-Type: application/json" \
    -d '{"enabled":true}' | jq .

echo
echo "Checking result..."

curl -s "$API" | jq .

echo
echo "---------------------------------"

# Disable Anti-Xray
echo "[3] Disabling Anti-Xray..."

curl -s -X PUT "$API" \
    -H "Content-Type: application/json" \
    -d '{"enabled":false}' | jq .

echo
echo "Checking result..."

curl -s "$API" | jq .

echo
echo "================================="
echo " Anti-Xray API test complete"
echo "================================="