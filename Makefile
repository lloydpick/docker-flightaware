build:
	docker build -t lloydpick/flightaware .

run:
	docker run -it --rm lloydpick/flightaware:latest

buildx:
	docker buildx build --platform linux/amd64,linux/arm64,linux/arm/v7,linux/arm/v6 -t lloydpick/flightaware .

deploy:
	docker buildx build --platform linux/amd64,linux/arm64,linux/arm/v7,linux/arm/v6 -t lloydpick/flightaware --push .

.PHONY: buildx
