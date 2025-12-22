# Prerequisites Guide

[🏠 Home][home] > [📚 Documentation][docs] > Prerequisites Guide

This guide helps you understand what knowledge, tools, and system requirements you need to use the Zairakai
Docker Ecosystem effectively.

## Table of Contents

- [Required Knowledge by Level](#required-knowledge-by-level)
  - [Beginner Level](#beginner-level)
  - [Intermediate Level](#intermediate-level)
  - [Advanced Level](#advanced-level)
- [Required Tools](#required-tools)
  - [For All Users](#for-all-users)
  - [For Local Development](#for-local-development)
  - [For Production Deployment](#for-production-deployment)
- [System Requirements](#system-requirements)
  - [Development Environment](#development-environment)
  - [Production Environment](#production-environment)
- [Network Requirements](#network-requirements)
  - [Development](#development)
  - [Production](#production)
- [Skill Assessment](#skill-assessment)
  - [Can I start with Beginner level?](#can-i-start-with-beginner-level)
  - [Am I ready for Intermediate level?](#am-i-ready-for-intermediate-level)
  - [Am I ready for Advanced level?](#am-i-ready-for-advanced-level)
- [Common Issues](#common-issues)
- [Next Steps](#next-steps)
- [Navigation](#navigation)

## Required Knowledge by Level

### Beginner Level

**Minimum Docker Knowledge:**

- [x] Know what Docker is and why it's used
- [x] Can run `docker run hello-world` successfully
- [x] Understand basic concepts: container, image, volume
- [x] Can use `docker-compose up` and `docker-compose down`

**Minimum Laravel Knowledge:**

- [x] Can create a Laravel project with `composer create-project`
- [x] Understand basic Laravel structure (`app/`, `routes/`, `resources/`)
- [x] Know how to run `php artisan` commands

**Recommended Reading:**

- [Docker Getting Started](https://docs.docker.com/get-started/)
- [Docker Compose Tutorial](https://docs.docker.com/compose/gettingstarted/)
- [Laravel Documentation](https://laravel.com/docs)

### Intermediate Level

**Required Docker Knowledge:**

- [x] Understand multi-container applications
- [x] Know how to use Docker networks and volumes
- [x] Can read and modify `docker-compose.yml` files
- [x] Understand environment variables and `.env` files
- [x] Know how to check container logs (`docker logs`)
- [x] Can debug basic container issues

**Required Laravel Knowledge:**

- [x] Understand Laravel request lifecycle
- [x] Know about database migrations and seeders
- [x] Familiar with Laravel Blade templating
- [x] Basic understanding of Vue.js (for hybrid setups)
- [x] Understand Laravel's routing and middleware

**Recommended Reading:**

- [Docker Networking](https://docs.docker.com/network/)
- [Docker Volumes](https://docs.docker.com/storage/volumes/)
- [Laravel Advanced Topics](https://laravel.com/docs/requests)
- [Vue.js Essentials](https://vuejs.org/guide/essentials/)

### Advanced Level

**Required Docker Knowledge:**

- [x] Multi-stage Docker builds
- [x] Docker orchestration (Kubernetes or Swarm)
- [x] Service mesh concepts
- [x] Distributed tracing and observability
- [x] High availability patterns
- [x] Security hardening and image scanning
- [x] Container registry management

**Required Laravel + Vue.js Knowledge:**

- [x] Laravel API development (RESTful, GraphQL)
- [x] Vue.js 3 Composition API
- [x] Vite build system and optimization
- [x] SSR vs SPA architectures
- [x] Asset compilation pipelines
- [x] Performance optimization techniques

**Recommended Reading:**

- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Docker Swarm Guide](https://docs.docker.com/engine/swarm/)
- [Vue.js 3 Guide](https://vuejs.org/guide/)
- [Vite Documentation](https://vitejs.dev/)

## Required Tools

### For All Users

**Docker Installation:**

```bash
# Check Docker is installed
docker --version
# Should show: Docker version 20.10+ or higher

# Check Docker Compose is installed
docker-compose --version
# Should show: Docker Compose version 2.0+ or higher
```

**Install Docker:**

- **Linux**: https://docs.docker.com/engine/install/
- **macOS**: https://docs.docker.com/desktop/mac/install/
- **Windows**: https://docs.docker.com/desktop/windows/install/

**Disk Space:**

- **Minimum**: 5GB free space
- **Recommended**: 10GB+ for all images and volumes
- **Production**: 50GB+ depending on application size

**Memory:**

- **Minimum**: 4GB RAM
- **Recommended**: 8GB+ RAM for development
- **Production**: 16GB+ RAM recommended

### For Local Development

**Git:**

```bash
git --version
# Should show: git version 2.30+ or higher
```

**Composer (for Laravel):**

```bash
composer --version
# Should show: Composer version 2.0+ or higher
```

> **💡 Note**: Composer is included in the `php:8.3-dev` image, so local installation is optional

**Node.js (for Vue.js/Vite):**

```bash
node --version
# Should show: v18+ or v20+ (LTS recommended)

npm --version
# Should show: npm version 9+ or higher
```

> **💡 Note**: Node.js and npm are included in the `node:20-dev` image

### For Production Deployment

**Kubernetes (if using K8s):**

```bash
kubectl version --client
# Should show: Client Version v1.25+ or higher

helm version
# Should show: version.BuildInfo{Version:"v3.10+"}
```

**Docker Swarm (if using Swarm):**

```bash
docker swarm --help
# Should show swarm management commands
```

## System Requirements

### Development Environment

**Minimum:**

- **CPU**: 2 cores
- **RAM**: 4GB
- **Disk**: 20GB free (SSD recommended)
- **OS**: Linux, macOS, or Windows 10/11 with WSL2

**Recommended:**

- **CPU**: 4+ cores
- **RAM**: 8GB+ (16GB for large projects)
- **Disk**: 50GB+ SSD
- **OS**: Linux or macOS (best Docker performance)

### Production Environment

**Single Server:**

- **CPU**: 4+ cores
- **RAM**: 8GB+ (16GB recommended)
- **Disk**: 100GB+ SSD
- **OS**: Ubuntu 22.04 LTS or similar

**High Availability Cluster:**

- **Minimum**: 3 nodes
- **Each node**: 4+ cores, 8GB+ RAM
- **Storage**: Shared storage or distributed volumes
- **Load Balancer**: Nginx, HAProxy, or cloud LB

## Network Requirements

### Development

- [x] Internet connection for pulling images from GitLab Container Registry
- [x] No special firewall rules needed for local development
- [x] Optional: Access to Docker Hub for base images

### Production

**Required Ports:**

| Port | Service | Access |
| ---- | ------- | ------ |
| 80 | HTTP | Public |
| 443 | HTTPS | Public |
| 3306 | MySQL | Internal only |
| 6379 | Redis | Internal only |
| 9000 | PHP-FPM | Internal only |

**Optional Ports (Monitoring):**

| Port | Service | Access |
| ---- | ------- | ------ |
| 9090 | Prometheus | Internal/VPN |
| 3000 | Grafana | Internal/VPN |
| 16686 | Jaeger UI | Internal/VPN |
| 9411 | Zipkin UI | Internal/VPN |

## Skill Assessment

### Can I start with Beginner level?

✅ **YES** if you can answer these:

- [ ] I can run `docker run nginx` successfully
- [ ] I can create a `docker-compose.yml` file
- [ ] I have a Laravel project ready (or can create one)
- [ ] I understand what environment variables are
- [ ] I can execute basic terminal commands

❌ **NO** - Start with Docker basics first if you can't answer the above

**Recommended**: [Docker Getting Started](https://docs.docker.com/get-started/)

### Am I ready for Intermediate level?

✅ **YES** if you can answer these:

- [ ] I understand the difference between SSR and SPA
- [ ] I can modify Nginx configuration files
- [ ] I know how to debug container issues with logs
- [ ] I understand Laravel's MVC pattern
- [ ] I can read and write Docker Compose files

❌ **NO** - Stick with beginner guides first

**Recommended**: Complete [Quick Start Guide][quickstart] first

### Am I ready for Advanced level?

✅ **YES** if you can answer these:

- [ ] I have deployed applications to production before
- [ ] I understand high availability concepts
- [ ] I can read Kubernetes manifests
- [ ] I know how distributed tracing works
- [ ] I'm comfortable with CI/CD pipelines

❌ **NO** - Master intermediate concepts first

**Recommended**: Study [Architecture Guide][architecture] and [Testing Modes][testing-modes]

## Common Issues

### Docker not installed

```bash
# Error: command not found: docker

# Solution: Install Docker
# Linux: https://docs.docker.com/engine/install/
# macOS: https://docs.docker.com/desktop/mac/install/
# Windows: https://docs.docker.com/desktop/windows/install/
```

### Permission denied

```bash
# Error: Got permission denied while trying to connect to the Docker daemon

# Solution (Linux):
sudo usermod -aG docker $USER

# Then logout and login again
# OR restart your terminal session
```

### Port already in use

```bash
# Error: Bind for 0.0.0.0:80 failed: port is already allocated

# Check what's using the port:
sudo lsof -i :80

# Stop the service or change port in docker-compose.yml:
# ports:
#   - "8080:80"  # Use port 8080 instead
```

### Out of disk space

```bash
# Error: no space left on device

# Clean up Docker resources:
docker system prune -a --volumes

# WARNING: This removes:
# - All stopped containers
# - All unused images
# - All unused volumes
```

### Container fails to start

```bash
# Check container logs:
docker-compose logs app

# Check container health:
docker-compose ps

# Restart specific service:
docker-compose restart app
```

## Next Steps

Once you've confirmed you meet the prerequisites:

**Choose your path based on your skill level:**

| Level | Next Step | Documentation |
| ----- | --------- | ------------- |
| **Beginner** | Start developing | [Quick Start Guide][quickstart] |
| **Intermediate** | Understand architecture | [Architecture Overview][architecture] |
| **Advanced** | Advanced configurations | [Testing Modes][testing-modes], [Kubernetes][kubernetes] |

## Navigation

- [← Documentation Index](INDEX.md)
- [Quick Start Guide →][quickstart]

**Need help?** Join our [Discord][discord] community or report issues on [GitLab][issues].

<!-- Reference Links -->

[home]: ../README.md
[docs]: INDEX.md
[quickstart]: QUICKSTART.md
[architecture]: ARCHITECTURE.md
[testing-modes]: TESTING_MODES.md
[reference]: REFERENCE.md
[kubernetes]: KUBERNETES.md
[swarm]: SWARM.md
[monitoring]: MONITORING.md
[disaster-recovery]: DISASTER_RECOVERY.md
[discord]: https://discord.gg/MAmD5SG8Zu
[issues]: https://gitlab.com/zairakai/docker-ecosystem/-/issues
