# Zairakai Docker Ecosystem

<p align="center">
  <img src="./assets/banner.svg" alt="Zairakai Docker Ecosystem" style="max-width: 800px; width: 100%;">
</p>

<!-- CI/CD & Quality -->
[![Release][release-badge]][release-link]
[![License][license-badge]][license]
[![Security][security-badge]][security]
[![Main][pipeline-main-badge]][pipeline-main-link]
[![Develop][pipeline-develop-badge]][pipeline-develop-link]

<!-- Community & Stats -->
[![GitLab Stars][stars-badge]][stars-link]
[![Discord][discord-badge]][discord]
[![Contributors][contributors-badge]][contributors]

**13 lightweight images** with progressive architecture (prod → dev → test) and comprehensive security scanning.

> 📦 **This is an image repository**  
> These images are intended to be **consumed by application repositories** (via Docker Compose, CI/CD, or orchestration), not for direct development inside this repository.

## 📦 Available Registries

Images are available on **two registries** for maximum convenience:

### [![Docker Hub][dockerhub-badge]][dockerhub]

```bash
docker pull zairakai/php:8.3-prod
docker pull zairakai/mysql:8.0
docker pull zairakai/redis:7
docker pull zairakai/nginx:1.26
```

### [![GitLab Registry][gitlab-registry-badge]][gitlab-registry]

```bash
docker pull registry.gitlab.com/zairakai/docker-ecosystem/php:8.3-prod
docker pull registry.gitlab.com/zairakai/docker-ecosystem/database:mysql-8.0
docker pull registry.gitlab.com/zairakai/docker-ecosystem/database:redis-7
docker pull registry.gitlab.com/zairakai/docker-ecosystem/web:nginx-1.26
```

**Sync Strategy:**

- GitLab Registry = Primary source (built by CI/CD)
- Docker Hub = Public mirror (synced automatically after each release)
- Both registries contain identical images, choose based on your preference

## Quick Start

```bash
# 1. Create docker-compose.yml in your Laravel project
cat > docker-compose.yml <<'EOF'
services:
  app:
    image: zairakai/php:8.3-dev
    volumes:
      - .:/var/www/html
    environment:
      - APP_ENV=local

  mysql:
    image: zairakai/mysql:8.0
    environment:
      - MYSQL_DATABASE=laravel
      - MYSQL_USER=laravel
      - MYSQL_PASSWORD=secret

  redis:
    image: zairakai/redis:7
EOF

# 2. Start your stack (images pulled automatically from Docker Hub)
docker-compose up -d

# 3. Setup Laravel
docker-compose exec app composer install
docker-compose exec app php artisan migrate
```

