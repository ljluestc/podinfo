# CI/CD Pipeline Documentation

## Overview

This project uses a comprehensive CI/CD pipeline with GitHub Actions to ensure code quality, test coverage, and automated deployment.

## Pipeline Architecture

The CI/CD pipeline consists of the following jobs:

```
┌─────────────┐
│   TRIGGER   │
│ Push/PR/Cron│
└──────┬──────┘
       │
       ├──────────────────┬──────────────────┬──────────────────┬──────────────────┐
       │                  │                  │                  │                  │
   ┌───▼────┐      ┌─────▼──────┐    ┌─────▼──────┐   ┌──────▼───────┐  ┌───────▼────────┐
   │  Test  │      │ Java Tests │    │Python Tests│   │   Security   │  │  Code Quality  │
   │  (Go)  │      │  (JaCoCo)  │    │  (pytest)  │   │    Scan      │  │  (golangci)    │
   └───┬────┘      └─────┬──────┘    └─────┬──────┘   └──────┬───────┘  └───────┬────────┘
       │                  │                  │                  │                  │
       └─────────┬────────┴────────┬─────────┘                  │                  │
                 │                 │                            │                  │
          ┌──────▼─────────────────▼────┐                      │                  │
          │   Coverage Summary Report   │                      │                  │
          └──────┬──────────────────────┘                      │                  │
                 │                                              │                  │
                 └────────────────┬──────────────────┬──────────┴──────────────────┘
                                  │                  │
                           ┌──────▼─────┐    ┌──────▼────────┐
                           │   Build    │    │   Deploy      │
                           │  Package   │    │(Staging/Prod) │
                           └──────┬─────┘    └──────┬────────┘
                                  │                  │
                                  └─────────┬────────┘
                                            │
                                     ┌──────▼──────┐
                                     │   Notify    │
                                     │ (Success/   │
                                     │  Failure)   │
                                     └─────────────┘
```

## Jobs

### 1. Test (Go)

**Purpose**: Run Go unit, integration, and comprehensive tests with coverage

**Steps**:
- Checkout code
- Setup Go (1.21.5, 1.22.0 matrix)
- Cache Go modules
- Run unit tests with race detection
- Run integration tests
- Run comprehensive tests
- Generate coverage report
- Check coverage threshold (configurable, target: 100%)
- Upload coverage reports

**Coverage Threshold**: Configurable via `COVERAGE_THRESHOLD` env var (default: 100.0%)

**Artifacts**:
- `coverage.out` - Go coverage data
- `coverage.html` - HTML coverage report
- `integration.out` - Integration test coverage
- `comprehensive.out` - Comprehensive test coverage

### 2. Java Tests

**Purpose**: Run Java unit tests with JaCoCo coverage analysis

**Steps**:
- Checkout code
- Setup JDK 11
- Cache Maven dependencies
- Run Maven tests with coverage (`mvn clean verify`)
- JaCoCo enforces 100% coverage automatically
- Upload JaCoCo reports
- Upload coverage to Codecov

**Coverage Enforcement**:
- JaCoCo configured in `pom.xml` to enforce:
  - **LINE coverage**: 100%
  - **BRANCH coverage**: 100%
  - **METHOD coverage**: 100%
- Build fails if any threshold not met

**Artifacts**:
- `target/site/jacoco/` - JaCoCo HTML reports
- `target/site/jacoco/jacoco.xml` - Codecov XML

### 3. Python Tests

**Purpose**: Run Python tests with pytest and coverage

**Steps**:
- Checkout code
- Setup Python (3.9, 3.10, 3.11 matrix)
- Cache pip dependencies
- Install test dependencies from `requirements-test.txt`
- Run pytest with coverage
- Enforce 100% coverage with `--cov-fail-under=100`
- Upload coverage reports
- Upload coverage to Codecov

**Coverage Enforcement**:
- pytest configured with `--cov-fail-under=100`
- Build fails if coverage < 100%

**Artifacts**:
- `coverage.xml` - Codecov XML
- `htmlcov/` - HTML coverage report

### 4. Security Scan

**Purpose**: Security vulnerability scanning

**Tools**:
- Gosec (Go security scanner)
- SARIF report upload to GitHub Code Scanning

**Steps**:
- Checkout code
- Run Gosec security scanner
- Generate SARIF report
- Upload SARIF to GitHub Security tab

### 5. Code Quality

**Purpose**: Code quality and style enforcement

**Tools**:
- golangci-lint
- go vet
- go fmt
- go mod tidy

**Steps**:
- Run linter with 5-minute timeout
- Check code formatting
- Verify go.mod/go.sum are tidy
- Fail build on any violations

### 6. Coverage Summary Report

**Purpose**: Aggregate and display all coverage metrics

**Steps**:
- Download all coverage artifacts
- Generate comprehensive summary
- Display in GitHub Step Summary
- Upload combined coverage to Codecov

**Output Example**:
```
## Coverage Summary Report

### Go Coverage
total: (statements) 91.5%

### Java Coverage
JaCoCo enforces 100% LINE, BRANCH, and METHOD coverage

### Python Coverage
pytest enforces 100% coverage with --cov-fail-under=100

✅ **All coverage thresholds met!**
```

### 7. Build

**Purpose**: Build and package application

**Matrix**: ubuntu-latest, windows-latest, macos-latest

**Steps**:
- Build Go binaries with version info
- Build Docker images (Linux only)
- Upload build artifacts

