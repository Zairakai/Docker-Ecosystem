# Documentation Index

Welcome to the Zairakai Docker Ecosystem documentation.

## Getting Started

> **First time here?** Check the **[Prerequisites Guide](PREREQUISITES.md)** to see if you're ready.

### For Beginners

👉 **[Quick Start Guide](QUICKSTART.md)** - Get up and running in 5 minutes

**Prerequisites:**

- Basic Docker knowledge (docker run, docker-compose up)
- Laravel project ready
- 10GB disk space for images

**Check your readiness:** [Prerequisites Guide](PREREQUISITES.md)

**What you'll learn:**

- Pull pre-built images from registry
- Start a basic Laravel stack
- Connect to databases
- Access your application

### For Intermediate Users

👉 **[Architecture Overview](ARCHITECTURE.md)** - Understand the ecosystem

**Prerequisites:**

- Comfortable with Docker Compose
- Understanding of multi-container applications
- Familiarity with Laravel structure

**What you'll learn:**

- Image architecture (prod/dev/test stages)
- Service organization
- Networking and volumes
- Health checks and monitoring

### For Advanced Users

👉 **[Testing Modes](TESTING_MODES.md)** - Three testing architectures

**Prerequisites:**

- Experience with Laravel + Vue.js
- Understanding of SSR vs SPA
- Docker networking knowledge

**What you'll learn:**

- Blade-only mode (pure SSR)
- SPA-only mode (decoupled architecture)
- Hybrid mode (Laravel + Vite standard)
- Switching between modes

## Core Documentation

### CI/CD Release Flow

- Overview: see README section CI/CD Release Flow (staging tags, probes, promotion, cleanup)
  - ../README.md#ci-cd-release-flow
- Detailed reference: configuration and image tags
  - REFERENCE.md#ci-cd-release-flow

### Architecture & Design

- **[Architecture Overview](ARCHITECTURE.md)** - System design and patterns
- **[Architecture Comparison](ARCHITECTURE_COMPARISON.md)** - Detailed comparison of 3 testing modes
- **[Reference Guide](REFERENCE.md)** - Complete configuration reference

### Testing Strategies

- **[Testing Modes](TESTING_MODES.md)** - How to test Blade, SPA, and Hybrid architectures
- **Build Workflow** - See `examples/testing-modes/BUILD_WORKFLOW.md`

### Operations

- **[Monitoring & Observability](MONITORING.md)** - Prometheus, Grafana, Jaeger, Zipkin
- **[Disaster Recovery](DISASTER_RECOVERY.md)** - Backup, restore, HA procedures
- **[Security Guide](../SECURITY.md)** - Security best practices

### Deployment

- **[Kubernetes Deployment](KUBERNETES.md)** - Helm charts and K8s deployment
- **[Docker Swarm Deployment](SWARM.md)** - Swarm orchestration guide

## Examples & Tutorials

### Quick Examples

Located in `examples/` directory:

**Testing Modes** (`examples/testing-modes/`)

- `docker-compose-mode-blade.yml` - Pure Blade SSR
- `docker-compose-mode-spa.yml` - Decoupled SPA + API
- `docker-compose-mode-hybrid.yml` - Laravel + Vite
- `BUILD_WORKFLOW.md` - Detailed build workflow

**Compose Configurations** (`examples/compose/`)

- `minimal-laravel.yml` - Basic Laravel setup
- `docker-compose-ha.yml` - High Availability
- `docker-compose-testing.yml` - Testing environment
- `docker-compose-tracing.yml` - Distributed tracing
- `production-single.yml` - Single-server production
- `api-only.yml` - API-only backend
- `frontend-only.yml` - Frontend-only SPA

**Nginx Configurations** (`examples/nginx/`)

- `nginx-laravel-vite.conf` - Standard Laravel + Vite
- `nginx-mode-blade-only.conf` - Blade SSR only
- `nginx-mode-spa-only.conf` - SPA with API proxy
- `nginx-mode-hybrid.conf` - Hybrid SSR + SPA
- `nginx-testing.conf` - Testing environment

