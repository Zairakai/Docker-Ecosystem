# ================================
# ZAIRAKAI DOCKER ECOSYSTEM
# PHP 8.3 Multi-Stage Dockerfile
# ================================
# Production-ready PHP FPM with Alpine Linux
# Stages: prod → dev → test

# ================================
# BUILD ARGUMENTS
# ================================
ARG PHP_VERSION=8.3
ARG COMPOSER_VERSION=2
ARG XDEBUG_VERSION=3.4.0
ARG REDIS_VERSION=6.0.2
ARG IMAGICK_VERSION=3.7.0
ARG PCOV_VERSION=1.0.11
ARG XHPROF_VERSION=2.3.9
ARG PHP_FPM_EXPORTER_VERSION=2.2.0

# ================================
# STAGE 0: COMPOSER (intermediate stage)
# ================================
FROM composer:${COMPOSER_VERSION} AS composer-bin

# ================================
# STAGE 1: PRODUCTION
# ================================
FROM php:${PHP_VERSION}-fpm-alpine AS prod

LABEL maintainer="Stanislas Poisson <stanislas.p@the-white-rabbits.com>"
LABEL version="8.3-prod"
LABEL description="Production-ready PHP 8.3 FPM with Alpine Linux"
LABEL stage="prod"

# Install system dependencies and PHP extensions
RUN apk add --no-cache \
  bash \
  freetype-dev \
  libjpeg-turbo-dev \
  libpng-dev \
  libzip-dev \
  icu-dev \
  oniguruma-dev \
  postgresql-dev \
  libxml2-dev \
  curl-dev \
  openssl-dev \
  linux-headers \
  autoconf \
  g++ \
  make \
  && docker-php-ext-configure gd --with-freetype --with-jpeg \
  && docker-php-ext-install -j$(nproc) \
  gd \
  zip \
  intl \
  mbstring \
  pdo \
  pdo_mysql \
  pdo_pgsql \
  bcmath \
  opcache \
  pcntl \
  sockets \
  curl \
  && apk del autoconf g++ make linux-headers \
  && rm -rf /var/cache/apk/*

# Install Composer
COPY --from=composer-bin /usr/bin/composer /usr/bin/composer

# Create application directory
WORKDIR /var/www/html

# Copy configuration files (from base structure)
COPY base/config/fpm.conf /usr/local/etc/php-fpm.d/zz-custom.conf
COPY base/config/opcache.ini /usr/local/etc/php/conf.d/opcache.ini
COPY base/config/php.prod.ini /usr/local/etc/php/conf.d/php.ini

# Copy scripts
COPY base/scripts/entrypoint.sh /usr/local/bin/entrypoint.sh
COPY base/scripts/healthcheck.sh /usr/local/bin/healthcheck.sh

# Make scripts executable
RUN chmod +x /usr/local/bin/entrypoint.sh /usr/local/bin/healthcheck.sh

# Create non-root user
RUN addgroup -g 1000 www && adduser -u 1000 -G www -s /bin/sh -D www

# Create runtime directories with proper ownership (BEFORE USER switch)
RUN mkdir -p /var/run/php /tmp/opcache \
  && chown -R www:www /var/run/php /tmp/opcache /var/www/html

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD /usr/local/bin/healthcheck.sh

USER www

EXPOSE 9000

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["php-fpm"]

# ================================
# STAGE 2: DEVELOPMENT
# ================================
FROM prod AS dev

LABEL version="8.3-dev"
LABEL description="Development PHP 8.3 with Xdebug and development tools"
LABEL stage="dev"

# Switch to root for installations
USER root

# Temporarily remove production PHP config that disables functions needed by PECL
# (will be overridden by dev config after extensions are installed)
RUN rm -f /usr/local/etc/php/conf.d/php.ini

# Install development tools and dependencies
RUN apk add --no-cache \
  git \
  vim \
  nano \
  curl \
  wget \
  unzip \
  sqlite \
  mariadb-client \
  postgresql-client \
  redis \
  imagemagick \
  imagemagick-dev \
  autoconf \
  g++ \
  make \
  linux-headers

# Install php-fpm-exporter for Prometheus metrics
ARG PHP_FPM_EXPORTER_VERSION=2.2.0
RUN wget -q https://github.com/hipages/php-fpm_exporter/releases/download/v${PHP_FPM_EXPORTER_VERSION}/php-fpm_exporter_${PHP_FPM_EXPORTER_VERSION}_linux_amd64 -O /usr/local/bin/php-fpm-exporter \
  && chmod +x /usr/local/bin/php-fpm-exporter

# Install Xdebug
ARG XDEBUG_VERSION=3.4.0
RUN pecl install xdebug-${XDEBUG_VERSION} \
  && docker-php-ext-enable xdebug

# Install Redis extension
ARG REDIS_VERSION=6.0.2
RUN pecl install redis-${REDIS_VERSION} \
  && docker-php-ext-enable redis

# Install imagick extension from GitHub (PECL 3.7.0 has compilation issues with PHP 8.3)
# Using master branch which has PHP 8.3 compatibility fixes
RUN git clone https://github.com/Imagick/imagick.git /tmp/imagick \
  && cd /tmp/imagick \
  && phpize \
  && ./configure \
  && make \
  && make install \
  && docker-php-ext-enable imagick \
  && rm -rf /tmp/imagick

# Clean up build dependencies
RUN apk del autoconf g++ make linux-headers \
  && rm -rf /var/cache/apk/* /tmp/pear

# Copy development configuration files (overrides production config)
COPY dev/config/php.dev.ini /usr/local/etc/php/conf.d/php-dev.ini
COPY dev/config/xdebug.ini /usr/local/etc/php/conf.d/xdebug.ini

# Copy development scripts
COPY dev/scripts/composer-install.sh /usr/local/bin/composer-install.sh
COPY dev/scripts/dev-setup.sh /usr/local/bin/dev-setup.sh
COPY dev/scripts/healthcheck-dev.sh /usr/local/bin/healthcheck-dev.sh

# Make scripts executable
RUN chmod +x /usr/local/bin/composer-install.sh \
  /usr/local/bin/dev-setup.sh \
  /usr/local/bin/healthcheck-dev.sh

# Note: Quality tools (phpstan, php-cs-fixer, etc.) should be installed
# via project composer.json for version consistency and project-specific configuration

# Add global Composer bin to PATH
ENV PATH="/home/www/.composer/vendor/bin:$PATH"

# Override health check to use development version
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD /usr/local/bin/healthcheck-dev.sh

# Create development directories
RUN mkdir -p /var/log/xdebug /var/log/php \
  && chown -R www:www /var/log/xdebug /var/log/php

# Switch back to non-root user
USER www

# Set working directory
WORKDIR /var/www/html

# Expose PHP-FPM port and Prometheus metrics port
EXPOSE 9000 9253

# Override entrypoint to include development setup
ENTRYPOINT ["/usr/local/bin/dev-setup.sh"]
CMD ["php-fpm"]

# ================================
# STAGE 3: TESTING
# ================================
FROM dev AS test

LABEL version="8.3-test"
LABEL description="Testing PHP 8.3 with coverage, profiling and testing tools"
LABEL stage="test"

# Switch to root for installations
USER root

# Install testing-specific tools and dependencies
RUN apk add --no-cache \
  autoconf \
  g++ \
  make \
  linux-headers

# Install PCOV for code coverage (faster than Xdebug for coverage)
ARG PCOV_VERSION=1.0.11
RUN pecl install pcov-${PCOV_VERSION} \
  && docker-php-ext-enable pcov

# Install XHProf for profiling
ARG XHPROF_VERSION=2.3.9
RUN pecl install xhprof-${XHPROF_VERSION} \
  && docker-php-ext-enable xhprof

# Clean up build dependencies
RUN apk del autoconf g++ make linux-headers \
  && rm -rf /var/cache/apk/* /tmp/pear

# Copy testing configuration files
COPY test/config/pcov.ini /usr/local/etc/php/conf.d/pcov.ini
COPY test/config/php.test.ini /usr/local/etc/php/conf.d/php-test.ini
COPY test/config/xhprof.ini /usr/local/etc/php/conf.d/xhprof.ini

# Copy testing scripts
COPY test/scripts/healthcheck-test.sh /usr/local/bin/healthcheck-test.sh
COPY test/scripts/run-all-tests.sh /usr/local/bin/run-all-tests.sh
COPY test/scripts/run-coverage.sh /usr/local/bin/run-coverage.sh
COPY test/scripts/run-e2e.sh /usr/local/bin/run-e2e.sh
COPY test/scripts/run-performance.sh /usr/local/bin/run-performance.sh
COPY test/scripts/wait-for-services.sh /usr/local/bin/wait-for-services.sh

# Make scripts executable
RUN chmod +x /usr/local/bin/healthcheck-test.sh \
  /usr/local/bin/run-all-tests.sh \
  /usr/local/bin/run-coverage.sh \
  /usr/local/bin/run-e2e.sh \
  /usr/local/bin/run-performance.sh \
  /usr/local/bin/wait-for-services.sh

# Note: Testing tools (phpunit, phpstan, infection, etc.) should be installed
# via project composer.json for version consistency and project-specific configuration.
# Each project manages its own test dependencies and versions.
#
# Example project composer.json devDependencies:
#   "phpunit/phpunit": "^10.0"
#   "phpstan/phpstan": "^1.10"
#   "infection/infection": "^0.27"
#   "phpunit/php-code-coverage": "^10.0"
#
# This allows:
# - Version pinning per project
# - Project-specific configurations (phpunit.xml, phpstan.neon)
# - No version conflicts between projects
#
# E2E testing with browsers is handled by the dedicated e2e-testing service
# This stage focuses on PHP-specific testing (unit, integration, coverage, mutation)

# Override health check to use testing version
HEALTHCHECK --interval=45s --timeout=10s --start-period=15s --retries=3 \
  CMD /usr/local/bin/healthcheck-test.sh

# Create testing directories
RUN mkdir -p \
  /var/log/testing \
  /var/log/coverage \
  /var/log/profiling \
  /var/log/performance \
  /tmp/test-results \
  /tmp/coverage-reports \
  /tmp/profiling-data \
  && chown -R www:www \
  /var/log/testing \
  /var/log/coverage \
  /var/log/profiling \
  /var/log/performance \
  /tmp/test-results \
  /tmp/coverage-reports \
  /tmp/profiling-data

# Set testing environment variables
ENV TESTING_MODE=true
ENV PCOV_ENABLED=true
ENV XHPROF_ENABLED=false

# Switch back to non-root user
USER www

# Set working directory
WORKDIR /var/www/html

# Use development entrypoint (which includes base setup)
ENTRYPOINT []
CMD ["php-fpm"]
