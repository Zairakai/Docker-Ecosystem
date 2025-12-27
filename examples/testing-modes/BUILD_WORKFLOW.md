# Build Workflow: Laravel + Vite Assets

<!-- CI/CD & Quality -->
[![Pipeline][pipeline-badge]][pipeline]
[![License][license-badge]][license]

<!-- Community -->
[![Discord][discord-badge]][discord]
[![Issues][issues-badge]][issues]

This document explains how Laravel + Vite asset compilation works in the Docker ecosystem.

## Standard Laravel + Vite Setup

### Directory Structure

```bash
laravel-project/
├── resources/
│   ├── css/
│   │   └── app.css
│   └── js/
│       ├── app.js           # Entry point
│       ├── Components/      # Vue.js components
│       └── Pages/           # Vue.js pages
├── public/
│   ├── index.php
│   ├── build/               # Compiled assets (generated)
│   │   ├── manifest.json
│   │   ├── assets/
│   │   │   ├── app-*.js     # Hashed filenames
│   │   │   └── app-*.css
│   └── favicon.ico
├── package.json
├── vite.config.js
└── composer.json
```

### Asset Serving Modes

## Mode 1: Development (HMR - Hot Module Replacement)

### Architecture

```txt
Browser → Nginx → PHP → Blade @vite directive → Vite dev server (port 5173)
```

### Workflow

