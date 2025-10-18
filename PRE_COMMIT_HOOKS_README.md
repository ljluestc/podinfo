# Pre-commit Hooks Documentation

## Overview

This project uses pre-commit hooks to ensure code quality, test coverage, and security before code is committed. The hooks automatically run tests, linters, formatters, and security scans.

## Installation

### Install pre-commit framework

```bash
# Using pip
pip install pre-commit

# Using homebrew (macOS)
brew install pre-commit

# Using conda
conda install -c conda-forge pre-commit
```

### Install git hooks

```bash
# Install the pre-commit hooks in the repository
pre-commit install

# Install pre-push hooks
pre-commit install --hook-type pre-push

# Install all hook types
pre-commit install --install-hooks
```

## Hook Categories

### Pre-commit Hooks (Run on every commit)

These hooks run quickly and catch issues before code is committed:

1. **Code Format & Style**
   - `trailing-whitespace` - Remove trailing whitespace
   - `end-of-file-fixer` - Ensure files end with newline
   - `go-fmt` - Format Go code
   - `black` - Format Python code
   - `isort` - Sort Python imports

2. **Code Quality**
   - `go-vet` - Go static analysis
   - `golangci-lint` - Comprehensive Go linter
   - `python-lint` - Python linter (flake8)
   - `eslint` - JavaScript/TypeScript linter

3. **File Checks**
   - `check-yaml` - Validate YAML syntax
   - `check-json` - Validate JSON syntax
   - `check-toml` - Validate TOML syntax
   - `check-xml` - Validate XML syntax
   - `check-merge-conflict` - Detect merge conflicts
   - `check-case-conflict` - Detect case conflicts
   - `check-added-large-files` - Prevent large files (>1MB)

4. **Security**
   - `detect-private-key` - Detect private keys in code
   - `debug-statements` - Detect debug statements

5. **Quick Tests**
   - `go-test-unit` - Run Go unit tests
   - `python-tests` - Run Python tests
   - `java-unit-tests` - Run Java unit tests
   - `integration-test-quick` - Quick integration tests
   - `api-consistency-test` - API consistency validation
   - `error-handling-test` - Error handling validation

6. **Build Checks**
   - `go-build-check` - Verify Go build succeeds
   - `go-mod-tidy` - Ensure go.mod is tidy

### Pre-push Hooks (Run before push)

These hooks are more comprehensive and may take longer:

1. **Coverage Checks** ⭐
   - `java-coverage-check` - **Java 100% coverage** (JaCoCo)
   - `python-coverage-check` - **Python 100% coverage** (pytest)
   - `integration-test-coverage` - Integration test coverage
   - `test-coverage` - Go test coverage
   - `coverage-summary` - Combined coverage report

2. **Comprehensive Tests**
   - `integration-test-full` - Full integration test suite
   - `performance-test` - Performance benchmarks
   - `race-condition-test` - Race condition detection
   - `memory-leak-test` - Memory leak detection

3. **Security & Dependencies**
   - `security-scan` - Security scan with gosec
   - `dependency-check` - Check dependency versions
   - `binary-size-check` - Ensure binary size < 50MB

## Coverage Enforcement

### Java Coverage (100% Required)

```bash
# JaCoCo enforces 100% coverage for:
# - LINE coverage: 100%
# - BRANCH coverage: 100%
# - METHOD coverage: 100%

# Build will fail if any threshold not met
mvn verify
```

### Python Coverage (100% Required)

```bash
# pytest enforces 100% coverage
pytest test_comprehensive.py --cov=. --cov-fail-under=100

# View missing coverage
pytest test_comprehensive.py --cov=. --cov-report=term-missing
```

### Integration Test Coverage

```bash
# Run integration tests with coverage
go test -v -coverprofile=coverage.out ./pkg/api/http/...
go tool cover -func=coverage.out
```

## Running Hooks Manually

### Run all hooks on all files

```bash
pre-commit run --all-files
```

### Run specific hook

```bash
# Run only Go formatting
pre-commit run go-fmt --all-files

# Run only Java coverage check
pre-commit run java-coverage-check --all-files

# Run only Python tests
pre-commit run python-tests --all-files
```

### Run only pre-commit stage hooks

```bash
pre-commit run --hook-stage commit --all-files
```

### Run only pre-push stage hooks

```bash
pre-commit run --hook-stage push --all-files
```

## Skipping Hooks

### Skip all hooks (not recommended)

```bash
git commit --no-verify -m "message"
git push --no-verify
```

### Skip specific hooks

```bash
SKIP=go-test-unit git commit -m "message"
SKIP=java-coverage-check,python-coverage-check git push
```

### Skip multiple hooks

```bash
SKIP=go-fmt,black,isort git commit -m "message"
```

## Hook Execution Flow

### On Commit

```
git commit
  ↓
[Pre-commit Hooks]
  ├─ File Checks (YAML, JSON, etc.)
  ├─ Code Formatting (go-fmt, black, isort)
  ├─ Linters (golangci-lint, flake8, eslint)
  ├─ Security (detect-private-key, debug-statements)
  ├─ Build Checks (go-build, go-mod-tidy)
  └─ Quick Tests (unit tests, integration-test-quick)
  ↓
[If all pass] → Commit created
[If any fail] → Commit aborted
```

### On Push

```
git push
  ↓
[Pre-push Hooks]
  ├─ Coverage Checks ⭐
  │   ├─ Java: 100% (JaCoCo)
  │   ├─ Python: 100% (pytest)
  │   └─ Integration tests
  ├─ Full Integration Tests
  ├─ Performance Tests
  ├─ Race Condition Tests
  ├─ Security Scan (gosec)
  └─ Dependency Checks
  ↓
[If all pass] → Push succeeds
[If any fail] → Push aborted
```

