# Overview

`memsql-report-kubectl.sh` is the entrypoint for collecting a cluster report.

The report is collected as a part of a K8s job against a customer DB cluster.

For historical reasons, the script is called `memsql-report-kubectl.sh`. Collection of a cluster report is executed by running the `sdb-report collect-kube` command that performs K8s calls to collect all the information about the cluster.

# Testing

## Directly

The base step is to spin a local environment and create a DB cluster (preferably using helios local dev setup).

```bash
# S3 config
export AWS_ACCESS_KEY="admin"
export AWS_ACCESS_KEY_ID="admin"
export AWS_SECRET_ACCESS_KEY="password"
export S3_REPORT_ENDPOINT="http://localhost:8005"
export S3_REPORT_PATH="abc"
export S3_REPORT_BUCKET="local_bucket/reports/manual"

# cluster name
export CLUSTER_NAME="442c032e-89fc-4342-b16d-c87a51d4d436"

# command run to collect a report, check it, and upload results to S3
./memsql-report-kubectl.sh

# admin type report includes more collectors and runs checkers
export REPORT_TYPE="Admin"
export COLLECTOR_SUBSET="memsqlAuditlogs"
./memsql-report-kubectl.sh

# customer type includes only indicated collectors and doesn't run checkers
export REPORT_TYPE="Customer"
export COLLECTOR_SUBSET="memsqlAuditlogs"
./memsql-report-kubectl.sh
```

## Using Helios Mutation

To test changes to report-related logic follow [this](https://memsql.atlassian.net/wiki/spaces/MCDB/pages/1669661216/Cluster+report+script+in+deployment-docker) wiki page. Note that only an admin mutation is in use.
