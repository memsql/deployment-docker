# deployment-docker

This repository contains our official deployment Docker images for various products.
If you are interested in contributing, please read `CONTRIBUTING.md`.

| Image        | MemSQL Packages Installed                    |
| ------------ | -------------------------------------------- |
| ciab         | memsql-server, memsql-studio, memsql-toolbox |
| ciab-redhat  | memsql-server, memsql-studio, memsql-toolbox |
| dynamic-node | (none)                                       |
| node         | memsql-server                                |
| node-redhat  | memsql-server                                |
| tools        | memsql-toolbox                               |

# Running the Cluster in a Box image

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
