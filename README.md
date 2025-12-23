# Zairakai Docker Ecosystem

![Zairakai Docker Ecosystem][banner]

<!-- CI/CD & Quality -->
[![Main][pipeline-main-badge]][pipeline-main-link]
[![Develop][pipeline-develop-badge]][pipeline-develop-link]
[![Security][security-badge]][security]
[![License][license-badge]][license]

<!-- Registries -->
[![Docker Hub][dockerhub-badge]][dockerhub]
[![GitLab Registry][gitlab-registry-badge]][gitlab-registry]

<!-- Download Statistics -->
[![PHP Pulls][php-pulls-badge]][dockerhub-php]
[![MySQL Pulls][mysql-pulls-badge]][dockerhub-mysql]
[![Redis Pulls][redis-pulls-badge]][dockerhub-redis]
[![Node Pulls][node-pulls-badge]][dockerhub-node]

<!-- Available Images -->
[![PHP 8.3][php-version-badge]][dockerhub-php]
[![Node 20][node-version-badge]][dockerhub-node]
[![MySQL 8.0][mysql-version-badge]][dockerhub-mysql]
[![Redis 7][redis-version-badge]][dockerhub-redis]
[![Nginx 1.26][nginx-version-badge]][dockerhub-nginx]
[![MailHog][mailhog-badge]][dockerhub-mailhog]
[![MinIO][minio-badge]][dockerhub-minio]

**12 lightweight images** with progressive architecture (prod → dev → test) and comprehensive security scanning.

> 📦 **This is an image repository**  
> These images are intended to be **consumed by application repositories** (via Docker Compose, CI/CD, or orchestration), not for direct development inside this repository.

## 📦 Available Registries

Images are available on **two registries** for maximum convenience:

### Docker Hub (Recommended for simplicity)

```bash
docker pull zairakai/php:8.3-prod
docker pull zairakai/mysql:8.0
docker pull zairakai/redis:7
docker pull zairakai/nginx:1.26
```

### GitLab Container Registry (Primary source)

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

