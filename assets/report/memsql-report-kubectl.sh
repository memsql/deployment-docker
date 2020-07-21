#!/bin/bash
set -euxo pipefail

cd /report
source cluster-report-lib.sh
exec ./memsql-report-main.sh
