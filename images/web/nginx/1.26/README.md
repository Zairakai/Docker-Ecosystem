# Nginx 1.26 - Optimized Reverse Proxy for Laravel


<!-- Image Stats -->
[![Docker Pulls][pulls-badge]][dockerhub]
[![Image Size][size-badge]][dockerhub]

<!-- CI/CD & Quality -->
[![Pipeline][pipeline-badge]][pipeline]
[![License][license-badge]][license]

<!-- Community -->
[![Discord][discord-badge]][discord]
Production-ready Nginx 1.26 optimized for Laravel applications with HTTP/3 support.

Part of the [Zairakai Docker Ecosystem](https://gitlab.com/zairakai/docker-ecosystem).

---

## Quick Start

```bash
docker pull zairakai/nginx:1.26

docker run -d \
  -p 80:80 \
  -v ./public:/var/www/html/public \
  zairakai/nginx:1.26
```

### Docker Compose with Laravel

```yaml
services:
  nginx:
    image: zairakai/nginx:1.26
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./:/var/www/html
      - ./nginx.conf:/etc/nginx/conf.d/default.conf
    depends_on:
      - php
    networks:
      - laravel

  php:
    image: zairakai/php:8.3-prod
    volumes:
      - ./:/var/www/html
    networks:
      - laravel

networks:
  laravel:
```

---

## Key Features

- **HTTP/3 Support**: Latest protocol with QUIC
- **Laravel Optimized**: Pre-configured for Laravel routing
- **Gzip Compression**: Automatic asset compression
- **FastCGI Caching**: PHP-FPM cache integration
- **Security Headers**: HSTS, CSP, X-Frame-Options
- **Static Asset Optimization**: Long-term caching for assets

---

## Configuration Examples

### Basic Laravel Configuration

```nginx
server {
    listen 80;
    server_name localhost;
    root /var/www/html/public;
    index index.php index.html;

    location / {
        try_files $uri $uri/ /index.php?$query_string;
    }

    location ~ \.php$ {
        fastcgi_pass php:9000;
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        include fastcgi_params;
    }

    location ~ /\.(?!well-known).* {
        deny all;
    }
}
```

### Laravel + Vite (Hybrid Mode)

```nginx
server {
    # ... basic config ...

    # Proxy Vite dev server in development
    location ~ ^/(resources|@vite|@id|node_modules) {
        proxy_pass http://frontend:5173;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
    }
}
```

Full examples: [Nginx Configuration Examples](https://gitlab.com/zairakai/docker-ecosystem/-/tree/main/examples/nginx)

---

## Testing Modes

This ecosystem supports 3 testing architectures:

| Mode | Description | Use Case |
|------|-------------|----------|
| **Blade Only** | Traditional SSR | Simple apps, SEO-critical |
| **SPA Only** | Decoupled frontend | Mobile apps, PWA |
| **Hybrid** | Laravel + Vite | Modern full-stack (recommended) |

Documentation: [Testing Modes Guide](https://gitlab.com/zairakai/docker-ecosystem/-/blob/main/docs/TESTING_MODES.md)

---

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `NGINX_HOST` | `localhost` | Server name |
| `NGINX_ROOT` | `/var/www/html/public` | Document root |
| `NGINX_PHP_FPM` | `php:9000` | PHP-FPM upstream |

---

## SSL/TLS Configuration

```yaml
services:
  nginx:
    image: zairakai/nginx:1.26
    volumes:
      - ./ssl/cert.pem:/etc/nginx/ssl/cert.pem
      - ./ssl/key.pem:/etc/nginx/ssl/key.pem
      - ./nginx-ssl.conf:/etc/nginx/conf.d/default.conf
    ports:
      - "443:443"
```

---

## Performance Tuning

Included optimizations:
- **Gzip Level 6**: Balanced compression
- **Client Body Buffer**: 128k for uploads
- **FastCGI Buffers**: Optimized for PHP responses
- **Keepalive**: 65s timeout
- **Worker Connections**: 1024 per worker

---

## Related Images

- [zairakai/php](https://hub.docker.com/r/zairakai/php) - PHP 8.3 FPM backend
- [zairakai/node](https://hub.docker.com/r/zairakai/node) - Node.js for Vite
- [zairakai/mysql](https://hub.docker.com/r/zairakai/mysql) - MySQL database
- [zairakai/redis](https://hub.docker.com/r/zairakai/redis) - Redis cache

**Documentation**: https://gitlab.com/zairakai/docker-ecosystem


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

[![Discord][discord-badge]][discord]
[![Issues][issues-badge]][issues]

**Need help?** Join our Discord community or report issues on GitLab.


[issues]: https://gitlab.com/zairakai/docker-ecosystem/-/issues

<!-- Badge References -->
[pulls-badge]: https://img.shields.io/docker/pulls/zairakai/nginx?logo=docker&logoColor=white
[size-badge]: https://img.shields.io/docker/image-size/zairakai/nginx/1.26?logo=docker&logoColor=white&label=size
[pipeline-badge]: https://gitlab.com/zairakai/docker-ecosystem/badges/main/pipeline.svg
[pipeline]: https://gitlab.com/zairakai/docker-ecosystem/-/pipelines
[license-badge]: https://img.shields.io/badge/license-MIT-blue.svg
[license]: https://gitlab.com/zairakai/docker-ecosystem/-/blob/main/LICENSE
[discord-badge]: https://img.shields.io/discord/1260000352699289621?logo=discord&label=Discord&color=5865F2
[discord]: https://discord.gg/MAmD5SG8Zu
[issues-badge]: https://img.shields.io/gitlab/issues/open-raw/zairakai%2Fdocker-ecosystem?logo=gitlab&label=Issues
[issues]: https://gitlab.com/zairakai/docker-ecosystem/-/issues
[dockerhub]: https://hub.docker.com/r/zairakai/nginx
