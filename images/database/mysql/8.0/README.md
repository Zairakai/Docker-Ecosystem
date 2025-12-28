# MySQL 8.0 - Production-Ready with High Availability

<!-- Image Stats -->
[![Docker Pulls][pulls-badge]][dockerhub]
[![Image Size][size-badge]][dockerhub]

<!-- CI/CD & Quality -->
[![Pipeline][pipeline-badge]][pipeline]
[![License][license-badge]][license]

<!-- Community -->
[![Discord][discord-badge]][discord]
Production-ready MySQL 8.0 with built-in support for replication and high availability.

Part of the [Zairakai Docker Ecosystem][ecosystem].

---

## Quick Start

```bash
docker pull zairakai/mysql:8.0

docker run -d \
  -p 3306:3306 \
  -e MYSQL_ROOT_PASSWORD=secret \
  -e MYSQL_DATABASE=laravel \
  -e MYSQL_USER=laravel \
  -e MYSQL_PASSWORD=secret \
  zairakai/mysql:8.0
```

### Docker Compose

```yaml
services:
  mysql:
    image: zairakai/mysql:8.0
    environment:
      MYSQL_ROOT_PASSWORD: ${DB_ROOT_PASSWORD}
      MYSQL_DATABASE: ${DB_DATABASE}
      MYSQL_USER: ${DB_USERNAME}
      MYSQL_PASSWORD: ${DB_PASSWORD}
    volumes:
      - mysql_data:/var/lib/mysql
    ports:
      - "3306:3306"
    healthcheck:
      test: ["CMD", "mysqladmin", "ping", "-h", "localhost"]
      interval: 10s
      timeout: 5s
      retries: 3

volumes:
  mysql_data:
```

---

## Key Features

- **MySQL 8.0**: Latest stable version with modern features
- **Replication Support**: Master-slave and group replication ready
- **Performance Tuning**: Optimized for Laravel workloads
- **Automated Backups**: Built-in backup scripts (see ecosystem docs)
- **Health Checks**: Monitoring-ready with health endpoints
- **UTF-8mb4**: Full emoji and international character support

---

## High Availability Setup

Enable replication for HA:

```yaml
services:
  mysql-master:
    image: zairakai/mysql:8.0
    environment:
      MYSQL_REPLICATION_MODE: master
      MYSQL_REPLICATION_USER: repl_user
      MYSQL_REPLICATION_PASSWORD: repl_password

  mysql-slave:
    image: zairakai/mysql:8.0
    environment:
      MYSQL_REPLICATION_MODE: slave
      MYSQL_MASTER_HOST: mysql-master
      MYSQL_REPLICATION_USER: repl_user
      MYSQL_REPLICATION_PASSWORD: repl_password
    depends_on:
      - mysql-master
```

Full documentation: [Disaster Recovery Guide][disaster-recovery]

---

## Environment Variables

| Variable | Required | Default | Description |
| -------- | -------- | ------- | ----------- |
| `MYSQL_ROOT_PASSWORD` | Yes | - | Root password |
| `MYSQL_DATABASE` | No | - | Database to create |
| `MYSQL_USER` | No | - | User to create |
| `MYSQL_PASSWORD` | No | - | User password |
| `MYSQL_REPLICATION_MODE` | No | - | `master` or `slave` |

---

## Backup & Restore

Use ecosystem backup scripts:

```bash
# Backup
docker exec mysql-container bash /backup/backup-mysql.sh

# Restore
docker exec -i mysql-container mysql -u root -p${MYSQL_ROOT_PASSWORD} ${DB_NAME} < backup.sql
```

---

## Related Images

- [zairakai/php](https://hub.docker.com/r/zairakai/php) - PHP 8.3 for Laravel
- [zairakai/redis](https://hub.docker.com/r/zairakai/redis) - Redis 7 caching
- [zairakai/nginx](https://hub.docker.com/r/zairakai/nginx) - Nginx web server

**Documentation**: [Zairakai Docker Ecosystem][ecosystem]

## Support

[![Issues][issues-badge]][issues]
[![Discord][discord-badge]][discord]

[issues]: https://gitlab.com/zairakai/docker-ecosystem/-/issues



<!-- Badge References -->
[pipeline-badge]: https://gitlab.com/zairakai/docker-ecosystem/badges/main/pipeline.svg
[pipeline]: https://gitlab.com/zairakai/docker-ecosystem/-/pipelines
[license-badge]: https://img.shields.io/badge/license-MIT-blue.svg
[discord-badge]: https://img.shields.io/discord/1260000352699289621?logo=discord&label=Discord&color=5865F2
[discord]: https://discord.gg/MAmD5SG8Zu
[issues-badge]: https://img.shields.io/gitlab/issues/open-raw/zairakai%2Fdocker-ecosystem?logo=gitlab&label=Issues
[ecosystem]: https://gitlab.com/zairakai/docker-ecosystem
