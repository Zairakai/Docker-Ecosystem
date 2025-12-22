# Docker Compose Examples

Ready-to-use configurations for the Zairakai Docker images.

## Directory Structure

```bash
examples/
├── testing-modes/          # 3 testing architectures (Blade/SPA/Hybrid)
├── compose/                # Docker Compose configurations
├── nginx/                  # Nginx configuration examples
├── monitoring/             # Monitoring stack configs
└── README.md               # This file
```

## Quick Links

### Testing Architectures

**[testing-modes/](testing-modes/)** - Three distinct testing modes:

- `docker-compose-mode-blade.yml` - Pure Blade SSR (no JavaScript framework)
- `docker-compose-mode-spa.yml` - Decoupled SPA + Laravel API
- `docker-compose-mode-hybrid.yml` - Laravel + Vite (most common setup)
- `BUILD_WORKFLOW.md` - Detailed build and testing workflow

### Compose Configurations

**[compose/](compose/)** - Various deployment scenarios:

- `minimal-laravel.yml` - Basic Laravel development
- `api-only.yml` - Laravel API backend
- `frontend-only.yml` - Vue.js frontend only
- `production-single.yml` - Single-server production
- `docker-compose-ha.yml` - High Availability setup
- `docker-compose-testing.yml` - Testing environment
- `docker-compose-tracing.yml` - Distributed tracing

### Nginx Configurations

**[nginx/](nginx/)** - Nginx configs for each mode:

- `nginx-laravel-vite.conf` - Standard Laravel + Vite
- `nginx-mode-blade-only.conf` - Pure Blade SSR
- `nginx-mode-spa-only.conf` - SPA with API proxy
- `nginx-mode-hybrid.conf` - Hybrid SSR + SPA
- `nginx-testing.conf` - Testing environment

### Monitoring

**[monitoring/](monitoring/)** - Observability stack:

- `prometheus.yml` - Prometheus metrics config
- `grafana-datasources.yml` - Grafana datasources
- `otel-collector-config.yml` - OpenTelemetry Collector
- `redis-sentinel.conf` - Redis HA with Sentinel

## Quick Start

### Option 1: Download from GitLab (Recommended)

```bash
# Download example directly to your project
cd your-laravel-project

# For basic Laravel development
curl -o docker-compose.yml https://gitlab.com/zairakai/docker-ecosystem/-/raw/main/examples/compose/minimal-laravel.yml

# For Laravel + Vue.js
curl -o docker-compose.yml https://gitlab.com/zairakai/docker-ecosystem/-/raw/main/examples/testing-modes/docker-compose-mode-hybrid.yml

# Start development
docker-compose up -d
```

### Option 2: Copy from Local Clone

```bash
# If you've cloned this repository
cp examples/compose/minimal-laravel.yml your-project/docker-compose.yml
cd your-project
docker-compose up -d
```

**Note**: Images are automatically pulled from GitLab Container Registry - no build required!

## Examples by Use Case

### "I want basic Laravel development"

```bash
cd examples/compose
docker-compose -f minimal-laravel.yml up -d
```

- PHP 8.3 dev + MySQL + Redis
- Perfect for learning Laravel

### "I want to deploy a traditional Laravel app"

```bash
cd examples/testing-modes
docker-compose -f docker-compose-mode-blade.yml up
```

- Pure Blade SSR (no JavaScript framework)
- Nginx serves PHP-rendered HTML

### "I want to deploy a modern SPA with Laravel API"

```bash
cd examples/testing-modes
docker-compose -f docker-compose-mode-spa.yml up node-build
docker-compose -f docker-compose-mode-spa.yml up
```

- Separate Vue.js + Laravel API
- CORS configured
- Nginx serves static files + proxies API

### "I want Laravel with Vue.js components (standard)"

```bash
cd examples/testing-modes
docker-compose -f docker-compose-mode-hybrid.yml up node-build
docker-compose -f docker-compose-mode-hybrid.yml up
```

- Laravel + Vite standard setup
- Vue.js compiled to public/build/
- PHP serves everything

### "I need high availability for production"

```bash
cd examples/compose
docker-compose -f docker-compose-ha.yml up -d
```

- MySQL master-slave replication
- Redis Sentinel failover
- Load balancing ready

### "I want distributed tracing and monitoring"

```bash
cd examples/compose
docker-compose -f docker-compose-tracing.yml up -d
```

- OpenTelemetry + Jaeger + Zipkin
- Prometheus + Grafana
- Full observability stack

## Customization

All examples use **Zairakai images from the registry** - no build required!

