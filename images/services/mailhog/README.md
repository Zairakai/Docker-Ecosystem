# MailHog - Email Testing for Development


<!-- Image Stats -->
[![Docker Pulls][pulls-badge]][dockerhub]
[![Image Size][size-badge]][dockerhub]

<!-- CI/CD & Quality -->
[![Pipeline][pipeline-badge]][pipeline]
[![License][license-badge]][license]

<!-- Community -->
[![Discord][discord-badge]][discord]
Email testing tool with web UI for capturing and viewing emails sent by your Laravel application.

Part of the [Zairakai Docker Ecosystem](https://gitlab.com/zairakai/docker-ecosystem).

---

## Quick Start

```bash
docker pull zairakai/mailhog:latest

docker run -d \
  -p 1025:1025 \
  -p 8025:8025 \
  zairakai/mailhog:latest
```

Access web UI at: **http://localhost:8025**

---

## Docker Compose

```yaml
services:
  mailhog:
    image: zairakai/mailhog:latest
    ports:
      - "1025:1025"  # SMTP
      - "8025:8025"  # Web UI

  app:
    image: zairakai/php:8.3-dev
    environment:
      MAIL_MAILER: smtp
      MAIL_HOST: mailhog
      MAIL_PORT: 1025
      MAIL_ENCRYPTION: null
```

---

## Laravel Configuration

```env
MAIL_MAILER=smtp
MAIL_HOST=mailhog
MAIL_PORT=1025
MAIL_USERNAME=null
MAIL_PASSWORD=null
MAIL_ENCRYPTION=null
MAIL_FROM_ADDRESS=noreply@example.com
MAIL_FROM_NAME="${APP_NAME}"
```

---

## Features

- **Capture All Emails**: No emails escape to production
- **Web UI**: View HTML/plain text emails in browser
- **API Access**: Programmatic email retrieval
- **Search**: Find emails by recipient, subject, content
- **No Configuration**: Zero-config SMTP server

---

## API Endpoints

- `GET /api/v2/messages` - List all messages
- `GET /api/v2/messages/{id}` - Get specific message
- `DELETE /api/v2/messages/{id}` - Delete message
- `DELETE /api/v1/messages` - Delete all messages

---

## Use Cases

- **Development**: Test email workflows without sending real emails
- **CI/CD**: Verify email content in automated tests
- **Debugging**: Inspect email headers and content
- **Preview**: Show clients email templates before production

---

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
[pulls-badge]: https://img.shields.io/docker/pulls/zairakai/mailhog?logo=docker&logoColor=white
[size-badge]: https://img.shields.io/docker/image-size/zairakai/mailhog/latest?logo=docker&logoColor=white&label=size
[pipeline-badge]: https://gitlab.com/zairakai/docker-ecosystem/badges/main/pipeline.svg
[pipeline]: https://gitlab.com/zairakai/docker-ecosystem/-/pipelines
[license-badge]: https://img.shields.io/badge/license-MIT-blue.svg
[license]: https://gitlab.com/zairakai/docker-ecosystem/-/blob/main/LICENSE
[discord-badge]: https://img.shields.io/discord/1260000352699289621?logo=discord&label=Discord&color=5865F2
[discord]: https://discord.gg/MAmD5SG8Zu
[issues-badge]: https://img.shields.io/gitlab/issues/open-raw/zairakai%2Fdocker-ecosystem?logo=gitlab&label=Issues
[issues]: https://gitlab.com/zairakai/docker-ecosystem/-/issues
[dockerhub]: https://hub.docker.com/r/zairakai/mailhog
