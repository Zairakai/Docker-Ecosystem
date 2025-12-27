# Monitoring & Observability

[![Pipeline][pipeline-badge]][pipeline]
[![License][license-badge]][license]
[![Discord][discord-badge]][discord]
[![Issues][issues-badge]][issues]
[🏠 Home][home] > [📚 Documentation][docs] > Monitoring & Observability

This document describes how to monitor the Zairakai Docker Ecosystem using Prometheus metrics, structured
logging, and distributed tracing.

## Table of Contents

- [Prometheus Metrics](#prometheus-metrics)
  - [PHP-FPM Metrics](#php-fpm-metrics)
  - [Node.js Metrics](#nodejs-metrics)
- [Structured Logging](#structured-logging)
  - [PHP (Laravel)](#php-laravel)
  - [Node.js (Winston)](#nodejs-winston)
  - [Log Aggregation Integration](#log-aggregation-integration)
- [Distributed Tracing (OpenTelemetry)](#distributed-tracing-opentelemetry)
  - [Architecture Overview](#architecture-overview)
  - [PHP (Laravel) Setup](#php-laravel-setup)
  - [Node.js Setup](#nodejs-setup)
  - [OpenTelemetry Collector Setup](#opentelemetry-collector-setup)
  - [Docker Compose Example](#docker-compose-example)
  - [Trace Context Propagation](#trace-context-propagation)
- [Integration Examples](#integration-examples)
  - [Complete Stack with Monitoring](#complete-stack-with-monitoring)
  - [Alert Rules Example](#alert-rules-example)

## Prometheus Metrics

The Zairakai Docker images expose Prometheus-compatible metrics for monitoring application performance and health.

### PHP-FPM Metrics

**Available in**: `php:8.3-dev`, `php:8.3-test`

The development and testing PHP images include [php-fpm-exporter][php-fpm-exporter] to expose PHP-FPM pool
metrics in Prometheus format.

#### Exposed Metrics

| Metric | Type | Description |
| ------ | ---- | ----------- |
| `phpfpm_up` | Gauge | PHP-FPM process manager status (1=up, 0=down) |
| `phpfpm_accepted_connections_total` | Counter | Total number of accepted connections |
| `phpfpm_active_processes` | Gauge | Number of active processes |
| `phpfpm_idle_processes` | Gauge | Number of idle processes |
| `phpfpm_max_active_processes` | Gauge | Maximum number of active processes since start |
| `phpfpm_max_children_reached_total` | Counter | Number of times max children limit reached |
| `phpfpm_slow_requests_total` | Counter | Number of slow requests |
| `phpfpm_listen_queue` | Gauge | Current listen queue length |
| `phpfpm_max_listen_queue` | Gauge | Maximum listen queue length since start |

#### Configuration

##### **1. Enable PHP-FPM status page**

The PHP-FPM status page must be enabled in your pool configuration. Add to your `php-fpm.d/www.conf` or
custom pool config:

```ini
; Enable status page
pm.status_path = /status

; Enable ping page (optional)
ping.path = /ping
```

##### **2. Start php-fpm-exporter**

The exporter is available in dev and test images. Start it alongside PHP-FPM:

```bash
# Start in background
php-fpm-exporter --phpfpm.scrape-uri tcp://127.0.0.1:9000/status &

# Or with custom options
php-fpm-exporter \
  --phpfpm.scrape-uri tcp://127.0.0.1:9000/status \
  --web.listen-address :9253 \
  --web.telemetry-path /metrics \
  &
```

##### **3. Access metrics**

Metrics are exposed on port `9253` at `/metrics`:

```bash
# From within container
curl http://localhost:9253/metrics

# From host (if port mapped)
curl http://localhost:9253/metrics
```

#### Docker Compose Example

```yaml
services:
  php:
    image: registry.gitlab.com/zairakai/docker-ecosystem/php:8.3-dev
    ports:
      - "9000:9000"  # PHP-FPM
      - "9253:9253"  # Prometheus metrics
    command: >
      sh -c "
        php-fpm-exporter --phpfpm.scrape-uri tcp://127.0.0.1:9000/status &
        php-fpm
      "
    volumes:
      - ./app:/var/www/html
    environment:
      PHP_FPM_PM_STATUS_PATH: /status

  prometheus:
    image: prom/prometheus:latest
    ports:
      - "9090:9090"
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
```

#### Prometheus Configuration

```yaml
# prometheus.yml
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'php-fpm'
    static_configs:
      - targets: ['php:9253']
        labels:
          environment: 'development'
          service: 'laravel-app'
```

#### Grafana Dashboard

Import dashboard ID `14963` from [grafana.com][grafana-dashboards] for pre-built PHP-FPM visualizations,
or create custom queries:

```promql
# Active processes
phpfpm_active_processes{job="php-fpm"}

# Request rate (requests per second)
rate(phpfpm_accepted_connections_total[5m])

# Slow requests
rate(phpfpm_slow_requests_total[5m])

# Process saturation (% of max children reached)
rate(phpfpm_max_children_reached_total[5m]) > 0
```

### Node.js Metrics

**Available in**: `node:20-dev`, `node:20-test`

Node.js metrics implementation depends on your application framework:

#### Express.js with prom-client

```javascript
// Install: npm install prom-client
const client = require('prom-client');
const express = require('express');
const app = express();

// Collect default metrics (CPU, memory, event loop lag)
const register = new client.Registry();
client.collectDefaultMetrics({ register });

// Custom application metrics
const httpRequestDuration = new client.Histogram({
  name: 'http_request_duration_seconds',
  help: 'Duration of HTTP requests in seconds',
  labelNames: ['method', 'route', 'status_code'],
  registers: [register]
});

// Metrics endpoint
app.get('/metrics', async (req, res) => {
  res.set('Content-Type', register.contentType);
  res.end(await register.metrics());
});

app.listen(9090);
```

#### Prometheus Configuration

```yaml
scrape_configs:
  - job_name: 'nodejs'
    static_configs:
      - targets: ['node:9090']
        labels:
          environment: 'development'
          service: 'vue-app'
```

#### Available Default Metrics

| Metric | Type | Description |
| ------ | ---- | ----------- |
| `process_cpu_user_seconds_total` | Counter | User CPU time in seconds |
| `process_cpu_system_seconds_total` | Counter | System CPU time in seconds |
| `process_resident_memory_bytes` | Gauge | Resident memory size in bytes |
| `process_heap_bytes` | Gauge | Process heap size in bytes |
| `nodejs_eventloop_lag_seconds` | Gauge | Event loop lag in seconds |
| `nodejs_active_handles_total` | Gauge | Number of active handles |
| `nodejs_active_requests_total` | Gauge | Number of active requests |

## Structured Logging

Structured logging with JSON format enables easier parsing, searching, and analysis with log aggregation tools
like ELK, Loki, or CloudWatch.

### PHP (Laravel)

#### Configuration

##### **1. Update `config/logging.php`**

```php
<?php

use Monolog\Handler\StreamHandler;
use Monolog\Formatter\JsonFormatter;

return [
    'default' => env('LOG_CHANNEL', 'json'),

    'channels' => [
        'json' => [
            'driver' => 'monolog',
            'handler' => StreamHandler::class,
            'formatter' => JsonFormatter::class,
            'formatter_with' => [
                'includeStacktraces' => true,
            ],
            'with' => [
                'stream' => 'php://stdout',
            ],
            'level' => env('LOG_LEVEL', 'debug'),
            'processors' => [
                // Add context processors
                Monolog\Processor\PsrLogMessageProcessor::class,
                Monolog\Processor\IntrospectionProcessor::class,
                Monolog\Processor\WebProcessor::class,
                Monolog\Processor\MemoryUsageProcessor::class,
                Monolog\Processor\MemoryPeakUsageProcessor::class,
            ],
        ],

        'json_daily' => [
            'driver' => 'daily',
            'path' => storage_path('logs/laravel.log'),
            'level' => env('LOG_LEVEL', 'debug'),
            'days' => 14,
            'formatter' => JsonFormatter::class,
        ],

        'stderr' => [
            'driver' => 'monolog',
            'handler' => StreamHandler::class,
            'formatter' => JsonFormatter::class,
            'with' => [
                'stream' => 'php://stderr',
            ],
            'level' => 'error',
        ],
    ],
];
```

##### **2. Add context to logs**

```php
use Illuminate\Support\Facades\Log;

// Simple log
Log::info('User logged in', ['user_id' => $user->id]);

// With structured context
Log::info('Order created', [
    'order_id' => $order->id,
    'user_id' => $user->id,
    'total' => $order->total,
    'items_count' => $order->items->count(),
    'payment_method' => $order->payment_method,
]);

// Exception logging with context
try {
    // … code
}
catch (Exception $e) {
    Log::error(
      'Failed to process order',
      [
        'order_id' => $order->id,
        'error'    => $e->getMessage(),
        'trace'    => $e->getTraceAsString(),
      ]
    );
}
```

##### **3. Custom log processor**

Create a custom processor to add application-specific context:

```php
<?php

namespace App\Logging;

use Monolog\LogRecord;

class AppContextProcessor
{
    public function __invoke(LogRecord $record): LogRecord
    {
        $record->extra['app_name']    = config('app.name');
        $record->extra['environment'] = config('app.env');
        $record->extra['server_ip']   = request()->server('SERVER_ADDR');
        $record->extra['request_id']  = request()->header('X-Request-ID') ?? uniqid();

        if (auth()->check()) {
            $record->extra['user_id']    = auth()->id();
            $record->extra['user_email'] = auth()->user()->email;
        }

        return $record;
    }
}
```

Register in `config/logging.php`:

```php
'processors' => [
  App\Logging\AppContextProcessor::class,
],
```

##### **4. Environment variables**

```env
LOG_CHANNEL=json
LOG_LEVEL=info
LOG_STDERR_DRIVER=json
```

#### Output Example

```json
{
  "message": "User logged in",
  "context": {
    "user_id": 42
  },
  "level": 200,
  "level_name": "INFO",
  "channel": "production",
  "datetime": "2025-09-30T14:23:45.123456+00:00",
  "extra": {
    "app_name": "laravel-app",
    "environment": "production",
    "request_id": "65f3a2b4c1e8f",
    "user_id": 42,
    "user_email": "user@example.com",
    "memory_usage": "12 MB",
    "file": "/var/www/html/app/Http/Controllers/AuthController.php",
    "line": 123,
    "class": "App\\Http\\Controllers\\AuthController",
    "function": "login"
  }
}
```

### Node.js (Winston)

#### Configuration

##### **1. Install dependencies**

```bash
npm install winston winston-daily-rotate-file
```

##### **2. Create logger configuration**

Create `config/logger.js`:

```javascript
const winston = require('winston');
const DailyRotateFile = require('winston-daily-rotate-file');

// Custom format to add app context
const appContext = winston.format((info) => {
  info.app_name = process.env.APP_NAME || 'node-app';
  info.environment = process.env.NODE_ENV || 'development';
  info.hostname = require('os').hostname();
  info.pid = process.pid;
  return info;
});

// Combine formats
const logFormat = winston.format.combine(
  winston.format.timestamp({ format: 'YYYY-MM-DD HH:mm:ss.SSS' }),
  winston.format.errors({ stack: true }),
  appContext(),
  winston.format.json()
);

// Create logger instance
const logger = winston.createLogger({
  level: process.env.LOG_LEVEL || 'info',
  format: logFormat,
  defaultMeta: {
    service: process.env.SERVICE_NAME || 'api',
  },
  transports: [
    // Console output (JSON)
    new winston.transports.Console({
      format: winston.format.combine(
        winston.format.colorize({ all: false }), // Disable colors for JSON
        logFormat
      ),
    }),

    // Error logs to stderr
    new winston.transports.Console({
      level: 'error',
      format: logFormat,
      stderrLevels: ['error'],
    }),

    // Daily rotating file (optional, for persistent logs)
    new DailyRotateFile({
      filename: 'logs/app-%DATE%.log',
      datePattern: 'YYYY-MM-DD',
      maxSize: '20m',
      maxFiles: '14d',
      format: logFormat,
    }),
  ],

  // Handle exceptions and rejections
  exceptionHandlers: [
    new winston.transports.Console({ format: logFormat }),
    new DailyRotateFile({
      filename: 'logs/exceptions-%DATE%.log',
      datePattern: 'YYYY-MM-DD',
      maxFiles: '30d',
    }),
  ],
  rejectionHandlers: [
    new winston.transports.Console({ format: logFormat }),
    new DailyRotateFile({
      filename: 'logs/rejections-%DATE%.log',
      datePattern: 'YYYY-MM-DD',
      maxFiles: '30d',
    }),
  ],
});

module.exports = logger;
```

##### **3. Use in application**

```javascript
const logger = require('./config/logger');

// Simple log
logger.info('User logged in', { userId: 42 });

// With structured context
logger.info('Order created', {
  orderId: order.id,
  userId: user.id,
  total: order.total,
  itemsCount: order.items.length,
  paymentMethod: order.paymentMethod,
});

// Error logging
try {
  // … code
}
catch (error) {
  logger.error('Failed to process order', {
    orderId: order.id,
    error: error.message,
    stack: error.stack,
  });
}

// HTTP request logging (Express middleware)
app.use((req, res, next) => {
  const start = Date.now();
  res.on('finish', () => {
    logger.info('HTTP Request', {
      method: req.method,
      url: req.url,
      status: res.statusCode,
      duration: Date.now() - start,
      userAgent: req.get('user-agent'),
      ip: req.ip,
      requestId: req.headers['x-request-id'],
    });
  });
  next();
});
```

##### **4. Environment variables**

```env
NODE_ENV=production
LOG_LEVEL=info
APP_NAME=vue-app
SERVICE_NAME=frontend-api
```

#### Output Example

```json
{
  "level": "info",
  "message": "User logged in",
  "timestamp": "2025-09-30 14:23:45.123",
  "userId": 42,
  "app_name": "vue-app",
  "environment": "production",
  "hostname": "app-server-01",
  "pid": 1234,
  "service": "frontend-api"
}
```

### Log Aggregation Integration

#### Filebeat (ELK Stack)

```yaml
# filebeat.yml
filebeat.inputs:
  - type: container
    paths:
      - '/var/lib/docker/containers/*/*.log'
    json.keys_under_root: true
    json.add_error_key: true

output.elasticsearch:
  hosts: ["elasticsearch:9200"]
  index: "laravel-logs-%{+yyyy.MM.dd}"

processors:
  - add_docker_metadata: ~
  - decode_json_fields:
      fields: ["message"]
      target: ""
      overwrite_keys: true
```

#### Promtail (Loki)

```yaml
# promtail-config.yml
server:
  http_listen_port: 9080

positions:
  filename: /tmp/positions.yaml

clients:
  - url: http://loki:3100/loki/api/v1/push

scrape_configs:
  - job_name: docker
    docker_sd_configs:
      - host: unix:///var/run/docker.sock
        refresh_interval: 5s
    relabel_configs:
      - source_labels: ['__meta_docker_container_name']
        regex: '/(.*)'
        target_label: 'container'
    pipeline_stages:
      - json:
          expressions:
            level: level
            timestamp: timestamp
            message: message
```

#### Docker Compose Example

```yaml
services:
  php:
    image: registry.gitlab.com/zairakai/docker-ecosystem/php:8.3-dev
    environment:
      LOG_CHANNEL: json
      LOG_LEVEL: info
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"
        labels: "service=php,env=production"

  node:
    image: registry.gitlab.com/zairakai/docker-ecosystem/node:20-dev
    environment:
      NODE_ENV: production
      LOG_LEVEL: info
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"
        labels: "service=node,env=production"
```

## Distributed Tracing (OpenTelemetry)

OpenTelemetry provides distributed tracing capabilities to track requests across multiple services
(PHP ↔ Node.js ↔ Databases).

### Architecture Overview

```txt
┌─────────┐     HTTP      ┌─────────┐     HTTP      ┌──────────┐
│ Browser │──────────────▶│   PHP   │──────────────▶│  Node.js │
└─────────┘               │ Laravel │               │   API    │
                          └────┬────┘               └────┬─────┘
                               │                         │
                        Trace Context                Trace Context
                               │                         │
                               ▼                         ▼
                          ┌─────────────────────────────────┐
                          │   OpenTelemetry Collector       │
                          └────────────┬────────────────────┘
                                       │
                          ┌────────────┴────────────┐
                          ▼                         ▼
                    ┌──────────┐            ┌──────────┐
                    │  Jaeger  │            │  Zipkin  │
                    └──────────┘            └──────────┘
```

### PHP (Laravel) Setup

#### 1. Install OpenTelemetry Extension

##### **Option A: Add to Dockerfile (dev/test stages)**

```dockerfile
# In images/php/8.3/Dockerfile, dev stage
RUN pecl install opentelemetry-1.0.0 \
    && docker-php-ext-enable opentelemetry
```

##### **Option B: Manual installation in running container**

```bash
docker exec -u root php-container pecl install opentelemetry
docker exec -u root php-container docker-php-ext-enable opentelemetry
docker restart php-container
```

#### 2. Install PHP OpenTelemetry SDK

```bash
composer require \
    open-telemetry/sdk \
    open-telemetry/exporter-otlp \
    open-telemetry/transport-grpc \
    open-telemetry/opentelemetry-auto-laravel
```

#### 3. Configure Laravel

Create `config/opentelemetry.php`:

```php
<?php

return [
    'enabled'         => env('OTEL_ENABLED', false),
    'service_name'    => env('OTEL_SERVICE_NAME', 'laravel-app'),
    'service_version' => env('APP_VERSION', '1.0.0'),
    'exporter'        => env('OTEL_EXPORTER', 'otlp'), // otlp, jaeger, zipkin
    'endpoint'        => env('OTEL_EXPORTER_OTLP_ENDPOINT', 'http://otel-collector:4318'),
    'sampler'         => env('OTEL_TRACES_SAMPLER', 'always_on'), // always_on, always_off, traceidratio
    'sampler_arg'     => env('OTEL_TRACES_SAMPLER_ARG', 1.0),
];
```

Create service provider `app/Providers/OpenTelemetryServiceProvider.php`:

```php
<?php

namespace App\Providers;

use Illuminate\Support\ServiceProvider;
use OpenTelemetry\API\Globals;
use OpenTelemetry\API\Trace\TracerInterface;
use OpenTelemetry\Contrib\Otlp\OtlpHttpTransportFactory;
use OpenTelemetry\Contrib\Otlp\SpanExporter;
use OpenTelemetry\SDK\Trace\SpanProcessor\SimpleSpanProcessor;
use OpenTelemetry\SDK\Trace\TracerProvider;
use OpenTelemetry\SDK\Resource\ResourceInfo;
use OpenTelemetry\SDK\Resource\ResourceInfoFactory;
use OpenTelemetry\SDK\Common\Attribute\Attributes;

class OpenTelemetryServiceProvider extends ServiceProvider
{
  public function register(): void
  {
    $this->app->singleton(TracerInterface::class, function ($app) {
      if (! config('opentelemetry.enabled')) {
        return Globals::tracerProvider()->getTracer('noop');
      }

      $resource = ResourceInfoFactory::defaultResource()->merge(
        ResourceInfo::create(Attributes::create([
          'service.name'           => config('opentelemetry.service_name'),
          'service.version'        => config('opentelemetry.service_version'),
          'deployment.environment' => config('app.env'),
        ]))
      );

      $transport = (new OtlpHttpTransportFactory())->create(
        config('opentelemetry.endpoint') . '/v1/traces',
        'application/json'
      );

      $exporter      = new SpanExporter($transport);
      $spanProcessor = new SimpleSpanProcessor($exporter);

      $tracerProvider = TracerProvider::builder()
        ->addSpanProcessor($spanProcessor)
        ->setResource($resource)
        ->build();

      Globals::registerInitialTracerProvider($tracerProvider);

      return $tracerProvider->getTracer('laravel-tracer');
    });
  }

  public function boot(): void
  {
    if (config('opentelemetry.enabled')) {
      $this->registerMiddleware();
    }
  }

  protected function registerMiddleware(): void
  {
    $this->app['router']->aliasMiddleware('trace', \App\Http\Middleware\TraceMiddleware::class);
    $this->app['router']->pushMiddlewareToGroup('web', \App\Http\Middleware\TraceMiddleware::class);
    $this->app['router']->pushMiddlewareToGroup('api', \App\Http\Middleware\TraceMiddleware::class);
  }
}
```

Create middleware `app/Http/Middleware/TraceMiddleware.php`:

```php
<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use OpenTelemetry\API\Trace\TracerInterface;
use OpenTelemetry\API\Trace\SpanKind;
use OpenTelemetry\Context\Context;

class TraceMiddleware
{
  public function __construct(private TracerInterface $tracer) {}

  public function handle(Request $request, Closure $next)
  {
    $span = $this->tracer
      ->spanBuilder(sprintf('%s %s', $request->method(), $request->path()))
      ->setSpanKind(SpanKind::KIND_SERVER)
      ->startSpan();

    $span->setAttribute('http.method', $request->method());
    $span->setAttribute('http.url', $request->fullUrl());
    $span->setAttribute('http.target', $request->path());
    $span->setAttribute('http.host', $request->getHost());
    $span->setAttribute('http.scheme', $request->getScheme());
    $span->setAttribute('http.user_agent', $request->userAgent());
    $span->setAttribute('http.route', $request->route()?->uri());

    if ($user = $request->user()) {
      $span->setAttribute('enduser.id', $user->id);
    }

    $context = $span->storeInContext(Context::getCurrent());
    $scope   = $context->activate();

    try {
      $response = $next($request);

      $span->setAttribute('http.status_code', $response->getStatusCode());

      if ($response->getStatusCode() >= 400) {
        $span->setAttribute('error', true);
      }

      return $response;
    }
    catch (Throwable $e) {
      $span->recordException($e);
      $span->setAttribute('error', true);
      throw $e;
    }
    finally {
      $span->end();
      $scope->detach();
    }
  }
}
```

#### 4. Environment Variables

```env
# OpenTelemetry Configuration
OTEL_ENABLED=true
OTEL_SERVICE_NAME=laravel-app
OTEL_EXPORTER_OTLP_ENDPOINT=http://otel-collector:4318
OTEL_TRACES_SAMPLER=always_on
OTEL_TRACES_SAMPLER_ARG=1.0

# Optional: Direct Jaeger export (without collector)
# OTEL_EXPORTER_JAEGER_ENDPOINT=http://jaeger:14268/api/traces
```

#### 5. Manual Instrumentation Example

```php
use OpenTelemetry\API\Trace\TracerInterface;

class OrderService
{
  public function __construct(private TracerInterface $tracer) {}

  public function createOrder(array $data): Order
  {
    $span = $this->tracer
      ->spanBuilder('order.create')
      ->startSpan();

    try {
      $span->setAttribute('order.items_count', count($data['items']));
      $span->setAttribute('order.total', $data['total']);

      // Business logic
      $order = Order::create($data);

      $span->setAttribute('order.id', $order->id);
      $span->addEvent('order.created', ['order_id' => $order->id]);

      return $order;
    }
    catch (Exception $e) {
      $span->recordException($e);
      throw $e;
    }
    finally {
      $span->end();
    }
  }
}
```

### Node.js Setup

#### 1. Install OpenTelemetry Packages

```bash
npm install \
    @opentelemetry/api \
    @opentelemetry/sdk-node \
    @opentelemetry/auto-instrumentations-node \
    @opentelemetry/exporter-trace-otlp-http \
    @opentelemetry/resources \
    @opentelemetry/semantic-conventions
```

#### 2. Create Tracing Configuration

Create `config/tracing.js`:

```javascript
const { NodeSDK } = require('@opentelemetry/sdk-node');
const { getNodeAutoInstrumentations } = require('@opentelemetry/auto-instrumentations-node');
const { OTLPTraceExporter } = require('@opentelemetry/exporter-trace-otlp-http');
const { Resource } = require('@opentelemetry/resources');
const { SemanticResourceAttributes } = require('@opentelemetry/semantic-conventions');

const traceExporter = new OTLPTraceExporter({
  url: process.env.OTEL_EXPORTER_OTLP_ENDPOINT || 'http://otel-collector:4318/v1/traces',
});

const sdk = new NodeSDK({
  resource: new Resource({
    [SemanticResourceAttributes.SERVICE_NAME]: process.env.OTEL_SERVICE_NAME || 'node-app',
    [SemanticResourceAttributes.SERVICE_VERSION]: process.env.APP_VERSION || '1.0.0',
    [SemanticResourceAttributes.DEPLOYMENT_ENVIRONMENT]: process.env.NODE_ENV || 'development',
  }),
  traceExporter,
  instrumentations: [
    getNodeAutoInstrumentations({
      '@opentelemetry/instrumentation-http': {
        ignoreIncomingPaths: ['/health', '/metrics'],
      },
      '@opentelemetry/instrumentation-express': {},
      '@opentelemetry/instrumentation-axios': {},
      '@opentelemetry/instrumentation-mysql': {},
      '@opentelemetry/instrumentation-redis': {},
    }),
  ],
});

sdk.start();

// Graceful shutdown
process.on('SIGTERM', () => {
  sdk.shutdown()
    .then(() => console.log('Tracing terminated'))
    .catch((error) => console.log('Error terminating tracing', error))
    .finally(() => process.exit(0));
});

module.exports = sdk;
```

#### 3. Initialize in Application

##### **Option A: Require at start**

```javascript
// At the very top of your main file (index.js, app.js, server.js)
require('./config/tracing');

const express = require('express');
const app = express();
// … rest of your application
```

##### **Option B: Use Node.js `--require` flag**

```json
{
  "scripts": {
    "start": "node --require ./config/tracing.js app.js",
    "dev": "nodemon --require ./config/tracing.js app.js"
  }
}
```

#### 4. Manual Instrumentation Example

```javascript
const { trace, context } = require('@opentelemetry/api');

const tracer = trace.getTracer('order-service');

async function processOrder(orderData) {
  const span = tracer.startSpan('order.process', {
    kind: 1, // SERVER
    attributes: {
      'order.items_count': orderData.items.length,
      'order.total': orderData.total,
    },
  });

  try {
    // Wrap async operations in context
    return await context.with(trace.setSpan(context.active(), span), async () => {
      const order = await Order.create(orderData);

      span.setAttribute('order.id', order.id);
      span.addEvent('order.created', { order_id: order.id });

      // Call to PHP service with context propagation
      await notifyLaravelBackend(order);

      return order;
    });
  } catch (error) {
    span.recordException(error);
    span.setStatus({ code: 2, message: error.message }); // ERROR
    throw error;
  } finally {
    span.end();
  }
}

// HTTP client with automatic context propagation
const axios = require('axios');

async function notifyLaravelBackend(order) {
  // OpenTelemetry auto-instrumentation handles trace context propagation via HTTP headers
  await axios.post('http://php-service/api/orders/notify', {
    order_id: order.id,
  });
}
```

#### 5. Environment Variables

```env
# OpenTelemetry Configuration
OTEL_SERVICE_NAME=node-app
OTEL_EXPORTER_OTLP_ENDPOINT=http://otel-collector:4318
NODE_ENV=production
APP_VERSION=1.0.0
```

### OpenTelemetry Collector Setup

Create `otel-collector-config.yml`:

```yaml
receivers:
  otlp:
    protocols:
      grpc:
        endpoint: 0.0.0.0:4317
      http:
        endpoint: 0.0.0.0:4318

processors:
  batch:
    timeout: 10s
    send_batch_size: 1024

  memory_limiter:
    check_interval: 1s
    limit_mib: 512

  attributes:
    actions:
      - key: environment
        value: production
        action: insert

exporters:
  # Jaeger exporter
  jaeger:
    endpoint: jaeger:14250
    tls:
      insecure: true

  # Zipkin exporter
  zipkin:
    endpoint: http://zipkin:9411/api/v2/spans
    format: proto

  # Logging exporter for debugging
  logging:
    loglevel: info

service:
  pipelines:
    traces:
      receivers: [otlp]
      processors: [memory_limiter, batch, attributes]
      exporters: [jaeger, zipkin, logging]
```

### Docker Compose Example

Create `examples/compose/docker-compose-tracing.yml`:

```yaml
services:
  # PHP Laravel Application
  php:
    image: registry.gitlab.com/zairakai/docker-ecosystem/php:8.3-dev
    environment:
      OTEL_ENABLED: "true"
      OTEL_SERVICE_NAME: laravel-app
      OTEL_EXPORTER_OTLP_ENDPOINT: http://otel-collector:4318
    depends_on:
      - otel-collector

  # Node.js Application
  node:
    image: registry.gitlab.com/zairakai/docker-ecosystem/node:20-dev
    environment:
      OTEL_SERVICE_NAME: node-app
      OTEL_EXPORTER_OTLP_ENDPOINT: http://otel-collector:4318
    depends_on:
      - otel-collector

  # OpenTelemetry Collector
  otel-collector:
    image: otel/opentelemetry-collector-contrib:0.91.0
    command: ["--config=/etc/otel-collector-config.yml"]
    volumes:
      - ./otel-collector-config.yml:/etc/otel-collector-config.yml
    ports:
      - "4317:4317"   # OTLP gRPC
      - "4318:4318"   # OTLP HTTP
      - "13133:13133" # Health check
    depends_on:
      - jaeger
      - zipkin

  # Jaeger All-in-One
  jaeger:
    image: jaegertracing/all-in-one:1.52
    ports:
      - "16686:16686" # Jaeger UI
      - "14250:14250" # Jaeger gRPC
      - "14268:14268" # Jaeger HTTP
    environment:
      COLLECTOR_OTLP_ENABLED: "true"

  # Zipkin
  zipkin:
    image: openzipkin/zipkin:2.24
    ports:
      - "9411:9411"   # Zipkin UI and API

  # MySQL
  mysql:
    image: registry.gitlab.com/zairakai/docker-ecosystem/database:mysql-8.0
    environment:
      MYSQL_ROOT_PASSWORD: secret
      MYSQL_DATABASE: app

  # Redis
  redis:
    image: registry.gitlab.com/zairakai/docker-ecosystem/database:redis-7
```

#### Usage

```bash
# Start the complete tracing stack
docker compose -f examples/compose/docker-compose-tracing.yml up -d

# Access UIs
# Jaeger: http://localhost:16686
# Zipkin: http://localhost:9411

# Generate some traffic
curl http://localhost/api/orders

# View traces in Jaeger or Zipkin
```

### Trace Context Propagation

OpenTelemetry automatically propagates trace context via HTTP headers:

```txt
traceparent: 00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01
```

#### PHP → Node.js Example

```php
// PHP Laravel (automatic with middleware)
$response = Http::get('http://node-service/api/data');
// Trace context is automatically injected in headers
```

```javascript
// Node.js (automatic with auto-instrumentation)
app.get('/api/data', async (req, res) => {
  // Trace context is automatically extracted from headers
  // This span will be a child of the PHP span
  res.json({ data: 'response' });
});
```

## Integration Examples

### Complete Stack with Monitoring

```yaml
services:
  php:
    image: registry.gitlab.com/zairakai/docker-ecosystem/php:8.3-dev
    ports:
      - "9253:9253"
    command: >
      sh -c "
        php-fpm-exporter --phpfpm.scrape-uri tcp://127.0.0.1:9000/status &
        php-fpm
      "

  node:
    image: registry.gitlab.com/zairakai/docker-ecosystem/node:20-dev
    ports:
      - "9090:9090"
    environment:
      ENABLE_METRICS: "true"

  prometheus:
    image: prom/prometheus:latest
    ports:
      - "9091:9090"
    volumes:
      - ./monitoring/prometheus.yml:/etc/prometheus/prometheus.yml
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'

  grafana:
    image: grafana/grafana:latest
    ports:
      - "3000:3000"
    environment:
      GF_SECURITY_ADMIN_PASSWORD: admin
    volumes:
      - ./monitoring/grafana/datasources.yml:/etc/grafana/provisioning/datasources/datasources.yml
      - ./monitoring/grafana/dashboards.yml:/etc/grafana/provisioning/dashboards/dashboards.yml
    depends_on:
      - prometheus
```

### Alert Rules Example

```yaml
# prometheus-alerts.yml
groups:
  - name: php-fpm
    interval: 30s
    rules:
      - alert: PHPFPMHighProcessCount
        expr: phpfpm_active_processes > 50
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High PHP-FPM process count"
          description: "PHP-FPM has {{ $value }} active processes"

      - alert: PHPFPMMaxChildrenReached
        expr: rate(phpfpm_max_children_reached_total[5m]) > 0
        for: 2m
        labels:
          severity: critical
        annotations:
          summary: "PHP-FPM max children limit reached"
          description: "PHP-FPM reached max children limit, requests may be queued"
```

## Navigation

- [← Architecture Overview][architecture]
- [📚 Documentation Index][docs]
- [Kubernetes Deployment →][kubernetes]

**Learn More:**

- **[Disaster Recovery Guide][disaster-recovery]** - Backup and restore procedures
- **[Kubernetes Deployment][kubernetes]** - K8s deployment with monitoring
- **[Reference Guide][reference]** - Complete configuration reference

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
[kubernetes]: KUBERNETES.md
[disaster-recovery]: DISASTER_RECOVERY.md
[reference]: REFERENCE.md
[php-fpm-exporter]: https://github.com/hipages/php-fpm_exporter
[grafana-dashboards]: https://grafana.com/grafana/dashboards/