**Common modifications:**

```yaml
# Change mounted directory
volumes:
  - ./your-app:/var/www/html

# Update database credentials
environment:
  MYSQL_DATABASE: your-db-name
  MYSQL_PASSWORD: your-password

# Change exposed ports
ports:
  - "8080:80"
```

## Secrets Management

**IMPORTANT**: Never commit sensitive data (passwords, API keys, tokens) to version control!

### Development: Use .env files

```yaml
# docker-compose.yml
services:
  php:
    env_file:
      - .env
      - .env.local  # Override with local secrets (gitignored)
```

```bash
# .env (committed with placeholders)
DB_PASSWORD=changeme

# .env.local (NOT committed, in .gitignore)
DB_PASSWORD=super_secret_password
```

### Production: Use Docker secrets

```yaml
# docker-compose.prod.yml
services:
  php:
    secrets:
      - db_password
    environment:
      DB_PASSWORD_FILE: /run/secrets/db_password

secrets:
  db_password:
    external: true
```

```bash
# Create secrets in Docker Swarm
echo "my_secure_password" | docker secret create db_password -
docker stack deploy -c docker-compose.prod.yml myapp
```

**See full secrets management guide:** [Secrets Management](../SECURITY.md#secrets-management)

## Testing Modes Explained

The Docker Ecosystem supports **3 distinct architectures** for Laravel + Vue.js:

### 1. Blade-only Mode (Pure SSR)

- **What**: Traditional Laravel with Blade templates
- **When**: No JavaScript framework needed
- **Files**: `testing-modes/docker-compose-mode-blade.yml`
- **Nginx**: `nginx/nginx-mode-blade-only.conf`

### 2. SPA-only Mode (Decoupled)

- **What**: Separate Vue.js SPA + Laravel API
- **When**: Frontend and backend are completely independent
- **Files**: `testing-modes/docker-compose-mode-spa.yml`
- **Nginx**: `nginx/nginx-mode-spa-only.conf`

### 3. Hybrid Mode (Laravel + Vite)

- **What**: Laravel with Vue.js components (standard setup)
- **When**: Most common real-world Laravel + Vue.js
- **Files**: `testing-modes/docker-compose-mode-hybrid.yml`
- **Nginx**: `nginx/nginx-laravel-vite.conf`

**Detailed comparison:** [Architecture Comparison](../docs/ARCHITECTURE_COMPARISON.md)

## Features Comparison

| Example | PHP | Node | MySQL | Redis | Nginx | Use Case |
| ------- | --- | ---- | ----- | ----- | ----- | -------- |
| minimal-laravel | ✅ dev | ❌ | ✅ | ✅ | ❌ | Laravel development |
| frontend-only | ❌ | ✅ dev | ❌ | ❌ | ❌ | Vue.js development |
| api-only | ✅ prod | ❌ | ✅ | ✅ | ✅ | API backend |
| production-single | ✅ prod | ✅ prod | ✅ | ✅ | ✅ | Production |
| docker-compose-ha | ✅ prod | ✅ prod | ✅ (HA) | ✅ (Sentinel) | ✅ | High Availability |
| mode-blade | ✅ test | ❌ | ✅ | ✅ | ✅ | Blade SSR testing |
| mode-spa | ✅ test | ✅ build | ✅ | ✅ | ✅ | SPA testing |
| mode-hybrid | ✅ test | ✅ build | ✅ | ✅ | ✅ | Hybrid testing |

## Best Practices

### ✅ DO

- Use registry images (no `build:` directive)
- Mount your project as volume
- Use environment variables for config
- Separate dev/staging/prod credentials
- Use Docker secrets in production

### ❌ DON'T

- Build images locally (use registry)
- Commit secrets to Git
- Use default passwords in production
- Mix development and production configs
- Expose database ports publicly

## Need Help?

- **Documentation**: [docs/INDEX.md](../docs/INDEX.md)
- **Quick Start**: [docs/QUICKSTART.md](../docs/QUICKSTART.md)
- **Architecture**: [docs/ARCHITECTURE_COMPARISON.md](../docs/ARCHITECTURE_COMPARISON.md)
- **Discord**: [Zairakai Community](https://discord.gg/MAmD5SG8Zu)
- **Issues**: [GitLab Issues](https://gitlab.com/zairakai/docker-ecosystem/-/issues)

**Need help?** Join our [Discord][discord] community or check the [Reference Guide][reference].

<!-- Reference Links -->
[reference]: REFERENCE.md
[discord]: https://discord.gg/MAmD5SG8Zu
