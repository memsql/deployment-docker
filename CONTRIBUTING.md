The Continuous Integration (CI) associated with this repository is responsible for
publishing these images in Docker Hub and the Red Hat Container Registry.

# Publishing Images

These instructions assume that this the image is being updated as part of a
MemSQL product release. This project relies on publicly-available versions of
memsql-server, memsql-studio, and memsql-toolbox, so make sure that your target
versions have already been released.

1. Update the `Makefile` in the root of this repository to refer to the new version of the product you're releasing.
2. Use the standard `arc` and Phabricator workflow for code reviewing the change. (if you're not a MemSQL employee, please send a Pull Request through GitHub)
3. One you land, CircleCI will automatically start a new pipeline for that commit.
4. When the tests pass, run the publish jobs in CircleCI to push everything to Docker Hub and Red Hat's equivalent.

# Testing Changes

To test changes to this repository, run the following command:

```bash
RELEASE_ID=latest LICENSE_KEY=$LICENSE_KEY make test
```

# Accessing CI/CD Pipeline on CircleCI
There are two ways:
1. Go to the [CircleCI page](https://app.circleci.com/pipelines/github/memsql/deployment-docker) directly, and sign in with your GitHub account to find the pipeline for your commit.
2. Go to [GitHub](https://github.com) to find your [commit](https://github.com/memsql/deployment-docker/commits/master).
   There is a single yellow dot next to your commit. Click on the yellow dot and it will show you various jobs you can run on CircleCI.

# RHEL containers

By default, we only build CentOS containers. The RHEL containers must be built
on an entitled RHEL7 system with RH-provided docker. The RHEL containers will
be built by RedHat's auto-builder.

Program requirements are dictated by RedHat, and are available at:
https://connect.redhat.com/zones/containers/container-certification-policy-guide
