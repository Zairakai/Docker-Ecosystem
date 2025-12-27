# Node.js 20 LTS - Production-Ready Images for Vue.js


<!-- Image Stats -->
[![Docker Pulls][pulls-badge]][dockerhub]
[![Image Size][size-badge]][dockerhub]

<!-- CI/CD & Quality -->
[![Pipeline][pipeline-badge]][pipeline]
[![License][license-badge]][license]

<!-- Community -->
[![Discord][discord-badge]][discord]

Lightweight, secure, and optimized Node.js 20 LTS images designed for **Vue.js + Vite** applications.

Part of the [Zairakai Docker Ecosystem](https://gitlab.com/zairakai/docker-ecosystem) - a complete Docker stack for Laravel + Vue.js development.

---

## Available Tags

| Tag | Use Case | Key Features |
|-----|----------|--------------|
| `20-prod` | Production | Minimal runtime, non-root |
| `20-dev` | Development | + Yarn, npm, build tools, ESLint |
| `20-test` | CI/CD Testing | + Jest, Playwright, Gherkin/Cucumber |
| `latest-prod` | Production (latest) | Alias for 20-prod |
| `latest-dev` | Development (latest) | Alias for 20-dev |
| `latest-test` | Testing (latest) | Alias for 20-test |

---

## Quick Start

### Production (Run Built Assets)

```bash
docker pull zairakai/node:20-prod

# Serve production build
docker run -d \
  -v ./dist:/app/dist \
  -p 3000:3000 \
  zairakai/node:20-prod \
  node server.js
```

### Development (with Hot Reload)

```bash
docker pull zairakai/node:20-dev

docker run -d \
  -v ./vue-app:/app \
  -p 5173:5173 \
  -p 24678:24678 \
  zairakai/node:20-dev \
  npm run dev
```

### Docker Compose with Laravel Backend

```yaml
version: '3.8'
services:
  frontend:
    image: zairakai/node:20-dev
    working_dir: /app
    volumes:
      - ./frontend:/app
    ports:
      - "5173:5173"  # Vite dev server
      - "24678:24678"  # Vite HMR
    command: npm run dev
    networks:
      - laravel

  backend:
    image: zairakai/php:8.3-dev
    volumes:
      - ./backend:/var/www/html
    networks:
      - laravel

  nginx:
    image: zairakai/nginx:1.26
    ports:
      - "80:80"
    depends_on:
      - frontend
      - backend
    networks:
      - laravel

networks:
  laravel:
```

---

## Installed Tools

### Production (`20-prod`)
- **Node.js 20.x LTS** - JavaScript runtime
- **npm** - Package manager (minimal)

### Development (`20-dev`)
- **Yarn** - Fast package manager
- **npm** - Package manager
- **ESLint** - Linting and code quality
- **Build tools**: Vite, Webpack support
- **TypeScript** - Type-safe JavaScript

### Testing (`20-test`)
- **Jest** - Unit testing framework
- **Playwright** - E2E browser testing
- **Cucumber/Gherkin** - BDD testing
- **Testing Library** - Component testing

---

## Key Features

### Security First
- **Non-root execution**: Runs as `node:node` (UID/GID 1000)
- **Alpine Linux base**: Minimal attack surface
- **Dependency scanning**: Automated npm audit in CI/CD
- **No secrets in images**: Configuration via environment variables

### Performance Optimized
- **Minimal production size**: 35MB runtime-only image
- **Multi-stage builds**: Build artifacts excluded from production
- **Vite optimized**: Pre-configured for fast HMR
- **Caching**: npm/yarn cache layers optimized

### Developer Experience
- **Hot Module Replacement**: Full HMR support for Vite/Webpack
- **TypeScript ready**: Pre-configured for TS projects
- **ESLint included**: Code quality out of the box
- **Volume-friendly**: Proper permissions for bind mounts

---

## Configuration

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `NODE_ENV` | `production` | Node environment |
| `PORT` | `3000` | Application port |
| `VITE_PORT` | `5173` | Vite dev server port |
| `VITE_HMR_PORT` | `24678` | Vite HMR port |

### Vite Configuration

For Docker development, configure Vite:

```javascript
// vite.config.js
export default {
  server: {
    host: '0.0.0.0',  // Listen on all interfaces
    port: 5173,
    strictPort: true,
    hmr: {
      port: 24678,  // Explicit HMR port
      clientPort: 24678
    },
    watch: {
      usePolling: true  // Required for Docker volumes
    }
  }
}
```

---

## Architecture

This image follows a **progressive extension architecture**:

```
Production (minimal) → Development (+tools) → Testing (+frameworks)
```

Each layer builds upon the previous, ensuring:
- **Production stays minimal** (35MB)
- **No dev dependencies in production**
- **Consistent Node.js version across environments**

---

## Use Cases

### Vue.js + Vite Applications
Optimized for Vue 3 with Vite:
- Fast HMR in development
- Optimized production builds
- TypeScript support

### Nuxt 3 Applications
Perfect for Nuxt 3 SSR/SSG:
- Server-side rendering
- Static site generation
- API routes

### React + Vite/Next.js
Works great with React ecosystems:
- React 18+ support
- Next.js compatible
- Fast refresh

### Build Pipelines
Excellent for CI/CD:
- Consistent build environment
- Cached dependencies
- Reproducible builds

---

## Common Workflows

### Build Vue.js for Production

```bash
# Build locally
docker run --rm \
  -v ./vue-app:/app \
  zairakai/node:20-dev \
  sh -c "npm install && npm run build"

# Serve with production image
docker run -d \
  -v ./vue-app/dist:/app/dist \
  -p 3000:3000 \
  zairakai/node:20-prod \
  npx serve -s dist -l 3000
```

### Run Tests

```bash
docker run --rm \
  -v ./vue-app:/app \
  zairakai/node:20-test \
  npm test
```

### Lint Code

```bash
docker run --rm \
  -v ./vue-app:/app \
  zairakai/node:20-dev \
  npm run lint
```

---

## Integration with Laravel

### Laravel + Vite (Recommended)

```yaml
# docker-compose.yml
services:
  frontend:
    image: zairakai/node:20-dev
    volumes:
      - ./:/var/www/html
    working_dir: /var/www/html
    command: npm run dev
    ports:
      - "5173:5173"
    networks:
      - laravel

  backend:
    image: zairakai/php:8.3-dev
    volumes:
      - ./:/var/www/html
    networks:
      - laravel
```

Laravel will proxy Vite dev server automatically:

```blade
{{-- resources/views/app.blade.php --}}
@vite(['resources/js/app.js'])
```

---

## Health Checks

Built-in health check for web servers:

```yaml
services:
  frontend:
    image: zairakai/node:20-prod
    healthcheck:
      test: ["CMD", "wget", "--quiet", "--tries=1", "--spider", "http://localhost:3000/health"]
      interval: 30s
      timeout: 10s
      retries: 3
```

---

## Documentation

- **Full Documentation**: https://gitlab.com/zairakai/docker-ecosystem/-/blob/main/docs/INDEX.md
- **Quickstart Guide**: https://gitlab.com/zairakai/docker-ecosystem/-/blob/main/docs/QUICKSTART.md
- **Testing Modes**: https://gitlab.com/zairakai/docker-ecosystem/-/blob/main/docs/TESTING_MODES.md
- **Docker Compose Examples**: https://gitlab.com/zairakai/docker-ecosystem/-/tree/main/examples/compose

---


## Related Images

| Image | Description |
|-------|-------------|
| [zairakai/php](https://hub.docker.com/r/zairakai/php) | PHP 8.3 for Laravel |
| [zairakai/nginx](https://hub.docker.com/r/zairakai/nginx) | Nginx reverse proxy |
| [zairakai/mysql](https://hub.docker.com/r/zairakai/mysql) | MySQL 8.0 with HA |
| [zairakai/redis](https://hub.docker.com/r/zairakai/redis) | Redis 7 with Sentinel |

---


## Support

[![Discord][discord-badge]][discord]
[![Issues][issues-badge]][issues]

**Need help?** Join our Discord community or report issues on GitLab.

**Built with care by [Zairakai](https://gitlab.com/zairakai) for the Vue.js community.**

<!-- Badge References -->
[pulls-badge]: https://img.shields.io/docker/pulls/zairakai/node?logo=docker&logoColor=white
[size-badge]: https://img.shields.io/docker/image-size/zairakai/node/20-prod?logo=docker&logoColor=white&label=size
[pipeline-badge]: https://gitlab.com/zairakai/docker-ecosystem/badges/main/pipeline.svg
[pipeline]: https://gitlab.com/zairakai/docker-ecosystem/-/pipelines
[license-badge]: https://img.shields.io/badge/license-MIT-blue.svg
[license]: https://gitlab.com/zairakai/docker-ecosystem/-/blob/main/LICENSE
[discord-badge]: https://img.shields.io/discord/1260000352699289621?logo=discord&label=Discord&color=5865F2
[discord]: https://discord.gg/MAmD5SG8Zu
[issues-badge]: https://img.shields.io/gitlab/issues/open-raw/zairakai%2Fdocker-ecosystem?logo=gitlab&label=Issues
[issues]: https://gitlab.com/zairakai/docker-ecosystem/-/issues
[dockerhub]: https://hub.docker.com/r/zairakai/node
