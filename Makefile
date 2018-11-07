REGISTRY                           := hisshadow85
ELASTIC_SEARCH_IMAGE_REPO        := $(REGISTRY)/elasticsearch-oss
IMAGE_TAG                          := $(shell cat VERSION)

.PHONY: docker-build
	@docker build -t $(ELASTIC_SEARCH_IMAGE_REPO):$(IMAGE_TAG) --rm .

.PHONY: docker-push
docker-build:
	@if ! docker images $(ELASTIC_SEARCH_IMAGE_REPO) | awk '{ print $$2 }' | grep -q -F $(IMAGE_TAG); then echo "$(ELASTIC_SEARCH_IMAGE_REPO) version $(IMAGE_TAG) is not yet built. Please run 'make docker-build'"; false; fi
	@docker push $(ELASTIC_SEARCH_IMAGE_REPO):$(IMAGE_TAG)

.PHONY: all
docker-push: