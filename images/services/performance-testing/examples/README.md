# Performance Testing Examples

[![Pipeline][pipeline-badge]][pipeline]
[![License][license-badge]][license]
[![Discord][discord-badge]][discord]
[![Issues][issues-badge]][issues]

This container provides multiple load and performance testing tools for Laravel and Vue.js applications.

## Available Tools

- **Artillery**: HTTP load testing with YAML scenarios
- **k6**: Modern load testing with JavaScript
- **Autocannon**: Fast HTTP benchmarking
- **Locust**: Python-based distributed load testing

## Usage

### Artillery Load Test

```bash
docker run --rm \
  -e TARGET_URL=http://your-app:3000 \
  -e TEST_TYPE=artillery \
  -v $(pwd)/reports:/app/reports \
  registry.gitlab.com/zairakai/docker-ecosystem/services:performance-testing \
  /usr/local/bin/run-load-test.sh
```

### k6 Load Test

```bash
docker run --rm \
  -e TARGET_URL=http://your-app:3000 \
  -e TEST_TYPE=k6 \
  -v $(pwd)/reports:/app/reports \
  registry.gitlab.com/zairakai/docker-ecosystem/services:performance-testing \
  /usr/local/bin/run-load-test.sh
```

### k6 Stress Test

```bash
docker run --rm \
  -e TARGET_URL=http://your-app:3000 \
  -v $(pwd)/reports:/app/reports \
  registry.gitlab.com/zairakai/docker-ecosystem/services:performance-testing \
  /usr/local/bin/run-stress-test.sh
```

### Autocannon Benchmark

```bash
docker run --rm \
  -e TARGET_URL=http://your-app:3000 \
  -e TEST_TYPE=autocannon \
  -v $(pwd)/reports:/app/reports \
  registry.gitlab.com/zairakai/docker-ecosystem/services:performance-testing \
  /usr/local/bin/run-load-test.sh
```

### Locust Distributed Test

```bash
docker run --rm \
  -e TARGET_URL=http://your-app:3000 \
  -e TEST_TYPE=locust \
  -v $(pwd)/reports:/app/reports \
  registry.gitlab.com/zairakai/docker-ecosystem/services:performance-testing \
  /usr/local/bin/run-load-test.sh
```

## Docker Compose Integration

```yaml

services:
  app:
    image: registry.gitlab.com/zairakai/docker-ecosystem/php:8.3-dev
    # Your app configuration

  performance-test:
    image: registry.gitlab.com/zairakai/docker-ecosystem/services:performance-testing
    environment:
      - TARGET_URL=http://app:3000
      - TEST_TYPE=k6
    volumes:
      - ./performance-reports:/app/reports
      - ./custom-tests:/app/tests
    depends_on:
      - app
```

## Custom Test Scripts

Mount your custom test scripts to `/app/tests`:

```bash
docker run --rm \
  -e TARGET_URL=http://your-app:3000 \
  -v $(pwd)/my-k6-script.js:/app/tests/custom.js \
  -v $(pwd)/reports:/app/reports \
  registry.gitlab.com/zairakai/docker-ecosystem/services:performance-testing \
  k6 run /app/tests/custom.js
```

## Reports Location

All test reports are saved to `/app/reports` inside the container.

Mount a volume to persist reports:

```bash
-v $(pwd)/reports:/app/reports
```

## Support

[![Discord][discord-badge]][discord]
[![Issues][issues-badge]][issues]

**Need help?** Join our Discord community or report issues on GitLab.

<!-- Badge References -->
[pipeline-badge]: https://gitlab.com/zairakai/docker-ecosystem/badges/main/pipeline.svg
[pipeline]: https://gitlab.com/zairakai/docker-ecosystem/-/pipelines
[license-badge]: https://img.shields.io/badge/license-MIT-blue.svg
[license]: ../../../../LICENSE
[discord-badge]: https://img.shields.io/discord/1260000352699289621?logo=discord&label=Discord&color=5865F2
[discord]: https://discord.gg/MAmD5SG8Zu
[issues-badge]: https://img.shields.io/gitlab/issues/open-raw/zairakai%2Fdocker-ecosystem?logo=gitlab&label=Issues
[issues]: https://gitlab.com/zairakai/docker-ecosystem/-/issues
