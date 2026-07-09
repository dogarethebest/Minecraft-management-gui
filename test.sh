#!/bin/bash
log_file="tests/logs/test.log"
echo "The script already expects the server to be running and does not launch it. Please ensure the server is running before executing this script."
sleep 5

./tests/api_username_test.sh ${log_file}
./tests/test_antixray_api.sh ${log_file}
./tests/test-server-property-API.sh ${log_file}