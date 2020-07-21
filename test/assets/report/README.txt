# Who Calls Who
========================================================================================

memsql-report-test.sh                       // test driver for cluster report in test mode
+--> memsql-report-main.sh                  // this is in the prod code tree
     + --> memsql-report-test-local.sh      // runs in parallel across fake test pods (bash processes)
     + --> memsql-report-test-cluster.sh    // runs once

For sample test output see memsql-report-test-baseline.txt

Testing locally (code path and parallelism only, no report upload)
==================================================================

Step 1      $ ./memsql-report-test.sh  && echo PASS
Step 2      Compare output to memsql-report-test-baseline.txt
Step 3      If you changed something, update the basleine text file. e.g.
            $ ./update-report-test-baseline.sh*

Expected behaviour:
===================

    The test code path runs with parallism 2 for 4 pretend pods. So you should see two saying hi,
    a brief pause then the second two saying hi. Then exit with no error.

Manual testing on local dev cluster with local minio S3 store in docker
=======================================================================

Step 1      Enable the minio local dev plugin in freya by copying scripts/plugins/init-minio.sh into
            ~/.freya/local-dev/plugins/ (create this folder if missing)
Step 2      Copy memsql-report-kubectl.sh over ../../../assets/report/memsql-report-kubectl.sh
            ### DO NOT COMMIT this test script into the prod code. ###
Step 3      Create a local cluster and create a report through the web front end:
            freya$ make start-local-helios
            Enable minio by logging in http://172.18.0.5:9000/minio/login
            (open local dev HELIOS link shown in browser probably http://localhost:8001/admin)
            click reports
            click create
Step 4      Inspect report output files in minio browser 
