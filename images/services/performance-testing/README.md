# Performance Testing - Artillery, k6, Locust

[![Docker Image Size](https://img.shields.io/docker/image-size/zairakai/performance-testing)](https://hub.docker.com/r/zairakai/performance-testing)
[![Docker Pulls](https://img.shields.io/docker/pulls/zairakai/performance-testing)](https://hub.docker.com/r/zairakai/performance-testing)

Comprehensive load and performance testing toolkit with multiple frameworks.

Part of the [Zairakai Docker Ecosystem](https://gitlab.com/zairakai/docker-ecosystem).

---

## Quick Start

```bash
docker pull zairakai/performance-testing:latest

# Run Artillery test
docker run --rm \
  -v ./load-tests:/tests \
  --network host \
  zairakai/performance-testing:latest \
  artillery run /tests/basic-load.yml
```

---

## Included Tools

| Tool | Language | Best For |
|------|----------|----------|
| **Artillery** | YAML/JS | Simple HTTP load tests |
| **k6** | JavaScript | Modern scripting, metrics |
| **Locust** | Python | Complex user behavior |

---

## Docker Compose

```yaml
services:
  load-test:
    image: zairakai/performance-testing:latest
    volumes:
      - ./load-tests:/tests
    environment:
      TARGET_URL: http://nginx
    depends_on:
      - nginx
    command: artillery run /tests/scenario.yml
```

---

## Artillery Example

```yaml
# load-tests/basic-load.yml
config:
  target: "http://localhost"
  phases:
    - duration: 60
      arrivalRate: 10
      name: Warm up
    - duration: 120
      arrivalRate: 50
      name: Sustained load

scenarios:
  - name: "Browse products"
    flow:
      - get:
          url: "/api/products"
      - think: 2
      - get:
          url: "/api/products/{{ $randomNumber(1, 100) }}"
```

Run:
```bash
docker run --rm -v ./load-tests:/tests zairakai/performance-testing \
  artillery run /tests/basic-load.yml
```

---

## k6 Example

```javascript
// load-tests/script.js
import http from 'k6/http';
import { check, sleep } from 'k6';

export const options = {
  stages: [
    { duration: '30s', target: 20 },
    { duration: '1m', target: 50 },
    { duration: '30s', target: 0 },
  ],
};

export default function () {
  const res = http.get('http://localhost/api/products');
  check(res, {
    'status is 200': (r) => r.status === 200,
    'response time < 500ms': (r) => r.timings.duration < 500,
  });
  sleep(1);
}
```

Run:
```bash
docker run --rm -v ./load-tests:/tests zairakai/performance-testing \
  k6 run /tests/script.js
```

---

## Locust Example

```python
# load-tests/locustfile.py
from locust import HttpUser, task, between

class WebsiteUser(HttpUser):
    wait_time = between(1, 3)

    @task(3)
    def browse_products(self):
        self.client.get("/api/products")

    @task(1)
    def view_product(self):
        self.client.get("/api/products/1")
```

Run:
```bash
docker run --rm -p 8089:8089 \
  -v ./load-tests:/tests \
  zairakai/performance-testing \
  locust -f /tests/locustfile.py --host=http://localhost
```

Access web UI at: **http://localhost:8089**

---

## Use Cases

- **Load Testing**: Simulate concurrent users
- **Stress Testing**: Find breaking points
- **Spike Testing**: Sudden traffic increases
- **Endurance Testing**: Long-duration stability
- **API Performance**: Measure response times

---

## CI/CD Integration

```yaml
# .gitlab-ci.yml
test:performance:
  stage: test
  image: zairakai/performance-testing:latest
  script:
    - artillery run load-tests/scenario.yml --output report.json
    - k6 run load-tests/k6-script.js
  artifacts:
    paths:
      - report.json
      - k6-report.html
```

---

## Metrics & Reporting

All tools generate detailed reports:

- **Artillery**: JSON/HTML reports with response times, errors, RPS
- **k6**: Built-in metrics, Grafana integration
- **Locust**: Web UI with real-time charts

---

**Documentation**: https://gitlab.com/zairakai/docker-ecosystem

## Support

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
[issues]: https://gitlab.com/zairakai/docker-ecosystem/-/issues
