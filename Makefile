TOOLBOX_VERSION=1.18.7
KUBE_CLIENT_VERSION=v1.11.6
REVISION=$(shell git describe --dirty=-dirty --always --long --abbrev=40 --match='')

VARIANT ?= alma
BASE_IMAGE_REGISTRY ?= gcr.io/internal_freya
BASE_IMAGE ?= almalinux:8.7

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
		-t singlestore/tools-min:${TOOLS_TAG} \
		-f Dockerfile-tools-minimal .
	docker tag singlestore/tools-min:${TOOLS_TAG} singlestore/tools-min:latest
	docker tag singlestore/tools-min:${TOOLS_TAG} memsql/tools-min:${TOOLS_TAG}
	docker tag singlestore/tools-min:${TOOLS_TAG} memsql/tools-min:latest


.PHONY: publish-tools-minimal
publish-tools-minimal:
	docker push singlestore/tools-min:${TOOLS_TAG}
	docker push singlestore/tools-min:latest
	docker push memsql/tools-min:${TOOLS_TAG}
	docker push memsql/tools-min:latest
