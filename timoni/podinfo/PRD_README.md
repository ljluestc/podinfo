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


## 4. DETAILED SPECIFICATIONS

### 4.1 Original Content

The following sections contain the original documentation:


#### Podinfo

# Podinfo

[Podinfo](https://github.com/stefanprodan/podinfo) is a tiny web application
made with Go that showcases best practices of running microservices in Kubernetes.


#### Module Repository

## Module Repository

This module is available on GitHub Container Registry at
[ghcr.io/stefanprodan/modules/podinfo](https://github.com/stefanprodan/podinfo/pkgs/container/modules%2Fpodinfo).


#### Install

## Install

To create an instance using the default values:

```shell
timoni -n default apply podinfo oci://ghcr.io/stefanprodan/modules/podinfo
```

To install a specific module version:

```shell
timoni -n default apply podinfo oci://ghcr.io/stefanprodan/modules/podinfo -v 6.5.0
```

To change the [default configuration](#configuration),
create one or more `values.cue` files and apply them to the instance.

For example, create a file `my-values.cue` with the following content:

```cue
values: {
	resources: requests: {
		cpu:    "100m"
		memory: "128Mi"
	}
}
```

And apply the values with:

```shell
timoni -n default apply podinfo oci://ghcr.io/stefanprodan/modules/podinfo \
--values ./my-values.cue
```


#### Uninstall

## Uninstall

To uninstall an instance and delete all its Kubernetes resources:

```shell
timoni -n default delete podinfo
```


#### Configuration

## Configuration


#### General Values

### General values

| Key                          | Type                                    | Default                        | Description                                                                                                                                  |
|------------------------------|-----------------------------------------|--------------------------------|----------------------------------------------------------------------------------------------------------------------------------------------|
| `image: tag:`                | `string`                                | `<latest version>`             | Container image tag                                                                                                                          |
| `image: digest:`             | `string`                                | `""`                           | Container image digest, takes precedence over `tag` when specified                                                                           |
| `image: repository:`         | `string`                                | `ghcr.io/stefanprodan/podinfo` | Container image repository                                                                                                                   |
| `image: pullPolicy:`         | `string`                                | `IfNotPresent`                 | [Kubernetes image pull policy](https://kubernetes.io/docs/concepts/containers/images/#image-pull-policy)                                     |
| `metadata: labels:`          | `{[ string]: string}`                   | `{}`                           | Common labels for all resources                                                                                                              |
| `metadata: annotations:`     | `{[ string]: string}`                   | `{}`                           | Common annotations for all resources                                                                                                         |
| `podAnnotations:`            | `{[ string]: string}`                   | `{}`                           | Annotations applied to pods                                                                                                                  |
| `imagePullSecrets:`          | `[...corev1.LocalObjectReference]`      | `[]`                           | [Kubernetes image pull secrets](https://kubernetes.io/docs/concepts/containers/images/#specifying-imagepullsecrets-on-a-pod)                 |
| `tolerations:`               | `[ ...corev1.#Toleration]`              | `[]`                           | [Kubernetes toleration](https://kubernetes.io/docs/concepts/scheduling-eviction/taint-and-toleration)                                        |
| `affinity:`                  | `corev1.#Affinity`                      | `{}`                           | [Kubernetes affinity and anti-affinity](https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/#affinity-and-anti-affinity) |
| `resources:`                 | `corev1.#ResourceRequirements`          | `{}`                           | [Kubernetes resource requests and limits](https://kubernetes.io/docs/concepts/configuration/manage-resources-containers)                     |
| `topologySpreadConstraints:` | `[...corev1.#TopologySpreadConstraint]` | `[]`                           | [Kubernetes pod topology spread constraints](https://kubernetes.io/docs/concepts/scheduling-eviction/topology-spread-constraints)            |
| `podSecurityContext:`        | `corev1.#PodSecurityContext`            | `{}`                           | [Kubernetes pod security context](https://kubernetes.io/docs/tasks/configure-pod-container/security-context)                                 |
| `securityContext:`           | `corev1.#SecurityContext`               | `{}`                           | [Kubernetes container security context](https://kubernetes.io/docs/tasks/configure-pod-container/security-context)                           |
| `test: enabled:`             | `bool`                                  | `false`                        | Run end-to-end tests at install and upgrades                                                                                                 |


#### Recommended Values

#### Recommended values

Comply with the
restricted [Kubernetes pod security standard](https://kubernetes.io/docs/concepts/security/pod-security-standards/):

```cue
values: {
	podSecurityContext: {
		runAsUser:  100
		runAsGroup: 101
		fsGroup:    101
	}
	securityContext: {
		allowPrivilegeEscalation: false
		readOnlyRootFilesystem:   true
		runAsNonRoot:             true
		capabilities: drop: ["ALL"]
		seccompProfile: type: "RuntimeDefault"
	}
}
```


#### Autoscaling Values

### Autoscaling values

| Key                         | Type     | Default       | Description                                                                                                  |
|-----------------------------|----------|---------------|--------------------------------------------------------------------------------------------------------------|
| `replicas:`                 | `int`    | `1`           | Number of pods when autoscaling is disabled                                                                  |
| `autoscaling: enabled:`     | `bool`   | `false`       | Enable [Kubernetes HPA](https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale/) creation |
| `autoscaling: minReplicas:` | `int`    | `replicas`    | Minimum number of pods                                                                                       |
| `autoscaling: maxReplicas:` | `int`    | `minReplicas` | Maximum number of pods                                                                                       |
| `autoscaling: cpu:`         | `int`    | `99`          | CPU average utilization (percentage)                                                                         |
| `autoscaling: memory:`      | `string` | `""`          | memory average value (e.g. `1024Mi`)                                                                         |


#### Ingress Values

### Ingress values

| Key                     | Type                  | Default         | Description                                                                                            |
|-------------------------|-----------------------|-----------------|--------------------------------------------------------------------------------------------------------|
| `service: port:`        | `int`                 | `80`            | Kubernetes Service ClusterIP port                                                                      |
| `ingress: enabled:`     | `bool`                | `false`         | Enable [Kubernetes Ingress](https://kubernetes.io/docs/concepts/services-networking/ingress/) creation |
| `ingress: tls:`         | `bool`                | `false`         | Enable TLS (requires cert-manager)                                                                     |
| `ingress: host:`        | `string`              | `podinfo.local` | Ingress host                                                                                           |
| `ingress: className:`   | `string`              | `""`            | Ingress class name                                                                                     |
| `ingress: annotations:` | `{[ string]: string}` | `{}`            | Annotations applied to ingress                                                                         |


#### Monitoring Values

### Monitoring values

| Key                     | Type   | Default | Description                                                                   |
|-------------------------|--------|---------|-------------------------------------------------------------------------------|
| `monitoring: enabled:`  | `bool` | `false` | Enable [Prometheus ServiceMonitor](https://prometheus-operator.dev/) creation |
| `monitoring: interval:` | `int`  | `15`    | Prometheus scrape interval in seconds                                         |


#### Cashing Values

### Cashing values

| Key                  | Type     | Default | Description                                             |
|----------------------|----------|---------|---------------------------------------------------------|
| `caching: enabled:`  | `bool`   | `false` | Enable Redis caching                                    |
| `caching: redisURL:` | `string` | `""`    | Redis URL in the format `tcp://:[password]@host[:port]` |


#### Ui Values

### UI values

| Key            | Type     | Default   | Description      |
|----------------|----------|-----------|------------------|
| `ui: color:`   | `string` | `#34577c` | Background color |
| `ui: message:` | `string` | `""`      | Greeting message |
| `ui: backend:` | `string` | `""`      | Backend URL      |


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
