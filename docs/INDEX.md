# 📚 Documentation Index

[🏠 Home][home] > Documentation Index

Welcome to the Zairakai Docker Ecosystem documentation - your complete guide to production-ready Docker images
for Laravel + Vue.js development.

## Table of Contents

- [📚 Documentation Index](#-documentation-index)
  - [Table of Contents](#table-of-contents)
  - [Getting Started](#getting-started)
    - [For Beginners](#for-beginners)
    - [For Intermediate Users](#for-intermediate-users)
    - [For Advanced Users](#for-advanced-users)
  - [Core Documentation](#core-documentation)
    - [CI/CD Release Flow](#cicd-release-flow)
    - [Architecture \& Design](#architecture--design)
    - [Testing Strategies](#testing-strategies)
    - [Operations](#operations)
    - [Deployment](#deployment)
  - [Examples \& Tutorials](#examples--tutorials)
    - [Quick Examples](#quick-examples)
    - [Docker Compose Configurations](#docker-compose-configurations)
    - [Nginx Configurations](#nginx-configurations)
    - [Monitoring Configurations](#monitoring-configurations)
  - [By Use Case](#by-use-case)
    - ["I want to deploy a traditional Laravel app"](#i-want-to-deploy-a-traditional-laravel-app)
    - ["I want to deploy a modern SPA with Laravel API"](#i-want-to-deploy-a-modern-spa-with-laravel-api)
    - ["I want to deploy Laravel with Vue.js components"](#i-want-to-deploy-laravel-with-vuejs-components)
    - ["I need high availability for production"](#i-need-high-availability-for-production)
    - ["I want to add monitoring and observability"](#i-want-to-add-monitoring-and-observability)
    - ["I want to deploy to Kubernetes"](#i-want-to-deploy-to-kubernetes)
    - ["I want to deploy to Docker Swarm"](#i-want-to-deploy-to-docker-swarm)
  - [Skill Level Requirements](#skill-level-requirements)
    - [Beginner Level](#beginner-level)
    - [Intermediate Level](#intermediate-level)
    - [Advanced Level](#advanced-level)
  - [Contributing \& Support](#contributing--support)
    - [Contributing](#contributing)
    - [Getting Help](#getting-help)
  - [Navigation](#navigation)

## Getting Started

> **First time here?** Check the **[Prerequisites Guide][prerequisites]** to see if you're ready.

### For Beginners

👉 **[Quick Start Guide][quickstart]** - Get up and running in 5 minutes

**Prerequisites:**

- Basic Docker knowledge (`docker run`, `docker-compose up`)
- Laravel project ready (or create a new one)
- 10GB disk space for images

**Check your readiness:** [Prerequisites Guide][prerequisites]

**What you'll learn:**

- Pull pre-built images from registry
- Start a basic Laravel stack with Docker Compose
- Connect to MySQL and Redis databases
- Access and configure your application
- Basic development workflow

### For Intermediate Users

👉 **[Architecture Overview][architecture]** - Understand the ecosystem design

**Prerequisites:**

- Comfortable with Docker Compose
- Understanding of multi-container applications
- Familiarity with Laravel project structure

**What you'll learn:**

- Progressive architecture (prod → dev → test stages)
- Multi-stage Docker builds
- Service organization and networking
- Health checks and container monitoring
- Image optimization techniques

### For Advanced Users

👉 **[Testing Modes][testing-modes]** - Three testing architectures

**Prerequisites:**

- Experience with Laravel + Vue.js
- Understanding of SSR vs SPA patterns
- Docker networking and volumes knowledge

**What you'll learn:**

- **Blade-only mode** (pure Server-Side Rendering)
- **SPA-only mode** (decoupled Vue.js + Laravel API)
- **Hybrid mode** (Laravel + Vite standard)
- How to switch between testing modes
- Performance implications of each architecture

## Core Documentation

### CI/CD Release Flow

- **Overview**: See [README - CI/CD Release Flow][README-cicd-release-flow-quality-gated]
  - Staging tags with commit SHA
  - Quality-gated validation
  - Automatic promotion and cleanup
- **Detailed Reference**: [Configuration and Image Tags][reference]

### Architecture & Design

- **[Architecture Overview][architecture]** - System design patterns and philosophy
- **[Architecture Comparison][architecture-comparison]** - Detailed comparison of 3 testing modes
- **[Reference Guide][reference]** - Complete configuration reference

### Testing Strategies

- **[Testing Modes][testing-modes]** - How to test Blade, SPA, and Hybrid architectures
- **[Build Workflow][build_workflow]** - Detailed build workflow for each mode

### Operations

- **[Monitoring & Observability][monitoring]** - Prometheus, Grafana, Jaeger, Zipkin setup
- **[Disaster Recovery][disaster-recovery]** - Backup, restore, and High Availability procedures
- **[Security Guide][security]** - Security scanning and best practices

### Deployment

- **[Kubernetes Deployment][kubernetes]** - Helm charts and K8s manifests
- **[Docker Swarm Deployment][swarm]** - Swarm orchestration guide

## Examples & Tutorials

### Quick Examples

All examples are located in the [`examples/`][examples] directory.

### Docker Compose Configurations

Located in [`examples/compose/`][examples-compose]:

| File | Description | Use Case |
| ---- | ----------- | -------- |
| `minimal-laravel.yml` | Basic Laravel setup | Simple development |
| `docker-compose-ha.yml` | High Availability | Production with HA |
| `docker-compose-testing.yml` | Testing environment | CI/CD testing |
| `docker-compose-tracing.yml` | Distributed tracing | Observability |
| `production-single.yml` | Single-server production | Small production |
| `api-only.yml` | API-only backend | Headless backend |
| `frontend-only.yml` | Frontend-only SPA | Separate frontend |

### Nginx Configurations

Located in [`examples/nginx/`][examples-nginx]

| File | Description | Mode |
| ---- | ----------- | ---- |
| `nginx-laravel-vite.conf` | Standard Laravel + Vite | Hybrid |
| `nginx-mode-blade-only.conf` | Blade SSR only | Blade |
| `nginx-mode-spa-only.conf` | SPA with API proxy | SPA |
| `nginx-mode-hybrid.conf` | Hybrid SSR + SPA | Hybrid |
| `nginx-testing.conf` | Testing environment | Testing |

### Monitoring Configurations

Located in [`examples/monitoring/`][examples-monitoring]:

- `prometheus.yml` - Prometheus scrape configuration
- `grafana-datasources.yml` - Grafana datasources
- `otel-collector-config.yml` - OpenTelemetry Collector
- `redis-sentinel.conf` - Redis HA with Sentinel

## By Use Case

### "I want to deploy a traditional Laravel app"

**Stack**: Laravel with Blade templates (Server-Side Rendering)

1. **Read**: [Quick Start Guide][quickstart]
2. **Use**: [`examples/testing-modes/docker-compose-mode-blade.yml`][examples-testing-blade]
3. **Nginx**: [`examples/nginx/nginx-mode-blade-only.conf`](../examples/nginx/nginx-mode-blade-only.conf)

### "I want to deploy a modern SPA with Laravel API"

**Stack**: Decoupled Vue.js frontend + Laravel API backend

1. **Read**: [Architecture Comparison][architecture-comparison] - SPA-only section
2. **Use**: [`examples/testing-modes/docker-compose-mode-spa.yml`][examples-testing-spa]
3. **Nginx**: [`examples/nginx/nginx-mode-spa-only.conf`][examples-nginx-spa]

### "I want to deploy Laravel with Vue.js components"

**Stack**: Laravel + Vite (standard modern Laravel setup)

1. **Read**: [Architecture Comparison][architecture-comparison] - Hybrid section
2. **Read**: [`examples/testing-modes/BUILD_WORKFLOW.md`][examples-testing-build_workflow]
3. **Use**: [`examples/testing-modes/docker-compose-mode-hybrid.yml`][examples-testing-hybrid]
4. **Nginx**: [`examples/nginx/nginx-laravel-vite.conf`][examples-nginx-laravel-vite]

### "I need high availability for production"

**Stack**: MySQL replication + Redis Sentinel

1. **Read**: [Disaster Recovery Guide][disaster-recovery]
2. **Use**: [`examples/compose/docker-compose-ha.yml`][examples-compose-ha]
3. **Config**: [`examples/monitoring/redis-sentinel.conf`][examples-monitoring-redis-sentinel]

### "I want to add monitoring and observability"

**Stack**: Prometheus + Grafana + Jaeger

1. **Read**: [Monitoring Guide][monitoring]
2. **Use**: [`examples/compose/docker-compose-tracing.yml`][examples-compose-tracing]
3. **Configs**:
   - [`examples/monitoring/prometheus.yml`][examples-monitoring-prometheus]
   - [`examples/monitoring/otel-collector-config.yml`][examples-monitoring-otel]

### "I want to deploy to Kubernetes"

**Stack**: Kubernetes with Helm

1. **Read**: [Kubernetes Deployment Guide][kubernetes]
2. **Use**: Helm charts in [`k8s/helm/laravel-stack/`][k8s-helm-laravel]
3. **Customize**: `values.yaml` for your environment

### "I want to deploy to Docker Swarm"

**Stack**: Docker Swarm orchestration

1. **Read**: [Docker Swarm Deployment Guide][swarm]
2. **Use**: [`swarm/stack-laravel.yml`][swarm-stack-laravel]
3. **Deploy**: `docker stack deploy -c swarm/stack-laravel.yml laravel`

## Skill Level Requirements

### Beginner Level

**Docker knowledge needed:**

- Running containers with `docker run`
- Using `docker-compose up` and `docker-compose down`
- Basic volume and network concepts
- Reading Docker Compose YAML files

**Recommended documentation:**

- [Prerequisites Guide][prerequisites]
- [Quick Start Guide][quickstart]
- [`examples/compose/minimal-laravel.yml`][examples-compose-laravel]

### Intermediate Level

**Docker knowledge needed:**

- Multi-stage Docker builds
- Docker networking (bridge, overlay networks)
- Health checks and restart policies
- Environment variables and secrets management
- Volume mounting and persistence

**Recommended documentation:**

- [Architecture Overview][architecture]
- [Testing Modes][testing-modes]
- [Reference Guide][reference]

### Advanced Level

**Docker knowledge needed:**

- Container orchestration (Kubernetes or Swarm)
- Service mesh and distributed tracing
- High availability and failover patterns
- Security hardening and image scanning
- CI/CD pipeline integration

**Recommended documentation:**

- [Kubernetes Deployment][kubernetes]
- [Docker Swarm Deployment][swarm]
- [Monitoring & Observability][monitoring]
- [Disaster Recovery][disaster-recovery]

## Contributing & Support

### Contributing

Want to contribute to the Zairakai Docker Ecosystem?

📖 **See [Contributing Guide][contributing]** for:

- Development workflow
- Quality standards (ShellCheck 100%, multi-stage builds)
- Git commit format (Conventional Commits)
- Security guidelines

### Getting Help

- **💬 Discord**: [Zairakai Community][discord] (*🖥️・Developers* role)
- **🐛 Issues**: [GitLab Issues][issues]
- **🔒 Security**: See [Security Policy][security] for responsible disclosure

## Navigation

- [← Back to Home][home]
- [Quick Start Guide →][quickstart]

*Built with ❤️ by the Zairakai team for Laravel + Vue.js developers*

<!-- Reference Links -->

[home]: ../README.md
[prerequisites]: PREREQUISITES.md
[quickstart]: QUICKSTART.md
[architecture]: ARCHITECTURE.md
[architecture-comparison]: ARCHITECTURE_COMPARISON.md
[testing-modes]: TESTING_MODES.md
[reference]: REFERENCE.md
[monitoring]: MONITORING.md
[disaster-recovery]: DISASTER_RECOVERY.md
[security]: ../SECURITY.md
[kubernetes]: KUBERNETES.md
[swarm]: SWARM.md
[contributing]: ../CONTRIBUTING.md
[examples]: ../examples/
[discord]: https://discord.gg/MAmD5SG8Zu
[issues]: https://gitlab.com/zairakai/docker-ecosystem/-/issues

[README-cicd-release-flow-quality-gated]: ../README.md#cicd-release-flow-quality-gated
[build_workflow]: ../examples/testing-modes/BUILD_WORKFLOW.md
[examples-compose]: ../examples/compose/
[examples-nginx]: ../examples/nginx/
[examples-monitoring]: ../examples/monitoring/
[examples-testing-blade]: ../examples/testing-modes/docker-compose-mode-blade.yml
[examples-testing-spa]: ../examples/testing-modes/docker-compose-mode-spa.yml
[examples-nginx-spa]: ../examples/nginx/nginx-mode-spa-only.conf
[examples-testing-build_workflow]: ../examples/testing-modes/BUILD_WORKFLOW.md
[examples-testing-hybrid]: ../examples/testing-modes/docker-compose-mode-hybrid.yml
[examples-nginx-laravel-vite]: ../examples/nginx/nginx-laravel-vite.conf
[examples-compose-ha]: ../examples/compose/docker-compose-ha.yml
[examples-monitoring-redis-sentinel]: ../examples/monitoring/redis-sentinel.conf
[examples-compose-tracing]: ../examples/compose/docker-compose-tracing.yml
[examples-monitoring-prometheus]: ../examples/monitoring/prometheus.yml
[examples-monitoring-otel]: ../examples/monitoring/otel-collector-config.yml
[k8s-helm-laravel]: ../k8s/helm/laravel-stack/
[swarm-stack-laravel]: ../swarm/stack-laravel.yml
[examples-compose-laravel]: ../examples/compose/minimal-laravel.yml
