# Docker Ecosystem Reference

[![Pipeline][pipeline-badge]][pipeline]
[![License][license-badge]][license]
[![Discord][discord-badge]][discord]
[![Issues][issues-badge]][issues]
[🏠 Home][home] > [📚 Documentation][docs] > Docker Ecosystem Reference

Quick reference for images, tags, commands, and configurations.

## Table of Contents

- [CI/CD Release Flow](#cicd-release-flow)
- [Image Tags](#image-tags)
  - [PHP Stack](#php-stack)
  - [Node.js Stack](#nodejs-stack)
  - [Database Services](#database-services)
  - [Web & Services](#web--services)
- [Build Commands](#build-commands)
  - [Build All Images](#build-all-images)
  - [Build Individual Images](#build-individual-images)
- [Docker Compose Configurations](#docker-compose-configurations)
  - [Development Stack](#development-stack)
  - [Production Stack](#production-stack)
- [Common Commands](#common-commands)
  - [Laravel Development](#laravel-development)
  - [Vue.js Development](#vuejs-development)
  - [Database Operations](#database-operations)
  - [Health Checks](#health-checks)
- [Security Commands](#security-commands)
  - [Manual Security Scanning](#manual-security-scanning)
- [Monitoring & Logs](#monitoring--logs)
  - [Container Monitoring](#container-monitoring)
  - [Performance Analysis](#performance-analysis)
- [Environment Variables](#environment-variables)
  - [PHP Configuration](#php-configuration)
  - [Node.js Configuration](#nodejs-configuration)
  - [Service Configuration](#service-configuration)
  - [GitLab CI/CD Variables](#gitlab-cicd-variables)
- [Useful Links](#useful-links)

## CI/CD Release Flow

**Trigger**: pushing a tag `vX.Y.Z` starts the release pipeline.

**Pipeline Stages:**

- **Build**: all images are built **locally on the CI runner** with a `-$CI_COMMIT_SHORT_SHA` suffix (NOT pushed to registry).
  - Examples: `php:8.3-<sha>-prod`, `mysql-8.0-<sha>` (local-only)
  - All build jobs run on the same runner (shared Docker daemon)
- **Test**: readiness via `docker inspect` plus image sizes validation and multi-stage integrity checks
- **Promote**: if checks pass, stable tags are created and pushed to registry
  - Examples: `php:8.3-prod`, `php:1.3.0-prod`, `php:latest-prod`
  - Stable tags are automatically synced to Docker Hub

**Notes:**

- Staging images exist **only locally on the CI runner**, never in the registry
- Registry contains **only stable production-ready images** (no ephemeral staging tags)
- Runner's daily Docker cleanup removes local staging images automatically
- MailHog/MinIO are thin wrappers on top of official images, with versions pinned in their Dockerfiles

## Image Tags

### PHP Stack

```bash
# Production
registry.gitlab.com/zairakai/docker-ecosystem/php:8.3-prod         # Technical version (PHP 8.3)
registry.gitlab.com/zairakai/docker-ecosystem/php:1.1.0-prod       # Release version
registry.gitlab.com/zairakai/docker-ecosystem/php:latest-prod      # Latest stable

# Development
registry.gitlab.com/zairakai/docker-ecosystem/php:8.3-dev          # Technical version (PHP 8.3)
registry.gitlab.com/zairakai/docker-ecosystem/php:1.1.0-dev        # Release version
registry.gitlab.com/zairakai/docker-ecosystem/php:latest-dev       # Latest stable

# Testing
registry.gitlab.com/zairakai/docker-ecosystem/php:8.3-test         # Technical version (PHP 8.3)
registry.gitlab.com/zairakai/docker-ecosystem/php:1.1.0-test       # Release version
registry.gitlab.com/zairakai/docker-ecosystem/php:latest-test      # Latest stable
```

### Node.js Stack

```bash
# Production
registry.gitlab.com/zairakai/docker-ecosystem/node:20-prod        # Technical version (Node 20 LTS)
registry.gitlab.com/zairakai/docker-ecosystem/node:1.1.0-prod     # Release version
registry.gitlab.com/zairakai/docker-ecosystem/node:latest-prod    # Latest stable

# Development
registry.gitlab.com/zairakai/docker-ecosystem/node:20-dev         # Technical version (Node 20 LTS)
registry.gitlab.com/zairakai/docker-ecosystem/node:1.1.0-dev      # Release version
registry.gitlab.com/zairakai/docker-ecosystem/node:latest-dev     # Latest stable

# Testing
registry.gitlab.com/zairakai/docker-ecosystem/node:20-test        # Technical version (Node 20 LTS)
registry.gitlab.com/zairakai/docker-ecosystem/node:1.1.0-test     # Release version
registry.gitlab.com/zairakai/docker-ecosystem/node:latest-test    # Latest stable
```

### Database Services

```bash
registry.gitlab.com/zairakai/docker-ecosystem/database:mysql-8.0           # Service version
registry.gitlab.com/zairakai/docker-ecosystem/database:mysql-8.0-1.1.0     # Release version
registry.gitlab.com/zairakai/docker-ecosystem/database:mysql-8.0-latest    # Latest stable

registry.gitlab.com/zairakai/docker-ecosystem/database:redis-7             # Service version
registry.gitlab.com/zairakai/docker-ecosystem/database:redis-7-1.1.0       # Release version
registry.gitlab.com/zairakai/docker-ecosystem/database:redis-7-latest      # Latest stable
```

### Web & Services

```bash
# Web Server
registry.gitlab.com/zairakai/docker-ecosystem/web:nginx-1.26               # Service version
registry.gitlab.com/zairakai/docker-ecosystem/web:nginx-1.26-1.1.0         # Release version
registry.gitlab.com/zairakai/docker-ecosystem/web:nginx-1.26-latest        # Latest stable

# Development Services
registry.gitlab.com/zairakai/docker-ecosystem/services:mailhog             # Service name
registry.gitlab.com/zairakai/docker-ecosystem/services:mailhog-1.1.0       # Release version
registry.gitlab.com/zairakai/docker-ecosystem/services:mailhog-latest      # Latest stable

registry.gitlab.com/zairakai/docker-ecosystem/services:minio               # Service name
registry.gitlab.com/zairakai/docker-ecosystem/services:minio-1.1.0         # Release version
registry.gitlab.com/zairakai/docker-ecosystem/services:minio-latest        # Latest stable

registry.gitlab.com/zairakai/docker-ecosystem/services:e2e-testing         # Service name
registry.gitlab.com/zairakai/docker-ecosystem/services:e2e-testing-1.1.0   # Release version
registry.gitlab.com/zairakai/docker-ecosystem/services:e2e-testing-latest  # Latest stable
```

## Build Commands

### Build All Images

```bash
# Build complete stack with versioned tags
./scripts/build-all-images.sh

# Build with registry push
PUSH_TO_REGISTRY=true ./scripts/build-all-images.sh

# Build with custom registry
DOCKER_REGISTRY=your-registry.com ./scripts/build-all-images.sh
```

### Build Individual Images

```bash
# PHP Images (multi-stage build with --target)
docker build --target prod -t registry.gitlab.com/zairakai/docker-ecosystem/php:8.3-prod images/php/8.3/
docker build --target dev -t registry.gitlab.com/zairakai/docker-ecosystem/php:8.3-dev images/php/8.3/
docker build --target test -t registry.gitlab.com/zairakai/docker-ecosystem/php:8.3-test images/php/8.3/

# Node.js Images (multi-stage build with --target)
docker build --target prod -t registry.gitlab.com/zairakai/docker-ecosystem/node:20-prod images/node/20/
docker build --target dev -t registry.gitlab.com/zairakai/docker-ecosystem/node:20-dev images/node/20/
docker build --target test -t registry.gitlab.com/zairakai/docker-ecosystem/node:20-test images/node/20/

# Database Images
docker build -t registry.gitlab.com/zairakai/docker-ecosystem/database:mysql-8.0 images/database/mysql/8.0/
docker build -t registry.gitlab.com/zairakai/docker-ecosystem/database:redis-7 images/database/redis/7/

# Service Images
docker build -t registry.gitlab.com/zairakai/docker-ecosystem/web:nginx-1.26 images/web/nginx/1.26/
docker build -t registry.gitlab.com/zairakai/docker-ecosystem/services:mailhog images/services/mailhog/
docker build -t registry.gitlab.com/zairakai/docker-ecosystem/services:minio images/services/minio/
docker build -t registry.gitlab.com/zairakai/docker-ecosystem/services:e2e-testing images/services/e2e-testing/
```

## Docker Compose Configurations

### Development Stack

```yaml
services:
  app:
    image: registry.gitlab.com/zairakai/docker-ecosystem/php:8.3-dev
    volumes:
      - ./app:/var/www/html
    environment:
      - APP_ENV=local
      - XDEBUG_MODE=develop,debug

  frontend:
    image: registry.gitlab.com/zairakai/docker-ecosystem/node:20-dev
    volumes:
      - ./app:/var/www/html
    ports:
      - "5173:5173"
    command: yarn dev --host 0.0.0.0

  mysql:
    image: registry.gitlab.com/zairakai/docker-ecosystem/database:mysql-8.0
    environment:
      MYSQL_DATABASE: laravel
      MYSQL_USER: laravel
      MYSQL_PASSWORD: secret

  redis:
    image: registry.gitlab.com/zairakai/docker-ecosystem/database:redis-7

  mailhog:
    image: registry.gitlab.com/zairakai/docker-ecosystem/services:mailhog
    ports:
      - "8025:8025"

  minio:
    image: registry.gitlab.com/zairakai/docker-ecosystem/services:minio
    ports:
      - "9000:9000"
      - "9001:9001"
```

### Production Stack

```yaml
services:
  app:
    image: registry.gitlab.com/zairakai/docker-ecosystem/php:8.3-prod
    volumes:
      - ./app:/var/www/html:ro
    environment:
      - APP_ENV=production
    deploy:
      replicas: 3

  frontend:
    image: registry.gitlab.com/zairakai/docker-ecosystem/node:20-prod
    volumes:
      - ./dist:/var/www/html/public:ro

  nginx:
    image: registry.gitlab.com/zairakai/docker-ecosystem/web:nginx-1.26
    ports:
      - "80:80"
      - "443:443"
    depends_on:
      - app
```

## Common Commands

### Laravel Development

```bash
# Container access
docker-compose exec php-dev bash

# Composer commands
docker-compose exec php-dev composer install
docker-compose exec php-dev composer update
docker-compose exec php-dev composer require package/name

# Artisan commands
docker-compose exec php-dev php artisan migrate
docker-compose exec php-dev php artisan make:model ModelName
docker-compose exec php-dev php artisan tinker
docker-compose exec php-dev php artisan optimize:clear

# Testing
docker-compose exec php-test vendor/bin/phpunit
docker-compose exec php-test vendor/bin/phpstan analyse
docker-compose exec php-test vendor/bin/php-cs-fixer fix
```

### Vue.js Development

```bash
# Container access
docker-compose exec node-dev sh

# Package management
docker-compose exec node-dev yarn install
docker-compose exec node-dev yarn add package-name
docker-compose exec node-dev yarn upgrade

# Development
docker-compose exec node-dev yarn dev
docker-compose exec node-dev yarn build
docker-compose exec node-dev yarn preview

# Testing
docker-compose exec node-test yarn test
docker-compose exec node-test yarn test:unit
docker-compose exec node-test yarn test:e2e

# Code quality
docker-compose exec node-dev yarn lint
docker-compose exec node-dev yarn format
```

### Database Operations

```bash
# MySQL
docker-compose exec mysql mysql -u laravel -psecret laravel
docker-compose exec mysql mysqldump -u laravel -psecret laravel > backup.sql

# Redis
docker-compose exec redis redis-cli
docker-compose exec redis redis-cli ping
docker-compose exec redis redis-cli flushall
```

### Health Checks

```bash
# Test all health checks
docker-compose exec php-dev /usr/local/bin/healthcheck.sh
docker-compose exec node-dev /usr/local/bin/healthcheck.sh
docker-compose exec mysql /scripts/healthcheck.sh
docker-compose exec redis /scripts/healthcheck.sh

# Check container status
docker-compose ps
docker-compose logs service-name
```

## Security Commands

### Manual Security Scanning

```bash
# SAST scanning
docker run --rm -v $(pwd):/code \
  registry.gitlab.com/security-products/sast:latest /analyzer run

# Container scanning
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
  registry.gitlab.com/security-products/container-scanning:latest \
  /analyzer run --image registry.gitlab.com/zairakai/docker-ecosystem/php:8.3-prod

# Dependency scanning
docker run --rm -v $(pwd):/code \
  registry.gitlab.com/security-products/dependency-scanning:latest \
  /analyzer run
```

## Monitoring & Logs

### Container Monitoring

```bash
# Resource usage
docker stats

# Logs
docker-compose logs -f
docker-compose logs -f php-dev
docker-compose logs --tail=100 mysql

# Container inspection
docker inspect container-name
docker exec -it container-name ps aux
```

### Performance Analysis

```bash
# Image sizes
docker images registry.gitlab.com/zairakai/docker-ecosystem/*

# Build cache
docker system df
docker builder prune

# Network analysis
docker network ls
docker network inspect docker-ecosystem_default
```

## Environment Variables

### PHP Configuration

```env
# Application
APP_ENV=local|production
APP_DEBUG=true|false
XDEBUG_MODE=develop,debug,coverage

# Database
DB_CONNECTION=mysql
DB_HOST=mysql
DB_PORT=3306
DB_DATABASE=laravel
DB_USERNAME=laravel
DB_PASSWORD=secret

# Cache & Queue
REDIS_HOST=redis
REDIS_PORT=6379
CACHE_DRIVER=redis
QUEUE_CONNECTION=redis

# Mail
MAIL_MAILER=smtp
MAIL_HOST=mailhog
MAIL_PORT=1025
```

### Node.js Configuration

```env
# Environment
NODE_ENV=development|production
VITE_API_URL=http://localhost:8000

# Build
GENERATE_SOURCEMAP=true|false
BUILD_PATH=dist
```

### Service Configuration

```env
# MySQL
MYSQL_ROOT_PASSWORD=secret
MYSQL_DATABASE=laravel
MYSQL_USER=laravel
MYSQL_PASSWORD=secret

# MinIO
MINIO_ROOT_USER=minio
MINIO_ROOT_PASSWORD=minio123

# Registry
DOCKER_REGISTRY=registry.gitlab.com/zairakai/docker-ecosystem
PUSH_TO_REGISTRY=true|false
```

### GitLab CI/CD Variables

**Automatic Variables** (no configuration needed):

The pipeline automatically uses GitLab's built-in CI/CD variables:

- `CI_JOB_TOKEN` - Used for GitLab API authentication (tag cleanup, registry management)
- `CI_REGISTRY`, `CI_REGISTRY_USER`, `CI_REGISTRY_PASSWORD` - Docker registry authentication
- `CI_COMMIT_SHORT_SHA`, `CI_PROJECT_ID` - Pipeline metadata

**Optional Variables** (Settings > CI/CD > Variables):

```env
# Image Signing with Cosign (optional - allows image signature verification)
COSIGN_PRIVATE_KEY=<your-cosign-private-key>
COSIGN_PASSWORD=<password-for-cosign-private-key>
COSIGN_PUBLIC_KEY=<your-cosign-public-key>
```

**Note**: Image signing is optional. The pipeline will continue if signing fails (`allow_failure: true`).

**Docker Registry Mirror**:

The CI/CD pipeline uses Google Container Registry mirror (`https://mirror.gcr.io`) for faster image pulls.
This is optional and may not work in all regions.

To disable or customize:

```bash
# Disable mirror (use direct pulls)
# In GitLab: Settings > CI/CD > Variables
# Add variable: DOCKER_REGISTRY_MIRROR=""

# Use custom mirror
# Add variable: DOCKER_REGISTRY_MIRROR="https://your-mirror.example.com"
```

**Fallback**: If the mirror fails, Docker will automatically fallback to pulling from the official registry.

**Generating Cosign Keys**:

```bash
# Install Cosign
brew install cosign  # macOS
# or
wget https://github.com/sigstore/cosign/releases/download/v2.2.2/cosign-linux-amd64
chmod +x cosign-linux-amd64
sudo mv cosign-linux-amd64 /usr/local/bin/cosign

# Generate key pair
cosign generate-key-pair

# This creates:
# - cosign.key (private key) -> Add to COSIGN_PRIVATE_KEY variable
# - cosign.pub (public key) -> Add to COSIGN_PUBLIC_KEY variable
# - Password prompt -> Add to COSIGN_PASSWORD variable
```

**Adding to GitLab**:

1. Go to your project: Settings > CI/CD > Variables
2. Add variable `COSIGN_PRIVATE_KEY`:
   - Type: File
   - Value: Content of `cosign.key`
   - Protected: Yes
   - Masked: No (too long)
3. Add variable `COSIGN_PASSWORD`:
   - Type: Variable
   - Value: Your Cosign password
   - Protected: Yes
   - Masked: Yes
4. Add variable `COSIGN_PUBLIC_KEY`:
   - Type: File
   - Value: Content of `cosign.pub`
   - Protected: Yes
   - Masked: No

## Useful Links

- **[Architecture Guide][architecture]** - Technical overview
- **[Quick Start][quickstart]** - 5-minute setup
- **[Security Policy][security]** - Security scanning
- **[Contributing][contributing]** - Development guidelines
- **[Examples][examples]** - Ready-to-use configurations

## Navigation

- [← Architecture Comparison][architecture-comparison]
- [📚 Documentation Index][docs]

**Learn More:**

- **[Architecture Guide][architecture]** - System design patterns
- **[Testing Modes][testing-modes]** - Blade, SPA, and Hybrid architectures
- **[Monitoring Guide][monitoring]** - Prometheus, Grafana, Jaeger setup

## Support

[![Discord][discord-badge]][discord]
[![Issues][issues-badge]][issues]

## Support

[![Discord][discord-badge]][discord]
[![Issues][issues-badge]][issues]

**Need help?** Join our Discord community or report issues on GitLab.


<!-- Badge References -->
[pipeline-badge]: https://gitlab.com/zairakai/docker-ecosystem/badges/main/pipeline.svg
[pipeline]: https://gitlab.com/zairakai/docker-ecosystem/-/pipelines
[license-badge]: https://img.shields.io/badge/license-MIT-blue.svg
[license]: ../LICENSE
[discord-badge]: https://img.shields.io/discord/1260000352699289621?logo=discord&label=Discord&color=5865F2
[issues-badge]: https://img.shields.io/gitlab/issues/open-raw/zairakai%2Fdocker-ecosystem?logo=gitlab&label=Issues

<!-- Reference Links -->

[home]: ../README.md
[docs]: INDEX.md
[architecture-comparison]: ARCHITECTURE_COMPARISON.md
[architecture]: ARCHITECTURE.md
[testing-modes]: TESTING_MODES.md
[monitoring]: MONITORING.md
[quickstart]: QUICKSTART.md
[security]: ../SECURITY.md
[contributing]: ../CONTRIBUTING.md
[examples]: ../examples/
