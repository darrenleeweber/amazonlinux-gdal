SHELL = /bin/bash
PY_VERSION = 3.6
PY_TAG = py${PY_VERSION}
IMAGE := aws-geopandas
BUILD := ${IMAGE}:${PY_TAG}

build:
	docker build -f Dockerfile -t ${BUILD} .

shell: build
	docker run --name aws_geopandas --volume $(shell pwd)/:/data --rm  -it ${BUILD} /bin/bash

test:
	docker run ${BUILD} bash -c "gdalinfo --version"
	docker run ${BUILD} bash -c "python --version | grep '${PY_VERSION}'"

push:
	docker push ${DOCKER_USERNAME}/${BUILD}

container-clean:
	docker stop aws_geopandas > /dev/null 2>&1 || true
	docker rm aws_geopandas > /dev/null 2>&1 || true

# ---
# lambda layer build and package using /opt

LAYER_BUILD = ${BUILD}-layer
LAYER_PREFIX = /opt

lambda-layer-build:
	docker build -f Dockerfile -t ${LAYER_BUILD} --build-arg prefix=${LAYER_PREFIX} .

lambda-layer-shell: lambda-layer-build container-clean
	docker run --name aws_geopandas --volume $(shell pwd)/:/data --rm -it ${LAYER_BUILD} /bin/bash

lambda-layer-test: lambda-layer-build
	docker run --volume $(shell pwd)/:/data --rm -it ${LAYER_BUILD} /bin/bash -c '/data/tests/test.sh'

lambda-layer-package: lambda-layer-build container-clean
	docker run --name aws_geopandas \
		-e PREFIX=${LAYER_PREFIX} \
		-e PY_VERSION=${PY_VERSION} \
		-e LAYER_BUILD=${LAYER_BUILD} \
		-itd ${LAYER_BUILD} /bin/bash
	docker cp package_lambda_layer.sh aws_geopandas:/tmp/package_lambda_layer.sh
	docker exec -it aws_geopandas bash -c '/tmp/package_lambda_layer.sh'
	mkdir -p ./layers
	docker cp aws_geopandas:/tmp/${LAYER_BUILD}-libs.zip ./layers/
	docker cp aws_geopandas:/tmp/${LAYER_BUILD}-python.zip ./layers/
	docker stop aws_geopandas && docker rm aws_geopandas

