FROM node:20-alpine

LABEL maintainer="Stanislas Poisson <stanislas.p@the-white-rabbits.com>"
LABEL version="performance-testing"
LABEL description="Performance and load testing with Artillery, k6, and autocannon"

# Install system dependencies and build tools for Python packages
RUN apk add --no-cache \
  bash \
  curl \
  git \
  python3 \
  py3-pip \
  apache2-utils \
  gcc \
  python3-dev \
  musl-dev \
  linux-headers \
  && rm -rf /var/cache/apk/*

# Install k6 for load testing
RUN wget -q https://github.com/grafana/k6/releases/download/v0.49.0/k6-v0.49.0-linux-amd64.tar.gz \
  && tar -xzf k6-v0.49.0-linux-amd64.tar.gz \
  && mv k6-v0.49.0-linux-amd64/k6 /usr/local/bin/ \
  && rm -rf k6-v0.49.0-linux-amd64*

# Install Node.js performance testing tools
# Note: apache-bench is a system tool (ab), not an npm package
RUN npm install -g \
  artillery \
  autocannon \
  clinic \
  loadtest \
  && npm cache clean --force

# Install Python load testing tools
RUN pip3 install --no-cache-dir --break-system-packages \
  locust \
  pytest-benchmark

# Use existing node user (UID/GID 1000 in node:20-alpine)
# Create working directories
RUN mkdir -p /app/tests /app/reports /app/results \
  && chown -R node:node /app

# Copy configuration and scripts
COPY --chown=root:root config/artillery.yml /app/config/artillery.yml
COPY --chown=root:root config/k6-config.js /app/config/k6-config.js
COPY --chown=root:root scripts/run-load-test.sh /usr/local/bin/run-load-test.sh
COPY --chown=root:root scripts/run-stress-test.sh /usr/local/bin/run-stress-test.sh
COPY --chown=root:root scripts/healthcheck.sh /usr/local/bin/healthcheck.sh

RUN chmod +x /usr/local/bin/run-load-test.sh \
  /usr/local/bin/run-stress-test.sh \
  /usr/local/bin/healthcheck.sh

# Copy example test files
COPY --chown=node:node examples/ /app/examples/

# Health check
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD /usr/local/bin/healthcheck.sh

USER node

WORKDIR /app

EXPOSE 3000 8089

CMD ["/bin/bash"]
