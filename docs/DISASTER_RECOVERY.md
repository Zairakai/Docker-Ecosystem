# Disaster Recovery Guide

<!-- CI/CD & Quality -->
[![License][license-badge]][license]
[![Pipeline][pipeline-badge]][pipeline]


[🏠 Home][home] > [📚 Documentation][docs] > Disaster Recovery Guide

Complete disaster recovery procedures for the Zairakai Docker Ecosystem.

## Table of Contents

- [Overview](#overview)
- [RTO and RPO](#rto-and-rpo)
- [Backup Procedures](#backup-procedures)
- [Restore Procedures](#restore-procedures)
- [Automated Testing](#automated-testing)
- [Incident Response](#incident-response)
- [Runbooks](#runbooks)

## Overview

Disaster Recovery (DR) ensures business continuity by enabling rapid recovery from data loss, system
failures, or catastrophic events.

### Coverage

| Component | Backup Frequency | Retention | Storage Location |
| --------- | ---------------- | --------- | ---------------- |
| **MySQL Database** | Daily (2 AM UTC) | 7 days local, 30 days S3 | Local + S3/MinIO |
| **Redis Cache** | Daily (3 AM UTC) | 7 days local, 30 days S3 | Local + S3/MinIO |
| **Application Files** | Daily (4 AM UTC) | 7 days local, 30 days S3 | Local + S3/MinIO |
| **Configuration** | On change | 90 days | Git + S3 |

## RTO and RPO

### Recovery Time Objective (RTO)

**Target RTO**: < 15 minutes

| Scenario | RTO Target | RTO Actual |
| -------- | ---------- | ---------- |
| Single database restore | 5 minutes | 2-3 minutes |
| Full application restore | 15 minutes | 10-12 minutes |
| Complete infrastructure rebuild | 30 minutes | 25-28 minutes |

### Recovery Point Objective (RPO)

**Target RPO**: < 1 hour

| Component | RPO Target | RPO Actual |
| --------- | ---------- | ---------- |
| MySQL (with replication) | 0 (real-time) | 0 (synchronous) |
| MySQL (without replication) | 24 hours | 24 hours (daily backup) |
| Redis | 1 hour | 1 hour (AOF persist) |
| Application files | 24 hours | 24 hours (daily backup) |

## Backup Procedures

### MySQL Backup

#### Manual Backup

```bash
# Run backup script
bash ./scripts/backup/backup.sh mysql

# With S3 upload
S3_ENABLED=true \
S3_BUCKET=my-backups \
S3_ENDPOINT=https://s3.amazonaws.com \
./scripts/backup/backup.sh mysql
```

#### Automated Backup (Cron)

```bash
# Add to crontab
0 2 * * * /path/to/scripts/backup/backup.sh mysql >> /var/log/mysql-backup.log 2>&1
```

#### Automated Backup (Docker Compose)

```yaml
services:
  backup:
    image: mysql:8.0
    volumes:
      - ./scripts/backup:/scripts
      - ./backups:/backups
    environment:
      MYSQL_HOST: mysql
      MYSQL_PASSWORD: ${MYSQL_ROOT_PASSWORD}
      BACKUP_DIR: /backups/mysql
      S3_ENABLED: "true"
      S3_BUCKET: my-backups
    command: sh -c "while true; do bash /scripts/backup.sh mysql; sleep 86400; done"
```

#### Automated Backup (Kubernetes CronJob)

```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: mysql-backup
spec:
  schedule: "0 2 * * *"
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: backup
            image: registry.gitlab.com/zairakai/docker-ecosystem/database:mysql-8.0
            command:
            - bash
            - /scripts/backup.sh
            - mysql
            env:
            - name: MYSQL_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: mysql-credentials
                  key: root-password
            volumeMounts:
            - name: backup-scripts
              mountPath: /scripts
            - name: backups
              mountPath: /backups
          volumes:
          - name: backup-scripts
            configMap:
              name: backup-scripts
          - name: backups
            persistentVolumeClaim:
              claimName: mysql-backups
          restartPolicy: OnFailure
```

### Redis Backup

#### Manual Backup

```bash
# Run backup script
bash ./scripts/backup/backup.sh redis

# With S3 upload
S3_ENABLED=true \
S3_BUCKET=my-backups \
bash ./scripts/backup/backup.sh redis
```

#### Docker Volume Backup

```bash
# Backup Redis volume
docker run --rm \
  -v redis_data:/data:ro \
  -v $(pwd)/backups:/backup \
  alpine \
  tar czf /backup/redis-$(date +%Y%m%d).tar.gz -C /data .
```

## Restore Procedures

### MySQL Restore

#### From Local Backup

```bash
# Restore latest backup
bash ./scripts/backup/restore.sh mysql

# Restore specific backup
bash ./scripts/backup/restore.sh mysql mysql-backup-20250930-140000.sql.gz
```

#### From S3 Backup

```bash
# Download and restore
S3_ENABLED=true \
S3_BUCKET=my-backups \
bash ./scripts/backup/restore.sh mysql mysql-backup-20250930-140000.sql.gz
```

#### Step-by-Step Manual Restore

```bash
# 1. Stop application to prevent writes
docker-compose stop php

# 2. Download backup (if from S3)
aws s3 cp s3://my-backups/mysql/backup.sql.gz ./backups/

# 3. Verify backup integrity
gunzip -t ./backups/backup.sql.gz

# 4. Restore database
gunzip -c ./backups/backup.sql.gz | \
  mysql -h mysql -u root -p"${MYSQL_ROOT_PASSWORD}"

# 5. Verify data
mysql -h mysql -u root -p"${MYSQL_ROOT_PASSWORD}" -e "SHOW DATABASES;"

# 6. Restart application
docker-compose start php
```

### Redis Restore

#### From RDB File

```bash
# 1. Stop Redis
docker-compose stop redis

# 2. Copy backup to data directory
docker cp ./backups/dump.rdb redis:/data/dump.rdb

# 3. Restart Redis
docker-compose start redis

# 4. Verify data
docker exec redis redis-cli KEYS '*'
```

#### From Volume Backup

```bash
# 1. Stop Redis
docker-compose stop redis

# 2. Restore volume
docker run --rm \
  -v redis_data:/data \
  -v $(pwd)/backups:/backup \
  alpine \
  sh -c "cd /data && tar xzf /backup/redis-20250930.tar.gz"

# 3. Start Redis
docker-compose start redis
```

## Automated Testing

### CI/CD Integration

The `.gitlab-ci.yml` includes automated DR testing:

```yaml
test:backup-restore:
  stage: disaster-recovery
  script:
    - # Create test data
    - # Backup
    - # Destroy database
    - # Restore
    - # Verify data integrity
```

### Running Tests Locally

```bash
# Start test environment
docker-compose -f examples/docker-compose-ha.yml up -d mysql-master redis-master

# Run backup test
bash ./scripts/backup/backup.sh mysql
bash ./scripts/backup/backup.sh redis

# Simulate disaster
docker-compose -f examples/docker-compose-ha.yml stop mysql-master redis-master
docker-compose -f examples/docker-compose-ha.yml rm -f mysql-master redis-master

# Restore
docker-compose -f examples/docker-compose-ha.yml up -d mysql-master redis-master
sleep 10
bash ./scripts/backup/restore.sh mysql latest.sql.gz

# Verify
docker exec mysql-master mysql -u root -prootsecret -e "SHOW DATABASES;"
```

## Incident Response

### Incident Response Plan

#### 1. Detection

**Alerting Channels:**

- Monitoring alerts (Prometheus/Grafana)
- Health check failures
- User reports
- Automated tests

**Severity Levels:**

- **P0 (Critical)**: Complete data loss, system down
- **P1 (High)**: Partial data loss, degraded service
- **P2 (Medium)**: Non-critical data loss, service operational
- **P3 (Low)**: Backup failure, no immediate impact

#### 2. Assessment

**Questions to Answer:**

- What data is affected?
- When did the incident occur?
- What is the extent of the damage?
- Are backups available and intact?
- What is the estimated recovery time?

**Tools:**

```bash
# Check MySQL status
docker exec mysql mysqladmin status

# Check Redis status
docker exec redis redis-cli INFO

# List available backups
ls -lh /backups/mysql/
ls -lh /backups/redis/

# Verify backup integrity
gunzip -t /backups/mysql/latest.sql.gz
```

#### 3. Response

**Immediate Actions:**

1. Notify stakeholders
2. Enable maintenance mode
3. Stop affected services
4. Assess backup availability
5. Initiate restore procedure

**Communication Template:**

```text
INCIDENT ALERT

Severity: [P0/P1/P2/P3]
Component: [MySQL/Redis/Application]
Impact: [Description]
Start Time: [UTC timestamp]
Estimated Recovery: [Time]
Status: [Investigating/Restoring/Resolved]

Actions Taken:
- [Action 1]
- [Action 2]

Next Steps:
- [Step 1]
- [Step 2]
```

#### 4. Recovery

Follow the restore procedures documented above.

#### 5. Post-Incident Review

**Review Template:**

- **Incident Summary**: What happened?
- **Root Cause**: Why did it happen?
- **Impact**: What was affected and for how long?
- **Response**: What went well? What didn't?
- **Action Items**: How can we prevent this in the future?

## Runbooks

### Runbook 1: Complete MySQL Database Loss

**Scenario**: MySQL database is corrupted or completely lost

**Prerequisites:**

- Access to backup storage
- MySQL root credentials
- Downtime window approved

**Steps:**

```bash
# 1. Enable maintenance mode
docker-compose exec php php artisan down

# 2. Stop MySQL
docker-compose stop mysql

# 3. Remove corrupted data
docker volume rm mysql_data

# 4. Start MySQL with fresh volume
docker-compose up -d mysql
sleep 20

# 5. Verify MySQL is running
docker exec mysql mysqladmin ping

# 6. Restore from latest backup
bash ./scripts/backup/restore.sh mysql latest.sql.gz

# 7. Verify databases
docker exec mysql mysql -u root -p"${MYSQL_ROOT_PASSWORD}" -e "SHOW DATABASES;"

# 8. Test application connectivity
docker-compose exec php php artisan migrate:status

# 9. Disable maintenance mode
docker-compose exec php php artisan up

# 10. Monitor application logs
docker-compose logs -f php
```

**RTO**: 10-15 minutes
**RPO**: Last backup (typically 24 hours)

### Runbook 2: Redis Cache Failure

**Scenario**: Redis cache is lost or corrupted

**Prerequisites:**

- Redis backup available (optional, cache can be rebuilt)

**Steps:**

```bash
# 1. Stop Redis
docker-compose stop redis

# 2. Clear Redis data (if corrupted)
docker volume rm redis_data

# 3. Start Redis
docker-compose up -d redis
sleep 5

# 4. (Optional) Restore from backup
# If backup exists and cache rebuild is expensive
docker cp /backups/redis/dump.rdb redis:/data/dump.rdb
docker-compose restart redis

# 5. Verify Redis is running
docker exec redis redis-cli ping

# 6. Warm up cache (Laravel)
docker-compose exec php php artisan cache:clear
docker-compose exec php php artisan config:cache
docker-compose exec php php artisan route:cache

# 7. Monitor performance
docker exec redis redis-cli INFO stats
```

**RTO**: 2-5 minutes
**RPO**: 0 (cache can be rebuilt) or Last backup (1 hour with AOF)

### Runbook 3: Complete Infrastructure Failure

**Scenario**: Complete data center or cloud region failure

**Prerequisites:**

- Off-site backups in S3/MinIO
- Infrastructure as Code templates
- DNS failover configured

**Steps:**

```bash
# 1. Deploy infrastructure in DR region
# Kubernetes
kubectl apply -f k8s/helm/laravel-stack/

# Or Docker Swarm
docker stack deploy -c swarm/stack-laravel.yml myapp

# Or Docker Compose
docker-compose -f docker-compose-ha.yml up -d

# 2. Download backups from S3
aws s3 sync s3://my-backups/mysql/ ./backups/mysql/
aws s3 sync s3://my-backups/redis/ ./backups/redis/

# 3. Restore MySQL
bash ./scripts/backup/restore.sh mysql latest.sql.gz

# 4. Restore Redis (optional)
docker cp ./backups/redis/latest.rdb redis:/data/dump.rdb
docker restart redis

# 5. Update DNS to point to new infrastructure
# (Manual step or automated with Route53/CloudFlare API)

# 6. Verify application is accessible
curl https://app.example.com/health

# 7. Monitor error rates and performance
# Check Grafana dashboards
```

**RTO**: 20-30 minutes
**RPO**: Last S3 backup (typically 24 hours)

## Best Practices

### Backup

- [x] **3-2-1 Rule**: 3 copies, 2 different media, 1 off-site
- [x] **Test backups** regularly (automated CI/CD testing)
- [x] **Encrypt backups** at rest and in transit
- [x] **Monitor backup** success/failure
- [x] **Document procedures** and keep updated
- [x] **Automate everything** possible
- [x] **Version backups** with timestamps

### Restore

- [x] **Practice restores** quarterly
- [x] **Document RTO/RPO** for each component
- [x] **Maintain runbooks** for common scenarios
- [x] **Test in staging** before production restore
- [x] **Have rollback plan** if restore fails
- [x] **Verify data integrity** after restore
- [x] **Communicate** with stakeholders

## Monitoring & Alerting

### Backup Monitoring

```yaml
# Prometheus Alert Rule
groups:
  - name: backup_alerts
    rules:
      - alert: BackupFailed
        expr: backup_last_success_timestamp < (time() - 86400)
        for: 1h
        labels:
          severity: warning
        annotations:
          summary: "Backup has not succeeded in 24 hours"

      - alert: BackupMissing
        expr: absent(backup_last_success_timestamp)
        for: 2h
        labels:
          severity: critical
        annotations:
          summary: "No backup metrics found"
```

### Recovery Testing Alerts

```yaml
- alert: DRTestFailed
  expr: dr_test_last_success_timestamp < (time() - 604800)
  for: 1h
  labels:
    severity: warning
  annotations:
    summary: "DR test has not succeeded in 7 days"
```

## Additional Resources

- **Backup Scripts**: `scripts/backup/`
- **HA Configuration**: `examples/docker-compose-ha.yml`
- **CI/CD Tests**: `.gitlab-ci.yml` (disaster-recovery stage)
- **Kubernetes Guide**: `docs/KUBERNETES.md`
- **Swarm Guide**: `docs/SWARM.md`

## Support

[![Issues][issues-badge]][issues]
[![Discord][discord-badge]][discord]

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
