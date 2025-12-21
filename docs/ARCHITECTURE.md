# Docker Ecosystem Architecture

## Overview

The Zairakai Docker Ecosystem provides **12 lightweight Docker images** specifically designed for **Laravel + Vue.js** development, following a progressive **extension-only** architecture.

## Design Philosophy

### Extension-Only Architecture

Each image builds purposefully on the previous one:

- **Base images**: Production-ready with essential components
- **Dev images**: Base + development tools and debugging
- **Test images**: Dev + testing frameworks and coverage

### Transparency & Security

- **No black boxes**: Every addition is visible and documented
- **Non-root users**: All containers run with restricted privileges
- **Alpine Linux**: Minimal attack surface with small image sizes
- **Health checks**: Comprehensive monitoring at every layer

## Image Structure

### PHP Stack (3 images)

```txt
registry.gitlab.com/zairakai/docker-ecosystem/php:8.3-prod (45MB)    ← Production PHP-FPM + essential extensions
    ↓ extends
registry.gitlab.com/zairakai/docker-ecosystem/php:8.3-dev (85MB)     ← Base + Xdebug + Composer + dev tools
    ↓ extends
registry.gitlab.com/zairakai/docker-ecosystem/php:8.3-test (180MB)   ← Dev + PHPUnit + coverage + static analysis
```

### Node.js Stack (3 images)

```txt
registry.gitlab.com/zairakai/docker-ecosystem/node:20-prod (35MB)    ← Production Node.js runtime
    ↓ extends
registry.gitlab.com/zairakai/docker-ecosystem/node:20-dev (120MB)    ← Base + Yarn + build tools + ESLint
    ↓ extends
registry.gitlab.com/zairakai/docker-ecosystem/node:20-test (240MB)   ← Dev + Jest + Playwright + E2E testing
```

### Database & Services (6 images)

- **mysql:8.0** (90MB) - Production MySQL with optimizations
- **redis:7** (35MB) - Cache and session storage
- **nginx:1.26** (25MB) - Reverse proxy with SSL support
- **mailhog** (20MB) - Email testing with web interface
- **minio** (40MB) - S3-compatible object storage
- **e2e-testing** (200MB) - Behavioral testing with .feature files

## 🔗 System Architecture

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

## Performance Benefits

| Metric              | Traditional Setup | Zairakai       | Improvement |
| ------------------- | ----------------- | -------------- | ----------- |
| **Total Images**    | 20-30+ images     | 12 images      | 60% fewer   |
| **Base Image Size** | 150MB+            | 45MB           | 70% smaller |
| **Setup Time**      | 15-30 min         | 5 min          | 80% faster  |
| **Maintenance**     | Complex scripts   | Simple & clear | 90% easier  |

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

### Container Security

- **Non-root execution**: All containers run as `www:www` or `node:node`
- **Health checks**: Comprehensive monitoring at every layer
- **Alpine base**: Minimal attack surface
- **No secrets**: Environment-based configuration only

## Use Cases

### Perfect For

- **Laravel + Vue.js** applications
- **API development** with frontend
- **E-commerce platforms** with file storage
- **SaaS applications** with email features
- **Team development** with consistent environments

### Not Recommended For

- Non-Laravel PHP frameworks (use generic PHP images)
- Pure API backends without frontend (overkill)
- Microservices requiring specialized databases
- Python/Django or Ruby/Rails applications

## Version Strategy

### Tagging Strategy

Each image supports multiple tag levels:

```bash
# Example for PHP 8.3 production
registry.gitlab.com/zairakai/docker-ecosystem/php:8.3-prod         # Specific version
registry.gitlab.com/zairakai/docker-ecosystem/php:8.3.x-prod       # Minor version family
registry.gitlab.com/zairakai/docker-ecosystem/php:8.3-latest-prod  # Latest in this major version
```

### Version Selection

- **PHP 8.3**: Current stable + 6 months strategy
- **Node.js 20 LTS**: Long-term support until 2026
- **MySQL 8.0**: Proven stable version
- **Nginx 1.26**: Latest with HTTP/3 support

## Development Workflow

### Typical Development Session

```bash
# 1. Start core services
docker-compose up -d php-dev mysql redis mailhog

# 2. Laravel setup
docker-compose exec php-dev composer install
docker-compose exec php-dev php artisan migrate

# 3. Frontend development
docker-compose up -d node-dev
docker-compose exec node-dev yarn dev

# 4. Services available
# - Application: http://localhost:8000
# - Emails: http://localhost:8025
# - Files: http://localhost:9001
```

### Testing Workflow

```bash
# Backend tests
docker-compose exec php-test vendor/bin/phpunit

# Frontend tests
docker-compose exec node-test yarn test

# E2E tests with .feature files
docker-compose run --rm e2e-testing
```

---

**Need help?** Join our [Discord][discord] community or check the [Reference Guide][reference].

<!-- Reference Links -->
[reference]: REFERENCE.md
[discord]: https://discord.gg/MAmD5SG8Zu
