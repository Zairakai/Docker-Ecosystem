# ================================
# ZAIRAKAI DOCKER ECOSYSTEM
# Node.js 20 LTS Multi-Stage Dockerfile
# ================================
# Production-ready Node.js with Alpine Linux
# Stages: prod → dev → test

# ================================
# BUILD ARGUMENTS
# ================================
ARG NODE_VERSION=20
ARG USER_ID=1000
ARG GROUP_ID=1000
ARG YARN_VERSION=1.22.22
ARG PNPM_VERSION=9.10.0
ARG JEST_VERSION=29.7.0
ARG CYPRESS_VERSION=13.14.2
ARG PLAYWRIGHT_VERSION=1.47.2
ARG CUCUMBER_VERSION=10.9.0

# ================================
# STAGE 1: PRODUCTION
# ================================
FROM node:${NODE_VERSION}-alpine AS prod

# Labels
LABEL maintainer="Stanislas Poisson <stanislas.p@the-white-rabbits.com>"
LABEL version="20-prod"
LABEL description="Production-ready Node.js 20 LTS base image"
LABEL stage="prod"

# Environment variables
ENV NODE_ENV=production \
  NPM_CONFIG_CACHE=/tmp/.npm \
  NPM_CONFIG_PREFIX=/usr/local \
  NPM_CONFIG_LOGLEVEL=warn \
  NODE_OPTIONS="--max-old-space-size=512" \
  PATH=/usr/local/bin:$PATH

