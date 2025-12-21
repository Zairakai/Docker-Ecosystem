# Cache Configuration Guide

This guide explains how to configure persistent cache volumes for Composer and npm/yarn/pnpm to improve container restart performance.

## Why Use Cache Volumes?

**Benefits:**

- ✅ **Faster container restarts** - No need to re-download packages
- ✅ **Reduced network usage** - Packages downloaded once and reused
- ✅ **Offline development** - Work with cached packages even without internet
- ✅ **CI/CD optimization** - Share cache between pipeline jobs

## Composer Cache Configuration

### Default Cache Location

```bash
# Inside PHP container
/home/www/.composer/cache
```

### Docker Compose Setup

```yaml
services:
  php:
    image: your-php-image
    volumes:
      - composer-cache:/home/www/.composer/cache
    environment:
      - COMPOSER_CACHE_DIR=/home/www/.composer/cache

volumes:
  composer-cache:
```

### Verify Cache

```bash
# Check cache size
docker exec php-container du -sh /home/www/.composer/cache

# Clear cache if needed
docker exec php-container composer clear-cache
```

## npm/Yarn/pnpm Cache Configuration

### Default Cache Locations

```bash
# npm
/home/node/.npm

# Yarn
/home/node/.cache/yarn

# pnpm (content-addressable store)
/home/node/.local/share/pnpm/store
```

### Docker Compose Setup

```yaml
services:
  node:
    image: your-node-image
    volumes:
      - npm-cache:/home/node/.npm
      - yarn-cache:/home/node/.cache/yarn
      - pnpm-store:/home/node/.local/share/pnpm/store
    environment:
      - NPM_CONFIG_CACHE=/home/node/.npm
      - YARN_CACHE_FOLDER=/home/node/.cache/yarn
      - PNPM_HOME=/home/node/.local/share/pnpm

volumes:
  npm-cache:
  yarn-cache:
  pnpm-store:
```

### Verify Cache

```bash
# npm cache info
docker exec node-container npm cache verify

# Yarn cache dir
docker exec node-container yarn cache dir

# pnpm store status
docker exec node-container pnpm store status
```

## Host-Bound Volumes (Optional)

For easier inspection and management, bind cache to host directories:

```yaml
volumes:
  composer-cache:
    driver: local
    driver_opts:
      type: none
      o: bind
      device: ./docker-cache/composer

  npm-cache:
    driver: local
    driver_opts:
      type: none
      o: bind
      device: ./docker-cache/npm
```

**Create directories first:**

```bash
mkdir -p docker-cache/{composer,npm,yarn,pnpm}
```

## GitLab CI/CD Cache

Add to `.gitlab-ci.yml`:

```yaml
variables:
  COMPOSER_CACHE_DIR: "$CI_PROJECT_DIR/.composer-cache"
  NPM_CONFIG_CACHE: "$CI_PROJECT_DIR/.npm-cache"

cache:
  key: "${CI_COMMIT_REF_SLUG}"
  paths:
    - .composer-cache/
    - .npm-cache/
    - node_modules/
    - vendor/
```

## Cache Management

### Clear All Caches

```bash
# Composer
composer clear-cache

# npm
npm cache clean --force

# Yarn
yarn cache clean

# pnpm
pnpm store prune
```

### Check Cache Sizes

```bash
# Host-bound volumes
du -sh docker-cache/*

# Docker managed volumes
docker system df -v | grep cache
```

### Remove Unused Cache

```bash
# Remove all unused volumes (WARNING: irreversible)
docker volume prune

# Remove specific cache volume
docker volume rm project_composer-cache
```

## Performance Tips

1. **Use .dockerignore** to exclude `node_modules/` and `vendor/` from build context
2. **Multi-stage builds** to separate build cache from runtime
3. **Layer caching** in Dockerfile with proper ordering
4. **Share cache** between dev/test/prod environments when possible

## Example: Complete Setup

See `examples/docker-compose-with-cache.yml` for a complete working example with:

- PHP + Composer cache
- Node.js + npm/yarn/pnpm cache
- Host-bound volumes for easy inspection
- Environment variable configuration

## Troubleshooting

### Permission Issues

If you encounter permission errors:

```bash
# Fix ownership (use correct UID/GID from containers)
sudo chown -R 1000:1000 docker-cache/

# Or use container user
docker exec -u www php-container composer install
docker exec -u node node-container npm install
```

### Cache Not Working

1. Verify volume mounts: `docker inspect <container> | grep Mounts`
2. Check environment variables: `docker exec <container> env | grep CACHE`
3. Verify cache directory exists and is writable
4. Check logs for cache-related errors

### Cache Too Large

```bash
# Set cache size limits
export NPM_CONFIG_CACHE_MAX=500  # MB
export COMPOSER_CACHE_FILES_MAXSIZE=500M

# Or configure in Docker Compose
environment:
  - NPM_CONFIG_CACHE_MAX=500
  - COMPOSER_CACHE_FILES_MAXSIZE=500M
```

---

**Need help?** Join our [Discord][discord] community or check the [Reference Guide][reference].

<!-- Reference Links -->
[reference]: REFERENCE.md
[discord]: https://discord.gg/MAmD5SG8Zu
