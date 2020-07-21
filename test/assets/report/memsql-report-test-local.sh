#!/bin/bash

echo "I Am $0 $*"

POD=$1
REPORT_DIR=$2
TB_CONFIG=$3

# UNDONE (MCDB-985): test mode report pods never fail. Consider adding fail mode test.

echo "Hi from pod $POD. My report dir is $REPORT_DIR and my tb_config is $TB_CONFIG"
sleep 2
echo "Bye from pod $POD"

