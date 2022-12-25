def NAME = "memsql-base-automation-image-builder"
def EMAIL = "_devmicrocosm@kenshoo.com"
def JOB_NAME = "${NAME}-release"
def BRANCH_NAME = "master"

job(JOB_NAME) {
    label("microcosm-ubuntu-base")

    logRotator(10,10)
    concurrentBuild(true)

    throttleConcurrentBuilds{
        maxPerNode 1
        maxTotal 10
    }

    scm {
        git {
            remote {
                url("https://github.com/kenshoo/${NAME}.git")
                credentials('jenkins-microcosm-github-app')
                refspec("+refs/heads/${BRANCH_NAME}:refs/remotes/origin/${BRANCH_NAME}")
            }

            configure { node ->
                node / 'extensions' / 'hudson.plugins.git.extensions.impl.CleanBeforeCheckout' {}
            }

            branch(BRANCH_NAME)
        }
    }

    configure { project ->
        def properties = project / 'properties'
        properties<< {
            'com.coravy.hudson.plugins.github.GithubProjectProperty'{
                projectUrl "https://github.com/kenshoo/${NAME}/"
            }
        }
    }

    wrappers {
        preBuildCleanup()
        timestamps()
        injectPasswords()
        colorizeOutput()
        timeout {
            absolute(120)
        }
        sshAgent('kgithub-build-jenkins-microcosm-key')
        credentialsBinding {
            usernamePassword('MICROSERVICES_ARTIFACTORY_USER', 'MICROSERVICES_ARTIFACTORY_PASSWORD', 'jcasc_deployer-microcosm')
        }
    }

    steps {
        shell("""
          make
          docker build -t kenshoo-docker.jfrog.io/TEMP-FOR-TESTING-ks-db-memsql-76-cluster-in-a-box-base -f Dockerfile-ciab . && echo "Successfully built base image"
          docker push kenshoo-docker.jfrog.io/TEMP-FOR-TESTING-ks-db-memsql-76-cluster-in-a-box-base && echo "Successfully pushed image"
      """)
    }

    publishers {

        extendedEmail {
            recipientList("${EMAIL}")
            triggers {
                unstable {
                    sendTo {
                        requester()
                        developers()
                    }
                }
                failure {
                    sendTo {
                        requester()
                        developers()
                    }
                }
                statusChanged {
                    sendTo {
                        requester()
                        developers()
                    }
                }

                configure { node ->
                    node / contentType << 'text/html'
                }
            }
        }

    }
}