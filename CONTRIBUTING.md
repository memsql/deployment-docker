The Continuous Integration (CI) associated with this repository is responsible for
publishing these images in Docker Hub Container Registry.

# Publishing Images

This project relies on publicly-available versions of singlestoredb-studio and singlestoredb-toolbox, so make sure that your target
versions have already been released.

1. Update the `Makefile` in the root of this repository to refer to the new version of the product you're releasing.
2. Use the standard `arc` and Phabricator workflow for code reviewing the change. (if you're not a SingleStore employee, please send a Pull Request through GitHub)
3. One you land, CircleCI will automatically start a new pipeline for that commit.
4. When the tests pass, run the publish jobs in CircleCI to push everything to Docker Hub and Red Hat's equivalent.


# Accessing CI/CD Pipeline on CircleCI
There are two ways:
1. Go to the [CircleCI page](https://app.circleci.com/pipelines/github/memsql/deployment-docker) directly, and sign in with your GitHub account to find the pipeline for your commit.
2. Go to [GitHub](https://github.com) to find your [commit](https://github.com/memsql/deployment-docker/commits/master).
   There is a single yellow dot next to your commit. Click on the yellow dot and it will show you various jobs you can run on CircleCI.