# Install system dependencies
RUN apk add --no-cache \
    # Core system packages
    bash \
    ca-certificates \
    tzdata \
    dumb-init \
    tini \
  # Create necessary directories
  && mkdir -p /app /tmp/.npm \
  && chown -R node:node /app /tmp/.npm \
  # Clean npm cache
  && npm cache clean --force \
  && rm -rf /tmp/* /var/cache/apk/*

# Copy configuration files (from base structure)
COPY base/config/npm.conf /etc/npmrc
COPY base/config/node.prod.json /usr/local/etc/node-config.json

# Copy scripts
COPY base/scripts/entrypoint.sh /usr/local/bin/entrypoint.sh
COPY base/scripts/healthcheck.sh /usr/local/bin/healthcheck.sh

# Set permissions
RUN chmod +x /usr/local/bin/entrypoint.sh /usr/local/bin/healthcheck.sh

# Set working directory
WORKDIR /app

# Change to node user
USER node

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
  CMD /usr/local/bin/healthcheck.sh

# Expose default port
EXPOSE 3000

# Entry point
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["node"]

# ================================
# STAGE 2: DEVELOPMENT
# ================================
FROM prod AS dev

# Labels
LABEL version="20-dev"
LABEL description="Development Node.js 20 LTS image with development tools"
LABEL stage="dev"

# Switch to root for installation
USER root

# Build arguments (must be after FROM in each stage)
ARG YARN_VERSION=1.22.22
ARG PNPM_VERSION=9.10.0

LABEL yarn.version="${YARN_VERSION}"
LABEL pnpm.version="${PNPM_VERSION}"

# Environment variables for development
ENV NODE_ENV=development \
  NPM_CONFIG_LOGLEVEL=info \
  NODE_OPTIONS="--max-old-space-size=1024 --inspect=0.0.0.0:9229" \
  DEBUG=* \
  CHOKIDAR_USEPOLLING=true

# Install development dependencies and tools
RUN apk add --no-cache \
    # Development tools
    git \
    openssh-client \
    curl \
    wget \
    unzip \
    zip \
    # Build tools for native modules
    build-base \
    python3 \
    make \
    g++ \
    # Essential utilities only
    vim \
    jq \
    # Process management
    supervisor \
  # Install Yarn (force symlinks to override existing ones)
  && curl -fsSLO "https://github.com/yarnpkg/yarn/releases/download/v${YARN_VERSION}/yarn-v${YARN_VERSION}.tar.gz" \
  && tar -xzf "yarn-v${YARN_VERSION}.tar.gz" -C /opt \
  && ln -sf "/opt/yarn-v${YARN_VERSION}/bin/yarn" /usr/local/bin/yarn \
  && ln -sf "/opt/yarn-v${YARN_VERSION}/bin/yarnpkg" /usr/local/bin/yarnpkg \
  && rm "yarn-v${YARN_VERSION}.tar.gz" \
  # Install pnpm
  && npm install -g pnpm@${PNPM_VERSION} \
  # Install essential global development tools
  && npm install -g \
    nodemon \
    pm2 \
    typescript \
    ts-node \
    vite \
  # Create development directories
  && mkdir -p /home/node/.cache /home/node/.npm /home/node/.yarn /home/node/.config \
  && chown -R node:node /home/node \
  # Set up Git configuration directory
  && mkdir -p /home/node/.gitconfig.d \
  && chown -R node:node /home/node/.gitconfig.d \
  # Clean npm cache
  && npm cache clean --force

# Copy development configuration files
COPY dev/config/node.dev.json /usr/local/etc/node-config.json

# Note: ESLint/Prettier configs should be managed per-project
# Each project has its own .eslintrc.js, .prettierrc, etc.

# Copy development scripts
COPY dev/scripts/yarn-install.sh /usr/local/bin/yarn-install.sh
COPY dev/scripts/dev-setup.sh /usr/local/bin/dev-setup.sh
COPY dev/scripts/healthcheck-dev.sh /usr/local/bin/healthcheck-dev.sh

# Set permissions for scripts
RUN chmod +x /usr/local/bin/yarn-install.sh \
  /usr/local/bin/dev-setup.sh \
  /usr/local/bin/healthcheck-dev.sh

# Switch back to node user
USER node

# Set up development environment
RUN /usr/local/bin/dev-setup.sh

# Development health check (extends base health check)
HEALTHCHECK --interval=30s --timeout=15s --start-period=10s --retries=3 \
  CMD /usr/local/bin/healthcheck-dev.sh

# Expose development ports
EXPOSE 3000 9229 24678

# Default development command
CMD ["npm", "run", "dev"]

# ================================
# STAGE 3: TESTING
# ================================
FROM dev AS test

# Labels
LABEL version="20-test"
LABEL description="Testing Node.js 20 LTS image with comprehensive testing tools including Playwright + Gerkin"
LABEL stage="test"

# Switch to root for installation
USER root

# Build arguments (must be after FROM in each stage)
ARG JEST_VERSION=29.7.0
ARG CYPRESS_VERSION=13.14.2
ARG PLAYWRIGHT_VERSION=1.47.2
ARG CUCUMBER_VERSION=10.9.0

LABEL jest.version="${JEST_VERSION}"
LABEL cypress.version="${CYPRESS_VERSION}"
LABEL playwright.version="${PLAYWRIGHT_VERSION}"
LABEL cucumber.version="${CUCUMBER_VERSION}"

# Environment variables for testing
ENV NODE_ENV=test \
  CI=true \
  DISPLAY=:99 \
  CYPRESS_CACHE_FOLDER=/home/node/.cache/cypress \
  PLAYWRIGHT_BROWSERS_PATH=/home/node/.cache/playwright

# Install testing dependencies and tools
RUN apk add --no-cache \
    # X11 and graphics for browser testing
    xvfb \
    chromium \
    firefox \
    # Additional testing utilities
    curl \
    wget \
    unzip \
    zip \
    # Process management for parallel testing
    parallel \
    # Coverage and reporting tools
    lcov \
    # Networking tools for API testing
    netcat-openbsd \
    # Performance testing tools
    stress-ng \
    # Additional Python packages for test utilities
    py3-pip \
  # Install Chromium dependencies
  && apk add --no-cache \
    nss \
    freetype \
    harfbuzz \
    ca-certificates \
    ttf-freefont \
  # Install global testing tools
  && npm install -g \
    vitest \
    @vitest/ui \
    @playwright/test@${PLAYWRIGHT_VERSION} \
    playwright@${PLAYWRIGHT_VERSION} \
    @cucumber/cucumber@${CUCUMBER_VERSION} \
    @cucumber/pretty-formatter \
    @cucumber/html-formatter \
    lighthouse \
    c8 \
    artillery \
    k6 \
  # Install Playwright browsers
  && npx playwright install chromium firefox webkit \
  # Create testing directories
  && mkdir -p \
    /home/node/.cache/cypress \
    /home/node/.cache/playwright \
    /home/node/.cache/jest \
    /home/node/test-results \
    /home/node/coverage \
  && chown -R node:node /home/node \
  # Set up Xvfb for headless testing
  && mkdir -p /tmp/.X11-unix \
  && chmod 1777 /tmp/.X11-unix \
  # Clean npm cache
  && npm cache clean --force

# Copy testing configuration files
COPY test/config/jest.config.js /usr/local/etc/jest.config.js
COPY test/config/node.test.json /usr/local/etc/node-config.json
COPY test/config/cypress.config.js /usr/local/etc/cypress.config.js

# Copy testing scripts
COPY test/scripts/healthcheck-test.sh /usr/local/bin/healthcheck-test.sh
COPY test/scripts/run-all-tests.sh /usr/local/bin/run-all-tests.sh
COPY test/scripts/run-coverage.sh /usr/local/bin/run-coverage.sh
COPY test/scripts/run-e2e.sh /usr/local/bin/run-e2e.sh
COPY test/scripts/run-performance.sh /usr/local/bin/run-performance.sh
COPY test/scripts/wait-for-services.sh /usr/local/bin/wait-for-services.sh

# Set permissions for scripts
RUN chmod +x /usr/local/bin/healthcheck-test.sh \
  /usr/local/bin/run-all-tests.sh \
  /usr/local/bin/run-coverage.sh \
  /usr/local/bin/run-e2e.sh \
  /usr/local/bin/run-performance.sh \
  /usr/local/bin/wait-for-services.sh

# Switch back to node user
USER node

# Set up Cypress and Playwright
RUN cypress verify || echo "Cypress verification skipped" \
  && npx playwright --version || echo "Playwright verification skipped"

# Testing health check (extends dev health check)
HEALTHCHECK --interval=30s --timeout=20s --start-period=15s --retries=3 \
  CMD /usr/local/bin/healthcheck-test.sh

# Expose testing ports
EXPOSE 3000 9229 24678 8080 4173

# Default testing command
CMD ["npm", "test"]
