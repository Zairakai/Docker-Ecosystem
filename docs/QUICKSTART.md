# Quick Start Guide

[🏠 Home][home] > [📚 Documentation][docs] > Quick Start Guide  

Get your Laravel + Vue.js development environment running with Zairakai images in 5 minutes.

## Table of Contents

- [Quick Start Guide](#quick-start-guide)
  - [Table of Contents](#table-of-contents)
  - [Prerequisites](#prerequisites)
  - [Step 1: Create Docker Compose Configuration](#step-1-create-docker-compose-configuration)
  - [Step 2: Start Your Environment](#step-2-start-your-environment)
  - [Step 3: Setup Your Laravel Application](#step-3-setup-your-laravel-application)
  - [Step 4: Development Workflow](#step-4-development-workflow)
  - [You're Ready! 🎉](#youre-ready-)
  - [Next Steps](#next-steps)
    - [Configure Your Application](#configure-your-application)
    - [Development Commands](#development-commands)
    - [Testing Your Setup](#testing-your-setup)
  - [Troubleshooting](#troubleshooting)
    - [Common Issues](#common-issues)
    - [Health Checks](#health-checks)
  - [Production Deployment](#production-deployment)
  - [Advanced Configuration](#advanced-configuration)
  - [Navigation](#navigation)

## Prerequisites

Before you begin, ensure you have:

- **Docker** 20.10+ installed
- **Docker Compose** 2.0+ installed
- A **Laravel project** ready (or create a new one)
- **10GB disk space** for images

> **📌 Detailed Prerequisites**:  
> See [Prerequisites Guide][prerequisites] for installation instructions

## Step 1: Create Docker Compose Configuration

Create a `docker-compose.yml` in your Laravel project:

```yaml
services:
  app:
    image: zairakai/php:8.3-dev
    volumes:
      - .:/var/www/html
    ports:
      - "9000:9000"
    environment:
      - APP_ENV=local
      - DB_HOST=mysql
      - REDIS_HOST=redis

  mysql:
    image: zairakai/database:mysql-8.0
    environment:
      - MYSQL_ROOT_PASSWORD=root
      - MYSQL_DATABASE=laravel
      - MYSQL_USER=laravel
      - MYSQL_PASSWORD=secret
    ports:
      - "3306:3306"
    volumes:
      - mysql-data:/var/lib/mysql

  redis:
    image: zairakai/database:redis-7
    ports:
      - "6379:6379"
    volumes:
      - redis-data:/data

volumes:
  mysql-data:
  redis-data:
```

**💡 Note**: Images are automatically pulled from our GitLab registry when you start the stack.

## Step 2: Start Your Environment

```bash
# Start with Zairakai images (auto-pulled from registry)
docker-compose up -d

# Verify services are running
docker-compose ps
```

**Expected output:**

```bash
NAME           COMMAND                  SERVICE   STATUS    PORTS
your-app-1     "docker-entrypoint…"   app       running   0.0.0.0:9000->9000/tcp
your-mysql-1   "docker-entrypoint…"   mysql     running   0.0.0.0:3306->3306/tcp
your-redis-1   "docker-entrypoint…"   redis     running   0.0.0.0:6379->6379/tcp
```

## Step 3: Setup Your Laravel Application

```bash
# Access the PHP container to set up your Laravel project
docker-compose exec app bash

# Inside the container, install/configure your Laravel app
composer install
php artisan key:generate
php artisan migrate
```

## Step 4: Development Workflow

```bash
# All Zairakai images include development tools
# Use the containers as your development environment
docker-compose exec app php artisan tinker    # Laravel REPL
docker-compose exec app composer require package  # Add packages
```

## You're Ready! 🎉

Your development environment is running with Zairakai images:

- [x] **Laravel Application**: Available in the `app` container
- [x] **Database**: MySQL ready for connections
- [x] **Cache**: Redis available for session/cache storage
- [x] **All tools included**: Composer, Artisan, debugging tools

## Next Steps

### Configure Your Application

Edit your Laravel `.env` file:

```env
DB_CONNECTION=mysql
DB_HOST=mysql
DB_PORT=3306
DB_DATABASE=laravel
DB_USERNAME=laravel
DB_PASSWORD=secret

REDIS_HOST=redis
REDIS_PORT=6379

MAIL_MAILER=smtp
MAIL_HOST=mailhog
MAIL_PORT=1025
```

### Development Commands

```bash
# Laravel commands
docker-compose exec app php artisan migrate
docker-compose exec app php artisan tinker
docker-compose exec app composer install

# Frontend commands
docker-compose exec app npm run dev
docker-compose exec app npm run build
docker-compose exec app npm test

# Database access
docker-compose exec mysql mysql -u laravel -psecret laravel
```

### Testing Your Setup

```bash
# Test PHP environment
docker-compose exec app php --version

# Test database connection
docker-compose exec app php artisan tinker
>>> DB::connection()->getPdo()
```

## Troubleshooting

### Common Issues

**Port conflicts**:

```bash
# Stop conflicting services
sudo service apache2 stop
sudo service nginx stop
sudo service mysql stop
```

**Permission issues**:

```bash
# Fix Laravel storage permissions
docker-compose exec app chown -R www:www /var/www/html/storage
docker-compose exec app chmod -R 775 /var/www/html/storage
```

**Container not starting**:

```bash
# Check logs
docker-compose logs app
docker-compose logs mysql
docker-compose logs redis
```

### Health Checks

```bash
# Test all health checks
docker-compose exec app /usr/local/bin/healthcheck.sh
docker-compose exec mysql /scripts/healthcheck.sh
docker-compose exec redis redis-cli PING
```

## Production Deployment

For production deployment, use production images:

```yaml
services:
  app:
    image: zairakai/php:8.3-prod
    # Your production configuration

  frontend:
    image: zairakai/node:20-prod
    # Your production configuration
```

> **📖 Learn More**: See [Architecture Guide][architecture] for production patterns

## Advanced Configuration

- **[Architecture Guide][architecture]** - Technical overview and design patterns
- **[Testing Modes][testing-modes]** - Blade, SPA, and Hybrid architectures
- **[Reference Guide][reference]** - Complete image tags and configurations
- **[Examples][examples]** - Ready-to-use Docker Compose examples

## Navigation

- [← Prerequisites Guide](PREREQUISITES.md)
- [📚 Documentation Index](INDEX.md)
- [Architecture Overview →](ARCHITECTURE.md)

**Need help?** Join our [Discord][discord] community or report issues on [GitLab][issues].

<!-- Reference Links -->

[home]: ../README.md
[docs]: INDEX.md
[prerequisites]: PREREQUISITES.md
[architecture]: ARCHITECTURE.md
[testing-modes]: TESTING_MODES.md
[reference]: REFERENCE.md
[examples]: ../examples/
[discord]: https://discord.gg/MAmD5SG8Zu
[issues]: https://gitlab.com/zairakai/docker-ecosystem/-/issues
