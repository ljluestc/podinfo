# Makefile for Comprehensive Test Coverage and CI/CD Pipeline

.PHONY: help test test-unit test-integration test-comprehensive test-java coverage coverage-html coverage-report lint security build clean install-tools pre-commit ci-cd

# Default target
help:
	@echo "Available targets:"
	@echo "  test                 - Run all tests"
	@echo "  test-unit           - Run unit tests"
	@echo "  test-integration    - Run integration tests"
	@echo "  test-comprehensive  - Run comprehensive tests"
	@echo "  test-java           - Run Java tests"
	@echo "  coverage            - Generate coverage report"
	@echo "  coverage-html       - Generate HTML coverage report"
	@echo "  coverage-report     - Generate detailed coverage report"
	@echo "  lint                - Run linter"
	@echo "  security            - Run security scan"
	@echo "  build               - Build application"
	@echo "  clean               - Clean build artifacts"
	@echo "  install-tools       - Install required tools"
	@echo "  pre-commit          - Run pre-commit checks"
	@echo "  ci-cd               - Run full CI/CD pipeline"

# Test targets
test: test-unit test-integration test-comprehensive test-java

test-unit:
	@echo "🧪 Running unit tests..."
	go test -v -race -coverprofile=coverage.out ./pkg/... ./cmd/...

test-integration:
	@echo "🔗 Running integration tests..."
	go test -v -tags=integration -coverprofile=integration.out ./test/...

test-comprehensive:
	@echo "🎯 Running comprehensive tests..."
	go test -v -tags=comprehensive -coverprofile=comprehensive.out ./pkg/... ./cmd/...

test-java:
	@echo "☕ Running Java tests..."
	@if [ -f "pom.xml" ]; then \
		mvn test; \
	else \
		echo "No pom.xml found, skipping Java tests"; \
	fi

# Coverage targets
coverage: test-unit
	@echo "📊 Generating coverage report..."
	go tool cover -func=coverage.out

coverage-html: test-unit
	@echo "📊 Generating HTML coverage report..."
	go tool cover -html=coverage.out -o coverage.html
	@echo "Coverage report generated: coverage.html"

coverage-report: test-unit
	@echo "📊 Generating detailed coverage report..."
	go tool cover -func=coverage.out | tee coverage.txt
	@echo "Coverage report saved to: coverage.txt"

# Quality targets
lint:
	@echo "🔍 Running linter..."
	@if command -v golangci-lint >/dev/null 2>&1; then \
		golangci-lint run; \
	else \
		echo "golangci-lint not installed, skipping linter"; \
	fi

security:
	@echo "🔒 Running security scan..."
	@if command -v gosec >/dev/null 2>&1; then \
		gosec ./...; \
	else \
		echo "gosec not installed, skipping security scan"; \
	fi

# Build targets
build:
	@echo "🏗️  Building application..."
	go build -v -ldflags="-X main.version=$(shell git rev-parse HEAD)" -o bin/podinfo ./cmd/podinfo
	go build -v -ldflags="-X main.version=$(shell git rev-parse HEAD)" -o bin/podcli ./cmd/podcli
	@echo "Build completed: bin/podinfo, bin/podcli"

# Clean targets
clean:
	@echo "🧹 Cleaning build artifacts..."
	rm -rf bin/
	rm -f coverage.out coverage.html coverage.txt integration.out comprehensive.out
	rm -rf target/
	@echo "Clean completed"

# Tool installation
install-tools:
	@echo "🛠️  Installing required tools..."
	@if ! command -v golangci-lint >/dev/null 2>&1; then \
		echo "Installing golangci-lint..."; \
		curl -sSfL https://raw.githubusercontent.com/golangci/golangci-lint/master/install.sh | sh -s -- -b $(go env GOPATH)/bin v1.54.2; \
	fi
	@if ! command -v gosec >/dev/null 2>&1; then \
		echo "Installing gosec..."; \
		go install github.com/securecodewarrior/gosec/v2/cmd/gosec@latest; \
	fi
	@if ! command -v bc >/dev/null 2>&1; then \
		echo "Installing bc..."; \
		sudo apt-get update && sudo apt-get install -y bc; \
	fi
	@echo "Tools installation completed"

# Pre-commit checks
pre-commit:
	@echo "🔍 Running pre-commit checks..."
	@./.git/hooks/pre-commit

# Full CI/CD pipeline
ci-cd: install-tools lint security test coverage-html build
	@echo "🎉 CI/CD pipeline completed successfully!"

# Docker targets
docker-build:
	@echo "🐳 Building Docker image..."
	docker build -t podinfo:latest .
	docker build -t podinfo:$(shell git rev-parse --short HEAD) .

docker-test:
	@echo "🐳 Running tests in Docker..."
	docker run --rm -v $(PWD):/app -w /app golang:1.21.5 make test

# Performance testing
benchmark:
	@echo "⚡ Running benchmarks..."
	go test -bench=. -benchmem ./pkg/... ./cmd/...

# Memory profiling
profile-mem:
	@echo "📊 Running memory profiling..."
	go test -memprofile=mem.prof ./pkg/... ./cmd/...
	go tool pprof mem.prof

# CPU profiling
profile-cpu:
	@echo "📊 Running CPU profiling..."
	go test -cpuprofile=cpu.prof ./pkg/... ./cmd/...
	go tool pprof cpu.prof

# Race detection
race:
	@echo "🏃 Running race detection..."
	go test -race ./pkg/... ./cmd/...

# Generate test coverage badge
coverage-badge:
	@echo "📊 Generating coverage badge..."
	@COVERAGE=$$(go tool cover -func=coverage.out | grep total | awk '{print $$3}' | sed 's/%//'); \
	echo "Coverage: $$COVERAGE%"; \
	curl -s "https://img.shields.io/badge/coverage-$$COVERAGE%25-brightgreen" > coverage-badge.svg

# Generate test report
test-report:
	@echo "📊 Generating test report..."
	@mkdir -p reports
	@go test -v -json ./pkg/... ./cmd/... > reports/test-results.json
	@echo "Test report generated: reports/test-results.json"

# Check dependencies
deps-check:
	@echo "📦 Checking dependencies..."
	go mod verify
	go mod tidy
	@if [ "$$(git diff --exit-code)" != "0" ]; then \
		echo "Dependencies need to be updated"; \
		exit 1; \
	fi

# Format code
format:
	@echo "🎨 Formatting code..."
	gofmt -s -w .
	goimports -w .

# Generate documentation
docs:
	@echo "📚 Generating documentation..."
	godoc -http=:6060 &
	@echo "Documentation server started at http://localhost:6060"

# Run all quality checks
quality: format lint security test coverage-html
	@echo "✅ All quality checks completed!"

# Continuous testing (watch mode)
watch:
	@echo "👀 Watching for changes..."
	@if command -v entr >/dev/null 2>&1; then \
		find . -name "*.go" | entr -c make test; \
	else \
		echo "entr not installed, install with: sudo apt-get install entr"; \
	fi