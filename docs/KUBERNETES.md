# Kubernetes Deployment Guide

<!-- CI/CD & Quality -->
[![Pipeline][pipeline-badge]][pipeline]
[![License][license-badge]][license]

<!-- Community -->
[![Discord][discord-badge]][discord]
[![Issues][issues-badge]][issues]
[🏠 Home][home] > [📚 Documentation][docs] > Kubernetes Deployment Guide

Complete guide for deploying Zairakai Docker Ecosystem on Kubernetes using Helm.

## Table of Contents

- [Overview](#overview)
  - [Architecture](#architecture)
  - [Components](#components)
- [Prerequisites](#prerequisites)
  - [Required Tools](#required-tools)
  - [Kubernetes Cluster](#kubernetes-cluster)
  - [Storage Provisioner](#storage-provisioner)
  - [Ingress Controller](#ingress-controller)
- [Installation](#installation)
  - [1. Create Namespace](#1-create-namespace)
  - [2. Create Image Pull Secret (GitLab Registry)](#2-create-image-pull-secret-gitlab-registry)
  - [3. Create Application Secrets](#3-create-application-secrets)
  - [4. Create values.yaml](#4-create-valuesyaml)
  - [5. Install Helm Chart](#5-install-helm-chart)
  - [6. Verify Deployment](#6-verify-deployment)
- [Configuration](#configuration)
  - [Resource Limits](#resource-limits)
  - [Horizontal Pod Autoscaling](#horizontal-pod-autoscaling)
  - [Storage Configuration](#storage-configuration)
- [High Availability](#high-availability)
  - [MySQL Replication](#mysql-replication)
  - [Redis Sentinel](#redis-sentinel)
  - [Pod Disruption Budgets](#pod-disruption-budgets)
  - [Multi-Zone Deployment](#multi-zone-deployment)
- [Monitoring](#monitoring)
  - [Prometheus ServiceMonitor](#prometheus-servicemonitor)
  - [Grafana Dashboards](#grafana-dashboards)
  - [Check Metrics](#check-metrics)
- [Security](#security)
  - [Network Policies](#network-policies)
  - [Pod Security Standards](#pod-security-standards)
  - [Image Verification with Cosign](#image-verification-with-cosign)
- [Troubleshooting](#troubleshooting)
  - [Pods Stuck in Pending](#pods-stuck-in-pending)
  - [Image Pull Errors](#image-pull-errors)
  - [Database Connection Issues](#database-connection-issues)
  - [Application Logs](#application-logs)
  - [Performance Issues](#performance-issues)
- [Backup & Restore](#backup--restore)
  - [Manual Backup](#manual-backup)
  - [Automated Backups with CronJob](#automated-backups-with-cronjob)
- [Production Checklist](#production-checklist)
- [Additional Resources](#additional-resources)

## Overview

The Zairakai Docker Ecosystem provides production-ready Helm charts for deploying Laravel + Vue.js
applications on Kubernetes.

### Architecture

```txt
┌──────────────────────────────────────────┐
│            Kubernetes Cluster            │
│                                          │
│  ┌────────────┐                          │
│  │   Ingress  │ (Load Balancer)          │
│  └──────┬─────┘                          │
│         │                                │
│  ┌──────▼────────┐                       │
│  │  Nginx (x2)   │ (Service: ClusterIP)  │
│  └──────┬────────┘                       │
│         │                                │
│    ┌────┴────┐                           │
│    │         │                           │
│  ┌─▼──────┐ ┌▼─────────┐                 │
│  │PHP (x3)│ │Node (x2) │                 │
│  │Laravel │ │ Vue.js   │                 │
│  └─┬──────┘ └┬─────────┘                 │
│    │         │                           │
│  ┌─▼─────────▼────┐   ┌──────────┐       │
│  │  Redis (x1)    │   │MySQL (x1)│       │
│  │  Cache         │   │ Database │       │
│  └────────────────┘   └──────────┘       │
│         │                    │           │
│    ┌────▼────────────────────▼────┐      │
│    │  Persistent Volume Claims    │      │
│    └──────────────────────────────┘      │
└──────────────────────────────────────────┘
```

### Components

| Component | Purpose | Replicas | Storage |
| --------- | ------- | -------- | ------- |
| **PHP (Laravel)** | Backend API | 3 (auto-scaled) | 10Gi (shared) |
| **Node.js (Vue)** | Frontend | 2 (auto-scaled) | - |
| **Nginx** | Web server / Reverse proxy | 2 | - |
| **MySQL** | Database | 1 (+ optional replicas) | 20Gi |
| **Redis** | Cache & Sessions | 1 (+ optional sentinel) | 5Gi |

## Prerequisites

### Required Tools

```bash
# kubectl (Kubernetes CLI)
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# Helm (Package Manager)
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Verify installations
kubectl version --client
helm version
```

### Kubernetes Cluster

**Minimum Requirements:**

- Kubernetes 1.24+
- 3 worker nodes (for HA)
- 8 GB RAM per node
- 50 GB storage
- Ingress controller (nginx recommended)
- Storage provisioner (for PersistentVolumes)

**Recommended Providers:**

- **Cloud**: AWS EKS, Google GKE, Azure AKS, DigitalOcean DOKS
- **On-Premise**: k3s, RKE2, kubeadm
- **Local**: minikube, kind, k3d

### Storage Provisioner

```bash
# Check available storage classes
kubectl get storageclass

# If none exist, install local-path-provisioner (for development)
kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/master/deploy/local-path-storage.yaml
```

### Ingress Controller

```bash
# Install nginx-ingress controller
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update

helm install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --create-namespace \
  --set controller.service.type=LoadBalancer
```

## Installation

### 1. Create Namespace

```bash
kubectl create namespace production
kubectl label namespace production name=production
```

### 2. Create Image Pull Secret (GitLab Registry)

```bash
kubectl create secret docker-registry gitlab-registry \
  --namespace production \
  --docker-server=registry.gitlab.com \
  --docker-username=<your-username> \
  --docker-password=<your-token> \
  --docker-email=<your-email>
```

### 3. Create Application Secrets

```bash
# Generate Laravel APP_KEY
APP_KEY=$(php -r "echo 'base64:'.base64_encode(random_bytes(32));")

# Create secrets
kubectl create secret generic laravel-secrets \
  --namespace production \
  --from-literal=APP_KEY="$APP_KEY" \
  --from-literal=DB_PASSWORD="$(openssl rand -base64 32)" \
  --from-literal=JWT_SECRET="$(openssl rand -base64 64)"

kubectl create secret generic mysql-credentials \
  --namespace production \
  --from-literal=root-password="$(openssl rand -base64 32)" \
  --from-literal=password="$(openssl rand -base64 32)"
```

### 4. Create values.yaml

```yaml
# production-values.yaml
global:
  imageRegistry: registry.gitlab.com/zairakai/docker-ecosystem

nginx:
  ingress:
    enabled: true
    className: nginx
    annotations:
      cert-manager.io/cluster-issuer: letsencrypt-prod
    hosts:
      - host: app.example.com
        paths:
          - path: /
            pathType: Prefix
    tls:
      - secretName: app-tls
        hosts:
          - app.example.com

php:
  replicaCount: 3
  environment:
    APP_URL: https://app.example.com
  secrets:
    APP_KEY:
      secretName: laravel-secrets
      key: APP_KEY
    DB_PASSWORD:
      secretName: mysql-credentials
      key: password

mysql:
  persistence:
    size: 50Gi
  secrets:
    MYSQL_ROOT_PASSWORD:
      secretName: mysql-credentials
      key: root-password
    MYSQL_PASSWORD:
      secretName: mysql-credentials
      key: password

monitoring:
  enabled: true
```

### 5. Install Helm Chart

```bash
# Install from local chart
helm install my-laravel-app ./k8s/helm/laravel-stack \
  --namespace production \
  --values production-values.yaml \
  --timeout 10m

# Monitor installation
kubectl get pods -n production --watch

# Check status
helm status my-laravel-app -n production
```

### 6. Verify Deployment

```bash
# Check all resources
kubectl get all -n production

# Check PVCs
kubectl get pvc -n production

# Check ingress
kubectl get ingress -n production

# Test application
curl https://app.example.com
```

## Configuration

### Resource Limits

```yaml
# production-resources.yaml
php:
  resources:
    requests:
      cpu: 500m
      memory: 1Gi
    limits:
      cpu: 2000m
      memory: 2Gi

node:
  resources:
    requests:
      cpu: 250m
      memory: 512Mi
    limits:
      cpu: 1000m
      memory: 1Gi

mysql:
  resources:
    requests:
      cpu: 1000m
      memory: 2Gi
    limits:
      cpu: 4000m
      memory: 8Gi

redis:
  resources:
    requests:
      cpu: 100m
      memory: 256Mi
    limits:
      cpu: 500m
      memory: 512Mi
```

### Horizontal Pod Autoscaling

```yaml
php:
  autoscaling:
    enabled: true
    minReplicas: 3
    maxReplicas: 20
    targetCPUUtilizationPercentage: 70
    targetMemoryUtilizationPercentage: 80

node:
  autoscaling:
    enabled: true
    minReplicas: 2
    maxReplicas: 15
    targetCPUUtilizationPercentage: 70
```

Verify HPA:

```bash
kubectl get hpa -n production
kubectl describe hpa my-laravel-app-php -n production
```

### Storage Configuration

```yaml
# Use specific storage class
php:
  persistence:
    storageClass: "fast-ssd"
    size: 20Gi
    accessMode: ReadWriteMany

mysql:
  persistence:
    storageClass: "retain-ssd"
    size: 100Gi
    accessMode: ReadWriteOnce

redis:
  persistence:
    storageClass: "standard"
    size: 10Gi
```

## High Availability

### MySQL Replication

```yaml
mysql:
  replication:
    enabled: true
    replicaCount: 3
  persistence:
    size: 100Gi
  resources:
    requests:
      cpu: 2000m
      memory: 4Gi
```

### Redis Sentinel

```yaml
redis:
  sentinel:
    enabled: true
    replicaCount: 3
  persistence:
    enabled: true
    size: 10Gi
```

### Pod Disruption Budgets

```yaml
podDisruptionBudget:
  enabled: true
  minAvailable: 2
```

Verify PDB:

```bash
kubectl get pdb -n production
```

### Multi-Zone Deployment

```yaml
# Use node affinity for zone distribution
php:
  affinity:
    podAntiAffinity:
      preferredDuringSchedulingIgnoredDuringExecution:
        - weight: 100
          podAffinityTerm:
            labelSelector:
              matchExpressions:
                - key: app.kubernetes.io/component
                  operator: In
                  values:
                    - php
            topologyKey: topology.kubernetes.io/zone
```

## Monitoring

### Prometheus ServiceMonitor

```yaml
monitoring:
  enabled: true
  prometheus:
    enabled: true
    serviceMonitor:
      enabled: true
      interval: 30s
```

### Grafana Dashboards

```bash
# Access Grafana (if installed)
kubectl port-forward -n monitoring svc/grafana 3000:80

# Open browser: http://localhost:3000
# Import dashboard ID 14963 for PHP-FPM metrics
```

### Check Metrics

```bash
# PHP-FPM metrics
kubectl port-forward -n production svc/my-laravel-app-php 9253:9253
curl http://localhost:9253/metrics

# Application logs
kubectl logs -n production -l app.kubernetes.io/component=php --tail=100 -f
```

## Security

### Network Policies

```yaml
security:
  networkPolicy:
    enabled: true
    ingress:
      - from:
        - namespaceSelector:
            matchLabels:
              name: ingress-nginx
```

### Pod Security Standards

```bash
# Apply pod security standards
kubectl label namespace production \
  pod-security.kubernetes.io/enforce=restricted \
  pod-security.kubernetes.io/audit=restricted \
  pod-security.kubernetes.io/warn=restricted
```

### Image Verification with Cosign

```yaml
security:
  imageSigning:
    verify: true
    cosignPublicKey: |
      -----BEGIN PUBLIC KEY-----
      <Your Cosign public key>
      -----END PUBLIC KEY-----
```

Use admission controller to enforce:

```bash
# Install Sigstore Policy Controller
kubectl apply -f https://github.com/sigstore/policy-controller/releases/latest/download/policy-controller.yaml
```

## Troubleshooting

### Pods Stuck in Pending

```bash
# Check pod events
kubectl describe pod <pod-name> -n production

# Common causes:
# - Insufficient resources
# - PVC not bound
# - Image pull errors
```

### Image Pull Errors

```bash
# Verify image pull secret
kubectl get secret gitlab-registry -n production -o yaml

# Test manually
kubectl run test-pull --rm -it \
  --image=registry.gitlab.com/zairakai/docker-ecosystem/php:8.3-prod \
  --image-pull-policy=Always \
  --overrides='{"spec":{"imagePullSecrets":[{"name":"gitlab-registry"}]}}' \
  --namespace production
```

### Database Connection Issues

```bash
# Test MySQL connection
kubectl run mysql-test --rm -it \
  --image=mysql:8.0 \
  --namespace production \
  -- mysql -h my-laravel-app-mysql -u root -p

# Check MySQL logs
kubectl logs -n production -l app.kubernetes.io/component=mysql

# Check environment variables
kubectl exec -n production deployment/my-laravel-app-php -- env | grep DB_
```

### Application Logs

```bash
# PHP logs
kubectl logs -n production -l app.kubernetes.io/component=php --tail=100

# Node.js logs
kubectl logs -n production -l app.kubernetes.io/component=node --tail=100

# All pods logs
kubectl logs -n production --all-containers=true --tail=100
```

### Performance Issues

```bash
# Check resource usage
kubectl top pods -n production
kubectl top nodes

# Check HPA status
kubectl get hpa -n production

# Describe HPA for details
kubectl describe hpa my-laravel-app-php -n production
```

## Backup & Restore

### Manual Backup

```bash
# Backup MySQL
kubectl exec -n production deployment/my-laravel-app-mysql -- \
  mysqldump -u root -p"$MYSQL_ROOT_PASSWORD" --all-databases \
  > backup-$(date +%Y%m%d-%H%M%S).sql

# Backup Redis
kubectl exec -n production deployment/my-laravel-app-redis -- \
  redis-cli --rdb /tmp/dump.rdb
kubectl cp production/my-laravel-app-redis:/tmp/dump.rdb ./redis-backup.rdb
```

### Automated Backups with CronJob

```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: mysql-backup
  namespace: production
spec:
  schedule: "0 2 * * *"  # Daily at 2 AM
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: backup
            image: mysql:8.0
            command:
            - /bin/sh
            - -c
            - mysqldump -h my-laravel-app-mysql -u root -p"$MYSQL_ROOT_PASSWORD" --all-databases | gzip > /backup/backup-$(date +%Y%m%d).sql.gz
            env:
            - name: MYSQL_ROOT_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: mysql-credentials
                  key: root-password
            volumeMounts:
            - name: backup
              mountPath: /backup
          volumes:
          - name: backup
            persistentVolumeClaim:
              claimName: mysql-backups
          restartPolicy: OnFailure
```

## Production Checklist

Before going to production:

- [ ] Configure proper resource limits
- [ ] Enable horizontal pod autoscaling
- [ ] Set up high availability (multi-replica)
- [ ] Configure persistent storage with proper storage classes
- [ ] Enable network policies
- [ ] Set up TLS certificates (cert-manager + Let's Encrypt)
- [ ] Configure monitoring and alerting
- [ ] Set up log aggregation
- [ ] Configure automated backups
- [ ] Test disaster recovery procedures
- [ ] Enable pod disruption budgets
- [ ] Configure image signing verification
- [ ] Set up secrets management (Sealed Secrets / External Secrets Operator)
- [ ] Review and harden security policies
- [ ] Load test application
- [ ] Document runbooks and incident response procedures

## Additional Resources

- **Helm Chart**: `k8s/helm/laravel-stack/`
- **Examples**: `k8s/helm/laravel-stack/examples/`
- **[Monitoring Guide][monitoring]** - Prometheus, Grafana, observability
- **[Security Guide][security]** - Security scanning and best practices

## Navigation

- [← Monitoring & Observability][monitoring]
- [📚 Documentation Index][docs]
- [Docker Swarm Deployment →][swarm]

**Learn More:**

- **[Monitoring Guide][monitoring]** - Prometheus, Grafana, Jaeger setup
- **[Docker Swarm Deployment][swarm]** - Swarm orchestration guide
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
[issues-badge]: https://img.shields.io/gitlab/issues/open-raw/zairakai%2Fdocker-ecosystem?logo=gitlab&label=Issues

<!-- Reference Links -->

[home]: ../README.md
[docs]: INDEX.md
[monitoring]: MONITORING.md
[swarm]: SWARM.md
[reference]: REFERENCE.md
[security]: ../SECURITY.md
