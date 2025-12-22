FROM mysql:8.0-debian

LABEL maintainer="Stanislas Poisson <stanislas.p@the-white-rabbits.com>"
LABEL description="Optimized MySQL 8.0 container with production configurations"

# Install additional packages for monitoring and backup tools
RUN apt-get update && apt-get install -y \
  curl \
  wget \
  procps \
  net-tools \
  iproute2 \
  xz-utils \
  && rm -rf /var/lib/apt/lists/*

# Create necessary directories
RUN mkdir -p /var/log/mysql \
  && mkdir -p /var/lib/mysql-files \
  && mkdir -p /docker-entrypoint-initdb.d \
  && mkdir -p /etc/mysql/conf.d \
  && mkdir -p /scripts \
  && mkdir -p /backups

# Copy configuration files
COPY --chown=root:root config/my.cnf /etc/mysql/conf.d/my.cnf
COPY --chown=root:root config/mysql.dev.cnf /etc/mysql/conf.d/mysql.dev.cnf

# Fix config file permissions (MySQL refuses world-writable configs)
RUN chmod 644 /etc/mysql/conf.d/*.cnf

# Copy scripts
COPY --chown=mysql:mysql scripts/entrypoint.sh /scripts/entrypoint.sh
COPY --chown=mysql:mysql scripts/healthcheck.sh /scripts/healthcheck.sh
COPY --chown=mysql:mysql scripts/backup.sh /scripts/backup.sh
COPY --chown=mysql:mysql scripts/restore.sh /scripts/restore.sh

# Make scripts executable
RUN chmod +x /scripts/*.sh

# Set proper ownership (scripts already chowned via COPY --chown)
RUN chown -R mysql:mysql /var/log/mysql \
  && chown -R mysql:mysql /var/lib/mysql-files \
  && chown -R mysql:mysql /backups

# Health check configuration
# CI mode: simplified ping-only check for faster CI/CD feedback
# Production: comprehensive health monitoring after initialization
HEALTHCHECK --interval=15s --timeout=10s --start-period=120s --retries=2 \
  CMD ["sh", "-c", "CI=true /scripts/healthcheck.sh"]

# Set environment variables
ENV MYSQL_ROOT_PASSWORD_FILE=/run/secrets/mysql_root_password
ENV MYSQL_USER_FILE=/run/secrets/mysql_user
ENV MYSQL_PASSWORD_FILE=/run/secrets/mysql_password
ENV MYSQL_CHARSET=utf8mb4
ENV MYSQL_COLLATION=utf8mb4_0900_ai_ci

# Expose MySQL port
EXPOSE 3306

# Set custom entrypoint
ENTRYPOINT ["/scripts/entrypoint.sh"]
CMD ["mysqld"]