> **Alternative:** Use GitLab Registry  
> Replace **`zairakai/`** with **`registry.gitlab.com/zairakai/docker-ecosystem/`**  
> Adjust image names (see [Image Naming](#image-naming-conventions) below)

- **[📚 Documentation Index](docs/INDEX.md)**
- **[5-Minute Tutorial][quickstart]**
- **[Examples][examples]**
- **[Architecture Guide][architecture]**

## CI/CD Release Flow (Quality-Gated)

- **Trigger**: pushing a tag `vX.Y.Z` starts the release pipeline
- **Build**: all images are built **locally on the CI runner** with a `-$CI_COMMIT_SHORT_SHA` suffix
  - Examples: `php:8.3-<sha>-prod`, `mysql-8.0-<sha>` (local-only, never pushed to registry)
  - All build jobs run on the same runner (shared Docker daemon)
- **Test**: quality-gated validation using container readiness checks (`docker inspect`, HTTP/CLI probes), crash-loop detection and timeouts
- **Promote**: if all tests pass, stable tags are created and pushed to registry
  - Examples: `php:8.3-prod`, `php:1.3.0-prod`, `php:latest-prod`
  - Stable tags are automatically synced to Docker Hub

Notes:

- Staging images exist **only locally on the CI runner**, never in the registry
- Registry contains **only stable production-ready images** (no ephemeral staging tags)
- Runner's daily Docker cleanup removes local staging images automatically
- MailHog/MinIO are thin wrappers on top of official images, with versions pinned in their Dockerfiles

## Repository Structure

```tree
docker-ecosystem/
├── images/                          # Docker image definitions
│   ├── php/8.3/                     # PHP 8.3 multi-stage (prod/dev/test)
│   │   ├── Dockerfile               # Multi-stage build definition
│   │   ├── base/                    # Production stage configs
│   │   ├── dev/                     # Development stage configs
│   │   └── test/                    # Testing stage configs
│   ├── node/20/                     # Node.js 20 LTS multi-stage
│   │   ├── Dockerfile               # Multi-stage build definition
│   │   ├── base/                    # Production stage configs
│   │   ├── dev/                     # Development stage configs
│   │   └── test/                    # Testing stage configs
│   ├── database/                    # Database images
│   │   ├── mysql/8.0/               # MySQL 8.0 with HA support
│   │   └── redis/7/                 # Redis 7 with Sentinel
│   ├── web/                         # Web server images
│   │   └── nginx/1.26/              # Nginx 1.26 for Laravel
│   └── services/                    # Support services
│       ├── mailhog/                 # Email testing
│       ├── minio/                   # S3-compatible storage
│       └── e2e-testing/             # E2E testing tools
│
├── scripts/                         # Build automation and CI/CD
│   ├── build-all-images.sh          # Main build script (local)
│   ├── docker-functions.sh          # Docker build functions
│   ├── common.sh                    # Shared utilities (logging, validation)
│   ├── promote.sh                   # Promote local staging images to stable registry tags
│   ├── backup/                      # Backup/restore scripts
│   │   ├── backup.sh                # MySQL + Redis backup
│   │   └── restore.sh               # MySQL + Redis restore
│   └── pipeline/                    # CI/CD pipeline scripts
│       ├── build-image.sh           # Generic image builder (multi/single-stage)
│       ├── validate-config.sh       # Validate Dockerfiles and configs
│       ├── validate-shellcheck.sh   # ShellCheck validation (100% compliance)
│       ├── test-image-sizes.sh      # Pull and track image sizes
│       ├── test-multi-stage.sh      # Verify multi-stage integrity
│       └── sync-dockerhub.sh        # Mirror images to Docker Hub
│
├── examples/                        # Docker Compose examples
│   ├── testing-modes/               # 3 testing architectures (Blade/SPA/Hybrid)
│   ├── compose/                     # Docker Compose configurations
│   ├── nginx/                       # Nginx configuration examples
│   ├── monitoring/                  # Monitoring stack configs
│   └── README.md                    # Examples documentation
│
├── k8s/                             # Kubernetes deployment
│   └── helm/laravel-stack/          # Helm chart for K8s
│
├── swarm/                           # Docker Swarm deployment
│   └── stack-laravel.yml            # Swarm stack file
│
├── docs/                            # Documentation
│   ├── ARCHITECTURE.md              # System architecture
│   ├── QUICKSTART.md                # Getting started guide
│   ├── KUBERNETES.md                # K8s deployment guide
│   ├── SWARM.md                     # Swarm deployment guide
│   ├── MONITORING.md                # Observability setup
│   ├── DISASTER_RECOVERY.md         # DR procedures
│   └── REFERENCE.md                 # Complete reference
│
├── .gitlab-ci.yml                   # CI/CD pipeline
├── .dockerignore                    # Docker build exclusions
├── SECURITY.md                      # Security policies
├── CONTRIBUTING.md                  # Contribution guidelines
└── README.md                        # This file
```

## 🔧 Pipeline Scripts (Local & CI)

All CI/CD logic is **externalized in reusable scripts** for testability and maintainability:

### Validation Scripts

```bash
# Validate configuration (Dockerfiles, scripts, directories)
bash scripts/pipeline/validate-config.sh

# Run ShellCheck on all shell scripts (100% compliance required)
bash scripts/pipeline/validate-shellcheck.sh
```

### Build Scripts

```bash
# Build a single image (supports multi-stage and single-stage builds)
bash scripts/pipeline/build-image.sh <image-path> <image-prefix> <image-tag>

# Examples:
bash scripts/pipeline/build-image.sh images/php/8.3 php 8.3-prod
bash scripts/pipeline/build-image.sh images/database/mysql/8.0 database mysql-8.0
bash scripts/pipeline/build-image.sh images/services/mailhog services mailhog
```

### Test Scripts

```bash
# Test image sizes (pull all images and generate report)
CI_REGISTRY_IMAGE=registry.gitlab.com/zairakai/docker-ecosystem \
  bash scripts/pipeline/test-image-sizes.sh

# Test multi-stage integrity (Xdebug, PCOV, size progression)
CI_REGISTRY_IMAGE=registry.gitlab.com/zairakai/docker-ecosystem \
  bash scripts/pipeline/test-multi-stage.sh
```

### Release Scripts

```bash
# Promote local staging images to stable registry tags (CI/CD only)
# Requires: CI_REGISTRY_IMAGE, IMAGE_SUFFIX, PROMOTED_VERSION, registry credentials
export PROMOTED_VERSION=v1.2.3
export IMAGE_SUFFIX=-abc1234
bash scripts/promote.sh

# Sync stable images to Docker Hub (CI/CD only)
bash scripts/pipeline/sync-dockerhub.sh
```

**Benefits:**

- [x] **Local execution** - Test scripts before pushing to CI
- [x] **DRY principle** - Zero code duplication in `.gitlab-ci.yml`
- [x] **ShellCheck 100%** - All scripts pass strict validation
- [x] **Maintainability** - Logic separated from CI configuration
- [x] **Debuggability** - Clear logs via `common.sh` functions

## 📦 Available Images

### Multi-Stage Images (Progressive Architecture)

| Image | Prod | Dev | Test |
| ----- | ---- | --- | ---- |
| [![PHP 8.3][php-version-badge]][dockerhub-php] | [![Size][php-prod-size-badge]][dockerhub-php] [![Pulls][php-prod-pulls-badge]][dockerhub-php] | [![Size][php-dev-size-badge]][dockerhub-php] [![Pulls][php-dev-pulls-badge]][dockerhub-php] | [![Size][php-test-size-badge]][dockerhub-php] [![Pulls][php-test-pulls-badge]][dockerhub-php] |
| [![Node 20][node-version-badge]][dockerhub-node] | [![Size][node-prod-size-badge]][dockerhub-node] [![Pulls][node-prod-pulls-badge]][dockerhub-node] | [![Size][node-dev-size-badge]][dockerhub-node] [![Pulls][node-dev-pulls-badge]][dockerhub-node] | [![Size][node-test-size-badge]][dockerhub-node] [![Pulls][node-test-pulls-badge]][dockerhub-node] |

### Single-Stage Images (Database, Web & Services)

| Image | Description | Size | Downloads |
| ----- | ----------- | ---- | --------- |
| [![MySQL 8.0][mysql-version-badge]][dockerhub-mysql] | Database with HA support | [![Size][mysql-size-badge]][dockerhub-mysql] | [![Pulls][mysql-pulls-badge]][dockerhub-mysql] |
| [![Redis 7][redis-version-badge]][dockerhub-redis] | Caching with Sentinel | [![Size][redis-size-badge]][dockerhub-redis] | [![Pulls][redis-pulls-badge]][dockerhub-redis] |
| [![Nginx 1.26][nginx-version-badge]][dockerhub-nginx] | Reverse proxy for Laravel | [![Size][nginx-size-badge]][dockerhub-nginx] | [![Pulls][nginx-pulls-badge]][dockerhub-nginx] |
| [![MailHog][mailhog-badge]][dockerhub-mailhog] | Email testing with web UI | [![Size][mailhog-size-badge]][dockerhub-mailhog] | [![Pulls][mailhog-pulls-badge]][dockerhub-mailhog] |
| [![MinIO][minio-badge]][dockerhub-minio] | S3-compatible object storage | [![Size][minio-size-badge]][dockerhub-minio] | [![Pulls][minio-pulls-badge]][dockerhub-minio] |
| [![E2E Testing][e2e-testing-badge]][dockerhub-e2e] | Playwright + Gherkin/Cucumber | [![Size][e2e-size-badge]][dockerhub-e2e] | [![Pulls][e2e-pulls-badge]][dockerhub-e2e] |
| [![Performance Testing][performance-testing-badge]][dockerhub-performance] | Artillery, k6, Locust | [![Size][performance-size-badge]][dockerhub-performance] | [![Pulls][performance-pulls-badge]][dockerhub-performance] |

### Platform Support

[![Alpine 3.19][alpine-badge]][alpine-link]
[![Multi-Arch][multi-arch-badge]][multi-arch-link]

All images are built on **Alpine Linux 3.19** for minimal size and attack surface, supporting **linux/amd64** and **linux/arm64** architectures.

## Image Naming Conventions

**Docker Hub** (simpler):

```text
zairakai/<image>:<tag>
```

Examples: `zairakai/php:8.3-prod`, `zairakai/mysql:8.0`

**GitLab Container Registry** (grouped by type):

```text
registry.gitlab.com/zairakai/docker-ecosystem/<type>:<image>-<version>
```

Examples: `php:8.3-prod`, `database:mysql-8.0`, `services:mailhog`

> **Tip:** Use Docker Hub for simpler syntax in docker-compose files

## Security & Quality

Security practices are documented in detail in [SECURITY.md][security], following the same disclosure and hardening principles as `zairakai/laravel-dev-tools`.

**Comprehensive security scanning** integrated into CI/CD:

- **SAST** (Static Application Security Testing)
- **Container Scanning** (Trivy)
- **Dependency Scanning** (Composer + npm)
- **License Compliance** monitoring
- **Infrastructure as Code** scanning

**Quality features**:

- Non-root execution (`www:www`, `node:node`)
- Health checks at every layer
- Alpine Linux minimal base (70% smaller images)
- 80% faster setup than traditional stacks

## Key Features

### Progressive Architecture

```txt
prod (minimal) → dev (+ tools) → test (+ testing frameworks)
```

### Deployment Options

**Docker Compose** (Development & Single Server)

```bash
examples/compose/minimal-laravel.yml        # Basic Laravel + MySQL + Redis
examples/compose/frontend-only.yml          # Vue.js frontend only
examples/compose/api-only.yml               # Laravel API backend
examples/compose/production-single.yml      # Production single server
examples/compose/docker-compose-ha.yml      # High Availability setup
examples/compose/docker-compose-tracing.yml # Distributed tracing
```

**Kubernetes** (Production Orchestration)

```bash
k8s/helm/laravel-stack/             # Helm chart for K8s deployment
# See docs/KUBERNETES.md for manifests
```

**Docker Swarm** (Cluster Deployment)

```bash
swarm/stack-laravel.yml             # Swarm stack configuration
# See docs/SWARM.md for orchestration
```

### Multi-Tag Support

```bash
zairakai/php:8.3-prod         # Specific version
zairakai/php:8.3.x-prod       # Minor version family
zairakai/php:8.3-latest-prod  # Latest in major version
```

### Advanced Features

**E2E Testing** with Playwright + Gherkin

```gherkin
Feature: User Authentication
  Scenario: Successful login
    Given I am on the login page
    When I enter valid credentials
    Then I should be redirected to dashboard
```

**Disaster Recovery** - Automated backup/restore

```bash
scripts/backup/backup.sh mysql      # MySQL backup with compression
scripts/backup/backup.sh redis      # Redis persistence backup
scripts/backup/restore.sh mysql     # Point-in-time recovery
scripts/backup/restore.sh redis     # Point-in-time recovery
```

**Monitoring Stack** - Full observability

- Prometheus metrics collection
- Grafana dashboards
- Distributed tracing (Jaeger/Zipkin)
- Log aggregation

## 📚 Documentation

### Quick Start

- **[Quick Start Guide][quickstart]** - 5-minute setup with Docker Compose
- **[Examples][examples]** - Ready-to-use configurations for various use cases
- **[Reference][reference]** - Complete image tags, commands, and environment variables

### Architecture & Design

- **[Architecture Overview][architecture]** - Multi-stage image design and philosophy
- **[Security Policy][security]** - Security scanning and compliance

### Production Deployment

- **[Kubernetes Deployment][kubernetes]** - K8s manifests and Helm charts
- **[Docker Swarm][swarm]** - Swarm stack files and orchestration
- **[Disaster Recovery][disaster-recovery]** - Backup, restore, and failover strategies

### Monitoring & Operations

- **[Monitoring Stack][monitoring]** - Prometheus, Grafana, and observability
- **[Reference Guide][reference]** - Complete operational reference

### Contributing

- **[Contributing Guidelines][contributing]** - Development workflow and standards

## Support & License

[![Discord][discord-badge]][discord]
[![Issues][issues-badge]][issues]
[![License][license-badge]][license]
[![Docs][docs-badge]][docs]

**Need help?** Join our Discord community or report issues on GitLab.

---

Built with ❤️ by the Zairakai team for Laravel + Vue.js developers

<!-- Documentation Links (no badges) -->
[license]: ./LICENSE
[security]: ./SECURITY.md
[contributing]: ./CONTRIBUTING.md
[quickstart]: docs/QUICKSTART.md
[architecture]: docs/ARCHITECTURE.md
[reference]: docs/REFERENCE.md
[kubernetes]: docs/KUBERNETES.md
[swarm]: docs/SWARM.md
[monitoring]: docs/MONITORING.md
[disaster-recovery]: docs/DISASTER_RECOVERY.md
[examples]: examples/
[docs]: docs/

<!-- Line 1: CI/CD & Quality -->
[release-badge]: https://img.shields.io/gitlab/v/tag/zairakai%2Fdocker-ecosystem?label=release&logo=gitlab
[release-link]: https://gitlab.com/zairakai/docker-ecosystem/-/releases

[pipeline-main-badge]: https://gitlab.com/zairakai/docker-ecosystem/badges/main/pipeline.svg?ignore_skipped=true&key_text=Main
[pipeline-main-link]: https://gitlab.com/zairakai/docker-ecosystem/commits/main

[pipeline-develop-badge]: https://gitlab.com/zairakai/docker-ecosystem/badges/develop/pipeline.svg?ignore_skipped=true&key_text=Develop
[pipeline-develop-link]: https://gitlab.com/zairakai/docker-ecosystem/commits/develop

[security-badge]: https://img.shields.io/badge/security-scanned-green.svg

[license-badge]: https://img.shields.io/badge/license-MIT-blue.svg

<!-- Line 2: Available Images -->
[php-version-badge]: https://img.shields.io/badge/PHP-8.3-777BB4?logo=php&logoColor=white
[dockerhub-php]: https://hub.docker.com/r/zairakai/php

[node-version-badge]: https://img.shields.io/badge/Node-20%20LTS-339933?logo=node.js&logoColor=white
[dockerhub-node]: https://hub.docker.com/r/zairakai/node

[mysql-version-badge]: https://img.shields.io/badge/MySQL-8.0-4479A1?logo=mysql&logoColor=white
[dockerhub-mysql]: https://hub.docker.com/r/zairakai/mysql

[redis-version-badge]: https://img.shields.io/badge/Redis-7-DC382D?logo=redis&logoColor=white
[dockerhub-redis]: https://hub.docker.com/r/zairakai/redis

[nginx-version-badge]: https://img.shields.io/badge/Nginx-1.26-009639?logo=nginx&logoColor=white
[dockerhub-nginx]: https://hub.docker.com/r/zairakai/nginx

[mailhog-badge]: https://img.shields.io/badge/MailHog-latest-00ADD8?logo=mail.ru&logoColor=white
[dockerhub-mailhog]: https://hub.docker.com/r/zairakai/mailhog

[minio-badge]: https://img.shields.io/badge/MinIO-latest-C72E49?logo=minio&logoColor=white
[dockerhub-minio]: https://hub.docker.com/r/zairakai/minio

[e2e-testing-badge]: https://img.shields.io/badge/E2E%20Testing-Playwright-45BA4B?logo=playwright&logoColor=white
[dockerhub-e2e]: https://hub.docker.com/r/zairakai/e2e-testing

[performance-testing-badge]: https://img.shields.io/badge/Performance-Artillery%20%7C%20k6-FF6C37?logo=artillery&logoColor=white
[dockerhub-performance]: https://hub.docker.com/r/zairakai/performance-testing

<!-- Line 3: Registries & Infrastructure -->
[dockerhub-badge]: https://img.shields.io/badge/docker%20hub-zairakai-blue?logo=docker
[dockerhub]: https://hub.docker.com/u/zairakai

[gitlab-registry-badge]: https://img.shields.io/badge/gitlab%20registry-available-orange?logo=gitlab
[gitlab-registry]: https://gitlab.com/zairakai/docker-ecosystem/container_registry

[alpine-badge]: https://img.shields.io/badge/built%20on-Alpine%203.19-0D597F?logo=alpine-linux&logoColor=white
[alpine-link]: https://alpinelinux.org/

[multi-arch-badge]: https://img.shields.io/badge/platforms-linux%2Famd64%20%7C%20linux%2Farm64-blue?logo=docker
[multi-arch-link]: #-available-images

<!-- Line 4: Community & Stats -->
[stars-badge]: https://img.shields.io/gitlab/stars/zairakai%2Fdocker-ecosystem?logo=gitlab&label=Stars
[stars-link]: https://gitlab.com/zairakai/docker-ecosystem

[discord-badge]: https://img.shields.io/discord/1260000352699289621?logo=discord&label=Discord&color=5865F2
[discord]: https://discord.gg/MAmD5SG8Zu

[contributors-badge]: https://img.shields.io/gitlab/contributors/zairakai%2Fdocker-ecosystem?logo=gitlab&label=Contributors
[contributors]: https://gitlab.com/zairakai/docker-ecosystem/-/graphs/main

<!-- Support & License Section -->
[issues-badge]: https://img.shields.io/gitlab/issues/open-raw/zairakai%2Fdocker-ecosystem?logo=gitlab&label=Issues

[issues]: https://gitlab.com/zairakai/docker-ecosystem/-/issues

[docs-badge]: https://img.shields.io/badge/docs-available-blue?logo=readthedocs&logoColor=white

<!-- Stage-Specific Pulls Badges (PHP) -->
[php-prod-pulls-badge]: https://img.shields.io/docker/pulls/zairakai/php?logo=docker&label=8.3-prod

[php-dev-pulls-badge]: https://img.shields.io/docker/pulls/zairakai/php?logo=docker&label=8.3-dev

[php-test-pulls-badge]: https://img.shields.io/docker/pulls/zairakai/php?logo=docker&label=8.3-test

<!-- Stage-Specific Pulls Badges (Node) -->
[node-prod-pulls-badge]: https://img.shields.io/docker/pulls/zairakai/node?logo=docker&label=20-prod

[node-dev-pulls-badge]: https://img.shields.io/docker/pulls/zairakai/node?logo=docker&label=20-dev

[node-test-pulls-badge]: https://img.shields.io/docker/pulls/zairakai/node?logo=docker&label=20-test

<!-- Pulls Badges (Single-Stage Images) -->
[mysql-pulls-badge]: https://img.shields.io/docker/pulls/zairakai/mysql?logo=docker&label=pulls

[redis-pulls-badge]: https://img.shields.io/docker/pulls/zairakai/redis?logo=docker&label=pulls

[nginx-pulls-badge]: https://img.shields.io/docker/pulls/zairakai/nginx?logo=docker&label=pulls

[mailhog-pulls-badge]: https://img.shields.io/docker/pulls/zairakai/mailhog?logo=docker&label=pulls

[minio-pulls-badge]: https://img.shields.io/docker/pulls/zairakai/minio?logo=docker&label=pulls

[e2e-pulls-badge]: https://img.shields.io/docker/pulls/zairakai/e2e-testing?logo=docker&label=pulls

[performance-pulls-badge]: https://img.shields.io/docker/pulls/zairakai/performance-testing?logo=docker&label=pulls

<!-- Dynamic Size Badges (PHP) -->
[php-prod-size-badge]: https://img.shields.io/docker/image-size/zairakai/php/8.3-prod?logo=docker&label=size&color=success

[php-dev-size-badge]: https://img.shields.io/docker/image-size/zairakai/php/8.3-dev?logo=docker&label=size&color=blue

[php-test-size-badge]: https://img.shields.io/docker/image-size/zairakai/php/8.3-test?logo=docker&label=size&color=orange

<!-- Dynamic Size Badges (Node) -->
[node-prod-size-badge]: https://img.shields.io/docker/image-size/zairakai/node/20-prod?logo=docker&label=size&color=success

[node-dev-size-badge]: https://img.shields.io/docker/image-size/zairakai/node/20-dev?logo=docker&label=size&color=blue

[node-test-size-badge]: https://img.shields.io/docker/image-size/zairakai/node/20-test?logo=docker&label=size&color=orange

<!-- Dynamic Size Badges (Single-Stage Images) -->
[mysql-size-badge]: https://img.shields.io/docker/image-size/zairakai/mysql/8.0?logo=docker&label=size

[redis-size-badge]: https://img.shields.io/docker/image-size/zairakai/redis/7?logo=docker&label=size

[nginx-size-badge]: https://img.shields.io/docker/image-size/zairakai/nginx/1.26?logo=docker&label=size

[mailhog-size-badge]: https://img.shields.io/docker/image-size/zairakai/mailhog/latest?logo=docker&label=size

[minio-size-badge]: https://img.shields.io/docker/image-size/zairakai/minio/latest?logo=docker&label=size

[e2e-size-badge]: https://img.shields.io/docker/image-size/zairakai/e2e-testing/latest?logo=docker&label=size

[performance-size-badge]: https://img.shields.io/docker/image-size/zairakai/performance-testing/latest?logo=docker&label=size
