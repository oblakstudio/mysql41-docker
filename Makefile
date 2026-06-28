# Makefile for oblakstudio/mysql40 — legacy MySQL 4.0 in a container.
# The image is linux/386 (MySQL 4.0 is a 32-bit-era release); --platform keeps
# builds and runs consistent on amd64 hosts.

IMAGE       ?= oblakstudio/mysql40
VERSION     ?= 4.0.24
PLATFORM    ?= linux/386
ROOT_PW     ?= root
PORT        ?= 3306

.PHONY: build run shell push clean help

build: ## Build the image (tags :latest and :$(VERSION))
	docker build --platform=$(PLATFORM) -t $(IMAGE):latest -t $(IMAGE):$(VERSION) .

run: ## Run the image locally for smoke testing
	docker run --rm -it --platform=$(PLATFORM) \
		-e MYSQL_ROOT_PASSWORD=$(ROOT_PW) \
		-p $(PORT):3306 \
		$(IMAGE):latest

shell: ## Open a shell in the built image
	docker run --rm -it --platform=$(PLATFORM) --entrypoint /bin/bash $(IMAGE):latest

push: ## Publish :latest and :$(VERSION) to Docker Hub
	docker push $(IMAGE):latest
	docker push $(IMAGE):$(VERSION)

clean: ## Remove the locally built images
	-docker rmi $(IMAGE):latest $(IMAGE):$(VERSION)

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) \
		| awk 'BEGIN{FS=":.*?## "}{printf "  \033[36m%-10s\033[0m %s\n", $$1, $$2}'
