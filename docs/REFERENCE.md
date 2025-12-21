# Docker Ecosystem Reference

Quick reference for images, tags, commands, and configurations.

## CI/CD Release Flow

- Trigger: pushing a tag `vX.Y.Z` starts the release pipeline.
- Build (staging): all images are built and pushed with a `-$CI_COMMIT_SHORT_SHA` suffix.
  - Examples: `php:8.3-<sha>-prod`, `web:nginx-1.26-<sha>`, `services:minio-<sha>`.
- Tests: readiness via `docker inspect` plus HTTP/CLI probes (Nginx, MailHog, MinIO, MySQL, Redis) with crash‑loop detection and timeouts.
- Promotion: if checks pass, images are re‑tagged to stable without the suffix (e.g., `php:8.3-prod`).
- Cleanup: staging tags are removed from the registry (on success or failure) to keep it clean.

Notes:

- MailHog/MinIO are thin wrappers on top of official images, with versions pinned in their Dockerfiles.
- Staging tags are ephemeral and should not be consumed by downstream projects.

## Image Tags

### PHP Stack

```bash
# Production
registry.gitlab.com/zairakai/docker-ecosystem/php:8.3-prod
registry.gitlab.com/zairakai/docker-ecosystem/php:8.3.x-prod
registry.gitlab.com/zairakai/docker-ecosystem/php:8.3-latest-prod

# Development
registry.gitlab.com/zairakai/docker-ecosystem/php:8.3-dev
registry.gitlab.com/zairakai/docker-ecosystem/php:8.3.x-dev
registry.gitlab.com/zairakai/docker-ecosystem/php:8.3-latest-dev

# Testing
registry.gitlab.com/zairakai/docker-ecosystem/php:8.3-test
registry.gitlab.com/zairakai/docker-ecosystem/php:8.3.x-test
registry.gitlab.com/zairakai/docker-ecosystem/php:8.3-latest-test
```

### Node.js Stack

```bash
# Production
registry.gitlab.com/zairakai/docker-ecosystem/node:20-prod
registry.gitlab.com/zairakai/docker-ecosystem/node:20.x-prod
registry.gitlab.com/zairakai/docker-ecosystem/node:20-latest-prod

# Development
registry.gitlab.com/zairakai/docker-ecosystem/node:20-dev
registry.gitlab.com/zairakai/docker-ecosystem/node:20.x-dev
registry.gitlab.com/zairakai/docker-ecosystem/node:20-latest-dev

# Testing
registry.gitlab.com/zairakai/docker-ecosystem/node:20-test
registry.gitlab.com/zairakai/docker-ecosystem/node:20.x-test
registry.gitlab.com/zairakai/docker-ecosystem/node:20-latest-test
```

### Database Services

```bash
registry.gitlab.com/zairakai/docker-ecosystem/database:mysql-8.0
registry.gitlab.com/zairakai/docker-ecosystem/database:mysql-8.0.x
registry.gitlab.com/zairakai/docker-ecosystem/database:mysql-latest

registry.gitlab.com/zairakai/docker-ecosystem/database:redis-7
registry.gitlab.com/zairakai/docker-ecosystem/database:redis-7.x
registry.gitlab.com/zairakai/docker-ecosystem/database:redis-latest
```

### Web & Services

```bash
# Web Server
registry.gitlab.com/zairakai/docker-ecosystem/web:nginx-1.26
registry.gitlab.com/zairakai/docker-ecosystem/web:nginx-1.26.x
registry.gitlab.com/zairakai/docker-ecosystem/web:nginx-latest

# Development Services
registry.gitlab.com/zairakai/docker-ecosystem/services:mailhog
registry.gitlab.com/zairakai/docker-ecosystem/services:mailhog-latest

registry.gitlab.com/zairakai/docker-ecosystem/services:minio
registry.gitlab.com/zairakai/docker-ecosystem/services:minio-latest

registry.gitlab.com/zairakai/docker-ecosystem/services:e2e-testing
registry.gitlab.com/zairakai/docker-ecosystem/services:e2e-latest
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
version: "3.8"
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
version: "3.8"
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

## 🚀 Common Commands

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

Required variables for GitLab CI/CD pipeline (Settings > CI/CD > Variables):

```env
# Image Signing with Cosign (optional - allows image signature verification)
COSIGN_PRIVATE_KEY=<your-cosign-private-key>
COSIGN_PASSWORD=<password-for-cosign-private-key>
COSIGN_PUBLIC_KEY=<your-cosign-public-key>
```

**Note**: Image signing is optional. The pipeline will continue if signing fails (`allow_failure: true`).

**Docker Registry Mirror**:

The CI/CD pipeline uses Google Container Registry mirror (`https://mirror.gcr.io`) for faster image pulls. This is optional and may not work in all regions.

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

---

**Need help?** Join our [Discord][discord] community or check the [Reference Guide][reference].

<!-- Reference Links -->
[reference]: REFERENCE.md
[discord]: https://discord.gg/MAmD5SG8Zu

<!-- Reference Links -->

[architecture]: ARCHITECTURE.md
[quickstart]: QUICKSTART.md
[security]: ../SECURITY.md
[contributing]: ../CONTRIBUTING.md
[examples]: ../examples/
