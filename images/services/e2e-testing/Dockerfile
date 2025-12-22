FROM node:20-alpine

LABEL maintainer="Stanislas Poisson <stanislas.p@the-white-rabbits.com>"
LABEL version="e2e-testing"
LABEL description="E2E testing with Cucumber.js and Playwright for .feature files"

# Install system dependencies for Playwright
# Note: webkit2gtk is not available in Alpine Linux - WebKit browser is not supported
RUN apk add --no-cache \
  chromium \
  firefox \
  bash \
  curl \
  git \
  && rm -rf /var/cache/apk/*

# Install global testing tools
RUN npm install -g \
  @cucumber/cucumber \
  @playwright/test \
  playwright \
  allure-commandline \
  cucumber-html-reporter

# Download Playwright browsers (pre-installed system browsers)
ENV PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1
ENV PLAYWRIGHT_BROWSERS_PATH=/usr/bin

# Use existing node user (UID/GID 1000 in node:20-alpine)
# Create working directories
RUN mkdir -p /app/features /app/step-definitions /app/reports /app/screenshots \
  && chown -R node:node /app

# Copy configuration and scripts
COPY --chown=root:root config/cucumber.config.js /app/cucumber.config.js
COPY --chown=root:root config/playwright.config.js /app/playwright.config.js
COPY --chown=root:root scripts/run-tests.sh /usr/local/bin/run-tests.sh
COPY --chown=root:root scripts/healthcheck.sh /usr/local/bin/healthcheck.sh

RUN chmod +x /usr/local/bin/run-tests.sh /usr/local/bin/healthcheck.sh

# Copy example feature files
COPY --chown=node:node examples/ /app/examples/

# Health check
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD /usr/local/bin/healthcheck.sh

USER node

WORKDIR /app

EXPOSE 3000

CMD ["/usr/local/bin/run-tests.sh"]
