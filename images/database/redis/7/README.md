# Redis 7 - High-Performance Cache with Sentinel Support


<!-- Image Stats -->
[![Docker Pulls][pulls-badge]][dockerhub]
[![Image Size][size-badge]][dockerhub]

<!-- CI/CD & Quality -->
[![Pipeline][pipeline-badge]][pipeline]
[![License][license-badge]][license]

<!-- Community -->
[![Discord][discord-badge]][discord]
Production-ready Redis 7 with built-in support for Redis Sentinel high availability.

Part of the [Zairakai Docker Ecosystem](https://gitlab.com/zairakai/docker-ecosystem).

---

## Quick Start

```bash
docker pull zairakai/redis:7

docker run -d \
  -p 6379:6379 \
  zairakai/redis:7
```

### Docker Compose

```yaml
services:
  redis:
    image: zairakai/redis:7
    ports:
      - "6379:6379"
    volumes:
      - redis_data:/data
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 10s
      timeout: 5s
      retries: 3

volumes:
  redis_data:
```

---

## Key Features

- **Redis 7**: Latest stable with improved performance
- **Sentinel Support**: Built-in HA configuration
- **Persistence**: RDB + AOF hybrid persistence
- **Security**: Password protection and ACL support
- **Health Checks**: Monitoring-ready
- **Optimized**: Tuned for Laravel caching and sessions

---

## High Availability with Sentinel

```yaml
services:
  redis-master:
    image: zairakai/redis:7
    command: redis-server --port 6379

  redis-sentinel:
    image: zairakai/redis:7
    command: redis-sentinel /etc/redis/sentinel.conf
    volumes:
      - ./redis-sentinel.conf:/etc/redis/sentinel.conf
    depends_on:
      - redis-master
```

Full documentation: [Disaster Recovery Guide](https://gitlab.com/zairakai/docker-ecosystem/-/blob/main/docs/DISASTER_RECOVERY.md)

---

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `REDIS_PASSWORD` | - | Redis password (recommended) |
| `REDIS_MAXMEMORY` | `256mb` | Maximum memory |
| `REDIS_MAXMEMORY_POLICY` | `allkeys-lru` | Eviction policy |

---

## Laravel Configuration

```env
REDIS_HOST=redis
REDIS_PASSWORD=null
REDIS_PORT=6379
REDIS_CLIENT=phpredis  # or predis

CACHE_DRIVER=redis
SESSION_DRIVER=redis
QUEUE_CONNECTION=redis
```

---

## Backup & Restore

```bash
# Backup (creates dump.rdb)
docker exec redis-container redis-cli BGSAVE

# Restore
docker cp dump.rdb redis-container:/data/dump.rdb
docker restart redis-container
```

---

## Related Images

- [zairakai/php](https://hub.docker.com/r/zairakai/php) - PHP 8.3 with phpredis
- [zairakai/mysql](https://hub.docker.com/r/zairakai/mysql) - MySQL 8.0 database
- [zairakai/nginx](https://hub.docker.com/r/zairakai/nginx) - Nginx web server

**Documentation**: https://gitlab.com/zairakai/docker-ecosystem

## Support

[![Discord][discord-badge]][discord]
[![Issues][issues-badge]][issues]

**Need help?** Join our Discord community or report issues on GitLab.

<!-- Badge References -->
[pipeline-badge]: https://gitlab.com/zairakai/docker-ecosystem/badges/main/pipeline.svg
[pipeline]: https://gitlab.com/zairakai/docker-ecosystem/-/pipelines
[license-badge]: https://img.shields.io/badge/license-MIT-blue.svg
[discord-badge]: https://img.shields.io/discord/1260000352699289621?logo=discord&label=Discord&color=5865F2
[discord]: https://discord.gg/MAmD5SG8Zu
[issues-badge]: https://img.shields.io/gitlab/issues/open-raw/zairakai%2Fdocker-ecosystem?logo=gitlab&label=Issues

## Support

[![Discord][discord-badge]][discord]
[![Issues][issues-badge]][issues]

**Need help?** Join our Discord community or report issues on GitLab.

[issues]: https://gitlab.com/zairakai/docker-ecosystem/-/issues

<!-- Badge References -->
[pulls-badge]: https://img.shields.io/docker/pulls/zairakai/redis?logo=docker&logoColor=white
[size-badge]: https://img.shields.io/docker/image-size/zairakai/redis/7?logo=docker&logoColor=white&label=size
[pipeline-badge]: https://gitlab.com/zairakai/docker-ecosystem/badges/main/pipeline.svg
[pipeline]: https://gitlab.com/zairakai/docker-ecosystem/-/pipelines
[license-badge]: https://img.shields.io/badge/license-MIT-blue.svg
[license]: https://gitlab.com/zairakai/docker-ecosystem/-/blob/main/LICENSE
[discord-badge]: https://img.shields.io/discord/1260000352699289621?logo=discord&label=Discord&color=5865F2
[discord]: https://discord.gg/MAmD5SG8Zu
[issues-badge]: https://img.shields.io/gitlab/issues/open-raw/zairakai%2Fdocker-ecosystem?logo=gitlab&label=Issues
[issues]: https://gitlab.com/zairakai/docker-ecosystem/-/issues
[dockerhub]: https://hub.docker.com/r/zairakai/redis
