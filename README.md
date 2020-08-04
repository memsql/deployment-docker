# deployment-docker

Contains our "official" deployment Docker images.

| Image        | MemSQL Packages Installed                    |
| ------------ | -------------------------------------------- |
| ciab         | memsql-server, memsql-studio, memsql-toolbox |
| ciab-redhat  | memsql-server, memsql-studio, memsql-toolbox |
| dynamic-node | (none)                                       |
| node         | memsql-server                                |
| node-redhat  | memsql-server                                |
| tools        | memsql-toolbox                               |

# Testing Changes

To test changes to this repository, run the following command:

```bash
RELEASE_ID=latest LICENSE_KEY=$LICENSE_KEY make test
```

# Running Cluster in a Box

To initialize a new cluster in a box:

```bash
docker run -i --init \
    --name memsql-ciab \
    -e LICENSE_KEY=${LICENSE_KEY} \
    -p 3306:3306 -p 8080:8080 \
    memsql/cluster-in-a-box
```

To manage your cluster in a box:

```bash
To start the container:
    docker start memsql-ciab

To read logs from the container:
    docker logs memsql-ciab

To stop the container (must be started):
    docker stop memsql-ciab

To restart the container (must be started):
    docker restart memsql-ciab

To remove the container (all data will be deleted):
    docker rm memsql-ciab
```

# Automatically run SQL when Cluster in a Box initializes

If you want to automatically run SQL commands when creating a Cluster in a Box
container, you can mount a SQL file into the Docker container like so:

```bash
docker run -i --init \
    --name memsql-ciab \
    -e LICENSE_KEY=${LICENSE_KEY} \
    -v /PATH/TO/INIT.SQL:/init.sql \
    -p 3306:3306 -p 8080:8080 \
    memsql/cluster-in-a-box
```

**Replace `/PATH/TO/INIT.SQL` with a valid path on your machine to the SQL file
you want to run when initializing Cluster in a Box.**

# RHEL containers

By default, we only build CentOS containers.  The RHEL containers must be built
on an entitled RHEL7 system with RH-provided docker.  The RHEL containers will
be built by RedHat's auto-builder.

Program requirements are dictated by RedHat, and are available at:
https://connect.redhat.com/zones/containers/container-certification-policy-guide

# Accessing CI/CD Pipeline on CircleCI
There are two ways:
1. Go to the [CircleCI page](https://app.circleci.com/pipelines/github/memsql/deployment-docker) directly, and sign in with your GitHub account to find the pipeline for your commit.
2. Go to [GitHub](https://github.com) to find your [commit](https://github.com/memsql/deployment-docker/commits/master).
   There is a single yellow dot next to your commit. Click on the yellow dot and it will show you various jobs you can run on CircleCI.

# Publishing Images

These instructions assume that this the image is being updated as part of a MemSQL product release.  This project relies on publicly-available versions of memsql-server, memsql-studio, and memsql-toolbox, so make sure that your target versions have already been released in Freya.

1. Update the Makefile in the root of this repository to refer to the new version of the product you're releasing.
2. Use the standard `arc` and Phabricator workflow for code reviewing the change.
3. One you land, CircleCI will automatically start a new pipeline for that commit.
4. When the tests pass, run the publish jobs to push everything to Docker Hub and Red Hat's equivalent.
