# Laravel Stack Helm Chart

[![Pipeline][pipeline-badge]][pipeline]
[![License][license-badge]][license]
[![Kubernetes][k8s-badge]][k8s]
[![Helm][helm-badge]][helm]
[![Discord][discord-badge]][discord]
[![Contributors][contributors-badge]][contributors]
[![Alpine][alpine-badge]][alpine]

Complete Kubernetes deployment for Laravel + Vue.js applications using Zairakai Docker images.

## Features

- 🚀 **Full Stack**: PHP-FPM, Node.js, Nginx, MySQL, Redis
- 📊 **Horizontal Autoscaling**: Based on CPU and memory metrics
- 🔒 **Security**: Pod Security Policies, Network Policies, Image verification
- 💾 **Persistent Storage**: Configurable storage classes for databases and application data
- 📈 **Observability**: Prometheus metrics, service monitors, Grafana dashboards
- ⚡ **High Availability**: Multiple replicas with pod disruption budgets
- 🔄 **Rolling Updates**: Zero-downtime deployments

## Prerequisites

- Kubernetes 1.24+
- Helm 3.8+
- kubectl configured
- Storage provisioner (for persistent volumes)
- Ingress controller (for external access)

## Quick Start

```bash
# Add Zairakai Helm repository (if available)
helm repo add zairakai https://helm.zairakai.com
helm repo update

# Install chart
helm install my-laravel-app zairakai/laravel-stack \
  --namespace production \
  --create-namespace

# Or install from source
helm install my-laravel-app ./k8s/helm/laravel-stack \
  --namespace production \
  --create-namespace
```

## Configuration

### Minimal Configuration

```yaml
# values-prod.yaml
global:
  imageRegistry: registry.gitlab.com/zairakai/docker-ecosystem

nginx:
  ingress:
    enabled: true
    hosts:
      - host: myapp.example.com
        paths:
          - path: /
            pathType: Prefix

mysql:
  persistence:
    size: 50Gi
  environment:
    MYSQL_ROOT_PASSWORD: "change-me-in-production"
    MYSQL_PASSWORD: "change-me-in-production"
```

```bash
helm install my-app ./k8s/helm/laravel-stack \
  --namespace production \
  -f values-prod.yaml
```

### Using Secrets

> **Recommended: Use Kubernetes Secrets**

```bash
# Create MySQL credentials secret
kubectl create secret generic mysql-credentials \
  --namespace production \
  --from-literal=root-password='super-secret-root-pw' \
  --from-literal=password='super-secret-user-pw'

# Create Laravel app secret
kubectl create secret generic laravel-secrets \
  --namespace production \
  --from-literal=APP_KEY='base64:…' \
  --from-literal=JWT_SECRET='…'
```

Update your `values-prod.yaml`:

```yaml
php:
  secrets:
    APP_KEY:
      secretName: laravel-secrets
      key: APP_KEY
    DB_PASSWORD:
      secretName: mysql-credentials
      key: password

mysql:
  secrets:
    MYSQL_ROOT_PASSWORD:
      secretName: mysql-credentials
      key: root-password
    MYSQL_PASSWORD:
      secretName: mysql-credentials
      key: password
```

### High Availability Setup

```yaml
# values-ha.yaml
php:
  replicaCount: 5
  autoscaling:
    enabled: true
    minReplicas: 3
    maxReplicas: 20
    targetCPUUtilizationPercentage: 60

node:
  replicaCount: 3
  autoscaling:
    enabled: true
    minReplicas: 2
    maxReplicas: 15

mysql:
  replication:
    enabled: true
    replicaCount: 3

redis:
  sentinel:
    enabled: true
    replicaCount: 3

podDisruptionBudget:
  enabled: true
  minAvailable: 2
```

### Resource Limits (Production)

```yaml
# values-resources.yaml
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
```

## Installation

### Development Environment

```bash
helm install dev-app ./k8s/helm/laravel-stack \
  --namespace development \
  --create-namespace \
  --set php.image.tag=8.3-dev \
  --set node.image.tag=20-dev \
  --set php.environment.APP_DEBUG=true \
  --set php.environment.APP_ENV=development
```

### Production Environment

```bash
helm install prod-app ./k8s/helm/laravel-stack \
  --namespace production \
  --create-namespace \
  --values values-prod.yaml \
  --values values-ha.yaml \
  --values values-secrets.yaml \
  --timeout 10m
```

### Verify Installation

```bash
# Check deployments
kubectl get deployments -n production

# Check pods
kubectl get pods -n production

# Check services
kubectl get svc -n production

# Check ingress
kubectl get ingress -n production

# View logs
kubectl logs -n production -l app.kubernetes.io/component=php --tail=100
```

