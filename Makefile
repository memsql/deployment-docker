SERVER_VERSION=7.5.9-a8744b5453
SERVER_VERSION_PREVIEW=7.0.5-6b319cdd26
SERVER_VERSION_6_5=6.5.27-53746e2b5a
SERVER_VERSION_6_8=6.8.24-8e110b7bed
SERVER_VERSION_7_0=7.0.24-48304cf854
SERVER_VERSION_7_1=7.1.21-914af0b97e
SERVER_VERSION_7_3=7.3.16-8d9c1b9863
CLIENT_VERSION=1.0.3
TOOLBOX_VERSION=1.12.0
STUDIO_VERSION=3.2.11
KUBE_CLIENT_VERSION=v1.11.6
REVISION=$(shell git describe --dirty=-dirty --always --long --abbrev=40 --match='')

VARIANT ?= centos

ifeq (${VARIANT},redhat)
BASE_IMAGE=registry.access.redhat.com/ubi7/ubi:7.7-358
else
BASE_IMAGE=centos:7
endif

NODE_TAG=${VARIANT}-${SERVER_VERSION}
NODE_TAG_PREVIEW=${VARIANT}-${SERVER_VERSION_PREVIEW}-preview
NODE_TAG_6_5=${VARIANT}-${SERVER_VERSION_6_5}
NODE_TAG_6_8=${VARIANT}-${SERVER_VERSION_6_8}
NODE_TAG_7_0=${VARIANT}-${SERVER_VERSION_7_0}
NODE_TAG_7_1=${VARIANT}-${SERVER_VERSION_7_1}
NODE_TAG_7_3=${VARIANT}-${SERVER_VERSION_7_3}
DYNAMIC_TAG=${VARIANT}-${REVISION}
CIAB_TAG=${VARIANT}-${SERVER_VERSION}-${STUDIO_VERSION}-${TOOLBOX_VERSION}
TOOLS_TAG=${VARIANT}-${KUBE_CLIENT_VERSION}-${TOOLBOX_VERSION}-${REVISION}

.PHONY: build
build:
	${MAKE} build-dynamic-node
	${MAKE} build-ciab

.PHONY: build-dev
build-dev: build
	${MAKE} build-ciab-dev

.PHONY: test
test:
	# node
	${MAKE} build-node
	${MAKE} test-node
	${MAKE} test-node-ssl
	# node-preview
	${MAKE} build-node-preview
	${MAKE} test-node-preview
	${MAKE} test-node-preview-ssl
	# node-6-5
	${MAKE} build-node-6-5
	${MAKE} test-node-6-5
	# node-6-8
	${MAKE} build-node-6-8
	${MAKE} test-node-6-8
	# node-7-0
	${MAKE} build-node-7-0
	${MAKE} test-node-7-0
	# node-7-1
	${MAKE} build-node-7-1
	${MAKE} test-node-7-1
	# node-7-3
	${MAKE} build-node-7-3
	${MAKE} test-node-7-3
	# node-redhat
	${MAKE} build-node VARIANT=redhat
	${MAKE} test-node VARIANT=redhat
	# node-7-0-redhat
	${MAKE} build-node-7-0 VARIANT=redhat
	${MAKE} test-node-7-0 VARIANT=redhat
	# node-7-1-redhat
	${MAKE} build-node-7-1 VARIANT=redhat
	${MAKE} test-node-7-1 VARIANT=redhat
	# node-7-3-redhat
	${MAKE} build-node-7-3 VARIANT=redhat
	${MAKE} test-node-7-3 VARIANT=redhat
	# dynamic node
	${MAKE} build-dynamic-node
	${MAKE} test-dynamic-node
	# cluster-in-a-box (ciab)
	${MAKE} build-ciab
	${MAKE} test-ciab
	# cluster-in-a-box (ciab) redhat
	${MAKE} build-ciab VARIANT=redhat
	${MAKE} test-ciab VARIANT=redhat

.PHONY: build-base
build-base:
	docker build \
		--build-arg BASE_IMAGE=${BASE_IMAGE} \
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

.PHONY: build-node
build-node: build-base
	docker build \
		--build-arg BASE_IMAGE=s2-base:${VARIANT} \
		--build-arg SERVER_VERSION=${SERVER_VERSION} \
		--build-arg CLIENT_VERSION=${CLIENT_VERSION} \
		-t singlestore/node:${NODE_TAG} \
		-f Dockerfile-node .
	docker tag singlestore/node:${NODE_TAG} singlestore/node:latest
	docker tag singlestore/node:${NODE_TAG} memsql/node:${NODE_TAG}
	docker tag singlestore/node:${NODE_TAG} memsql/node:latest

