# Product Requirements Document: PODINFO: Readme

---

## Document Information
**Project:** podinfo
**Document:** README
**Version:** 1.0.0
**Date:** 2025-10-13
**Status:** READY FOR TASK-MASTER PARSING

---

## 1. EXECUTIVE SUMMARY

### 1.1 Overview
This PRD captures the requirements and implementation details for PODINFO: Readme.

### 1.2 Purpose
This document provides a structured specification that can be parsed by task-master to generate actionable tasks.

### 1.3 Scope
The scope includes all requirements, features, and implementation details from the original documentation.

---

## 2. REQUIREMENTS

### 2.1 Functional Requirements
**Priority:** HIGH

**REQ-001:** upgrade the release automatically


## 3. TASKS

The following tasks have been identified for implementation:

**TASK_001** [MEDIUM]: Health checks (readiness and liveness)

**TASK_002** [MEDIUM]: Graceful shutdown on interrupt signals

**TASK_003** [MEDIUM]: File watcher for secrets and configmaps

**TASK_004** [MEDIUM]: Instrumented with Prometheus and Open Telemetry

**TASK_005** [MEDIUM]: Structured logging with zap 

**TASK_006** [MEDIUM]: 12-factor app with viper

**TASK_007** [MEDIUM]: Fault injection (random errors and latency)

**TASK_008** [MEDIUM]: Swagger docs

**TASK_009** [MEDIUM]: Timoni, Helm and Kustomize installers

**TASK_010** [MEDIUM]: End-to-End testing with Kubernetes Kind and Helm

**TASK_011** [MEDIUM]: Multi-arch container image with Docker buildx and GitHub Actions

**TASK_012** [MEDIUM]: Container image signing with Sigstore cosign

**TASK_013** [MEDIUM]: SBOMs and SLSA Provenance embedded in the container image

**TASK_014** [MEDIUM]: CVE scanning with govulncheck

**TASK_015** [MEDIUM]: `GET /` prints runtime information

**TASK_016** [MEDIUM]: `GET /version` prints podinfo version and git commit hash 

**TASK_017** [MEDIUM]: `GET /metrics` return HTTP requests duration and Go runtime metrics

**TASK_018** [MEDIUM]: `GET /healthz` used by Kubernetes liveness probe

**TASK_019** [MEDIUM]: `GET /readyz` used by Kubernetes readiness probe

**TASK_020** [MEDIUM]: `POST /readyz/enable` signals the Kubernetes LB that this instance is ready to receive traffic

**TASK_021** [MEDIUM]: `POST /readyz/disable` signals the Kubernetes LB to stop sending requests to this instance

**TASK_022** [MEDIUM]: `GET /status/{code}` returns the status code

**TASK_023** [MEDIUM]: `GET /panic` crashes the process with exit code 255

**TASK_024** [MEDIUM]: `POST /echo` forwards the call to the backend service and echos the posted content 

**TASK_025** [MEDIUM]: `GET /env` returns the environment variables as a JSON array

**TASK_026** [MEDIUM]: `GET /headers` returns a JSON with the request HTTP headers

**TASK_027** [MEDIUM]: `GET /delay/{seconds}` waits for the specified period

**TASK_028** [MEDIUM]: `POST /token` issues a JWT token valid for one minute `JWT=$(curl -sd 'anon' podinfo:9898/token | jq -r .token)`

**TASK_029** [MEDIUM]: `GET /token/validate` validates the JWT token `curl -H "Authorization: Bearer $JWT" podinfo:9898/token/validate`

**TASK_030** [MEDIUM]: `GET /configs` returns a JSON with configmaps and/or secrets mounted in the `config` volume

**TASK_031** [MEDIUM]: `POST/PUT /cache/{key}` saves the posted content to Redis

**TASK_032** [MEDIUM]: `GET /cache/{key}` returns the content from Redis if the key exists

**TASK_033** [MEDIUM]: `DELETE /cache/{key}` deletes the key from Redis if exists

**TASK_034** [MEDIUM]: `POST /store` writes the posted content to disk at /data/hash and returns the SHA1 hash of the content

**TASK_035** [MEDIUM]: `GET /store/{hash}` returns the content of the file /data/hash if exists

**TASK_036** [MEDIUM]: `GET /ws/echo` echos content via websockets `podcli ws ws://localhost:9898/ws/echo`

**TASK_037** [MEDIUM]: `GET /chunked/{seconds}` uses `transfer-encoding` type `chunked` to give a partial response and then waits for the specified period

**TASK_038** [MEDIUM]: `GET /swagger.json` returns the API Swagger docs, used for Linkerd service profiling and Gloo routes discovery

**TASK_039** [MEDIUM]: `/grpc.health.v1.Health/Check` health checking