**Alternative:** Use GitLab Registry by replacing `zairakai/` with `registry.gitlab.com/zairakai/docker-ecosystem/`
and adjusting image names (see [Image Naming](#image-naming-conventions) below).

**[📚 Documentation Index](docs/INDEX.md)** | **[5-Minute Tutorial][quickstart]** | **[Examples][examples]** | **[Architecture Guide][architecture]**

## CI/CD Release Flow (Quality-Gated)

- Trigger: pushing a tag `vX.Y.Z` starts the release pipeline.
- Build (staging): all images are built and pushed with a `-$CI_COMMIT_SHORT_SHA` suffix.
  - Examples: `php:8.3-<sha>-prod`, `web:nginx-1.26-<sha>`, `services:minio-<sha>`.
- Tests: **quality-gated validation** using container readiness checks
  (`docker inspect`, HTTP/CLI probes), crash-loop detection and timeouts.
- Promotion: if all checks pass, tags are re‑tagged to stable without the suffix (e.g., `php:8.3-prod`).
- Cleanup: staging tags are removed from the registry (on success or failure) to keep it clean.

Notes:

- MailHog/MinIO are thin wrappers on top of official images, with versions pinned in their Dockerfiles.
- Staging tags are ephemeral and should not be consumed by downstream projects.

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
│   ├── promote.sh                   # Promote staging tags to stable
│   ├── cleanup.sh                   # Clean up staging tags
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
# Promote staging tags to stable version tags
PROMOTED_VERSION=v1.2.3 bash scripts/promote.sh

# Sync stable images to Docker Hub
bash scripts/pipeline/sync-dockerhub.sh

# Cleanup staging tags from registry
bash scripts/cleanup.sh
```

**Benefits:**

- [x] **Local execution** - Test scripts before pushing to CI
- [x] **DRY principle** - Zero code duplication in `.gitlab-ci.yml`
- [x] **ShellCheck 100%** - All scripts pass strict validation
- [x] **Maintainability** - Logic separated from CI configuration
- [x] **Debuggability** - Clear logs via `common.sh` functions

## 📦 Available Images

### Core Stack

- **PHP 8.3**: `prod` _(45MB)_, `dev` _(85MB)_, `test` _(180MB)_ - Laravel backend
- **Node.js 20 LTS**: `prod` _(35MB)_, `dev` _(120MB)_, `test` _(240MB)_ - Vue.js frontend
- **MySQL 8.0 + Redis 7**: Database and caching
- **Nginx 1.26**: Reverse proxy and static files

### Services

- **MailHog**: Email testing with web interface
- **MinIO**: S3-compatible object storage
- **E2E Testing**: Playwright + Gherkin/Cucumber for Blade and Vue.js testing
- **Performance Testing**: Artillery, k6, Locust for load and stress testing

## 🏷️ Image Naming Conventions

Images use different naming patterns depending on the registry:

| Image Type | Docker Hub | GitLab Container Registry |
| ---------- | ---------- | ------------------------- |
| **PHP** | `zairakai/php:8.3-prod` | `registry.gitlab.com/zairakai/docker-ecosystem/php:8.3-prod` |
| **Node.js** | `zairakai/node:20-dev` | `registry.gitlab.com/zairakai/docker-ecosystem/node:20-dev` |
| **MySQL** | `zairakai/mysql:8.0` | `registry.gitlab.com/zairakai/docker-ecosystem/database:mysql-8.0` |
| **Redis** | `zairakai/redis:7` | `registry.gitlab.com/zairakai/docker-ecosystem/database:redis-7` |
| **Nginx** | `zairakai/nginx:1.26` | `registry.gitlab.com/zairakai/docker-ecosystem/web:nginx-1.26` |
| **MailHog** | `zairakai/mailhog:latest` | `registry.gitlab.com/zairakai/docker-ecosystem/services:mailhog` |
| **MinIO** | `zairakai/minio:latest` | `registry.gitlab.com/zairakai/docker-ecosystem/services:minio` |

**Key Differences:**

- **Docker Hub**: Simpler names (`zairakai/mysql:8.0`)
- **GitLab Registry**: Grouped by type (`database:mysql-8.0`, `services:mailhog`)
- Both registries provide identical images with the same content and layers

**Recommendation:** Use **Docker Hub** for simpler syntax in docker-compose files, or **GitLab Registry** if you need private access or specific versioning.

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

## Support

- [Discord][discord] - Community discussions (_🖥️・Developers_ role)
- [Report Issues][issues]
- [Documentation][docs] - Architecture and reference guides

## License

MIT License - see [LICENSE][license] file for details.

_Built with ❤️ by the Zairakai team for Laravel + Vue.js developers_

<!-- Reference Links -->

[banner]: ./assets/banner.svg
[license]: ./LICENSE
[docker]: https://www.docker.com/
[php]: https://www.php.net/
[nodejs]: https://nodejs.org/
[mysql]: https://www.mysql.com/
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
[issues]: https://gitlab.com/zairakai/docker-ecosystem/-/issues
[discord]: https://discord.gg/MAmD5SG8Zu

<!-- Badge Links -->
[pipeline-main-badge]: https://gitlab.com/zairakai/docker-ecosystem/badges/main/pipeline.svg?ignore_skipped=true&key_text=Main
[pipeline-main-link]: https://gitlab.com/zairakai/docker-ecosystem/commits/main
[pipeline-develop-badge]: https://gitlab.com/zairakai/docker-ecosystem/badges/develop/pipeline.svg?ignore_skipped=true&key_text=Develop
[pipeline-develop-link]: https://gitlab.com/zairakai/docker-ecosystem/commits/develop
[license-badge]: https://img.shields.io/badge/license-MIT-blue.svg
[dockerhub-badge]: https://img.shields.io/badge/docker%20hub-zairakai-blue?logo=docker
[dockerhub]: https://hub.docker.com/u/zairakai
[gitlab-registry-badge]: https://img.shields.io/badge/gitlab%20registry-available-orange?logo=gitlab
[gitlab-registry]: https://gitlab.com/zairakai/docker-ecosystem/container_registry
[php-pulls-badge]: https://img.shields.io/docker/pulls/zairakai/php?label=PHP%20pulls&logo=docker
[dockerhub-php]: https://hub.docker.com/r/zairakai/php
[mysql-pulls-badge]: https://img.shields.io/docker/pulls/zairakai/mysql?label=MySQL%20pulls&logo=docker
[dockerhub-mysql]: https://hub.docker.com/r/zairakai/mysql
[redis-pulls-badge]: https://img.shields.io/docker/pulls/zairakai/redis?label=Redis%20pulls&logo=docker
[dockerhub-redis]: https://hub.docker.com/r/zairakai/redis
[node-pulls-badge]: https://img.shields.io/docker/pulls/zairakai/node?label=Node%20pulls&logo=docker
[dockerhub-node]: https://hub.docker.com/r/zairakai/node
[php-version-badge]: https://img.shields.io/badge/PHP-8.3-777BB4?logo=php&logoColor=white
[node-version-badge]: https://img.shields.io/badge/Node-20%20LTS-339933?logo=node.js&logoColor=white
[mysql-version-badge]: https://img.shields.io/badge/MySQL-8.0-4479A1?logo=mysql&logoColor=white
[redis-version-badge]: https://img.shields.io/badge/Redis-7-DC382D?logo=redis&logoColor=white
[nginx-version-badge]: https://img.shields.io/badge/Nginx-1.26-009639?logo=nginx&logoColor=white
[dockerhub-nginx]: https://hub.docker.com/r/zairakai/nginx
[mailhog-badge]: https://img.shields.io/badge/MailHog-latest-00ADD8?logo=mail.ru&logoColor=white
[dockerhub-mailhog]: https://hub.docker.com/r/zairakai/mailhog
[minio-badge]: https://img.shields.io/badge/MinIO-latest-C72E49?logo=minio&logoColor=white
[dockerhub-minio]: https://hub.docker.com/r/zairakai/minio
[security-badge]: https://img.shields.io/badge/security-scanned-green.svg
