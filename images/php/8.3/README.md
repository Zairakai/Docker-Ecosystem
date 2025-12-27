# PHP 8.3 - Production-Ready Images for Laravel

[![Docker Image Size](https://img.shields.io/docker/image-size/zairakai/php/8.3-prod)](https://hub.docker.com/r/zairakai/php)
[![Docker Pulls](https://img.shields.io/docker/pulls/zairakai/php)](https://hub.docker.com/r/zairakai/php)
[![GitLab Pipeline](https://gitlab.com/zairakai/docker-ecosystem/badges/main/pipeline.svg)](https://gitlab.com/zairakai/docker-ecosystem/-/pipelines)

Lightweight, secure, and optimized PHP 8.3 FPM images designed for **Laravel** applications.

Part of the [Zairakai Docker Ecosystem](https://gitlab.com/zairakai/docker-ecosystem) - a complete Docker stack for Laravel + Vue.js development.

---

## Available Tags

| Tag | Size | Use Case | Key Features |
|-----|------|----------|--------------|
| `8.3-prod` | ~45MB | Production | Minimal, OPcache, non-root |
| `8.3-dev` | ~85MB | Development | + Xdebug, Composer, dev tools |
| `8.3-test` | ~180MB | CI/CD Testing | + PHPUnit, Pcov, Xhprof, PHPStan |
| `latest-prod` | ~45MB | Production (latest) | Alias for 8.3-prod |
| `latest-dev` | ~85MB | Development (latest) | Alias for 8.3-dev |
| `latest-test` | ~180MB | Testing (latest) | Alias for 8.3-test |

---

## Quick Start

### Production

```bash
docker pull zairakai/php:8.3-prod

# Run with your Laravel app
docker run -d \
  -v ./laravel-app:/var/www/html \
  -p 9000:9000 \
  zairakai/php:8.3-prod
```

### Development (with Xdebug)

```bash
docker pull zairakai/php:8.3-dev

docker run -d \
  -v ./laravel-app:/var/www/html \
  -p 9000:9000 \
  -e XDEBUG_MODE=debug \
  -e XDEBUG_CONFIG="client_host=host.docker.internal" \
  zairakai/php:8.3-dev
```

### Docker Compose (Recommended)

```yaml
version: '3.8'
services:
  app:
    image: zairakai/php:8.3-dev
    volumes:
      - ./:/var/www/html
    environment:
      - APP_ENV=local
      - XDEBUG_MODE=debug
    networks:
      - laravel

  nginx:
    image: zairakai/nginx:1.26
    ports:
      - "80:80"
    volumes:
      - ./:/var/www/html
    depends_on:
      - app
    networks:
      - laravel

  mysql:
    image: zairakai/mysql:8.0
    environment:
      - MYSQL_DATABASE=laravel
      - MYSQL_USER=laravel
      - MYSQL_PASSWORD=secret
    networks:
      - laravel

networks:
  laravel:
```

---

## Installed PHP Extensions

### Core Extensions (All variants)
- **OPcache** - Bytecode caching
- **PDO** (MySQL, PostgreSQL) - Database drivers
- **GD** - Image manipulation
- **Intl** - Internationalization
- **Zip** - Archive handling
- **BCMath** - Arbitrary precision math
- **Mbstring** - Multi-byte string support
- **Sockets** - Socket communication
- **Pcntl** - Process control

### Development Extensions (`dev` and `test`)
- **Xdebug 3.x** - Step debugging & profiling
- **Composer 2.x** - Dependency management

### Testing Extensions (`test` only)
- **Pcov** - Code coverage (faster than Xdebug)
- **Xhprof** - Performance profiling
- **PHPUnit** - Unit testing framework

---

## Key Features

### Security First
- **Non-root execution**: Runs as `www:www` (UID/GID 82)
- **Alpine Linux base**: Minimal attack surface
- **No secrets in images**: Configuration via environment variables
- **Security scanning**: Automated vulnerability scans in CI/CD

### Performance Optimized
- **OPcache pre-configured**: Production-tuned settings
- **Multi-stage builds**: Only runtime dependencies in production
- **Minimal size**: 70% smaller than Debian-based images
- **FastCGI tuning**: Optimized PHP-FPM settings for Laravel

### Developer Experience
- **Hot reload support**: Development images support file watching
- **Xdebug ready**: Pre-configured for VS Code & PhpStorm
- **Composer included**: No need for separate containers
- **Laravel optimized**: Pre-configured for Laravel best practices

---

## Configuration

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `PHP_MEMORY_LIMIT` | `256M` | PHP memory limit |
| `PHP_MAX_EXECUTION_TIME` | `60` | Script timeout |
| `PHP_UPLOAD_MAX_FILESIZE` | `64M` | Max upload size |
| `PHP_POST_MAX_SIZE` | `64M` | Max POST size |
| `XDEBUG_MODE` | `off` | Xdebug mode (dev/test only) |
| `XDEBUG_CONFIG` | - | Xdebug configuration |

### Custom php.ini

Mount your custom configuration:

```bash
docker run -v ./custom.ini:/usr/local/etc/php/conf.d/99-custom.ini zairakai/php:8.3-prod
```

---

## Architecture

This image follows a **progressive extension architecture**:

```
Production (minimal) → Development (+tools) → Testing (+frameworks)
```

Each layer builds upon the previous, ensuring:
- **Production stays lean** (45MB)
- **No development tools in production**
- **Consistent behavior across environments**

---

## Health Checks

Built-in health check monitors PHP-FPM:

```bash
docker ps  # Shows health status
```

Custom health check:
```bash
docker inspect --format='{{.State.Health.Status}}' <container-id>
```

---

## Use Cases

### Laravel Applications
Optimized for Laravel 10+:
- Pre-installed extensions (Redis, MySQL, GD, etc.)
- OPcache tuned for Laravel
- Artisan command support

### API Development
Perfect for REST/GraphQL APIs:
- Minimal footprint
- Fast startup time
- Production-grade performance

### Microservices
Lightweight for containerized architectures:
- Small image size
- Quick deployment
- Scalable

---

## Documentation

- **Full Documentation**: https://gitlab.com/zairakai/docker-ecosystem/-/blob/main/docs/INDEX.md
- **Quickstart Guide**: https://gitlab.com/zairakai/docker-ecosystem/-/blob/main/docs/QUICKSTART.md
- **Docker Compose Examples**: https://gitlab.com/zairakai/docker-ecosystem/-/tree/main/examples/compose
- **Kubernetes Deployment**: https://gitlab.com/zairakai/docker-ecosystem/-/blob/main/docs/KUBERNETES.md

---

## Support & Contributing

- **Issues**: https://gitlab.com/zairakai/docker-ecosystem/-/issues
- **Source Code**: https://gitlab.com/zairakai/docker-ecosystem
- **License**: MIT

---

## Related Images

| Image | Description |
|-------|-------------|
| [zairakai/node](https://hub.docker.com/r/zairakai/node) | Node.js 20 for Vue.js/Vite |
| [zairakai/nginx](https://hub.docker.com/r/zairakai/nginx) | Nginx reverse proxy |
| [zairakai/mysql](https://hub.docker.com/r/zairakai/mysql) | MySQL 8.0 with HA |
| [zairakai/redis](https://hub.docker.com/r/zairakai/redis) | Redis 7 with Sentinel |

---

**Built with care by [Zairakai](https://gitlab.com/zairakai) for the Laravel community.**
