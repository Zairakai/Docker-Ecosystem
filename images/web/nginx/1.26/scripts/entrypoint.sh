#!/bin/bash
set -e

# Function to log messages
log() {
  echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"
}

# Function to check if a command exists
command_exists() {
  command -v "$1" >/dev/null 2>&1
}

# Function to generate self-signed certificate if none exists
generate_ssl_certificate() {
  local ssl_dir="/etc/nginx/ssl"
  local cert_file="${ssl_dir}/server.crt"
  local key_file="${ssl_dir}/server.key"
  local ca_bundle="${ssl_dir}/ca-bundle.crt"

  if [[ ! -f "$cert_file" || ! -f "$key_file" ]]; then
    log "Generating self-signed SSL certificate…"

    mkdir -p "$ssl_dir"

    # Generate private key
    openssl genrsa -out "$key_file" 2048

    # Generate certificate
    openssl req -new -x509 -key "$key_file" -out "$cert_file" -days 365 -subj "/C=US/ST=State/L=City/O=Organization/OU=OrgUnit/CN=${SSL_COMMON_NAME:-localhost}"

    # For self-signed certificates, the CA bundle is the certificate itself
    cp "$cert_file" "$ca_bundle"

    # Set proper permissions
    chmod 600 "$key_file"
    chmod 644 "$cert_file" "$ca_bundle"
    chown nginx:nginx "$key_file" "$cert_file" "$ca_bundle"

    log "SSL certificate generated successfully"
  else
    log "SSL certificate already exists"
  fi
}

# Function to generate DH parameters
generate_dhparam() {
  local dhparam_file="/etc/nginx/ssl/dhparam.pem"

  if [[ ! -f "$dhparam_file" ]]; then
    log "Generating DH parameters (this may take a while)…"
    # Use 1024 bits for faster generation (2048 recommended for production)
    openssl dhparam -out "$dhparam_file" "${DH_PARAM_SIZE:-1024}"
    chmod 644 "$dhparam_file"
    chown nginx:nginx "$dhparam_file"
    log "DH parameters generated successfully"
  else
    log "DH parameters already exist"
  fi
}

# Function to validate nginx configuration
validate_config() {
  log "Validating nginx configuration…"
  if nginx -t; then
    log "Nginx configuration is valid"
    return 0
  else
    log "ERROR: Nginx configuration is invalid"
    return 1
  fi
}

# Function to process environment variable templates
process_templates() {
  log "Processing configuration templates…"

  # Define which environment variables to substitute
  # This prevents envsubst from replacing Nginx variables like $document_root
  local env_vars="$PHP_FPM_HOST $PHP_FPM_PORT $API_HOST $API_PORT $SSL_CERTIFICATE $SSL_CERTIFICATE_KEY $SSL_TRUSTED_CERTIFICATE"

  # Process main nginx.conf if it contains environment variables
  if grep -q "\${" /etc/nginx/nginx.conf; then
    envsubst "$env_vars" < /etc/nginx/nginx.conf > /tmp/nginx.conf && mv /tmp/nginx.conf /etc/nginx/nginx.conf
  fi

  # Process all .conf files in conf.d directory
  for conf_file in /etc/nginx/conf.d/*.conf; do
    if [[ -f "$conf_file" ]] && grep -q "\${" "$conf_file"; then
      envsubst "$env_vars" < "$conf_file" > "/tmp/$(basename "$conf_file")" && mv "/tmp/$(basename "$conf_file")" "$conf_file"
    fi
  done

  log "Configuration templates processed"
}

# Function to setup log rotation
setup_log_rotation() {
  log "Setting up log rotation…"

  # Create logrotate configuration
  cat > /etc/logrotate.d/nginx << 'EOF'
/var/log/nginx/*.log {
  daily
  missingok
  rotate 52
  compress
  delaycompress
  notifempty
  create 0644 nginx nginx
  postrotate
    if [ -f /var/run/nginx.pid ]; then
      kill -USR1 `cat /var/run/nginx.pid`
    fi
  endscript
}
EOF

  log "Log rotation configured"
}

# Function to create necessary directories
create_directories() {
  log "Creating necessary directories…"

  local dirs=(
    "/var/cache/nginx"
    "/var/log/nginx"
    "/var/www/html"
    "/etc/nginx/ssl"
    "/run/nginx"
  )

  for dir in "${dirs[@]}"; do
    mkdir -p "$dir"
    chown nginx:nginx "$dir"
  done

  log "Directories created and permissions set"
}

# Function to handle graceful shutdown
graceful_shutdown() {
  log "Received shutdown signal, stopping nginx gracefully…"
  nginx -s quit
  wait
  log "Nginx stopped gracefully"
  exit 0
}

# Main entrypoint logic
main() {
  log "Starting Nginx entrypoint…"

  # Set up signal handlers for graceful shutdown
  trap graceful_shutdown SIGTERM SIGINT

  # Create necessary directories
  create_directories

  # Process configuration templates
  process_templates

  # Setup SSL (always generate self-signed certs if they don't exist)
  # This is necessary because the HTTPS server block in default.conf is always active
  generate_ssl_certificate
  # Note: DH param generation disabled (takes too long, ECDHE ciphers don't require it)
  # generate_dhparam

  # Setup log rotation
  setup_log_rotation

  # Validate configuration
  if ! validate_config; then
    log "ERROR: Configuration validation failed, exiting…"
    exit 1
  fi

  # Run any custom initialization scripts
  if [[ -d "/docker-entrypoint.d" ]]; then
    for script in /docker-entrypoint.d/*.sh; do
      if [[ -f "$script" && -x "$script" ]]; then
        log "Running custom script: $(basename "$script")"
        "$script"
      fi
    done
  fi

  log "Nginx entrypoint completed successfully"

  # Execute the main command
  exec "$@"
}

# Handle special cases for nginx commands
if [[ "$1" == "nginx" ]]; then
  main "$@"
elif [[ "$1" == "reload" ]]; then
  exec /usr/local/bin/reload.sh
elif [[ "$1" == "ssl-setup" ]]; then
  exec /usr/local/bin/ssl-setup.sh
else
  # For any other command, just execute it
  exec "$@"
fi