**TASK_040** [MEDIUM]: `/grpc.EchoService/Echo` echos the received content

**TASK_041** [MEDIUM]: `/grpc.VersionService/Version` returns podinfo version and Git commit hash

**TASK_042** [MEDIUM]: `/grpc.DelayService/Delay` returns a successful response after the given seconds in the body of gRPC request

**TASK_043** [MEDIUM]: `/grpc.EnvService/Env` returns environment variables as a JSON array

**TASK_044** [MEDIUM]: `/grpc.HeaderService/Header` returns the headers present in the gRPC request. Any custom header can also be given as a part of request and that can be returned using this API

**TASK_045** [MEDIUM]: `/grpc.InfoService/Info` returns the runtime information

**TASK_046** [MEDIUM]: `/grpc.PanicService/Panic` crashes the process with gRPC status code as '1 CANCELLED'

**TASK_047** [MEDIUM]: `/grpc.StatusService/Status` returns the gRPC Status code given in the request body

**TASK_048** [MEDIUM]: `/grpc.TokenService/TokenGenerate` issues a JWT token valid for one minute

**TASK_049** [MEDIUM]: `/grpc.TokenService/TokenValidate` validates the JWT token

**TASK_050** [MEDIUM]: [Getting started with Timoni](https://timoni.sh/quickstart/)

**TASK_051** [MEDIUM]: [Getting started with Flux](https://fluxcd.io/flux/get-started/)

**TASK_052** [MEDIUM]: [Progressive Deliver with Flagger and Linkerd](https://docs.flagger.app/tutorials/linkerd-progressive-delivery)

**TASK_053** [MEDIUM]: [Automated canary deployments with Kubernetes Gateway API](https://docs.flagger.app/tutorials/gatewayapi-progressive-delivery)


## 4. DETAILED SPECIFICATIONS

### 4.1 Original Content

The following sections contain the original documentation:


#### Podinfo

# podinfo

[![e2e](https://github.com/stefanprodan/podinfo/workflows/e2e/badge.svg)](https://github.com/stefanprodan/podinfo/blob/master/.github/workflows/e2e.yml)
[![test](https://github.com/stefanprodan/podinfo/workflows/test/badge.svg)](https://github.com/stefanprodan/podinfo/blob/master/.github/workflows/test.yml)
[![cve-scan](https://github.com/stefanprodan/podinfo/workflows/cve-scan/badge.svg)](https://github.com/stefanprodan/podinfo/blob/master/.github/workflows/cve-scan.yml)
[![Go Report Card](https://goreportcard.com/badge/github.com/stefanprodan/podinfo)](https://goreportcard.com/report/github.com/stefanprodan/podinfo)
[![Docker Pulls](https://img.shields.io/docker/pulls/stefanprodan/podinfo)](https://hub.docker.com/r/stefanprodan/podinfo)

Podinfo is a tiny web application made with Go that showcases best practices of running microservices in Kubernetes.
Podinfo is used by CNCF projects like [Flux](https://github.com/fluxcd/flux2) and [Flagger](https://github.com/fluxcd/flagger)
for end-to-end testing and workshops.

Specifications:

* Health checks (readiness and liveness)
* Graceful shutdown on interrupt signals
* File watcher for secrets and configmaps
* Instrumented with Prometheus and Open Telemetry
* Structured logging with zap 
* 12-factor app with viper
* Fault injection (random errors and latency)
* Swagger docs
* Timoni, Helm and Kustomize installers
* End-to-End testing with Kubernetes Kind and Helm
* Multi-arch container image with Docker buildx and GitHub Actions
* Container image signing with Sigstore cosign
* SBOMs and SLSA Provenance embedded in the container image
* CVE scanning with govulncheck

Web API:

* `GET /` prints runtime information
* `GET /version` prints podinfo version and git commit hash 
* `GET /metrics` return HTTP requests duration and Go runtime metrics
* `GET /healthz` used by Kubernetes liveness probe
* `GET /readyz` used by Kubernetes readiness probe
* `POST /readyz/enable` signals the Kubernetes LB that this instance is ready to receive traffic
* `POST /readyz/disable` signals the Kubernetes LB to stop sending requests to this instance
* `GET /status/{code}` returns the status code
* `GET /panic` crashes the process with exit code 255
* `POST /echo` forwards the call to the backend service and echos the posted content 
* `GET /env` returns the environment variables as a JSON array
* `GET /headers` returns a JSON with the request HTTP headers
* `GET /delay/{seconds}` waits for the specified period
* `POST /token` issues a JWT token valid for one minute `JWT=$(curl -sd 'anon' podinfo:9898/token | jq -r .token)`
* `GET /token/validate` validates the JWT token `curl -H "Authorization: Bearer $JWT" podinfo:9898/token/validate`
* `GET /configs` returns a JSON with configmaps and/or secrets mounted in the `config` volume
* `POST/PUT /cache/{key}` saves the posted content to Redis
* `GET /cache/{key}` returns the content from Redis if the key exists
* `DELETE /cache/{key}` deletes the key from Redis if exists

... (content truncated for PRD) ...


#### Guides

### Guides

* [Getting started with Timoni](https://timoni.sh/quickstart/)
* [Getting started with Flux](https://fluxcd.io/flux/get-started/)
* [Progressive Deliver with Flagger and Linkerd](https://docs.flagger.app/tutorials/linkerd-progressive-delivery)
* [Automated canary deployments with Kubernetes Gateway API](https://docs.flagger.app/tutorials/gatewayapi-progressive-delivery)


#### Install

### Install

To install Podinfo on Kubernetes the minimum required version is **Kubernetes v1.23**.


#### Timoni

#### Timoni

Install with [Timoni](https://timoni.sh):

```bash
timoni -n default apply podinfo oci://ghcr.io/stefanprodan/modules/podinfo
```


#### Helm

#### Helm

Install from github.io:

```bash
helm repo add podinfo https://stefanprodan.github.io/podinfo

helm upgrade --install --wait frontend \
--namespace test \
--set replicaCount=2 \
--set backend=http://backend-podinfo:9898/echo \
podinfo/podinfo

helm test frontend --namespace test

helm upgrade --install --wait backend \
--namespace test \
--set redis.enabled=true \
podinfo/podinfo
```

Install from ghcr.io:

```bash
helm upgrade --install --wait podinfo --namespace default \
oci://ghcr.io/stefanprodan/charts/podinfo
```


#### Kustomize

#### Kustomize

```bash
kubectl apply -k github.com/stefanprodan/podinfo//kustomize
```


#### Docker

#### Docker

```bash
docker run -dp 9898:9898 stefanprodan/podinfo
```


#### Continuous Delivery

### Continuous Delivery

In order to install podinfo on a Kubernetes cluster and keep it up to date with the latest
release in an automated manner, you can use [Flux](https://fluxcd.io).

Install the Flux CLI on MacOS and Linux using Homebrew:

```sh
brew install fluxcd/tap/flux
```

Install the Flux controllers needed for Helm operations:

```sh
flux install \
--namespace=flux-system \
--network-policy=false \
--components=source-controller,helm-controller
```

Add podinfo's Helm repository to your cluster and
configure Flux to check for new chart releases every ten minutes:

```sh
flux create source helm podinfo \
--namespace=default \
--url=https://stefanprodan.github.io/podinfo \
--interval=10m
```

Create a `podinfo-values.yaml` file locally:

```sh
cat > podinfo-values.yaml <<EOL
replicaCount: 2
resources:
  limits:
    memory: 256Mi
  requests:
    cpu: 100m
    memory: 64Mi
EOL
```

Create a Helm release for deploying podinfo in the default namespace:

```sh
flux create helmrelease podinfo \
--namespace=default \
--source=HelmRepository/podinfo \

... (content truncated for PRD) ...


---

## 5. TECHNICAL REQUIREMENTS

### 5.1 Dependencies
- All dependencies from original documentation apply
- Standard development environment
- Required tools and libraries as specified

### 5.2 Compatibility
- Compatible with existing infrastructure
- Follows project standards and conventions

---

## 6. SUCCESS CRITERIA

### 6.1 Functional Success Criteria
- All identified tasks completed successfully
- All requirements implemented as specified
- All tests passing

### 6.2 Quality Success Criteria
- Code meets quality standards
- Documentation is complete and accurate
- No critical issues remaining

---

## 7. IMPLEMENTATION PLAN

### Phase 1: Preparation
- Review all requirements and tasks
- Set up development environment
- Gather necessary resources

### Phase 2: Implementation
- Execute tasks in priority order
- Follow best practices
- Test incrementally

### Phase 3: Validation
- Run comprehensive tests
- Validate against requirements
- Document completion

---

## 8. TASK-MASTER INTEGRATION

### How to Parse This PRD

```bash
# Parse this PRD with task-master
task-master parse-prd --input="{doc_name}_PRD.md"

# List generated tasks
task-master list

# Start execution
task-master next
```

### Expected Task Generation
Task-master should generate approximately {len(tasks)} tasks from this PRD.

---

## 9. APPENDIX

### 9.1 References
- Original document: {doc_name}.md
- Project: {project_name}

### 9.2 Change History
| Version | Date | Changes |
|---------|------|---------|
| 1.0.0 | {datetime.now().strftime('%Y-%m-%d')} | Initial PRD conversion |

---

*End of PRD*
*Generated by MD-to-PRD Converter*
