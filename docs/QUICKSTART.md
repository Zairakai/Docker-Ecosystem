# Quick Start Guide

Get your Laravel + Vue.js development environment running with Zairakai images.

## Prerequisites

- Docker 20.10+
- Docker Compose 2.0+

## Step 1: Create Docker Compose Configuration

Create a `docker-compose.yml` in your Laravel project:

```bash
cd your-laravel-project

cat > docker-compose.yml <<'EOF'
version: '3.8'
services:
  app:
    image: registry.gitlab.com/zairakai/docker-ecosystem/php:8.3-dev
    volumes:
      - .:/var/www/html
    ports:
      - "9000:9000"
    environment:
      - APP_ENV=local
      - DB_HOST=mysql
      - REDIS_HOST=redis

  mysql:
    image: registry.gitlab.com/zairakai/docker-ecosystem/database:mysql-8.0
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
    image: registry.gitlab.com/zairakai/docker-ecosystem/database:redis-7
    ports:
      - "6379:6379"
    volumes:
      - redis-data:/data

volumes:
  mysql-data:
  redis-data:
EOF
```

**Note**: Images are automatically pulled from our GitLab registry when you start the stack.

## Step 2: Start Your Environment

```bash
# Start with Zairakai images (auto-pulled from registry)
docker-compose up -d

# Verify services are running
docker-compose ps
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

## You're Ready

Your development environment is running with Zairakai images:

- **Laravel Application**: Available in the `app` container
- **Database**: MySQL ready for connections
- **Cache**: Redis available for session/cache storage
- **All tools included**: Composer, Artisan, debugging tools

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
docker-compose exec php-dev php artisan migrate
docker-compose exec php-dev php artisan tinker
docker-compose exec php-dev composer install

# Frontend commands
docker-compose exec node-dev yarn dev
docker-compose exec node-dev yarn build
docker-compose exec node-dev yarn test

# Database access
docker-compose exec mysql mysql -u laravel -psecret laravel
```

### Testing Your Setup

```bash
# Test PHP environment
docker-compose exec php-dev php --version

# Test Node.js environment
docker-compose exec node-dev node --version
docker-compose exec node-dev yarn --version

# Test database connection
docker-compose exec php-dev php artisan tinker
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
docker-compose exec php-dev chown -R www:www /var/www/html/app/storage
docker-compose exec php-dev chmod -R 775 /var/www/html/app/storage
```

**Container not starting**:

```bash
# Check logs
docker-compose logs php-dev
docker-compose logs mysql
```

### Health Checks

```bash
# Test all health checks
docker-compose exec php-dev /usr/local/bin/healthcheck.sh
docker-compose exec node-dev /usr/local/bin/healthcheck.sh
docker-compose exec mysql /scripts/healthcheck.sh
```

## Production Deployment

For production deployment, use the base images:

```yaml
version: "3.8"
services:
  app:
    image: zairakai/php:8.3-prod
    # Your production configuration

  frontend:
    image: zairakai/node:20-prod
    # Your production configuration
```

## Advanced Configuration

- **[Architecture Guide][architecture]** - Technical overview
- **[Security Policy][security]** - Security scanning and policies
- **[Contributing][contributing]** - Development guidelines
- **[Reference Guide][reference]** - Complete tags and configurations

---

**Need help?** Join our [Discord][discord] community or check the [Reference Guide][reference].

<!-- Reference Links -->

[architecture]: ARCHITECTURE.md
[security]: ../SECURITY.md
[contributing]: ../CONTRIBUTING.md
[reference]: REFERENCE.md
[discord]: https://discord.gg/MAmD5SG8Zu
