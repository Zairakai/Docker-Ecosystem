FROM redis:7

LABEL maintainer="Stanislas Poisson <stanislas.p@the-white-rabbits.com>"
LABEL description="Optimized Redis 7 container with production configurations"

# Install additional packages for monitoring and backup tools
RUN apt-get update && apt-get install -y \
  curl \
  wget \
  procps \
  net-tools \
  iproute2 \
  xz-utils \
  jq \
  && rm -rf /var/lib/apt/lists/*

# Create necessary directories
RUN mkdir -p /var/log/redis \
  && mkdir -p /etc/redis \
  && mkdir -p /scripts \
  && mkdir -p /backups \
  && mkdir -p /data

# Copy configuration files
COPY config/redis.conf /etc/redis/redis.conf
COPY config/redis.dev.conf /etc/redis/redis.dev.conf

# Copy scripts
COPY scripts/entrypoint.sh /scripts/entrypoint.sh
COPY scripts/healthcheck.sh /scripts/healthcheck.sh
COPY scripts/backup.sh /scripts/backup.sh
COPY scripts/restore.sh /scripts/restore.sh

# Make scripts executable
RUN chmod +x /scripts/*.sh

# Set proper ownership
RUN chown -R redis:redis /var/log/redis \
  && chown -R redis:redis /scripts \
  && chown -R redis:redis /backups \
  && chown -R redis:redis /data \
  && chown -R redis:redis /etc/redis

# Health check configuration
# CI mode: simplified ping-only check for faster CI/CD feedback
# Production: comprehensive health monitoring
HEALTHCHECK --interval=15s --timeout=10s --start-period=60s --retries=2 \
  CMD ["sh", "-c", "CI=true /scripts/healthcheck.sh"]

# Set environment variables
ENV REDIS_PASSWORD_FILE=/run/secrets/redis_password
ENV REDIS_CONFIG_FILE=/etc/redis/redis.conf
ENV REDIS_LOG_LEVEL=notice
ENV REDIS_MAXMEMORY=512mb
ENV REDIS_MAXMEMORY_POLICY=allkeys-lru

# Expose Redis port
EXPOSE 6379

# Set custom entrypoint
ENTRYPOINT ["/scripts/entrypoint.sh"]
CMD ["redis-server"]