.PHONY: build-node-preview
build-node-preview: build-base-dev
	docker build \
		--build-arg BASE_IMAGE=s2-base-dev:${VARIANT} \
		--build-arg SERVER_VERSION=${SERVER_VERSION_PREVIEW} \
		--build-arg CLIENT_VERSION=${CLIENT_VERSION} \
		-t singlestore/node:${NODE_TAG_PREVIEW} \
		-f Dockerfile-node .
	docker tag singlestore/node:${NODE_TAG_PREVIEW} memsql/node:${NODE_TAG_PREVIEW}

.PHONY: build-node-6-5
build-node-6-5: build-base-dev
	docker build \
		--build-arg BASE_IMAGE=s2-base-dev:${VARIANT} \
		--build-arg SERVER_VERSION=${SERVER_VERSION_6_5} \
		--build-arg CLIENT_VERSION=${CLIENT_VERSION} \
		-t singlestore/node:${NODE_TAG_6_5} \
		-f Dockerfile-node .
	docker tag singlestore/node:${NODE_TAG_6_5} memsql/node:${NODE_TAG_6_5}

.PHONY: build-node-6-8
build-node-6-8: build-base
	docker build \
		--build-arg BASE_IMAGE=s2-base:${VARIANT} \
		--build-arg SERVER_VERSION=${SERVER_VERSION_6_8} \
		--build-arg CLIENT_VERSION=${CLIENT_VERSION} \
		-t singlestore/node:${NODE_TAG_6_8} \
		-f Dockerfile-node .
	docker tag singlestore/node:${NODE_TAG_6_8} memsql/node:${NODE_TAG_6_8}

.PHONY: build-node-7-0
build-node-7-0: build-base
	docker build \
		--build-arg BASE_IMAGE=s2-base:${VARIANT} \
		--build-arg SERVER_VERSION=${SERVER_VERSION_7_0} \
		--build-arg CLIENT_VERSION=${CLIENT_VERSION} \
		-t singlestore/node:${NODE_TAG_7_0} \
		-f Dockerfile-node .
	docker tag singlestore/node:${NODE_TAG_7_0} memsql/node:${NODE_TAG_7_0}

.PHONY: build-node-7-1
build-node-7-1: build-base
	docker build \
		--build-arg BASE_IMAGE=s2-base:${VARIANT} \
		--build-arg SERVER_VERSION=${SERVER_VERSION_7_1} \
		--build-arg CLIENT_VERSION=${CLIENT_VERSION} \
		-t singlestore/node:${NODE_TAG_7_1} \
		-f Dockerfile-node .
	docker tag singlestore/node:${NODE_TAG_7_1} memsql/node:${NODE_TAG_7_1}

.PHONY: build-node-7-3
build-node-7-3: build-base
	docker build \
		--build-arg BASE_IMAGE=s2-base:${VARIANT} \
		--build-arg SERVER_VERSION=${SERVER_VERSION_7_3} \
		--build-arg CLIENT_VERSION=${CLIENT_VERSION} \
		-t singlestore/node:${NODE_TAG_7_3} \
		-f Dockerfile-node .
	docker tag singlestore/node:${NODE_TAG_7_3} memsql/node:${NODE_TAG_7_3}

.PHONY: test-node
test-node: test-destroy
	IMAGE=singlestore/node:${NODE_TAG} ./test/node

.PHONY: test-node-preview
test-node-preview: test-destroy
	IMAGE=singlestore/node:${NODE_TAG_PREVIEW} ./test/node

.PHONY: test-node-6-5
test-node-6-5: test-destroy
	IMAGE=singlestore/node:${NODE_TAG_6_5} ./test/node

.PHONY: test-node-6-8
test-node-6-8: test-destroy
	IMAGE=singlestore/node:${NODE_TAG_6_8} ./test/node

.PHONY: test-node-7-0
test-node-7-0: test-destroy
	IMAGE=singlestore/node:${NODE_TAG_7_0} ./test/node

.PHONY: test-node-7-1
test-node-7-1: test-destroy
	IMAGE=singlestore/node:${NODE_TAG_7_1} ./test/node

.PHONY: test-node-7-3
test-node-7-3: test-destroy
	IMAGE=singlestore/node:${NODE_TAG_7_3} ./test/node

.PHONY: test-node-ssl
test-node-ssl: test-destroy
	IMAGE=singlestore/node:${NODE_TAG} ./test/node-ssl

