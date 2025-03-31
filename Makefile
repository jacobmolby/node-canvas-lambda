NODE_VERSION=22
TEST_IMG_NAME=canvas-lambda-test

help:
	@echo "Usage:"
	@echo " make help    — display this help"
	@echo " make build   — Build the layers using docker"
	@echo " make publish — Upload the layer to AWS"
	@echo " make test    — Test the layers, test pass if data uri is output"
	@echo " make clean   — Remove built layers"

build: 	clean
	docker build . \
		--platform linux/amd64 \
		--build-arg OUT="/root/layers" \
		--build-arg NODE_VERSION="${NODE_VERSION}" \
		--tag node${NODE_VERSION}-canvas-layers
	mkdir -p build
	docker create --platform linux/amd64 -ti --name dummy node${NODE_VERSION}-canvas-layers bash
	docker cp dummy:/root/layers/node${NODE_VERSION}_canvas_combined_layer.zip build/
	docker rm -f dummy

publish-combined:
	aws lambda publish-layer-version \
		--layer-name "node-canvas" \
		--compatible-runtimes nodejs${NODE_VERSION}.x \
		--zip-file "fileb://build/node${NODE_VERSION}_canvas_combined_layer.zip" \
		--description "canvas@3.1.0" \
		--profile feedr-management

publish: build publish-combined


# This doesn't work for some reason. It would be nice to use this instead of the 
# `docker build` below then we wouldn't need `test.dockerfile`
# docker run -p 9564:8080 --rm -d \
# 	--name ${TEST_IMG_NAME} \
# 	--volume "$$(pwd)":/var/task:ro,delegated \
# 	--volume "$$(pwd)/lib":/opt/lib:ro,delegated \
# 	--volume "$$(pwd)/nodejs":/opt/nodejs:ro,delegated \
# 	public.ecr.aws/lambda/nodejs:16 \
# 	test.handler

test: unzip-layers

	docker run --platform linux/amd64 \
		-p 9564:8080 \
		-d \
		--rm \
		--name ${TEST_IMG_NAME} \
		$$( docker build \
			--platform linux/amd64 \
			--no-cache \
			--build-arg NODE_VERSION=${NODE_VERSION} \
			--file test.dockerfile \
			-q \
			. \
		)

	echo $$(curl \
		-s \
		-XPOST "http://localhost:9564/2015-03-31/functions/function/invocations" \
		-d '{"message":"Test was successful!"}' \
		| jq '.body' );

	docker stop ${TEST_IMG_NAME}

debug: build unzip-layers

	docker run --platform linux/amd64 \
		--rm \
		-it \
		--volume "$$(pwd)":/var/task:ro,delegated \
		--volume "$$(pwd)/lib":/opt/lib:ro,delegated \
		--volume "$$(pwd)/nodejs":/opt/nodejs:ro,delegated \
		node${NODE_VERSION}-canvas-layers \
		/bin/bash


unzip-layers: build
unzip-layers: nodejs
unzip-layers: lib

nodejs:
	unzip build/node${NODE_VERSION}_canvas_combined_layer.zip

lib:
	unzip build/node${NODE_VERSION}_canvas_combined_layer.zip

clean:
	rm -rf build lib nodejs