**Dependencies**: Requires all tests, security, quality, and coverage to pass

### 8. Deploy

**Purpose**: Deploy to staging and production

**Trigger**: Only on `main` branch

**Steps**:
- Deploy to staging
- Run smoke tests
- Deploy to production (if smoke tests pass)

**Dependencies**: Requires build to pass

### 9. Notify

**Purpose**: Notification on pipeline completion

**Trigger**: Always runs (success or failure)

**Success Notification**:
```
✅ All tests passed! 100% coverage achieved and quality checks successful.
- Go tests: ✅
- Java tests (100% coverage): ✅
- Python tests (100% coverage): ✅
- Security scan: ✅
- Code quality: ✅
- Build: ✅
```

**Failure Notification**:
```
❌ Pipeline failed! Please check the logs.
Test Results:
- Go tests: [status]
- Java tests: [status]
- Python tests: [status]
- Coverage summary: [status]
- Security scan: [status]
- Code quality: [status]
- Build: [status]
```

## Triggers

The pipeline runs on:

1. **Push** to `main` or `develop` branches
2. **Pull Request** to `main` or `develop` branches
3. **Schedule**: Daily at 2 AM UTC (cron: `0 2 * * *`)

## Coverage Requirements

### Overall Coverage Goals

- **Go**: Configurable threshold (target: 100%)
- **Java**: 100% LINE, BRANCH, METHOD (enforced by JaCoCo)
- **Python**: 100% (enforced by pytest)

### Coverage Reporting

All coverage metrics are reported to:
- GitHub Actions artifacts
- GitHub Step Summary
- Codecov (with `codecov.yml` configuration)

### Coverage Badges

Add these badges to your README.md:

```markdown
[![codecov](https://codecov.io/gh/YOUR_ORG/YOUR_REPO/branch/main/graph/badge.svg)](https://codecov.io/gh/YOUR_ORG/YOUR_REPO)
```

## Local Development

### Running Tests Locally

```bash
# Go tests
go test -v -race -coverprofile=coverage.out ./pkg/... ./cmd/...
go tool cover -html=coverage.out

# Java tests
mvn clean verify
open target/site/jacoco/index.html

# Python tests
pytest test_comprehensive.py --cov=. --cov-report=html
open htmlcov/index.html
```

### Pre-commit Checks

```bash
# Install pre-commit hooks (see next section)
pre-commit install

# Run all pre-commit hooks manually
pre-commit run --all-files
```

## Configuration Files

### Pipeline Configuration
- `.github/workflows/ci-cd.yml` - Main CI/CD pipeline
- `.github/workflows/test.yml` - Go test workflow
- `.github/workflows/e2e.yml` - End-to-end tests

### Coverage Configuration
- `codecov.yml` - Codecov configuration
- `pom.xml` - JaCoCo Maven configuration
- `requirements-test.txt` - Python test dependencies

### Code Quality
- `.golangci.yml` - golangci-lint configuration
- `.pre-commit-config.yaml` - Pre-commit hooks

## Troubleshooting

### Coverage Below Threshold

**Java**:
```bash
# View coverage report
mvn jacoco:report
open target/site/jacoco/index.html
```

**Python**:
```bash
# Run with missing lines report
pytest test_comprehensive.py --cov=. --cov-report=term-missing
```

**Go**:
```bash
# View coverage
go tool cover -func=coverage.out
```

### Build Failures

1. Check GitHub Actions logs
2. Run tests locally to reproduce
3. Check coverage reports for uncovered code
4. Fix issues and push

### Slow Tests

1. Review test duration in logs
2. Optimize slow tests
3. Consider parallelization
4. Use test caching where appropriate

## Best Practices

1. **Write tests first** (TDD approach)
2. **Run tests locally** before pushing
3. **Keep coverage at 100%** for all new code
4. **Fix failing tests immediately** - don't merge with failing tests
5. **Review coverage reports** in pull requests
6. **Use descriptive test names** for easy debugging
7. **Mock external dependencies** for unit tests
8. **Test edge cases** and error conditions

## Performance

### Pipeline Execution Time

Approximate execution times:
- Go tests: ~30 seconds
- Java tests: ~45 seconds
- Python tests: ~10 seconds
- Security scan: ~20 seconds
- Code quality: ~30 seconds
- Build: ~2 minutes
- **Total**: ~4-5 minutes

### Optimization Tips

1. Use caching for dependencies (Go modules, Maven, pip)
2. Run tests in parallel where possible
3. Use matrix builds for multi-version testing
4. Fail fast on test failures

## Monitoring

### GitHub Actions Dashboard

View pipeline status at:
```
https://github.com/YOUR_ORG/YOUR_REPO/actions
```

### Codecov Dashboard

View coverage trends at:
```
https://codecov.io/gh/YOUR_ORG/YOUR_REPO
```

### Security Alerts

View security findings at:
```
https://github.com/YOUR_ORG/YOUR_REPO/security/code-scanning
```

## Maintenance

### Weekly Tasks

- Review security scan results
- Check coverage trends
- Update dependencies
- Review and optimize slow tests

### Monthly Tasks

- Update GitHub Actions versions
- Review and update coverage thresholds
- Audit test coverage quality
- Review pipeline performance

## Support

For issues with the CI/CD pipeline:
1. Check GitHub Actions documentation
2. Review workflow logs
3. Open an issue in the repository
4. Contact the development team