.PHONY: test-node-preview-ssl
test-node-preview-ssl: test-destroy
	IMAGE=singlestore/node:${NODE_TAG_PREVIEW} ./test/node-ssl

.PHONY: publish-node
publish-node:
	docker push singlestore/node:${NODE_TAG}
	docker push memsql/node:${NODE_TAG}
	docker push singlestore/node:latest
	docker push memsql/node:latest

.PHONY: stage-node
stage-node:
	docker tag singlestore/node:${NODE_TAG} singlestore/node:staging-${NODE_TAG}
	docker push singlestore/node:staging-${NODE_TAG}
	docker tag memsql/node:${NODE_TAG} memsql/node:staging-${NODE_TAG}
	docker push memsql/node:staging-${NODE_TAG}

.PHONY: publish-node-preview
publish-node-preview:
	docker push singlestore/node:${NODE_TAG_PREVIEW}
	docker push memsql/node:${NODE_TAG_PREVIEW}

.PHONY: stage-node-preview
stage-node-preview:
	docker tag singlestore/node:${NODE_TAG_PREVIEW} singlestore/node:staging-${NODE_TAG_PREVIEW}
	docker push singlestore/node:staging-${NODE_TAG_PREVIEW}
	docker tag memsql/node:${NODE_TAG_PREVIEW} memsql/node:staging-${NODE_TAG_PREVIEW}
	docker push memsql/node:staging-${NODE_TAG_PREVIEW}

.PHONY: publish-node-6-5
publish-node-6-5:
	docker push singlestore/node:${NODE_TAG_6_5}
	docker push memsql/node:${NODE_TAG_6_5}

.PHONY: publish-node-6-8
publish-node-6-8:
	docker push singlestore/node:${NODE_TAG_6_8}
	docker push memsql/node:${NODE_TAG_6_8}

.PHONY: publish-node-7-0
publish-node-7-0:
	docker push singlestore/node:${NODE_TAG_7_0}
	docker push memsql/node:${NODE_TAG_7_0}

.PHONY: publish-node-7-1
publish-node-7-1:
	docker push singlestore/node:${NODE_TAG_7_1}
	docker push memsql/node:${NODE_TAG_7_1}

.PHONY: publish-node-7-3
publish-node-7-3:
	docker push singlestore/node:${NODE_TAG_7_3}
	docker push memsql/node:${NODE_TAG_7_3}

.PHONY: redhat-verify-node
redhat-verify-node:
	docker tag singlestore/node:${NODE_TAG} scan.connect.redhat.com/ospid-faf4ba09-5344-40d5-b9c5-7c88ea143472/node:${NODE_TAG}
	docker push scan.connect.redhat.com/ospid-faf4ba09-5344-40d5-b9c5-7c88ea143472/node:${NODE_TAG}
	@echo "View results + publish: https://connect.redhat.com/project/1123901/view"

.PHONY: redhat-verify-node-7-0
redhat-verify-node-7-0:
	docker tag singlestore/node:${NODE_TAG_7_0} scan.connect.redhat.com/ospid-faf4ba09-5344-40d5-b9c5-7c88ea143472/node:${NODE_TAG_7_0}
	docker push scan.connect.redhat.com/ospid-faf4ba09-5344-40d5-b9c5-7c88ea143472/node:${NODE_TAG_7_0}
	@echo "View results + publish: https://connect.redhat.com/project/1123901/view"

.PHONY: redhat-verify-node-7-1
redhat-verify-node-7-1:
	docker tag singlestore/node:${NODE_TAG_7_1} scan.connect.redhat.com/ospid-faf4ba09-5344-40d5-b9c5-7c88ea143472/node:${NODE_TAG_7_1}
	docker push scan.connect.redhat.com/ospid-faf4ba09-5344-40d5-b9c5-7c88ea143472/node:${NODE_TAG_7_1}
	@echo "View results + publish: https://connect.redhat.com/project/1123901/view"

.PHONY: redhat-verify-node-7-3
redhat-verify-node-7-3:
	docker tag singlestore/node:${NODE_TAG_7_3} scan.connect.redhat.com/ospid-faf4ba09-5344-40d5-b9c5-7c88ea143472/node:${NODE_TAG_7_3}
	docker push scan.connect.redhat.com/ospid-faf4ba09-5344-40d5-b9c5-7c88ea143472/node:${NODE_TAG_7_3}
	@echo "View results + publish: https://connect.redhat.com/project/1123901/view"