**Monitoring** (`examples/monitoring/`)

- `prometheus.yml` - Prometheus configuration
- `grafana-datasources.yml` - Grafana datasources
- `otel-collector-config.yml` - OpenTelemetry Collector
- `redis-sentinel.conf` - Redis HA with Sentinel

## By Use Case

### "I want to deploy a traditional Laravel app"

1. Read: [Quick Start](QUICKSTART.md)
2. Use: `examples/testing-modes/docker-compose-mode-blade.yml`
3. Nginx: `examples/nginx/nginx-mode-blade-only.conf`

### "I want to deploy a modern SPA with Laravel API"

1. Read: [Architecture Comparison](ARCHITECTURE_COMPARISON.md) - SPA-only section
2. Use: `examples/testing-modes/docker-compose-mode-spa.yml`
3. Nginx: `examples/nginx/nginx-mode-spa-only.conf`

### "I want to deploy Laravel with Vue.js components"

1. Read: [Architecture Comparison](ARCHITECTURE_COMPARISON.md) - Hybrid section
2. Read: `examples/testing-modes/BUILD_WORKFLOW.md`
3. Use: `examples/testing-modes/docker-compose-mode-hybrid.yml`
4. Nginx: `examples/nginx/nginx-laravel-vite.conf`

### "I need high availability for production"

1. Read: [Disaster Recovery](DISASTER_RECOVERY.md)
2. Use: `examples/compose/docker-compose-ha.yml`
3. Config: `examples/monitoring/redis-sentinel.conf`

### "I want to add monitoring and observability"

1. Read: [Monitoring Guide](MONITORING.md)
2. Use: `examples/compose/docker-compose-tracing.yml`
3. Configs: `examples/monitoring/prometheus.yml`, `otel-collector-config.yml`

### "I want to deploy to Kubernetes"

1. Read: [Kubernetes Deployment](KUBERNETES.md)
2. Use: Helm charts in `k8s/helm/laravel-stack/`
3. Customize: `values.yaml` for your needs

### "I want to deploy to Docker Swarm"

1. Read: [Docker Swarm Deployment](SWARM.md)
2. Use: `swarm/stack-laravel.yml`
3. Deploy: `docker stack deploy -c swarm/stack-laravel.yml laravel`

## Skill Level Requirements

### Beginner Level

**Docker knowledge needed:**

- Running containers with `docker run`
- Using docker-compose
- Basic volume and network concepts

**Recommended docs:**

- [Quick Start](QUICKSTART.md)
- `examples/compose/minimal-laravel.yml`

### Intermediate Level

**Docker knowledge needed:**

- Multi-stage builds
- Docker networking (bridge, overlay)
- Health checks and restart policies
- Environment variables and secrets

**Recommended docs:**

- [Architecture Overview](ARCHITECTURE.md)
- [Testing Modes](TESTING_MODES.md)
- [Reference Guide](REFERENCE.md)

### Advanced Level

**Docker knowledge needed:**

- Orchestration (K8s or Swarm)
- Service mesh and distributed tracing
- High availability patterns
- Security hardening

**Recommended docs:**

- [Kubernetes Deployment](KUBERNETES.md)
- [Docker Swarm Deployment](SWARM.md)
- [Monitoring & Observability](MONITORING.md)
- [Disaster Recovery](DISASTER_RECOVERY.md)

## Contributing

Want to contribute? See **[Contributing Guide](../CONTRIBUTING.md)**

## Support

- **Issues**: [GitLab Issues](https://gitlab.com/zairakai/docker-ecosystem/-/issues)
- **Discord**: [Zairakai Community](https://discord.gg/MAmD5SG8Zu) (*🖥️・Developers* role)
- **Security**: See [SECURITY.md](../SECURITY.md)

---

**Navigation:**
- [← Back to README](../README.md)
- [Quick Start →](QUICKSTART.md)
