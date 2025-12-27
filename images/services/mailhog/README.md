# MailHog - Email Testing for Development

[![Docker Image Size](https://img.shields.io/docker/image-size/zairakai/mailhog)](https://hub.docker.com/r/zairakai/mailhog)
[![Docker Pulls](https://img.shields.io/docker/pulls/zairakai/mailhog)](https://hub.docker.com/r/zairakai/mailhog)

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