.PHONY: build-dynamic-node
build-dynamic-node: build-base
	docker build \
		--build-arg BASE_IMAGE=s2-base:${VARIANT} \
		--build-arg CLIENT_VERSION=${CLIENT_VERSION} \
		-t singlestore/dynamic-node:${DYNAMIC_TAG} \
		-f Dockerfile-dynamic .
	docker tag singlestore/dynamic-node:${DYNAMIC_TAG} singlestore/dynamic-node:latest
	docker tag singlestore/dynamic-node:${DYNAMIC_TAG} memsql/dynamic-node:${DYNAMIC_TAG}
	docker tag memsql/dynamic-node:${DYNAMIC_TAG} memsql/dynamic-node:latest

.PHONY: test-dynamic-node
test-dynamic-node: test-destroy
	IMAGE=singlestore/dynamic-node:${DYNAMIC_TAG} ./test/node

.PHONY: publish-dynamic-node
publish-dynamic-node:
	docker push singlestore/dynamic-node:${DYNAMIC_TAG}
	docker push singlestore/dynamic-node:latest
	docker push memsql/dynamic-node:${DYNAMIC_TAG}
	docker push memsql/dynamic-node:latest

.PHONY: build-ciab
build-ciab: build-base
	docker build \
		--build-arg BASE_IMAGE=s2-base:${VARIANT} \
		--build-arg SERVER_VERSION=${SERVER_VERSION} \
		--build-arg CLIENT_VERSION=${CLIENT_VERSION} \
		--build-arg STUDIO_VERSION=${STUDIO_VERSION} \
		--build-arg TOOLBOX_VERSION=${TOOLBOX_VERSION} \
		-t singlestore/cluster-in-a-box:${CIAB_TAG} \
		-f Dockerfile-ciab .
	docker tag singlestore/cluster-in-a-box:${CIAB_TAG} singlestore/cluster-in-a-box:latest
	docker tag singlestore/cluster-in-a-box:${CIAB_TAG} memsql/cluster-in-a-box:${CIAB_TAG}
	docker tag memsql/cluster-in-a-box:${CIAB_TAG} memsql/cluster-in-a-box:latest

.PHONY: build-ciab-dev
build-ciab-dev: build-base-dev
	docker build \
		--build-arg BASE_IMAGE=s2-base-dev:${VARIANT} \
		--build-arg SERVER_VERSION=${SERVER_VERSION} \
		--build-arg CLIENT_VERSION=${CLIENT_VERSION} \
		--build-arg STUDIO_VERSION=${STUDIO_VERSION} \
		--build-arg TOOLBOX_VERSION=${TOOLBOX_VERSION} \
		-t singlestore/cluster-in-a-box-dev:${CIAB_TAG} \
		-f Dockerfile-ciab .
	docker tag singlestore/cluster-in-a-box-dev:${CIAB_TAG} singlestore/cluster-in-a-box-dev:latest
	docker tag singlestore/cluster-in-a-box-dev:${CIAB_TAG} memsql/cluster-in-a-box-dev:${CIAB_TAG}
	docker tag memsql/cluster-in-a-box-dev:${CIAB_TAG} memsql/cluster-in-a-box-dev:latest

.PHONY: test-ciab
test-ciab: test-destroy
	IMAGE=singlestore/cluster-in-a-box:${CIAB_TAG} ./test/ciab

.PHONY: publish-ciab
publish-ciab:
	docker push singlestore/cluster-in-a-box:${CIAB_TAG}
	docker push singlestore/cluster-in-a-box:latest
	docker push memsql/cluster-in-a-box:${CIAB_TAG}
	docker push memsql/cluster-in-a-box:latest

.PHONY: redhat-verify-ciab
redhat-verify-ciab:
	docker tag singlestore/cluster-in-a-box:${CIAB_TAG} scan.connect.redhat.com/ospid-6b69e5e1-d98a-4d75-a591-e300d4820ecb/cluster-in-a-box:${CIAB_TAG}
	docker push scan.connect.redhat.com/ospid-6b69e5e1-d98a-4d75-a591-e300d4820ecb/cluster-in-a-box:${CIAB_TAG}
	@echo "View results + publish: https://connect.redhat.com/project/923891/view"

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

.PHONY: stage-tools
stage-tools:
	docker tag singlestore/tools:${TOOLS_TAG} singlestore/tools:staging-${TOOLS_TAG}
	docker push singlestore/tools:staging-${TOOLS_TAG}
	docker tag memsql/tools:${TOOLS_TAG} memsql/tools:staging-${TOOLS_TAG}
	docker push memsql/tools:staging-${TOOLS_TAG}

.PHONY: requires-license
requires-license:
ifndef LICENSE_KEY
	$(error LICENSE_KEY is required)
endif
