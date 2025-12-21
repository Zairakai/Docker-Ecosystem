# Prerequisites Guide

This guide helps you understand what knowledge and tools you need to use the Zairakai Docker Ecosystem.

## Required Knowledge by Level

### Beginner Level

**Minimum Docker Knowledge:**

- Know what Docker is and why it's used
- Can run `docker run hello-world`
- Understand basic concepts: container, image, volume
- Can use `docker-compose up` and `docker-compose down`

**Minimum Laravel Knowledge:**

- Can create a Laravel project with `composer create-project`
- Understand basic Laravel structure (app/, routes/, resources/)
- Know how to run `php artisan` commands

**Recommended Reading:**

- [Docker Getting Started](https://docs.docker.com/get-started/)
- [Docker Compose Tutorial](https://docs.docker.com/compose/gettingstarted/)
- [Laravel Documentation](https://laravel.com/docs)

### Intermediate Level

**Required Docker Knowledge:**

- Understand multi-container applications
- Know how to use Docker networks and volumes
- Can read and modify docker-compose.yml
- Understand environment variables
- Know how to check container logs (`docker logs`)

**Required Laravel Knowledge:**

- Understand Laravel request lifecycle
- Know about database migrations and seeders
- Familiar with Laravel Blade templating
- Basic understanding of Vue.js (for hybrid setups)

**Recommended Reading:**

- [Docker Networking](https://docs.docker.com/network/)
- [Docker Volumes](https://docs.docker.com/storage/volumes/)
- [Laravel Advanced](https://laravel.com/docs/requests)

### Advanced Level

**Required Docker Knowledge:**

- Multi-stage builds
- Docker orchestration (Kubernetes or Swarm)
- Service mesh concepts
- Distributed tracing
- High availability patterns
- Security hardening

**Required Laravel + Vue.js Knowledge:**

- Laravel API development
- Vue.js 3 Composition API
- Vite build system
- SSR vs SPA architectures
- Asset compilation pipelines

**Recommended Reading:**

- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Docker Swarm](https://docs.docker.com/engine/swarm/)
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

- Linux: https://docs.docker.com/engine/install/
- macOS: https://docs.docker.com/desktop/mac/install/
- Windows: https://docs.docker.com/desktop/windows/install/

**Disk Space:**

- Minimum: 5GB free space
- Recommended: 10GB+ for all images and volumes

**Memory:**

- Minimum: 4GB RAM
- Recommended: 8GB+ RAM for development

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

**Node.js (for Vue.js/Vite):**

```bash
node --version
# Should show: v18+ or v20+

npm --version
# Should show: npm version 9+ or higher
```

### For Production Deployment

**Kubernetes (if using K8s):**

```bash
kubectl version --client
helm version
```

**Docker Swarm (if using Swarm):**

```bash
docker swarm --help
```

## System Requirements

### Development Environment

**Minimum:**

- CPU: 2 cores
- RAM: 4GB
- Disk: 20GB free
- OS: Linux, macOS, or Windows 10/11 with WSL2

**Recommended:**

- CPU: 4+ cores
- RAM: 8GB+
- Disk: 50GB+ SSD
- OS: Linux or macOS (best performance)

### Production Environment

**Single Server:**

- CPU: 4+ cores
- RAM: 8GB+ (16GB recommended)
- Disk: 100GB+ SSD
- OS: Ubuntu 22.04 LTS or similar

**High Availability Cluster:**

- Minimum 3 nodes
- Each node: 4+ cores, 8GB+ RAM
- Shared storage or distributed volumes
- Load balancer (Nginx, HAProxy, or cloud LB)

## Network Requirements

### Development

- Internet connection for pulling images from GitLab Container Registry
- No special firewall rules needed for local development

### Production

**Required Ports:**

- 80 (HTTP)
- 443 (HTTPS)
- 3306 (MySQL - internal only)
- 6379 (Redis - internal only)
- 9000 (PHP-FPM - internal only)

**Optional Ports:**

- 9090 (Prometheus)
- 3000 (Grafana)
- 16686 (Jaeger UI)
- 9411 (Zipkin UI)

## Skill Assessment

### Can I start with Beginner level?

✅ **YES** if you can answer:

- [ ] I can run `docker run nginx` successfully
- [ ] I can create a docker-compose.yml file
- [ ] I have a Laravel project ready
- [ ] I understand what environment variables are

❌ **NO** - Start with Docker basics first if you can't answer the above

### Am I ready for Intermediate level?

✅ **YES** if you can answer:

- [ ] I understand the difference between SSR and SPA
- [ ] I can modify Nginx configuration
- [ ] I know how to debug container issues with logs
- [ ] I understand Laravel's MVC pattern

❌ **NO** - Stick with beginner guides first

### Am I ready for Advanced level?

✅ **YES** if you can answer:

- [ ] I have deployed applications to production
- [ ] I understand high availability concepts
- [ ] I can read Kubernetes manifests
- [ ] I know how distributed tracing works

❌ **NO** - Master intermediate concepts first

## Common Issues

### Docker not installed

```bash
# Error: command not found: docker
# Solution: Install Docker from https://docs.docker.com/get-started/
```

### Permission denied

```bash
# Error: Got permission denied while trying to connect to the Docker daemon
# Solution (Linux): sudo usermod -aG docker $USER
# Then logout and login again
```

### Port already in use

```bash
# Error: Bind for 0.0.0.0:80 failed: port is already allocated
# Solution: Stop the service using port 80 or change the port in docker-compose.yml
docker-compose down  # Stop current containers
sudo lsof -i :80     # Check what's using port 80
```

### Out of disk space

```bash
# Error: no space left on device
# Solution: Clean up Docker resources
docker system prune -a  # Remove unused images, containers, volumes
```

## Next Steps

Once you've confirmed you meet the prerequisites:

- **Beginners:** → [Quick Start Guide](QUICKSTART.md)
- **Intermediate:** → [Architecture Overview](ARCHITECTURE.md)
- **Advanced:** → [Testing Modes](TESTING_MODES.md) or [Kubernetes Deployment](KUBERNETES.md)

---

**Need help?** Join our [Discord][discord] community or check the [Reference Guide][reference].

<!-- Reference Links -->
[reference]: REFERENCE.md
[discord]: https://discord.gg/MAmD5SG8Zu
