# Local Development Workflow

[![Pipeline][pipeline-badge]][pipeline]
[![License][license-badge]][license]
[![Discord][discord-badge]][discord]
[![Issues][issues-badge]][issues]
This guide explains how to develop, build, and test the Docker Ecosystem locally.

---

## Quick Reference

```bash
# See all available commands
make help

# Full workflow (build + test)
make build-and-test

# Or step by step
make validate-all     # Validate configs and ShellCheck
make build-all        # Build all 13 images (takes ~10-15 min)
make test-all         # Run all tests on built images
```

---

## Prerequisites

- **Docker** 20.10+ with BuildKit enabled
- **Docker Buildx** plugin
- **Bash** 4.0+
- **ShellCheck** (for validation)
- **Make** (GNU Make 4.0+)

---

## Workflow Steps

### 1. Validation (Always First)

Before building images, validate all configurations:

```bash
make validate-all
```

This runs:
- ✅ **Dockerfile validation** (`validate-config.sh`)
- ✅ **ShellCheck 100% compliance** (`validate-shellcheck.sh`)

**If validation fails, STOP and fix issues before building.**

---

### 2. Build Images

#### Option A: Build All Images (Recommended)

```bash
make build-all
```

Builds all 13 images with `-local` suffix:
- `php:8.3-local-prod`, `php:8.3-local-dev`, `php:8.3-local-test`
- `node:20-local-prod`, `node:20-local-dev`, `node:20-local-test`
- `database:mysql-8.0-local`, `database:redis-7-local`
- `web:nginx-1.26-local`
- `services:mailhog-local`, `services:minio-local`, `services:e2e-testing-local`, `services:performance-testing-local`

**Time:** ~10-15 minutes (first build), ~3-5 minutes (with cache)

**Cache:** Enabled by default via BuildKit inline cache

#### Option B: Build Individual Images

```bash
make build-php-prod    # PHP 8.3 production only
make build-php-dev     # PHP 8.3 development only
make build-node-prod   # Node.js 20 production only
make build-mysql       # MySQL 8.0
```

**Note:** `test-all` requires ALL images to be built, so individual builds are mainly for debugging.

---

### 3. Test Images

**IMPORTANT:** You MUST run `make build-all` before `make test-all`.

```bash
make test-all
```

This runs:
- ✅ **Image size validation** (`test-image-sizes.sh`)
- ✅ **Multi-stage integrity tests** (`test-multi-stage.sh`)

**Output:** `image-sizes.txt` report in project root

#### Common Errors

**Error:** `13 images not found locally`

**Cause:** Images not built yet

**Solution:**
```bash
# Build images first
make build-all

# Then run tests
make test-all
```

---

### 4. Full Workflow (Build + Test)

The easiest way to build and test everything:

```bash
make build-and-test
```

This is equivalent to:
```bash
make build-all && make test-all
```

---

## Image Naming Convention

### Local Development

Images built locally have the `-local` suffix to distinguish them from CI builds:

```
registry.gitlab.com/zairakai/docker-ecosystem/php:8.3-local-prod
                                                    └─────┘
                                                    Suffix added by make
```

### CI/CD Pipeline

CI builds use commit SHA suffix:

```
registry.gitlab.com/zairakai/docker-ecosystem/php:8.3-abc1234-prod
                                                    └──────┘
                                                    CI_COMMIT_SHORT_SHA
```

### Production (After Release)

Released images have clean tags:

```
registry.gitlab.com/zairakai/docker-ecosystem/php:8.3-prod
                                                (no suffix)
```

---

## Cache Management

### Enable Cache (Default)

```bash
CACHE_ENABLED=1 make build-all
```

Uses previous builds as cache layers for faster rebuilds.

### Force Rebuild (No Cache)

```bash
NO_CACHE=1 make build-all
```

Forces complete rebuild from scratch (useful when debugging build issues).

### Clear Docker Cache

```bash
# Clean all local images
docker system prune -af

# Clean build cache only
docker builder prune -af
```

---

## Common Tasks

### Check Image Sizes

After building, view image sizes:

```bash
make test-image-sizes

# Or manually
docker images | grep "zairakai/docker-ecosystem"
```

Expected sizes:
- PHP prod: ~45 MB
- Node prod: ~35 MB
- PHP dev: ~85 MB
- Node dev: ~120 MB
- MySQL: ~150 MB
- Redis: ~40 MB
- Nginx: ~25 MB

### Inspect an Image

