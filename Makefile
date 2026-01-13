TOOLBOX_VERSION=1.18.9
KUBE_CLIENT_VERSION=v1.11.6
REVISION=$(shell git describe --dirty=-dirty --always --long --abbrev=40 --match='')

VARIANT ?= alma
BASE_IMAGE_REGISTRY ?= us-central1-docker.pkg.dev/singlestore-public/dockerhub-mirror
BASE_IMAGE ?= almalinux:10

ifneq (${BASE_IMAGE_REGISTRY},)
	BASE_IMAGE:=${BASE_IMAGE_REGISTRY}/${BASE_IMAGE}
endif

TOOLS_TAG=${VARIANT}-${KUBE_CLIENT_VERSION}-${TOOLBOX_VERSION}-${REVISION}

.PHONY: build-base
build-base:
	docker build \
		--build-arg BASE_IMAGE=${BASE_IMAGE} \
		--build-arg TOOLBOX_VERSION=${TOOLBOX_VERSION} \
		--build-arg KUBE_CLIENT_VERSION=${KUBE_CLIENT_VERSION} \
		--build-arg RELEASE_CHANNEL=production \
		-t tools-base:${VARIANT} \
		-f Dockerfile-base .


.PHONY: build-tools
build-tools: build-base
	docker build \
		--build-arg BASE_IMAGE=tools-base:${VARIANT} \
		-t singlestore/tools:${TOOLS_TAG} \
		-f Dockerfile-tools .
	docker tag singlestore/tools:${TOOLS_TAG} singlestore/tools:latest
	docker tag singlestore/tools:${TOOLS_TAG} memsql/tools:${TOOLS_TAG}
	docker tag singlestore/tools:${TOOLS_TAG} memsql/tools:latest


.PHONY: publish-tools
publish-tools:
	docker push singlestore/tools:${TOOLS_TAG}
	docker push singlestore/tools:latest
	docker push memsql/tools:${TOOLS_TAG}
	docker push memsql/tools:latest

.PHONY: build-tools-minimal
build-tools-minimal: build-base
	docker build \
		--build-arg BASE_IMAGE=tools-base:${VARIANT} \
		-t gcr.io/singlestore-public/tools-min:${TOOLS_TAG} \
		-f Dockerfile-tools-minimal .
	docker tag gcr.io/singlestore-public/tools-min:${TOOLS_TAG} gcr.io/singlestore-public/tools-min:latest


.PHONY: publish-tools-minimal
publish-tools-minimal:
	gcloud auth login
	docker push gcr.io/singlestore-public/tools-min:${TOOLS_TAG}
	docker push gcr.io/singlestore-public/tools-min:latest