1. Start Vite dev server: `npm run dev`
2. Vite runs on port 5173 with HMR enabled
3. Blade templates use `@vite(['resources/js/app.js'])`
4. Laravel generates URLs pointing to [http://localhost:5173](http://localhost:5173)
5. Browser loads assets directly from Vite dev server
6. Hot Module Replacement updates code without page reload

### Docker Compose

```bash
# Start with HMR (development profile)
docker-compose --profile development up

# Includes node-dev service with Vite dev server
```

### Blade Template

```html
<!DOCTYPE html>
<html>
<head>
    @vite(['resources/css/app.css', 'resources/js/app.js'])
</head>
<body>
    <div id="app"></div>
</body>
</html>
```

Generated HTML (dev mode):

```html
<script type="module" src="http://localhost:5173/@vite/client"></script>
<script type="module" src="http://localhost:5173/resources/js/app.js"></script>
```

## Mode 2: Production/Testing (Compiled Assets)

### Architecture

```txt
Browser → Nginx → PHP → Blade @vite directive → public/build/assets/app-*.js
```

### Workflow

1. Build assets: `npm run build`
2. Vite compiles and optimizes all assets
3. Output stored in `public/build/` with hashed filenames
4. `public/build/manifest.json` maps source to compiled files
5. Blade templates still use `@vite(['resources/js/app.js'])`
6. Laravel reads manifest.json and generates correct URLs
7. PHP serves compiled assets from `public/build/`

### Docker Compose

```bash
# Build assets first (node-build container)
docker-compose up node-build

# Then start testing stack
docker-compose up nginx php mysql redis e2e-testing
```

### Build Process

```bash
# Inside node-build container
npm install              # Install dependencies
npm run build            # Vite builds assets

# Output:
# public/build/manifest.json
# public/build/assets/app-[hash].js
# public/build/assets/app-[hash].css
```

### Blade Template (Same Code)

```blade
@vite(['resources/css/app.css', 'resources/js/app.js'])
```

Generated HTML (production mode):

```html
<link rel="stylesheet" href="/build/assets/app-abc123.css">
<script type="module" src="/build/assets/app-xyz789.js"></script>
```

## Testing Workflow

### Step 1: Build Assets

```bash
# Option A: Use docker-compose (recommended)
docker-compose up node-build

# Option B: Manual build
docker run --rm \
  -v $(pwd):/var/www/html \
  -w /var/www/html \
  registry.gitlab.com/zairakai/docker-ecosystem/node:20-test \
  sh -c "npm install && npm run build"
```

### Step 2: Verify Build

```bash
# Check manifest.json exists
ls -la public/build/manifest.json

# Check compiled assets
ls -la public/build/assets/

# Example output:
# app-abc123.js      # JavaScript bundle
# app-abc123.css     # CSS bundle
# vue-components-xyz789.js
```

### Step 3: Run Tests

```bash
# E2E tests will load compiled assets from public/build/
docker-compose up e2e-testing

# Performance tests measure real production assets
docker-compose up performance-testing
```

## Laravel Blade with Vue.js Components

### Example: Hybrid Page

```html
{{-- resources/views/dashboard.blade.php --}}
<!DOCTYPE html>
<html>
<head>
    <title>Dashboard</title>
    @vite(['resources/css/app.css', 'resources/js/app.js'])
</head>
<body>
    {{-- Blade SSR content --}}
    <header>
        <h1>Welcome, {{ $user->name }}</h1>
    </header>

    {{-- Vue.js SPA section --}}
    <div id="app">
        <dashboard-component :user="{{ $user }}"></dashboard-component>
    </div>

    {{-- More Blade SSR content --}}
    <footer>
        <p>&copy; 2025 Company</p>
    </footer>
</body>
</html>
```

### Vue.js Component

```javascript
// resources/js/Components/DashboardComponent.vue
<template>
  <div class="dashboard">
    <h2>Dashboard for {{ user.name }}</h2>
    <chart-component :data="chartData"></chart-component>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue';
import ChartComponent from './ChartComponent.vue';

const props = defineProps(['user']);
const chartData = ref([]);

onMounted(async () => {
  const response = await fetch('/api/dashboard/data');
  chartData.value = await response.json();
});
</script>
```

### app.js Entry Point

```javascript
// resources/js/app.js
import { createApp } from 'vue';
import DashboardComponent from './Components/DashboardComponent.vue';
import ChartComponent from './Components/ChartComponent.vue';

const app = createApp({});

app.component('dashboard-component', DashboardComponent);
app.component('chart-component', ChartComponent);

app.mount('#app');
```

## Asset Serving in Tests

### Gherkin Test (Hybrid Page)

```gherkin
Feature: Dashboard with Vue.js Components

  Scenario: Dashboard loads with server-rendered header
    Given I navigate to "http://nginx/dashboard"
    Then the page should contain "Welcome, John Doe"
    # Server-rendered by Blade, no JavaScript needed

  Scenario: Dashboard Vue.js component loads
    Given I navigate to "http://nginx/dashboard"
    When I wait for Vue.js component "dashboard-component" to mount
    Then the dashboard should display chart data
    And the chart should be interactive
    # Client-rendered by Vue.js from compiled assets in public/build/
```

## Nginx Configuration

### Static Asset Handling

```nginx
# Static assets (CSS, JS from public/build/)
location ~* \.(css|js|jpg|jpeg|png|gif|ico|svg|woff|woff2|ttf|eot)$ {
    expires 1y;
    add_header Cache-Control "public, immutable";
    access_log off;
    try_files $uri =404;
}

# Vite dev server proxy (DEV MODE ONLY)
location @vite {
    proxy_pass http://node:5173;
    proxy_http_version 1.1;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection 'upgrade';
}
```

## CI/CD Pipeline Integration

### GitLab CI Example

```yaml
test:e2e:
  stage: test
  script:
    # Build assets first
    - docker-compose up --exit-code-from node-build node-build

    # Verify build succeeded
    - test -f public/build/manifest.json
    - test -d public/build/assets

    # Run E2E tests with compiled assets
    - docker-compose up --exit-code-from e2e-testing e2e-testing
```

## Troubleshooting

### Assets not loading in tests

```bash
# Check if build directory exists
ls -la public/build/

# Check manifest.json
cat public/build/manifest.json

# Rebuild assets
docker-compose up --force-recreate node-build
```

### Vite dev server not accessible

```bash
# Check if Vite is running
docker-compose logs node-dev

# Check port 5173 is exposed
docker-compose ps

# Restart with dev profile
docker-compose --profile development up
```

### Wrong URLs generated by @vite

```bash
# Check APP_ENV in .env
echo $APP_ENV  # Should be 'local' for dev, 'production' for tests

# Clear Laravel config cache
docker-compose exec php php artisan config:clear
```

## Summary

| Mode | Assets Served From | Container | Use Case |
| ---- | ------------------ | --------- | -------- |
| **Development (HMR)** | Vite dev server (port 5173) | node-dev | Active development |
| **Testing** | public/build/ via PHP | node-build → php | E2E tests, CI/CD |
| **Production** | public/build/ via PHP | node-build → php | Deployed application |

**Key Point**: For tests, always use compiled assets from `public/build/`. The Vite dev server (HMR) is only for active development.

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

<!-- Reference Links -->
