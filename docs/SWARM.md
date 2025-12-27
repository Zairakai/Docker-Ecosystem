# Docker Swarm Deployment Guide

<!-- CI/CD & Quality -->
[![Pipeline][pipeline-badge]][pipeline]
[![License][license-badge]][license]

<!-- Community -->
[![Discord][discord-badge]][discord]
[![Issues][issues-badge]][issues]
[🏠 Home][home] > [📚 Documentation][docs] > Docker Swarm Deployment Guide

Complete guide for deploying Zairakai Docker Ecosystem on Docker Swarm for production high-availability setups.

## Table of Contents

- [Overview](#overview)
  - [Why Docker Swarm?](#why-docker-swarm)
  - [Architecture](#architecture)
- [Prerequisites](#prerequisites)
  - [Hardware Requirements](#hardware-requirements)
  - [Software Requirements](#software-requirements)
- [Swarm Setup](#swarm-setup)
  - [Initialize Swarm (Manager Node)](#initialize-swarm-manager-node)
  - [Add Manager Nodes (High Availability)](#add-manager-nodes-high-availability)
  - [Add Worker Nodes](#add-worker-nodes)
  - [Label Nodes](#label-nodes)
- [Deployment](#deployment)
  - [1. Create Docker Registry Secret](#1-create-docker-registry-secret)
  - [2. Create Application Secrets](#2-create-application-secrets)
  - [3. Create Configs](#3-create-configs)
  - [4. Deploy Stack](#4-deploy-stack)
  - [5. Verify Deployment](#5-verify-deployment)
- [High Availability](#high-availability)
  - [Scaling Services](#scaling-services)
  - [Rolling Updates](#rolling-updates)
  - [Rollback Deployment](#rollback-deployment)
  - [MySQL Replication (HA)](#mysql-replication-ha)
  - [Redis Sentinel (HA)](#redis-sentinel-ha)
  - [Health Checks](#health-checks)
- [Secrets Management](#secrets-management)
  - [Best Practices](#best-practices)
  - [Viewing Secret Metadata](#viewing-secret-metadata)
- [Monitoring](#monitoring)
  - [Service Status](#service-status)
  - [Resource Usage](#resource-usage)
  - [Logs](#logs)
  - [Prometheus Monitoring](#prometheus-monitoring)
- [Troubleshooting](#troubleshooting)
  - [Service Won't Start](#service-wont-start)
  - [Network Issues](#network-issues)
  - [Node Issues](#node-issues)
  - [Service Update Failures](#service-update-failures)
  - [Storage Issues](#storage-issues)
- [Backup & Restore](#backup--restore)
  - [Backup](#backup)
  - [Restore](#restore)
- [Production Checklist](#production-checklist)
- [Additional Resources](#additional-resources)

## Overview

Docker Swarm provides native orchestration for Docker containers with built-in load balancing, service
discovery, and rolling updates.

### Why Docker Swarm?

- **Simplicity**: Easier to set up than Kubernetes
- **Native Docker**: No additional tools required
- **Built-in**: Included with Docker Engine
- **Load Balancing**: Automatic internal load balancing
- **Secrets Management**: Native secrets encryption
- **Rolling Updates**: Zero-downtime deployments

### Architecture

```txt
┌────────────────────────────────────────────────────────────┐
│                    Docker Swarm Cluster                    │
│                                                            │
│  ┌──────────────┐   ┌──────────────┐   ┌──────────────┐    │
│  │ Manager Node │   │ Manager Node │   │ Manager Node │    │
│  │  (Leader)    │   │              │   │              │    │
│  └──────────────┘   └──────────────┘   └──────────────┘    │
│         │                  │                    │          │
│         └──────────────────┴────────────────────┘          │
│                           │                                │
│    ┌──────────────────────┴──────────────────────┐         │
│    │                                             │         │
│  ┌─▼────────────┐  ┌──────────────┐  ┌───────────▼─┐       │
│  │ Worker Node  │  │ Worker Node  │  │ Worker Node │       │
│  │              │  │              │  │             │       │
│  │ - Nginx (x2) │  │ - PHP (x5)   │  │ - Node (x3) │       │
│  │ - Redis (x1) │  │ - MySQL (x1) │  │             │       │
│  └──────────────┘  └──────────────┘  └─────────────┘       │
│                                                            │
│  Ingress Network: Load balancing across all worker nodes   │
│  Overlay Networks: Encrypted container communication       │
└────────────────────────────────────────────────────────────┘
```

## Prerequisites

### Hardware Requirements

**Minimum (Development):**

- 3 nodes (1 manager + 2 workers)
- 2 CPU cores per node
- 4 GB RAM per node
- 20 GB storage per node

**Recommended (Production):**

- 5+ nodes (3 managers + 2+ workers)
- 4 CPU cores per node
- 8 GB RAM per node
- 50 GB SSD storage per node

### Software Requirements

- Docker Engine 20.10+
- Linux kernel 3.10+ (CentOS 7, Ubuntu 18.04+, Debian 10+)
- Open ports:
  - `2377/tcp` - Cluster management
  - `7946/tcp` - Container network discovery
  - `7946/udp` - Container network discovery
  - `4789/udp` - Overlay network traffic

## Swarm Setup

### Initialize Swarm (Manager Node)

```bash
# On the first manager node
docker swarm init --advertise-addr <MANAGER-IP>

# Output will show join commands for workers and managers
# Example:
#   docker swarm join --token SWMTKN-1-… <MANAGER-IP>:2377
```

### Add Manager Nodes (High Availability)

```bash
# On first manager, get join token
docker swarm join-token manager

# On additional manager nodes
docker swarm join --token <MANAGER-TOKEN> <MANAGER-IP>:2377

# Verify cluster
docker node ls
```

### Add Worker Nodes

```bash
# On first manager, get join token
docker swarm join-token worker

# On worker nodes
docker swarm join --token <WORKER-TOKEN> <MANAGER-IP>:2377
```

### Label Nodes

```bash
# Label nodes for specific workloads
docker node update --label-add database=true worker-1
docker node update --label-add compute=true worker-2
docker node update --label-add compute=true worker-3

# Verify labels
docker node inspect worker-1 --format '{{ .Spec.Labels }}'
```

## Deployment

### 1. Create Docker Registry Secret

```bash
# Login to GitLab Container Registry
docker login registry.gitlab.com

# The login credentials are stored in ~/.docker/config.json
# Swarm automatically uses these credentials for image pulls
```

### 2. Create Application Secrets

```bash
# Generate secrets
APP_KEY=$(php -r "echo 'base64:'.base64_encode(random_bytes(32));")
DB_PASSWORD=$(openssl rand -base64 32)
MYSQL_ROOT_PASSWORD=$(openssl rand -base64 32)
MYSQL_PASSWORD=$(openssl rand -base64 32)
JWT_SECRET=$(openssl rand -base64 64)
REDIS_PASSWORD=$(openssl rand -base64 32)

# Create secrets in Swarm
echo "$DB_PASSWORD" | docker secret create db_password -
echo "$APP_KEY" | docker secret create app_key -
echo "$JWT_SECRET" | docker secret create jwt_secret -
echo "$MYSQL_ROOT_PASSWORD" | docker secret create mysql_root_password -
echo "$MYSQL_PASSWORD" | docker secret create mysql_password -
echo "$REDIS_PASSWORD" | docker secret create redis_password -

# Verify secrets
docker secret ls
```

### 3. Create Configs

```bash
# Create nginx configuration
cat > nginx.conf <<'EOF'
server {
    listen 80;
    server_name _;
    root /var/www/html/public;
    index index.php;

    location / {
        try_files $uri $uri/ /index.php?$query_string;
    }

    location ~ \.php$ {
        fastcgi_pass php:9000;
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        include fastcgi_params;
    }
}
EOF

docker config create nginx_config nginx.conf

# Create Redis Sentinel configuration
cat > sentinel.conf <<'EOF'
sentinel monitor mymaster redis 6379 2
sentinel down-after-milliseconds mymaster 5000
sentinel parallel-syncs mymaster 1
sentinel failover-timeout mymaster 10000
EOF

docker config create redis_sentinel_config sentinel.conf
```

### 4. Deploy Stack

```bash
# Deploy the stack
docker stack deploy -c swarm/stack-laravel.yml myapp

# Monitor deployment
watch docker service ls

# Check service logs
docker service logs myapp_php
docker service logs myapp_node
docker service logs myapp_nginx
```

### 5. Verify Deployment

```bash
# Check services
docker service ls

# Check service details
docker service ps myapp_php
docker service ps myapp_node

# Check networks
docker network ls | grep myapp

# Check secrets
docker secret ls

# Test application
curl http://<SWARM-NODE-IP>
```

## High Availability

### Scaling Services

```bash
# Scale PHP service
docker service scale myapp_php=10

# Scale Node.js service
docker service scale myapp_node=5

# Scale multiple services at once
docker service scale myapp_php=10 myapp_node=5 myapp_nginx=3
```

### Rolling Updates

```bash
# Update PHP image to new version
docker service update \
  --image registry.gitlab.com/zairakai/docker-ecosystem/php:8.3-prod \
  --update-parallelism 2 \
  --update-delay 10s \
  myapp_php

# Update with rollback on failure
docker service update \
  --image registry.gitlab.com/zairakai/docker-ecosystem/node:20-prod \
  --update-failure-action rollback \
  --update-max-failure-ratio 0.2 \
  myapp_node

# Monitor update progress
watch docker service ps myapp_php
```

### Rollback Deployment

```bash
# Rollback to previous version
docker service rollback myapp_php

# Rollback with specific options
docker service update --rollback \
  --rollback-parallelism 2 \
  --rollback-delay 5s \
  myapp_php
```

### MySQL Replication (HA)

```bash
# Enable MySQL replica
docker service scale myapp_mysql-replica=2

# Configure read/write splitting in Laravel
# Update .env:
#   DB_HOST=mysql  (for writes)
#   DB_HOST_READ=mysql-replica  (for reads)
```

### Redis Sentinel (HA)

```bash
# Enable Redis Sentinel
docker service scale myapp_redis-sentinel=3

# Update Laravel to use Sentinel
# config/database.php:
'redis' => [
    'client' => 'phpredis',
    'options' => [
        'cluster' => 'redis',
        'parameters' => [
            'password' => env('REDIS_PASSWORD'),
            'database' => 0,
        ],
    ],
    'clusters' => [
        'default' => [
            ['host' => 'redis-sentinel', 'port' => 26379],
        ],
    ],
],
```

### Health Checks

Services include built-in health checks:

```bash
# View service health
docker service ps myapp_php --filter "desired-state=running"

# Inspect health check configuration
docker service inspect myapp_php --format '{{json .Spec.TaskTemplate.ContainerSpec.Healthcheck}}'
```

## Secrets Management

### Best Practices

```bash
# Rotate secrets periodically
echo "new_password" | docker secret create db_password_v2 -

# Update service to use new secret
docker service update \
  --secret-rm db_password \
  --secret-add source=db_password_v2,target=db_password \
  myapp_php

# Remove old secret
docker secret rm db_password
```

### Viewing Secret Metadata

```bash
# List secrets
docker secret ls

# Inspect secret metadata (content is never exposed)
docker secret inspect db_password

# Check which services use a secret
docker service ls --format '{{.Name}}' | xargs -I {} sh -c 'docker service inspect {} | grep -q "db_password" && echo {}'
```

## Monitoring

### Service Status

```bash
# Monitor all services
watch -n 1 'docker service ls'

# Check service replicas
docker service ls --format 'table {{.Name}}\t{{.Replicas}}\t{{.Image}}'

# View service events
docker service ps myapp_php --no-trunc
```

### Resource Usage

```bash
# Node resource usage
docker node ls --format 'table {{.Hostname}}\t{{.Status}}\t{{.Availability}}\t{{.ManagerStatus}}'

# Service resource usage
docker stats --format 'table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}'
```

### Logs

```bash
# Service logs
docker service logs -f myapp_php
docker service logs -f myapp_node --tail 100

# Filter logs by time
docker service logs --since 1h myapp_php

# Search logs
docker service logs myapp_php 2>&1 | grep "ERROR"
```

### Prometheus Monitoring

```bash
# Deploy Prometheus stack
docker stack deploy -c monitoring-stack.yml monitoring

# Access Prometheus UI
curl http://<MANAGER-IP>:9090

# Query service metrics
# php_fpm_active_processes
# php_fpm_accepted_connections_total
```

## Troubleshooting

### Service Won't Start

```bash
# Check service status
docker service ps myapp_php --no-trunc

# Check logs
docker service logs myapp_php

# Inspect service configuration
docker service inspect myapp_php --pretty

# Common issues:
# - Image pull failure (check registry credentials)
# - Missing secrets (create required secrets)
# - Resource constraints (check node resources)
# - Port conflicts (ensure ports are available)
```

### Network Issues

```bash
# Check overlay networks
docker network ls | grep myapp

# Inspect network
docker network inspect myapp_backend

# Test connectivity between services
docker exec $(docker ps -q -f name=myapp_php) ping mysql

# Check network driver
docker network inspect myapp_backend --format '{{.Driver}}'
```

### Node Issues

```bash
# Check node status
docker node ls

# Drain node (for maintenance)
docker node update --availability drain worker-1

# Activate node after maintenance
docker node update --availability active worker-1

# Remove failed node
docker node rm worker-1
```

### Service Update Failures

```bash
# Check update status
docker service inspect myapp_php --format '{{json .UpdateStatus}}'

# Force update (bypass rollback)
docker service update --force myapp_php

# Reset update status
docker service update --detach=false myapp_php
```

### Storage Issues

```bash
# Check volume mounts
docker volume ls

# Inspect volume
docker volume inspect myapp_mysql_data

# Clean up unused volumes
docker volume prune
```

## Backup & Restore

### Backup

```bash
# Backup MySQL
docker exec $(docker ps -q -f name=myapp_mysql) \
  mysqldump -u root -p"$MYSQL_ROOT_PASSWORD" --all-databases \
  > backup-$(date +%Y%m%d).sql

# Backup Redis
docker exec $(docker ps -q -f name=myapp_redis) \
  redis-cli --rdb /tmp/dump.rdb

# Backup volumes
docker run --rm \
  -v myapp_mysql_data:/data \
  -v $(pwd):/backup \
  alpine tar czf /backup/mysql-data.tar.gz -C /data .
```

### Restore

```bash
# Restore MySQL
cat backup-20250930.sql | \
  docker exec -i $(docker ps -q -f name=myapp_mysql) \
  mysql -u root -p"$MYSQL_ROOT_PASSWORD"

# Restore Redis
docker cp redis-backup.rdb $(docker ps -q -f name=myapp_redis):/data/dump.rdb
docker service update --force myapp_redis
```

## Production Checklist

- [ ] Swarm cluster with 3+ manager nodes
- [ ] 5+ worker nodes for high availability
- [ ] All nodes labeled appropriately
- [ ] Secrets created and rotated
- [ ] Persistent volumes configured with backup
- [ ] Health checks configured for all services
- [ ] Resource limits set for all services
- [ ] Rolling update strategy configured
- [ ] MySQL replication enabled
- [ ] Redis Sentinel enabled
- [ ] Monitoring stack deployed
- [ ] Log aggregation configured
- [ ] Backup automation in place
- [ ] Disaster recovery plan documented
- [ ] Load testing performed
- [ ] Security hardening applied

## Additional Resources

- **Stack File**: `swarm/stack-laravel.yml`
- **[Docker Swarm Docs][docker-swarm-docs]** - Official documentation
- **[Monitoring Guide][monitoring]** - Prometheus, Grafana, observability
- **[Security Guide][security]** - Security scanning and best practices

## Navigation

- [← Kubernetes Deployment][kubernetes]
- [📚 Documentation Index][docs]
- [Architecture Comparison →][architecture-comparison]

**Learn More:**

- **[Monitoring Guide][monitoring]** - Prometheus, Grafana, Jaeger setup
- **[Kubernetes Deployment][kubernetes]** - K8s deployment guide
- **[Reference Guide][reference]** - Complete configuration reference

## Support

[![Discord][discord-badge]][discord]
[![Issues][issues-badge]][issues]

**Need help?** Join our Discord community or report issues on GitLab.



<!-- Badge References -->
[pipeline-badge]: https://gitlab.com/zairakai/docker-ecosystem/badges/main/pipeline.svg
[pipeline]: https://gitlab.com/zairakai/docker-ecosystem/-/pipelines
[license-badge]: https://img.shields.io/badge/license-MIT-blue.svg
[license]: ../LICENSE
[discord-badge]: https://img.shields.io/discord/1260000352699289621?logo=discord&label=Discord&color=5865F2
[discord]: https://discord.gg/MAmD5SG8Zu
[issues-badge]: https://img.shields.io/gitlab/issues/open-raw/zairakai%2Fdocker-ecosystem?logo=gitlab&label=Issues
[issues]: https://gitlab.com/zairakai/docker-ecosystem/-/issues

<!-- Reference Links -->

[home]: ../README.md
[docs]: INDEX.md
[kubernetes]: KUBERNETES.md
[architecture-comparison]: ARCHITECTURE_COMPARISON.md
[monitoring]: MONITORING.md
[reference]: REFERENCE.md
[security]: ../SECURITY.md
[docker-swarm-docs]: https://docs.docker.com/engine/swarm/
