FROM nginx:1.26-alpine

# Install necessary packages for SSL, envsubst, and additional tools
RUN apk add --no-cache \
  openssl \
  gettext \
  curl \
  ca-certificates \
  bash \
  tzdata \
  logrotate

# Ensure nginx user and group exist with correct IDs (usually pre-created in official nginx image)
RUN if ! getent group nginx > /dev/null 2>&1; then \
    addgroup -g 101 -S nginx; \
  fi && \
  if ! id -u nginx > /dev/null 2>&1; then \
    adduser -S -D -H -u 101 -h /var/cache/nginx -s /sbin/nologin -G nginx -g nginx nginx; \
  fi

# Create necessary directories
RUN mkdir -p /var/cache/nginx/client_temp \
  /var/cache/nginx/proxy_temp \
  /var/cache/nginx/fastcgi_temp \
  /var/cache/nginx/uwsgi_temp \
  /var/cache/nginx/scgi_temp \
  /var/log/nginx \
  /etc/nginx/ssl \
  /etc/nginx/templates \
  /docker-entrypoint.d

# Set proper permissions
RUN chown -R nginx:nginx /var/cache/nginx /var/log/nginx /etc/nginx/ssl

# Copy configuration files
COPY config/nginx.conf /etc/nginx/nginx.conf
COPY config/default.conf /etc/nginx/conf.d/default.conf
COPY config/ssl.conf /etc/nginx/conf.d/ssl.conf
COPY config/security.conf /etc/nginx/conf.d/security.conf

# Copy scripts
COPY scripts/entrypoint.sh /docker-entrypoint.sh
COPY scripts/healthcheck.sh /usr/local/bin/healthcheck.sh
COPY scripts/reload.sh /usr/local/bin/reload.sh
COPY scripts/ssl-setup.sh /usr/local/bin/ssl-setup.sh

# Make scripts executable
RUN chmod +x /docker-entrypoint.sh \
  /usr/local/bin/healthcheck.sh \
  /usr/local/bin/reload.sh \
  /usr/local/bin/ssl-setup.sh

# Set default environment variables for upstream services
ENV PHP_FPM_HOST=php \
  PHP_FPM_PORT=9000 \
  API_HOST=api \
  API_PORT=8080

# Set default environment variables for SSL
ENV SSL_CERTIFICATE=/etc/nginx/ssl/server.crt \
  SSL_CERTIFICATE_KEY=/etc/nginx/ssl/server.key \
  SSL_TRUSTED_CERTIFICATE=/etc/nginx/ssl/ca-bundle.crt

# Set up logrotate for nginx logs
RUN echo '/var/log/nginx/*.log {\
  daily\
  missingok\
  rotate 52\
  compress\
  delaycompress\
  notifempty\
  create 0644 nginx nginx\
  postrotate\
    if [ -f /var/run/nginx.pid ]; then\
      kill -USR1 `cat /var/run/nginx.pid`\
    fi\
  endscript\
}' > /etc/logrotate.d/nginx

# Expose ports
EXPOSE 80 443

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
  CMD /usr/local/bin/healthcheck.sh

# Use custom entrypoint
ENTRYPOINT ["/docker-entrypoint.sh"]

# Default command
CMD ["nginx", "-g", "daemon off;"]
