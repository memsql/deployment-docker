# this is the server version for cluster-in-a-box
SERVER_VERSION=8.7.14-4c3ad9de46

CLIENT_VERSION=1.0.5
TOOLBOX_VERSION=1.17.17
STUDIO_VERSION=4.1.0
KUBE_CLIENT_VERSION=v1.11.6
REVISION=$(shell git describe --dirty=-dirty --always --long --abbrev=40 --match='')

VARIANT ?= alma
BASE_IMAGE_REGISTRY ?= gcr.io/internal_freya
BASE_IMAGE ?= almalinux:8.6

ifeq (${VARIANT},redhat)
	BASE_IMAGE=registry.access.redhat.com/ubi8/ubi:8.6-903
else
	ifneq (${BASE_IMAGE_REGISTRY},)
		BASE_IMAGE:=${BASE_IMAGE_REGISTRY}/${BASE_IMAGE}
	endif
endif

CIAB_TAG=${VARIANT}-${SERVER_VERSION}-${STUDIO_VERSION}-${TOOLBOX_VERSION}
TOOLS_TAG=${VARIANT}-${KUBE_CLIENT_VERSION}-${TOOLBOX_VERSION}-${REVISION}

.PHONY: test
test:
	# cluster-in-a-box (ciab)
	${MAKE} build-ciab
	${MAKE} test-ciab
	${MAKE} test-ciab-no-license

.PHONY: build-base
build-base:
	docker build \
		--build-arg BASE_IMAGE=${BASE_IMAGE} \
		--build-arg RELEASE_CHANNEL=production \
		-t s2-base:${VARIANT} \
		-f Dockerfile-base .

.PHONY: build-base-dev
build-base-dev:
	docker build \
		--build-arg BASE_IMAGE=${BASE_IMAGE} \
		--build-arg RELEASE_CHANNEL=dev \
		-t s2-base-dev:${VARIANT} \
		-f Dockerfile-base .

.PHONY: build-tools
build-tools: build-base
	docker build \
		--build-arg BASE_IMAGE=s2-base:${VARIANT} \
		--build-arg TOOLBOX_VERSION=${TOOLBOX_VERSION} \
		--build-arg KUBE_CLIENT_VERSION=${KUBE_CLIENT_VERSION} \
		-t singlestore/tools:${TOOLS_TAG} \
		-f Dockerfile-tools .
	docker tag singlestore/tools:${TOOLS_TAG} singlestore/tools:latest
	docker tag singlestore/tools:${TOOLS_TAG} memsql/tools:${TOOLS_TAG}
	docker tag singlestore/tools:${TOOLS_TAG} memsql/tools:latest

.PHONY: build-ciab
build-ciab: build-base
	docker build \
		--build-arg BASE_IMAGE=s2-base:${VARIANT} \
		--build-arg SERVER_PACKAGE=singlestoredb-server \
		--build-arg SERVER_VERSION=${SERVER_VERSION} \
		--build-arg CLIENT_VERSION=${CLIENT_VERSION} \
		--build-arg STUDIO_VERSION=${STUDIO_VERSION} \
		--build-arg TOOLBOX_VERSION=${TOOLBOX_VERSION} \
		--build-arg JRE_PACKAGES="java-21-openjdk" \
		-t singlestore/cluster-in-a-box:${CIAB_TAG} \
		-f Dockerfile-ciab .
	docker tag singlestore/cluster-in-a-box:${CIAB_TAG} singlestore/cluster-in-a-box:latest
	docker tag singlestore/cluster-in-a-box:${CIAB_TAG} memsql/cluster-in-a-box:${CIAB_TAG}
	docker tag memsql/cluster-in-a-box:${CIAB_TAG} memsql/cluster-in-a-box:latest

.PHONY: build-ciab-dev
build-ciab-dev: build-base-dev
	docker build \
		--build-arg BASE_IMAGE=s2-base-dev:${VARIANT} \
		--build-arg SERVER_PACKAGE=memsql-server \
		--build-arg SERVER_VERSION=${SERVER_VERSION} \
		--build-arg CLIENT_VERSION=${CLIENT_VERSION} \
		--build-arg STUDIO_VERSION=${STUDIO_VERSION} \
		--build-arg TOOLBOX_VERSION=${TOOLBOX_VERSION} \
		--build-arg JRE_PACKAGES="java-21-openjdk" \
		-t singlestore/cluster-in-a-box-dev:${CIAB_TAG} \
		-f Dockerfile-ciab .
	docker tag singlestore/cluster-in-a-box-dev:${CIAB_TAG} singlestore/cluster-in-a-box-dev:latest
	docker tag singlestore/cluster-in-a-box-dev:${CIAB_TAG} memsql/cluster-in-a-box-dev:${CIAB_TAG}
	docker tag memsql/cluster-in-a-box-dev:${CIAB_TAG} memsql/cluster-in-a-box-dev:latest

.PHONY: test-ciab
test-ciab: test-destroy
	IMAGE=singlestore/cluster-in-a-box:${CIAB_TAG} ./test/ciab ${LICENSE_KEY}

.PHONY: test-ciab-no-license
test-ciab-no-license: test-destroy
	IMAGE=singlestore/cluster-in-a-box:${CIAB_TAG} ./test/ciab

.PHONY: publish-ciab
publish-ciab:
	docker push singlestore/cluster-in-a-box:${CIAB_TAG}
	docker push singlestore/cluster-in-a-box:latest
	docker push memsql/cluster-in-a-box:${CIAB_TAG}
	docker push memsql/cluster-in-a-box:latest

.PHONY: test-destroy
test-destroy:
	@-docker rm -f memsql-node-ma memsql-node-leaf memsql-ciab
	@-docker volume rm memsql-node-ma memsql-node-leaf memsql-ciab

.PHONY: publish-tools
publish-tools:
	docker push singlestore/tools:${TOOLS_TAG}
	docker push singlestore/tools:latest
	docker push memsql/tools:${TOOLS_TAG}
	docker push memsql/tools:latest

.PHONY: requires-license
requires-license:
ifndef LICENSE_KEY
	$(error LICENSE_KEY is required)
endif
