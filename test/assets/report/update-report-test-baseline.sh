#!/bin/bash
(./memsql-report-test.sh && echo PASS) 2>&1 > memsql-report-test-baseline.txt
