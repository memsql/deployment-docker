#!/usr/bin/python3

import boto3
import configparser
import json
import logging
import requests
import os

def _must_get_env(var, redact_log=False):
    val = os.getenv(var)
    if val is None:
        logging.error("Missing required environment variable {}".format(var))
        raise Exception("Environment variable {} is required".format(var))
    logging.info("Got {} = {}".format(var, val if not redact_log else "<redacted>"))
    return val

def download_bottle_version(ref, githubToken):
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
        print('failed to download BOTTLE_VERSION file: %s' % err)
        raise

def generate_release_metadata_file(file_name, data):
    with open(file_name, 'w') as f:
        json.dump(data, f)

def upload_release_metadata_file(bucket, region, accessKeyID, accessKeySecret, file_name, release):
    s3 = boto3.client('s3')
    key = "memsqlserver/%s/%s" % (release, file_name)
    s3.upload_file(file_name, bucket, key)

if __name__ == "__main__":
    try:
        memsqlServerVersion = _must_get_env("MEMSQL_SERVER_VERSION")
        memsqlReleaseChannel = _must_get_env("RELEASE_CHANNEL")
        releaseMetadataS3Bucket = _must_get_env("RELEASE_METADATA_BUCKET")
        releaseMetadataBucketRegion = _must_get_env("RELEASE_METADATA_BUCKET_REGION")
        releaseMetadataAWSAccessKeyID = _must_get_env("RELEASE_METADATA_AWS_ACCESS_KEY_ID", redact_log=True)
        releaseMetadataAWSAccessKeySecret = _must_get_env("RELEASE_METADATA_AWS_ACCESS_KEY_SECRET", redact_log=True)
        githubToken = _must_get_env("GITHUB_TOKEN", redact_log=True)
        bottleVersion = download_bottle_version("origin/master", githubToken)
        config = configparser.ConfigParser()
        config.read_string(bottleVersion)
        bottleVersionMajorStr = config['DEFAULT']['BOTTLE_VERSION_MAJOR']
        bottleVersionMinorStr = config['DEFAULT']['BOTTLE_VERSION_MINOR']
        bottleVersionPatchStr = config['DEFAULT']['BOTTLE_VERSION_PATCH']
        if not bottleVersionMajorStr.isdigit() or not bottleVersionMinorStr.isdigit() or not bottleVersionPatchStr.isdigit():
            raise Exception("BOTTLE_VERSION file contents are invalid: %s" % bottleVersion)
        releaseMetadataContents = {
            'bottleVersion': '%s.%s.%s' % (bottleVersionMajorStr, bottleVersionMinorStr, bottleVersionPatchStr),
        }
        releaseMetadataFile = "%s_%s_%s.json" % (bottleVersionMajorStr, bottleVersionMinorStr, bottleVersionPatchStr)
        generate_release_metadata_file(releaseMetadataFile, releaseMetadataContents)
        upload_release_metadata_file(releaseMetadataS3Bucket, releaseMetadataBucketRegion, releaseMetadataAWSAccessKeyID, releaseMetadataAWSAccessKeySecret, releaseMetadataFile, memsqlServerVersion)
    finally:
        if os.path.exists(releaseMetadataFile):
            os.remove(releaseMetadataFile)
