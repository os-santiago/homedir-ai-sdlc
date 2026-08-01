.PHONY: build test fmt vet render containers

COMPONENTS := admission-controller orchestrator worker release-manager

build:
	go build ./...

test:
	go test ./...

fmt:
	gofmt -w $$(find . -name '*.go' -not -path './.git/*')

vet:
	go vet ./...

render:
	kustomize build deploy/gitops/overlays/development >/dev/null
	kustomize build deploy/gitops/overlays/production >/dev/null

containers:
	@for component in $(COMPONENTS); do \
		podman build --build-arg COMPONENT=$$component \
			-f components/$$component/Containerfile \
			-t localhost/homedir-ai-sdlc-$$component:dev . || exit 1; \
	done
