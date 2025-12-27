# Testing Modes Architecture

[![Pipeline][pipeline-badge]][pipeline]
[![License][license-badge]][license]
[![Discord][discord-badge]][discord]
[![Issues][issues-badge]][issues]
[🏠 Home][home] > [📚 Documentation][docs] > Testing Modes Architecture

Complete guide to the three testing modes available in the Zairakai Docker Ecosystem - Blade SSR, SPA-only,
and Hybrid rendering strategies.

## Table of Contents

- [Overview](#overview)
- [Mode 1: Blade-only (Server-Side Rendering)](#mode-1-blade-only-server-side-rendering)
  - [Architecture](#architecture)
  - [Use Cases](#use-cases)
  - [Files](#files)
  - [Testing](#testing)
  - [Gherkin Example (Blade)](#gherkin-example-blade)
- [Mode 2: SPA-only (Single Page Application)](#mode-2-spa-only-single-page-application)
  - [Architecture](#architecture-1)
  - [Use Cases](#use-cases-1)
  - [Files](#files-1)
  - [Testing](#testing-1)
  - [Gherkin Example (SPA)](#gherkin-example-spa)
- [Mode 3: Hybrid (Laravel + Vite Standard)](#mode-3-hybrid-laravel--vite-standard)
  - [Architecture](#architecture-2)
  - [Build Process](#build-process)
  - [Use Cases](#use-cases-2)
  - [Files](#files-2)
  - [Testing](#testing-2)
  - [Example Blade + Vue.js Page](#example-blade--vuejs-page)
  - [Gherkin Example (Hybrid)](#gherkin-example-hybrid)
- [Switching Between Modes](#switching-between-modes)
  - [Method 1: Docker Compose Files (Recommended)](#method-1-docker-compose-files-recommended)
  - [Method 2: Environment Variables](#method-2-environment-variables)
  - [Method 3: GitLab CI Matrix (Automated)](#method-3-gitlab-ci-matrix-automated)
- [Test Organization](#test-organization)
  - [Directory Structure](#directory-structure)
- [Environment Variables](#environment-variables)
  - [E2E Testing Container](#e2e-testing-container)
  - [PHP Container](#php-container)
  - [Node Container](#node-container)
- [Performance Testing by Mode](#performance-testing-by-mode)
  - [Blade-only Performance](#blade-only-performance)
  - [SPA-only Performance](#spa-only-performance)
  - [Hybrid Performance](#hybrid-performance)
- [Best Practices](#best-practices)
  - [Blade-only Mode](#blade-only-mode)
  - [SPA-only Mode](#spa-only-mode)
  - [Hybrid Mode](#hybrid-mode)
- [Troubleshooting](#troubleshooting)
- [Summary](#summary)
- [Navigation](#navigation)

## Overview

The ecosystem supports three distinct rendering and testing strategies:

1. **Blade-only (SSR)** - Pure server-side rendering with Laravel Blade
2. **SPA-only** - Full client-side rendering with Vue.js SPA + Laravel API
3. **Hybrid** - Combined Blade SSR + Vue.js SPA sections

Each mode has its own Nginx configuration and docker-compose file for testing.

## Mode 1: Blade-only (Server-Side Rendering)

### Architecture

```txt
Browser → Nginx → PHP (Laravel) → Blade Templates → HTML Response
```

### Use Cases

- Traditional Laravel applications with Blade templates
- Server-side rendered pages without JavaScript frameworks
- HTML testing without JavaScript execution
- SEO-optimized content

### Files

- **Nginx config**: `examples/nginx-mode-blade-only.conf`
- **Docker Compose**: `examples/docker-compose-mode-blade.yml`
- **Gherkin features**: `tests/e2e/features-blade/`

### Testing

```bash
docker-compose -f examples/docker-compose-mode-blade.yml up

# E2E tests verify HTML structure without JavaScript
# Tests check server-rendered content, forms, links
```

### Gherkin Example (Blade)

```gherkin
Feature: Blade Server-Side Rendering
  Scenario: Homepage renders server-side HTML
    Given I navigate to "http://nginx/"
    When I wait for the page to load
    Then the HTML should contain "<h1>Welcome</h1>"
    And JavaScript should NOT be required for navigation
    And forms should work with standard POST requests
```

## Mode 2: SPA-only (Single Page Application)

### Architecture

```txt
Browser → Nginx → Vue.js Static Files (index.html)
Browser → Nginx /api/* → PHP (Laravel) → JSON Response
```

### Use Cases

- Modern SPA applications with Vue.js
- API-driven frontends
- Client-side routing and state management
- Progressive Web Apps (PWA)

### Files

- **Nginx config**: `examples/nginx-mode-spa-only.conf`
- **Docker Compose**: `examples/docker-compose-mode-spa.yml`
- **Gherkin features**: `tests/e2e/features-spa/`

### Testing

```bash
docker-compose -f examples/docker-compose-mode-spa.yml up

# E2E tests verify JavaScript execution and Vue.js components
# Tests wait for Vue.js hydration and client-side rendering
```

### Gherkin Example (SPA)

```gherkin
Feature: Vue.js SPA Client-Side Rendering
  Scenario: SPA loads and renders Vue.js components
    Given I navigate to "http://nginx/"
    When I wait for Vue.js to hydrate
    Then the page should contain Vue.js component "AppHeader"
    And client-side routing should be active
    And API calls to "/api/*" should return JSON
```

## Mode 3: Hybrid (Laravel + Vite Standard)

### Architecture

```txt
Browser → Nginx → PHP → Blade templates with @vite directive
                    ↓
                public/build/ (compiled Vue.js assets by Vite)
```

**Important**: In standard Laravel + Vite setup, PHP serves everything from `public/` directory. Vue.js components
are compiled by Vite into `public/build/` and served by Laravel/PHP.

### Build Process

```bash
# Step 1: Compile Vue.js assets
npm run build  # → public/build/assets/app-[hash].js

# Step 2: PHP serves compiled assets
# Blade @vite directive reads public/build/manifest.json
# Laravel generates correct URLs to compiled assets
```

### Use Cases

- Standard Laravel + Vue.js applications
- Blade pages with embedded Vue.js components
- Progressive enhancement (Blade + sprinkles of Vue.js)
- Most common real-world setup

### Files

- **Nginx config**: `examples/nginx-laravel-vite.conf`
- **Docker Compose**: `examples/docker-compose-mode-hybrid.yml`
- **Build workflow**: `examples/BUILD_WORKFLOW.md`

### Testing

```bash
# Build Vue.js assets first
docker-compose up node-build

# Then run tests with compiled assets
docker-compose up nginx php e2e-testing

# E2E tests verify:
# - Blade SSR content (immediate HTML)
# - Vue.js components (loaded from public/build/)
# - Interaction between Blade and Vue.js
```

### Example Blade + Vue.js Page

```html
<!DOCTYPE html>
<html>
<head>
    @vite(['resources/js/app.js'])
</head>
<body>
    {{-- Blade SSR --}}
    <h1>Welcome, {{ $user->name }}</h1>

    {{-- Vue.js component (compiled to public/build/) --}}
    <div id="app">
        <dashboard :user="{{ $user }}"></dashboard>
    </div>
</body>
</html>
```

### Gherkin Example (Hybrid)

```gherkin
Feature: Hybrid Rendering Strategy
  Scenario: Public pages use Blade SSR
    Given I navigate to "http://nginx/"
    Then the page should be server-rendered with Blade
    And the HTML should be complete without JavaScript

  Scenario: Dashboard uses Vue.js SPA
    Given I navigate to "http://nginx/app/dashboard"
    When I wait for Vue.js to hydrate
    Then the dashboard should be client-rendered
    And navigation should use Vue Router
    And data should load via API calls
```

## Switching Between Modes

### Method 1: Docker Compose Files (Recommended)

```bash
# Blade-only mode
docker-compose -f examples/docker-compose-mode-blade.yml up

# SPA-only mode
docker-compose -f examples/docker-compose-mode-spa.yml up

# Hybrid mode
docker-compose -f examples/docker-compose-mode-hybrid.yml up
```

### Method 2: Environment Variables

```bash
# Set test mode
export TEST_MODE=blade-ssr  # or spa-vue or hybrid

# Mount appropriate Nginx config
docker-compose up
```

### Method 3: GitLab CI Matrix (Automated)

```yaml
test:e2e:
  parallel:
    matrix:
      - TEST_MODE: [blade-ssr, spa-vue, hybrid]
  script:
    - docker-compose -f examples/docker-compose-mode-${TEST_MODE}.yml up
```

## Test Organization

### Directory Structure

```bash
tests/
├── e2e/
│   ├── features-blade/        # Gherkin for Blade SSR
│   │   ├── homepage.feature
│   │   ├── forms.feature
│   │   └── navigation.feature
│   ├── features-spa/          # Gherkin for Vue.js SPA
│   │   ├── dashboard.feature
│   │   ├── components.feature
│   │   └── routing.feature
│   ├── step-definitions/      # Shared step definitions
│   │   ├── blade-steps.js
│   │   ├── spa-steps.js
│   │   └── common-steps.js
│   └── reports/               # Test reports
└── performance/
    ├── blade-load.yml         # Artillery config for Blade
    ├── spa-load.js            # k6 config for SPA
    └── hybrid-stress.js       # Combined stress test
```

## Environment Variables

### E2E Testing Container

- `BASE_URL` - Target URL (default: `http://nginx`)
- `TEST_MODE` - Testing mode: `blade-ssr`, `spa-vue`, or `hybrid`
- `HEADLESS` - Run browser headless (default: `true`)
- `WAIT_FOR_HYDRATION` - Wait for Vue.js hydration in SPA mode (default: `false`)

### PHP Container

- `APP_MODE` - Application mode: `blade-ssr`, `api-only`, or `hybrid`
- `CORS_ALLOWED_ORIGINS` - CORS configuration for API mode

### Node Container

- `VITE_API_URL` - API endpoint for Vue.js (default: `http://nginx/api`)

## Performance Testing by Mode

### Blade-only Performance

```bash
# Artillery test for server-side rendering
TARGET_URL=http://nginx TEST_TYPE=artillery \
  docker run --rm \
  -v $(pwd)/tests/performance:/app/tests \
  registry.gitlab.com/zairakai/docker-ecosystem/services:performance-testing \
  /usr/local/bin/run-load-test.sh
```

### SPA-only Performance

```bash
# k6 test for client-side rendering
TARGET_URL=http://nginx TEST_TYPE=k6 \
  docker run --rm \
  -v $(pwd)/tests/performance:/app/tests \
  registry.gitlab.com/zairakai/docker-ecosystem/services:performance-testing \
  /usr/local/bin/run-load-test.sh
```

### Hybrid Performance

```bash
# Combined stress test
TARGET_URL=http://nginx \
  docker run --rm \
  -v $(pwd)/tests/performance:/app/tests \
  registry.gitlab.com/zairakai/docker-ecosystem/services:performance-testing \
  /usr/local/bin/run-stress-test.sh
```

## Best Practices

### Blade-only Mode

- Test HTML structure and content
- Verify form submissions (POST/GET)
- Check server-side redirects
- No JavaScript execution required
- Fast test execution

### SPA-only Mode

- Wait for Vue.js component mounting
- Test client-side routing
- Verify API JSON responses
- Check state management
- Test JavaScript interactions

### Hybrid Mode

- Separate tests for SSR and SPA sections
- Use `TEST_MODE` env var to switch context
- Test navigation between SSR and SPA
- Verify API consistency
- Test gradual migration scenarios

## Troubleshooting

**Blade tests fail with JavaScript errors:**

- Ensure `TEST_MODE=blade-ssr`
- Check Nginx config uses `nginx-mode-blade-only.conf`
- Verify no Vue.js build files are served

**SPA tests timeout waiting for content:**

- Increase `WAIT_FOR_HYDRATION` timeout
- Check Vue.js build completed successfully
- Verify API endpoints return JSON
- Check browser console for errors

**Hybrid mode routes conflict:**

- Review Nginx location priority
- Ensure `/app` routes to Vue.js
- Verify `/api` routes to PHP backend
- Check `try_files` order in Nginx config

## Summary

| Mode | Rendering | Testing Focus | Use Case |
| ---- | --------- | ------------- | -------- |
| **Blade-only** | Server-side | HTML structure, forms | Traditional Laravel apps |
| **SPA-only** | Client-side | Vue.js components, routing | Modern SPA applications |
| **Hybrid** | Both | Mixed rendering, migration | Gradual modernization |

Choose the mode that matches your application architecture and testing requirements.

## Navigation

- [← Architecture Overview][architecture]
- [📚 Documentation Index][docs]
- [Architecture Comparison →][architecture-comparison]

**Learn More:**

- **[Architecture Guide][architecture]** - System design patterns
- **[Architecture Comparison][architecture-comparison]** - Detailed mode comparison
- **[Examples][examples]** - Docker Compose configurations

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
[architecture]: ARCHITECTURE.md
[architecture-comparison]: ARCHITECTURE_COMPARISON.md
[examples]: ../examples/
