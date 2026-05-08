REGISTRY ?= abgeo
TAG      ?= latest
LIB      := images/lib
SERVICES := ap lan net-init

export DOCKER_BUILDKIT := 1

.PHONY: all build push clean help $(SERVICES) $(addprefix push-,$(SERVICES))

all: build

help:
	@echo "Targets:"
	@echo "  build           build all images ($(SERVICES))"
	@echo "  <service>       build a single image (ap | lan | net-init)"
	@echo "  push            push all images"
	@echo "  push-<service>  push a single image"
	@echo "  clean           remove built images"
	@echo ""
	@echo "Variables (override on the command line):"
	@echo "  REGISTRY=$(REGISTRY)"
	@echo "  TAG=$(TAG)"

build: $(SERVICES)

$(SERVICES):
	docker build \
	  --build-context lib=$(LIB) \
	  -t $(REGISTRY)/mezz-$@:$(TAG) \
	  images/$@

push: $(addprefix push-,$(SERVICES))

$(addprefix push-,$(SERVICES)): push-%: %
	docker push $(REGISTRY)/mezz-$*:$(TAG)

clean:
	-docker rmi $(foreach s,$(SERVICES),$(REGISTRY)/mezz-$(s):$(TAG))
