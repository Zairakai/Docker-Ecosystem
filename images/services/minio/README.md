# MinIO - S3-Compatible Object Storage

[![Docker Image Size](https://img.shields.io/docker/image-size/zairakai/minio)](https://hub.docker.com/r/zairakai/minio)
[![Docker Pulls](https://img.shields.io/docker/pulls/zairakai/minio)](https://hub.docker.com/r/zairakai/minio)

High-performance S3-compatible object storage for development and testing.

Part of the [Zairakai Docker Ecosystem](https://gitlab.com/zairakai/docker-ecosystem).

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

**Documentation**: https://gitlab.com/zairakai/docker-ecosystem
