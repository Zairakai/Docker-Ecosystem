# MinIO - S3-Compatible Object Storage

<!-- Image Stats -->
[![Docker Pulls][pulls-badge]][dockerhub]
[![Image Size][size-badge]][dockerhub]

<!-- CI/CD & Quality -->
[![Pipeline][pipeline-badge]][pipeline]
[![License][license-badge]][license]

<!-- Community -->
[![Discord][discord-badge]][discord]
High-performance S3-compatible object storage for development and testing.

Part of the [Zairakai Docker Ecosystem][ecosystem].

---

## Quick Start

```bash
docker pull zairakai/minio:latest

docker run -d \
  -p 9000:9000 \
  -p 9001:9001 \
  -e MINIO_ROOT_USER=minioadmin \
  -e MINIO_ROOT_PASSWORD=minioadmin \
  zairakai/minio:latest
```

Access console at: **http://localhost:9001**

---

## Docker Compose

```yaml
services:
  minio:
    image: zairakai/minio:latest
    ports:
      - "9000:9000"  # API
      - "9001:9001"  # Console
    environment:
      MINIO_ROOT_USER: minioadmin
      MINIO_ROOT_PASSWORD: minioadmin123
    volumes:
      - minio_data:/data
    command: server /data --console-address ":9001"

volumes:
  minio_data:
```

---

## Laravel Configuration

```env
FILESYSTEM_DISK=s3

AWS_ACCESS_KEY_ID=minioadmin
AWS_SECRET_ACCESS_KEY=minioadmin123
AWS_DEFAULT_REGION=us-east-1
AWS_BUCKET=laravel
AWS_ENDPOINT=http://minio:9000
AWS_USE_PATH_STYLE_ENDPOINT=true
```

Install AWS SDK:
```bash
composer require league/flysystem-aws-s3-v3 "^3.0"
```

---

## Features

- **S3 Compatible**: Drop-in replacement for AWS S3
- **High Performance**: Multi-threaded, high-throughput
- **Web Console**: Manage buckets and objects via UI
- **Encryption**: Server-side and client-side encryption
- **Versioning**: Object versioning support
- **Events**: Webhook notifications for object changes

---

## Creating Buckets

Via console (http://localhost:9001) or CLI:

```bash
docker exec minio-container mc mb /data/laravel
docker exec minio-container mc policy set download /data/laravel
```

---

## Use Cases

- **Local Development**: Test S3 uploads without AWS
- **CI/CD**: Automated testing of file storage
- **Staging**: Cost-effective staging environment
- **Backup**: Local backup storage

---

## API Compatibility

Compatible with AWS S3 SDKs:
- PHP AWS SDK
- Boto3 (Python)
- AWS CLI
- aws-sdk-js (JavaScript/Node.js)

---

**Documentation**: [Zairakai Docker Ecosystem][ecosystem]

[![Discord][discord-badge]][discord]
[![Issues][issues-badge]][issues]

**Need help?** Join our Discord community or report issues on GitLab.

<!-- Badge References -->
[pipeline-badge]: https://gitlab.com/zairakai/docker-ecosystem/badges/main/pipeline.svg
[pipeline]: https://gitlab.com/zairakai/docker-ecosystem/-/pipelines
[license-badge]: https://img.shields.io/badge/license-MIT-blue.svg
[discord-badge]: https://img.shields.io/discord/1260000352699289621?logo=discord&label=Discord&color=5865F2
[discord]: https://discord.gg/MAmD5SG8Zu
[issues-badge]: https://img.shields.io/gitlab/issues/open-raw/zairakai%2Fdocker-ecosystem?logo=gitlab&label=Issues

## Support

[![Issues][issues-badge]][issues]
[![Discord][discord-badge]][discord]

[issues]: https://gitlab.com/zairakai/docker-ecosystem/-/issues

