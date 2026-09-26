.PHONY: build test run clean

build:
	go build -o implementation-service ./cmd

test:
	go test -v ./...

run: build
	./implementation-service

clean:
	rm -f implementation-service
	rm -f *.test

docker-build:
	podman build -t ai-sdlc-implementation:latest -f Containerfile .

docker-run:
	podman run --rm -p 8082:8082 \
		-e SC_PROFILE=nvidia -e NVIDIA_API_KEY \
		-e QUALITY_THRESHOLD=8.0 \
		-e MAX_IMPLEMENTATION_ITERATIONS=3 \
		-v ~/.config/sc-agent:/root/.config/sc-agent:ro \
		ai-sdlc-implementation:latest
