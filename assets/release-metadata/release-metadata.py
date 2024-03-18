#!/usr/bin/python3

import boto3
import configparser
import json
import logging
import requests
import os

def _must_get_env(var, redact_log=False):
    logging.info("Extracting environment variable {}".format(var))
    val = os.getenv(var)
    if val is None:
        logging.error("Missing required environment variable {}".format(var))
        raise Exception("Environment variable {} is required".format(var))
    logging.info("Got {} = {}".format(var, val if not redact_log else "<redacted>"))
    return val

def download_bottle_version(ref, githubToken):
    logging.info("Downloading BOTTLE_VERSION file from GitHub")
    headers = {
        'Authorization': 'token ' + githubToken.strip(),
    }

    try:
        response = requests.get(
            'https://raw.githubusercontent.com/memsql/memsql/%s/BOTTLE_VERSION' % ref.replace("origin/", ""),
            headers=headers,
        )
        response.raise_for_status()
        return response.text.strip()
    except requests.exceptions.HTTPError as err:
        logging.error('failed to download BOTTLE_VERSION file: %s' % err)
        raise

def generate_release_metadata_file(fileName, data):
    logging.info("Generating release metadata file %s with contents (%s)" % (fileName, data))
    with open(fileName, 'wb') as f:
        f.write(json.dumps(data, indent=2).encode('utf-8'))

def upload_release_metadata_file(bucket, region, accessKeyID, accessKeySecret, fileName, release):
    key = "memsqlserver/%s/%s" % (release, fileName)
    logging.info("Uploading release metadata file '%s' to S3" % key)
    s3 = boto3.resource('s3', aws_access_key_id=accessKeyID, aws_secret_access_key=accessKeySecret, region_name=region)
    s3.meta.client.upload_file(fileName, bucket, key)

if __name__ == "__main__":
    try:
        logging.basicConfig(level=os.environ.get("LOGLEVEL", "INFO"))
        memsqlServerVersion = _must_get_env("MEMSQL_SERVER_VERSION")
        memsqlReleaseChannel = _must_get_env("RELEASE_CHANNEL")
        releaseBranch = _must_get_env("RELEASE_BRANCH")
        releaseMetadataS3Bucket = _must_get_env("RELEASE_METADATA_AWS_BUCKET_NAME")
        releaseMetadataBucketRegion = _must_get_env("RELEASE_METADATA_AWS_REGION")
        releaseMetadataAWSAccessKeyID = _must_get_env("RELEASE_METADATA_AWS_ACCESS_KEY_ID", redact_log=True)
        releaseMetadataAWSAccessKeySecret = _must_get_env("RELEASE_METADATA_AWS_SECRET_ACCESS_KEY", redact_log=True)
        githubToken = _must_get_env("GITHUB_TOKEN", redact_log=True)
        bottleVersion = download_bottle_version(releaseBranch, githubToken)
        config = configparser.ConfigParser()
        config.read_string('[default]\n' + bottleVersion)
        bottleVersionMajorStr = config['default']['BOTTLE_VERSION_MAJOR']
        bottleVersionMinorStr = config['default']['BOTTLE_VERSION_MINOR']
        bottleVersionPatchStr = config['default']['BOTTLE_VERSION_PATCH']
        if not bottleVersionMajorStr.isdigit() or not bottleVersionMinorStr.isdigit() or not bottleVersionPatchStr.isdigit():
            raise Exception("BOTTLE_VERSION file contents are invalid: %s" % bottleVersion)
        releaseMetadataContents = {
            'bottleVersion': '%s.%s.%s' % (bottleVersionMajorStr, bottleVersionMinorStr, bottleVersionPatchStr),
        }
        releaseMetadataFile = "%s.json" % memsqlServerVersion
        generate_release_metadata_file(releaseMetadataFile, releaseMetadataContents)
        upload_release_metadata_file(releaseMetadataS3Bucket, releaseMetadataBucketRegion, releaseMetadataAWSAccessKeyID, releaseMetadataAWSAccessKeySecret, releaseMetadataFile, memsqlReleaseChannel)
    finally:
        if os.path.exists(releaseMetadataFile):
            os.remove(releaseMetadataFile)