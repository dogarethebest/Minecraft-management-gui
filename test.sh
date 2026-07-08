#!/bin/bash
log_file="tests/logs/test.log"

./tests/api_username_test.sh ${log_file}
./tests/test_antixray_api.sh ${log_file}
./tests/test-server-property-API.sh ${log_file}