## Upgrading

```bash
# Upgrade to new version
helm upgrade prod-app ./k8s/helm/laravel-stack \
  --namespace production \
  --values values-prod.yaml \
  --timeout 10m

# Rollback if needed
helm rollback prod-app --namespace production
```

## Uninstalling

```bash
helm uninstall prod-app --namespace production

# Delete namespace (optional, removes all resources)
kubectl delete namespace production
```

## Customization Examples

### Custom Nginx Configuration

```yaml
nginx:
  config: |
    server {
      listen 80;
      root /var/www/html/public;

      location / {
        try_files $uri $uri/ /index.php?$query_string;
      }

      location ~ \.php$ {
        fastcgi_pass php-service:9000;
        fastcgi_index index.php;
        include fastcgi_params;
      }
    }
```

### Enable Prometheus Monitoring

```yaml
monitoring:
  enabled: true
  prometheus:
    enabled: true
    serviceMonitor:
      enabled: true
      interval: 30s

php:
  metrics:
    enabled: true
    port: 9253
```

### Enable Distributed Tracing

```yaml
monitoring:
  tracing:
    enabled: true
    jaeger:
      endpoint: "http://jaeger-collector.observability:14268/api/traces"

php:
  environment:
    OTEL_ENABLED: "true"
    OTEL_SERVICE_NAME: "laravel-app"
    OTEL_EXPORTER_OTLP_ENDPOINT: "http://otel-collector.observability:4318"
```

## Troubleshooting

### Pods not starting

```bash
# Check pod status
kubectl describe pod <pod-name> -n production

# Check events
kubectl get events -n production --sort-by='.lastTimestamp'

# Check logs
kubectl logs <pod-name> -n production
```

### Database connection issues

```bash
# Test MySQL connectivity
kubectl run mysql-client --rm -it \
  --image=mysql:8.0 \
  --namespace production \
  -- mysql -h laravel-stack-mysql -u root -p

# Check MySQL logs
kubectl logs -n production -l app.kubernetes.io/component=mysql
```

### Ingress not working

```bash
# Check ingress
kubectl describe ingress -n production

# Check ingress controller logs
kubectl logs -n ingress-nginx -l app.kubernetes.io/component=controller
```

## Production Checklist

Before deploying to production:

- [ ] Review and customize resource limits
- [ ] Configure proper storage classes
- [ ] Set up secrets management (Sealed Secrets, External Secrets Operator)
- [ ] Enable network policies
- [ ] Configure ingress with TLS certificates
- [ ] Enable Horizontal Pod Autoscaling
- [ ] Set up monitoring and alerting
- [ ] Configure backup schedules
- [ ] Review security policies
- [ ] Test disaster recovery procedures

## Values Reference

See `values.yaml` for complete configuration options.

## Support

[![Discord][discord-badge]][discord]
[![Issues][issues-badge]][issues]

**Need help?** Join our Discord community or report issues on GitLab.


<!-- Badge References -->
[pipeline-badge]: https://gitlab.com/zairakai/docker-ecosystem/badges/main/pipeline.svg
[pipeline]: https://gitlab.com/zairakai/docker-ecosystem/-/pipelines
[license-badge]: https://img.shields.io/badge/license-MIT-blue.svg
[license]: ../../../LICENSE
[discord-badge]: https://img.shields.io/discord/1260000352699289621?logo=discord&label=Discord&color=5865F2
[discord]: https://discord.gg/MAmD5SG8Zu
[issues-badge]: https://img.shields.io/gitlab/issues/open-raw/zairakai%2Fdocker-ecosystem?logo=gitlab&label=Issues
[issues]: https://gitlab.com/zairakai/docker-ecosystem/-/issues
[k8s-badge]: https://img.shields.io/badge/kubernetes-1.24+-326CE5.svg?logo=kubernetes&logoColor=white
[k8s]: https://kubernetes.io
[helm-badge]: https://img.shields.io/badge/helm-3.8+-0F1689.svg?logo=helm&logoColor=white
[helm]: https://helm.sh
[contributors-badge]: https://img.shields.io/gitlab/contributors/zairakai%2Fdocker-ecosystem?logo=gitlab&label=Contributors
[contributors]: https://gitlab.com/zairakai/docker-ecosystem/-/graphs/main
[alpine-badge]: https://img.shields.io/badge/built%20on-Alpine%203.19-0D597F?logo=alpine-linux&logoColor=white
[alpine]: https://alpinelinux.org/

<!-- Reference Links -->
[reference]: REFERENCE.md