## Troubleshooting

### Hook fails to run

```bash
# Update hooks
pre-commit autoupdate

# Clean and reinstall
pre-commit clean
pre-commit install --install-hooks
```

### Java coverage fails

```bash
# Check coverage report
mvn jacoco:report
open target/site/jacoco/index.html

# View uncovered code
mvn verify
```

### Python coverage fails

```bash
# See which lines are missing coverage
pytest test_comprehensive.py --cov=. --cov-report=term-missing

# Generate HTML report
pytest test_comprehensive.py --cov=. --cov-report=html
open htmlcov/index.html
```

### Go tests fail

```bash
# Run tests with verbose output
go test -v ./...

# Run specific test
go test -v -run TestFunctionName ./pkg/...
```

### Hook is too slow

```bash
# Skip slow hooks during development
SKIP=integration-test-full,performance-test git commit -m "WIP"

# Run slow hooks before final push
pre-commit run --hook-stage push --all-files
```

## Configuration

### Update hook versions

```bash
# Auto-update all hooks to latest versions
pre-commit autoupdate

# Update specific hook
pre-commit autoupdate --repo https://github.com/psf/black
```

### Disable specific hooks

Edit `.pre-commit-config.yaml` and comment out hooks:

```yaml
# Temporarily disabled
# - id: slow-hook
#   name: Slow Hook
#   ...
```

### Add new hooks

Edit `.pre-commit-config.yaml`:

```yaml
- repo: local
  hooks:
    - id: my-custom-hook
      name: My Custom Hook
      entry: bash -c 'echo "Running custom hook"'
      language: system
      pass_filenames: false
      always_run: true
      stages: [pre-commit]
```

## Best Practices

### Development Workflow

```bash
# 1. Make changes
git add .

# 2. Run hooks manually before commit (optional)
pre-commit run

# 3. Commit (hooks run automatically)
git commit -m "feat: add new feature"

# 4. Before push, ensure all tests pass
pre-commit run --hook-stage push

# 5. Push
git push
```

### Working on Large Changes

```bash
# Commit frequently with quick hooks
git commit -m "WIP: partial implementation"

# Before final push, run all hooks
pre-commit run --all-files
git push
```

### Fixing Hook Failures

```bash
# 1. Review hook output
pre-commit run --all-files

# 2. Fix issues identified
# - Format code
# - Fix linter warnings
# - Add missing tests
# - Fix failing tests

# 3. Verify fixes
pre-commit run --all-files

# 4. Commit and push
git commit -m "fix: address hook failures"
git push
```

## Hook Performance

### Execution Time Estimates

**Pre-commit hooks** (~30-60 seconds total):
- File checks: ~2s
- Code formatting: ~5s
- Linters: ~10s
- Build checks: ~10s
- Quick unit tests: ~15s
- Quick integration tests: ~10s

**Pre-push hooks** (~2-5 minutes total):
- Java coverage (100%): ~45s
- Python coverage (100%): ~10s
- Integration coverage: ~30s
- Full integration tests: ~60s
- Performance tests: ~60s
- Race condition tests: ~60s
- Security scan: ~20s

### Optimization Tips

1. **Use `SKIP` for WIP commits**
   ```bash
   SKIP=integration-test-full git commit -m "WIP"
   ```

2. **Run slow hooks only before push**
   - Quick hooks on commit
   - Comprehensive hooks on push

3. **Use caching**
   - Pre-commit automatically caches dependencies
   - Go modules cached
   - Maven dependencies cached

4. **Parallel execution**
   - Pre-commit runs independent hooks in parallel
   - Configure with `parallel: true` in config

## Coverage Reports

### View Java Coverage

```bash
mvn jacoco:report
open target/site/jacoco/index.html
```

### View Python Coverage

```bash
pytest test_comprehensive.py --cov=. --cov-report=html
open htmlcov/index.html
```

### View Go Coverage

```bash
go test -coverprofile=coverage.out ./...
go tool cover -html=coverage.out
```

### View Integration Test Coverage

```bash
go test -v -coverprofile=integration.out ./pkg/api/http/...
go tool cover -html=integration.out
```

## CI/CD Integration

The pre-commit hooks align with the CI/CD pipeline:

- **Pre-commit hooks** = Fast feedback during development
- **Pre-push hooks** = Comprehensive checks before code review
- **CI/CD pipeline** = Final validation before merge/deploy

```
Developer Machine          GitHub Actions
================          ==============
git commit
  ↓
Pre-commit hooks    →    (Not run in CI)
  ↓
git push
  ↓
Pre-push hooks      →    Similar to CI test job
  ↓                       ↓
Push to GitHub      →    CI/CD pipeline
                          ├─ Go tests
                          ├─ Java tests (100%)
                          ├─ Python tests (100%)
                          ├─ Security scan
                          ├─ Code quality
                          └─ Build & deploy
```

## Getting Help

```bash
# View pre-commit help
pre-commit --help

# View hook configuration
cat .pre-commit-config.yaml

# Check pre-commit version
pre-commit --version

# View installed hooks
pre-commit run --all-files --verbose
```

## Summary

Pre-commit hooks provide:
- ✅ **Automated code quality** checks
- ✅ **100% test coverage** enforcement (Java & Python)
- ✅ **Security scanning** before commit
- ✅ **Fast feedback** during development
- ✅ **Consistent code style** across team
- ✅ **Reduced CI/CD failures**

Remember: **Hooks are your friends!** They catch issues early and save time in code review.
