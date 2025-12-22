# Docker Ecosystem Architecture

[🏠 Home][home] > [📚 Documentation][docs] > Architecture Overview

Comprehensive architectural overview of the Zairakai Docker Ecosystem - 12 lightweight images following a
progressive extension-only architecture.

## Table of Contents

- [Overview](#overview)
- [Design Philosophy](#design-philosophy)
  - [Extension-Only Architecture](#extension-only-architecture)
  - [Transparency & Security](#transparency--security)
- [Image Structure](#image-structure)
  - [PHP Stack (3 images)](#php-stack-3-images)
  - [Node.js Stack (3 images)](#nodejs-stack-3-images)
  - [Database & Services (6 images)](#database--services-6-images)
- [System Architecture](#system-architecture)
- [Performance Benefits](#performance-benefits)
- [Security Architecture](#security-architecture)
  - [Multi-Layer Security Scanning](#multi-layer-security-scanning)
  - [Container Security](#container-security)
- [Use Cases](#use-cases)
  - [Perfect For](#perfect-for)
  - [Not Recommended For](#not-recommended-for)
- [Version Strategy](#version-strategy)
  - [Tagging Strategy](#tagging-strategy)
  - [Version Selection](#version-selection)
- [Development Workflow](#development-workflow)
  - [Typical Development Session](#typical-development-session)
  - [Testing Workflow](#testing-workflow)
- [Navigation](#navigation)

## Overview

The Zairakai Docker Ecosystem provides **12 lightweight Docker images** specifically designed for
**Laravel + Vue.js** development, following a progressive **extension-only** architecture.

**Key Characteristics:**
- [x] **Progressive layers**: prod → dev → test
- [x] **Alpine Linux base**: 70% smaller images
- [x] **Non-root execution**: Enhanced security
- [x] **Multi-stage builds**: Clean separation of concerns

## Design Philosophy

### Extension-Only Architecture

Each image builds purposefully on the previous one - nothing is removed, only added:

- **Base images (prod)**: Production-ready with essential components only
- **Dev images**: Base + development tools and debugging capabilities
- **Test images**: Dev + testing frameworks, coverage tools, and profiling

**Benefits:**
- 🎯 **Consistency**: Same base across all environments
- 🔒 **Security**: Production stays minimal
- 🚀 **Performance**: No unnecessary bloat in prod
- 🧪 **Testing**: Full toolkit available when needed

### Transparency & Security

- **No black boxes**: Every addition is visible and documented in Dockerfiles
- **Non-root users**: All containers run with restricted privileges (`www:www`, `node:node`)
- **Alpine Linux**: Minimal attack surface with small image sizes
- **Health checks**: Comprehensive monitoring at every layer
- **Environment-based config**: No secrets baked into images

## Image Structure

### PHP Stack (3 images)

```txt
registry.gitlab.com/zairakai/docker-ecosystem/php:8.3-prod (45MB)
    ↓ extends
registry.gitlab.com/zairakai/docker-ecosystem/php:8.3-dev (85MB)
    ↓ extends
registry.gitlab.com/zairakai/docker-ecosystem/php:8.3-test (180MB)
```

**Production (45MB)**:
- PHP 8.3 FPM
- Essential extensions: gd, zip, intl, pdo, bcmath, opcache
- Composer
- Non-root user (www:www)

**Development (+40MB)**:
- Xdebug 3.4
- Redis extension
- Imagick extension
- Development tools (git, vim, mariadb-client)
- PHP-FPM Exporter for Prometheus

**Testing (+95MB)**:
- PCOV (code coverage)
- XHProf (profiling)
- PHPUnit (via project composer.json)
- Static analysis tools (via project composer.json)

### Node.js Stack (3 images)

```txt
registry.gitlab.com/zairakai/docker-ecosystem/node:20-prod (35MB)
    ↓ extends
registry.gitlab.com/zairakai/docker-ecosystem/node:20-dev (120MB)
    ↓ extends
registry.gitlab.com/zairakai/docker-ecosystem/node:20-test (240MB)
```

**Production (35MB)**:
- Node.js 20 LTS (minimal runtime)
- npm + basic tooling
- Non-root user (node:node)

**Development (+85MB)**:
- Yarn + pnpm
- TypeScript + ts-node
- Vite build system
- nodemon + pm2
- ESLint (global)

**Testing (+120MB)**:
- Playwright browsers (Chromium, Firefox, WebKit)
- Cucumber/Gherkin for BDD
- Jest + Vitest
- Lighthouse for performance
- Artillery + k6 for load testing

### Database & Services (6 images)

| Image | Size | Description |
| ----- | ---- | ----------- |
| `database:mysql-8.0` | 90MB | MySQL with replication support |
| `database:redis-7` | 35MB | Redis with Sentinel for HA |
| `web:nginx-1.26` | 25MB | Nginx with HTTP/3 + SSL |
| `services:mailhog` | 20MB | Email testing with web UI |
| `services:minio` | 40MB | S3-compatible object storage |
| `services:e2e-testing` | 200MB | Playwright + Gherkin BDD |

## System Architecture

```txt
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Frontend      │    │    Backend      │    │   Database      │
│                 │    │                 │    │                 │
│ Node.js 20 LTS  │◄──►│ PHP 8.3         │◄──►│ MySQL 8.0       │
│ Vue.js + Vite   │    │ Laravel 11      │    │ Redis 7         │
│ Yarn + ESLint   │    │ Composer        │    │                 │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         └───────────────────────┼───────────────────────┘
                                 │
               ┌─────────────────▼─────────────────┐
               │         Support Services          │
               │                                   │
               │ • Nginx 1.26 (Reverse Proxy)      │
               │ • MailHog (Email Testing)         │
               │ • MinIO (S3 Storage)              │
               │ • E2E Testing (Playwright)        │
               └───────────────────────────────────┘
```

**Communication Flow:**
1. **User → Nginx** (HTTP/HTTPS)
2. **Nginx → PHP-FPM** (FastCGI)
3. **Nginx → Node.js** (Reverse Proxy for assets)
4. **PHP → MySQL/Redis** (Database queries)
5. **PHP → MailHog** (Email testing)
6. **PHP → MinIO** (File storage)

## Performance Benefits

| Metric | Traditional Setup | Zairakai | Improvement |
| ------ | ----------------- | -------- | ----------- |
| **Total Images** | 20-30+ images | 12 images | 60% fewer |
| **Base Image Size** | 150MB+ | 45MB | 70% smaller |
| **Setup Time** | 15-30 min | 5 min | 80% faster |
| **Maintenance** | Complex scripts | Simple & clear | 90% easier |
| **Build Cache Hit** | 30-40% | 80-90% | 2-3x better |

**Why Faster?**
- [x] Alpine base (70% smaller downloads)
- [x] Multi-stage builds (efficient layer caching)
- [x] Pre-built images (no local compilation)
- [x] Optimized Dockerfiles (minimal layers)

## Security Architecture

### Multi-Layer Security Scanning

```txt
Pre-Build Security (security stage)
├── SAST Analysis (Semgrep)
├── Dependency Scanning (Gemnasium + Retire.js)
├── License Compliance
└── IaC Scanning (KICS)

Post-Build Security (security-scan stage)
├── Container Scanning (Trivy)
├── Vulnerability Assessment
└── Security Report Generation
```

**Security Pipeline:**
1. **Validate** → Dockerfile linting (Hadolint)
2. **Scan Dependencies** → Composer + npm packages
3. **Build** → Multi-stage with minimal attack surface
4. **Scan Containers** → Trivy for vulnerabilities
5. **Test** → Health checks + smoke tests
6. **Sign** → Cosign image signing
7. **Promote** → Only secure images reach stable tags

### Container Security

- **Non-root execution**: All containers run as `www:www` or `node:node`
- **Health checks**: Comprehensive monitoring at every layer
- **Alpine base**: Minimal attack surface (5MB base layer)
- **No secrets**: Environment-based configuration only
- **Read-only filesystems**: Where possible
- **Capability dropping**: Minimal Linux capabilities

## Use Cases

### Perfect For

✅ **Laravel + Vue.js applications** - Optimized for this stack
✅ **API development with frontend** - Separate PHP/Node images
✅ **E-commerce platforms** - MinIO for product images
✅ **SaaS applications** - MailHog for transactional emails
✅ **Team development** - Consistent environments across team

### Not Recommended For

❌ **Non-Laravel PHP frameworks** - Use generic PHP images instead
❌ **Pure API backends** - Consider lighter PHP-only setups
❌ **Microservices with specialized DBs** - Too opinionated for microservices
❌ **Python/Django or Ruby/Rails** - Wrong stack entirely

## Version Strategy

### Tagging Strategy

Each image supports multiple tag levels for flexibility:

```bash
# Example for PHP 8.3 production
registry.gitlab.com/zairakai/docker-ecosystem/php:8.3-prod         # Specific version
registry.gitlab.com/zairakai/docker-ecosystem/php:8.3.x-prod       # Minor version family
registry.gitlab.com/zairakai/docker-ecosystem/php:8.3-latest-prod  # Latest in major version
```

**Tag Levels:**
- `8.3-prod` → Pinned to PHP 8.3.x minor version
- `8.3.x-prod` → Auto-updated for security patches
- `8.3-latest-prod` → Latest stable 8.3 release

### Version Selection

| Component | Version | Strategy | Support Until |
| --------- | ------- | -------- | ------------- |
| **PHP** | 8.3 | Current stable + 6 months | Nov 2026 |
| **Node.js** | 20 LTS | Long-term support | Apr 2026 |
| **MySQL** | 8.0 | Proven stable | Apr 2026 |
| **Nginx** | 1.26 | Latest with HTTP/3 | Ongoing |
| **Redis** | 7 | Latest stable | Ongoing |

**Update Policy:**
- **Security patches**: Auto-applied to `.x` tags
- **Minor versions**: Announced, opt-in upgrade
- **Major versions**: New image series (e.g., `php:8.4-*`)

## Development Workflow

### Typical Development Session

```bash
# 1. Start core services
docker-compose up -d app mysql redis mailhog

# 2. Laravel setup
docker-compose exec app composer install
docker-compose exec app php artisan migrate
docker-compose exec app php artisan db:seed

# 3. Frontend development (if using Vite)
docker-compose exec app npm install
docker-compose exec app npm run dev

# 4. Services available
# - Application: http://localhost
# - MailHog UI: http://localhost:8025
# - MinIO: http://localhost:9001
```

**Development Tools Included:**
- [x] Xdebug for step-through debugging
- [x] Composer for dependency management
- [x] Artisan CLI for Laravel commands
- [x] npm/Yarn for frontend tooling
- [x] Git for version control

### Testing Workflow

```bash
# Backend unit tests
docker-compose exec app vendor/bin/phpunit

# Backend with coverage
docker-compose exec app vendor/bin/phpunit --coverage-html coverage

# Frontend unit tests
docker-compose exec app npm test

# E2E tests with Playwright + Gherkin
docker-compose run --rm e2e-testing

# Performance testing
docker-compose run --rm performance-testing
```

**Testing Tools Included:**
- [x] PHPUnit (via composer.json)
- [x] PCOV for fast code coverage
- [x] Jest/Vitest for JS testing
- [x] Playwright for E2E tests
- [x] Artillery/k6 for load testing

## Navigation

- [← Quick Start Guide][quickstart]
- [📚 Documentation Index](INDEX.md)
- [Testing Modes →][testing-modes]

**Learn More:**
- **[Testing Modes][testing-modes]** - Blade, SPA, and Hybrid architectures
- **[Reference Guide][reference]** - Complete image tags and configurations
- **[Monitoring Guide][monitoring]** - Prometheus, Grafana, Jaeger setup

**Need help?** Join our [Discord][discord] community or report issues on [GitLab][issues].

<!-- Reference Links -->

[home]: ../README.md
[docs]: INDEX.md
[quickstart]: QUICKSTART.md
[prerequisites]: PREREQUISITES.md
[testing-modes]: TESTING_MODES.md
[architecture-comparison]: ARCHITECTURE_COMPARISON.md
[reference]: REFERENCE.md
[monitoring]: MONITORING.md
[disaster-recovery]: DISASTER_RECOVERY.md
[kubernetes]: KUBERNETES.md
[swarm]: SWARM.md
[discord]: https://discord.gg/MAmD5SG8Zu
[issues]: https://gitlab.com/zairakai/docker-ecosystem/-/issues