```bash
# View layers
docker history registry.gitlab.com/zairakai/docker-ecosystem/php:8.3-local-prod

# Inspect metadata
docker inspect registry.gitlab.com/zairakai/docker-ecosystem/php:8.3-local-prod

# Run interactively
docker run -it --rm registry.gitlab.com/zairakai/docker-ecosystem/php:8.3-local-prod sh
```

### Test an Image

```bash
# Start PHP-FPM
docker run -d --name test-php \
  -v ./test-app:/var/www/html \
  registry.gitlab.com/zairakai/docker-ecosystem/php:8.3-local-dev

# Check PHP version
docker exec test-php php -v

# Check installed extensions
docker exec test-php php -m

# Cleanup
docker stop test-php && docker rm test-php
```

---

## Development Tips

### Dry Run (See Commands Without Executing)

```bash
make dry-run
```

Shows what would be built without actually building.

### Debug Mode

```bash
DEBUG=1 make build-all
```

Enables verbose output for troubleshooting.

### Build Single Stage

If you only need one stage (e.g., dev):

```bash
# Build PHP dev stage only
docker buildx build \
  --target dev \
  --tag php:8.3-dev \
  --load \
  images/php/8.3
```

### Iterate Quickly

When developing a Dockerfile:

```bash
# 1. Make changes to Dockerfile
vim images/php/8.3/Dockerfile

# 2. Validate
make validate

# 3. Build just that image (no cache for testing)
NO_CACHE=1 make build-php-dev

# 4. Test
docker run -it --rm registry.gitlab.com/zairakai/docker-ecosystem/php:8.3-local-dev sh
```

---

## Troubleshooting

### Build Hangs or Times Out

**Problem:** BuildKit stuck on "exporting to image"

**Solution:** Use docker driver instead of docker-container driver

This is handled automatically when `PUSH_TO_REGISTRY=false` (default for local builds).

### ShellCheck Fails

**Problem:** `make validate-all` fails on ShellCheck

**Cause:** Shell script has warnings/errors

**Solution:**
```bash
# See specific errors
shellcheck scripts/pipeline/build-image.sh

# Only SC1091 (info) is acceptable
# All other warnings MUST be fixed
```

### Image Too Large

**Problem:** Production image exceeds 100 MB

**Solution:**
1. Check `.dockerignore` excludes build artifacts
2. Ensure multi-stage builds are working (no dev tools in prod)
3. Clean up package managers:
   ```dockerfile
   RUN apk add --no-cache package && \
       rm -rf /var/cache/apk/*
   ```

### Permission Errors

**Problem:** Files created by container have wrong ownership

**Cause:** Container runs as non-root but volume has root ownership

**Solution:**
```bash
# Fix ownership
sudo chown -R $(id -u):$(id -g) ./path/to/volume

# Or run container as current user
docker run --user $(id -u):$(id -g) ...
```

---

## CI/CD Comparison

| Aspect | Local (`make build-all`) | CI/CD Pipeline |
|--------|-------------------------|----------------|
| **Suffix** | `-local` | `-$CI_COMMIT_SHORT_SHA` |
| **Push** | No (stays local) | Yes (to registry) |
| **Cache** | Enabled by default | Enabled with inline cache |
| **Platform** | Your machine arch | `linux/amd64` |
| **Driver** | `docker` (faster local) | `docker-container` |
| **Time** | ~10-15 min first, ~3-5 cached | ~8-12 min (parallel) |

---

## Next Steps

After building and testing locally:

1. **Commit changes** with proper git format:
   ```bash
   git add .
   git commit -m "feat(images): description of changes"
   ```

2. **Push to GitLab**:
   ```bash
   git push origin feature/your-branch
   ```

3. **Create MR** and let CI/CD validate

4. **Tag for release** (after merge to main):
   ```bash
   git tag v1.2.3
   git push origin v1.2.3
   ```

   This triggers full CI/CD with registry push and Docker Hub sync.

---

## Support

[![Discord][discord-badge]][discord]
[![Issues][issues-badge]][issues]

**Need help?** Join our Discord community or report issues on GitLab.

---

## References

- [Makefile Help](../Makefile) - Run `make help` for all targets
- [Architecture](ARCHITECTURE.md) - Understanding multi-stage builds
- [CI/CD Pipeline](../.gitlab-ci.yml) - GitLab CI configuration
- [Build Scripts](../scripts/README.md) - Build automation details

---

**Last Updated:** January 2025
**Maintained by:** Stanislas Poisson (Zairakai)
