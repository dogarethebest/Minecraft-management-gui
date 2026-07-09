#!/bin/bash
cd "$(dirname "$0")"
nohup ./install.sh > /var/log/other-script.log 2>&1 &
