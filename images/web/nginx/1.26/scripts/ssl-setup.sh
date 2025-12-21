#!/bin/bash

# SSL Certificate Management Script for Nginx
# This script handles SSL certificate generation, installation, and management

set -e

# Configuration
SSL_DIR="/etc/nginx/ssl"
CERT_FILE="${SSL_DIR}/server.crt"
KEY_FILE="${SSL_DIR}/server.key"
CSR_FILE="${SSL_DIR}/server.csr"
DHPARAM_FILE="${SSL_DIR}/dhparam.pem"
CA_BUNDLE_FILE="${SSL_DIR}/ca-bundle.crt"

# Default values
DEFAULT_COUNTRY="US"
DEFAULT_STATE="State"
DEFAULT_CITY="City"
DEFAULT_ORG="Organization"
DEFAULT_OU="IT Department"
DEFAULT_CN="${SSL_COMMON_NAME:-localhost}"
DEFAULT_EMAIL="admin@${DEFAULT_CN}"

# Certificate validity period (days)
CERT_VALIDITY="${CERT_VALIDITY:-365}"
DHPARAM_SIZE="${DHPARAM_SIZE:-2048}"

# Function to log messages
log() {
  echo "[SSL-SETUP] $(date +'%Y-%m-%d %H:%M:%S') $1"
}

# Function to create SSL directory
create_ssl_directory() {
  log "Creating SSL directory: $SSL_DIR"
  mkdir -p "$SSL_DIR"
  chmod 700 "$SSL_DIR"
  chown nginx:nginx "$SSL_DIR"
}

# Function to generate private key
generate_private_key() {
  local key_size="${KEY_SIZE:-2048}"

  log "Generating private key (${key_size} bits)…"

  openssl genrsa -out "$KEY_FILE" "$key_size"

  # Set proper permissions
  chmod 600 "$KEY_FILE"
  chown nginx:nginx "$KEY_FILE"

  log "Private key generated: $KEY_FILE"
}

# Function to generate certificate signing request
generate_csr() {
  local country="${SSL_COUNTRY:-$DEFAULT_COUNTRY}"
  local state="${SSL_STATE:-$DEFAULT_STATE}"
  local city="${SSL_CITY:-$DEFAULT_CITY}"
  local org="${SSL_ORG:-$DEFAULT_ORG}"
  local ou="${SSL_OU:-$DEFAULT_OU}"
  local cn="${SSL_CN:-$DEFAULT_CN}"
  local email="${SSL_EMAIL:-$DEFAULT_EMAIL}"

  log "Generating Certificate Signing Request…"

  # Create subject string
  local subject="/C=${country}/ST=${state}/L=${city}/O=${org}/OU=${ou}/CN=${cn}/emailAddress=${email}"

  # Generate CSR
  openssl req -new -key "$KEY_FILE" -out "$CSR_FILE" -subj "$subject"

  # Set proper permissions
  chmod 644 "$CSR_FILE"
  chown nginx:nginx "$CSR_FILE"

  log "CSR generated: $CSR_FILE"
  log "Subject: $subject"
}

# Function to generate self-signed certificate
generate_self_signed() {
  local country="${SSL_COUNTRY:-$DEFAULT_COUNTRY}"
  local state="${SSL_STATE:-$DEFAULT_STATE}"
  local city="${SSL_CITY:-$DEFAULT_CITY}"
  local org="${SSL_ORG:-$DEFAULT_ORG}"
  local ou="${SSL_OU:-$DEFAULT_OU}"
  local cn="${SSL_CN:-$DEFAULT_CN}"
  local email="${SSL_EMAIL:-$DEFAULT_EMAIL}"

  log "Generating self-signed certificate (valid for ${CERT_VALIDITY} days)…"

  # Create subject string
  local subject="/C=${country}/ST=${state}/L=${city}/O=${org}/OU=${ou}/CN=${cn}/emailAddress=${email}"

  # Create extensions file for SAN
  local ext_file="/tmp/ssl_extensions.cnf"
  cat > "$ext_file" << EOF
[req]
distinguished_name = req_distinguished_name
req_extensions = v3_req
prompt = no

[req_distinguished_name]
C = ${country}
ST = ${state}
L = ${city}
O = ${org}
OU = ${ou}
CN = ${cn}
emailAddress = ${email}

[v3_req]
keyUsage = keyEncipherment, dataEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names

[alt_names]
DNS.1 = ${cn}
DNS.2 = localhost
DNS.3 = *.${cn}
IP.1 = 127.0.0.1
IP.2 = ::1
EOF

  # Generate self-signed certificate
  openssl req -new -x509 \
    -key "$KEY_FILE" \
    -out "$CERT_FILE" \
    -days "$CERT_VALIDITY" \
    -config "$ext_file" \
    -extensions v3_req

  # Clean up extensions file
  rm -f "$ext_file"

  # Set proper permissions
  chmod 644 "$CERT_FILE"
  chown nginx:nginx "$CERT_FILE"

  log "Self-signed certificate generated: $CERT_FILE"
}

# Function to generate DH parameters
generate_dhparam() {
  if [[ -f "$DHPARAM_FILE" ]]; then
    log "DH parameters already exist: $DHPARAM_FILE"
    return 0
  fi

  log "Generating DH parameters (${DHPARAM_SIZE} bits) - this may take several minutes…"

  openssl dhparam -out "$DHPARAM_FILE" "$DHPARAM_SIZE"

  # Set proper permissions
  chmod 644 "$DHPARAM_FILE"
  chown nginx:nginx "$DHPARAM_FILE"

  log "DH parameters generated: $DHPARAM_FILE"
}

# Function to install certificate from files
install_certificate() {
  local cert_source="$1"
  local key_source="$2"
  local ca_bundle_source="$3"

  if [[ ! -f "$cert_source" ]]; then
    log "ERROR: Certificate file not found: $cert_source"
    return 1
  fi

  if [[ ! -f "$key_source" ]]; then
    log "ERROR: Private key file not found: $key_source"
    return 1
  fi

  log "Installing SSL certificate from external files…"

  # Copy certificate
  cp "$cert_source" "$CERT_FILE"
  chmod 644 "$CERT_FILE"
  chown nginx:nginx "$CERT_FILE"

  # Copy private key
  cp "$key_source" "$KEY_FILE"
  chmod 600 "$KEY_FILE"
  chown nginx:nginx "$KEY_FILE"

  # Copy CA bundle if provided
  if [[ -n "$ca_bundle_source" && -f "$ca_bundle_source" ]]; then
    cp "$ca_bundle_source" "$CA_BUNDLE_FILE"
    chmod 644 "$CA_BUNDLE_FILE"
    chown nginx:nginx "$CA_BUNDLE_FILE"
    log "CA bundle installed: $CA_BUNDLE_FILE"
  fi

  log "Certificate installation completed"
}

# Function to validate certificate and key
validate_certificate() {
  log "Validating SSL certificate and private key…"

  if [[ ! -f "$CERT_FILE" ]]; then
    log "ERROR: Certificate file not found: $CERT_FILE"
    return 1
  fi

  if [[ ! -f "$KEY_FILE" ]]; then
    log "ERROR: Private key file not found: $KEY_FILE"
    return 1
  fi

  # Check if certificate is valid
  if ! openssl x509 -in "$CERT_FILE" -noout -text >/dev/null 2>&1; then
    log "ERROR: Invalid certificate file"
    return 1
  fi

  # Check if private key is valid
  if ! openssl rsa -in "$KEY_FILE" -check -noout >/dev/null 2>&1; then
      log "ERROR: Invalid private key file"
      return 1
  fi

  # Check if certificate and key match
  local cert_modulus
  cert_modulus=$(openssl x509 -noout -modulus -in "$CERT_FILE" | openssl md5)
  local key_modulus
  key_modulus=$(openssl rsa -noout -modulus -in "$KEY_FILE" | openssl md5)

  if [[ "$cert_modulus" != "$key_modulus" ]]; then
    log "ERROR: Certificate and private key do not match"
    return 1
  fi

  # Check certificate expiration
  local expiry_date
  expiry_date=$(openssl x509 -in "$CERT_FILE" -noout -enddate | cut -d= -f2)
  local expiry_epoch
  expiry_epoch=$(date -d "$expiry_date" +%s)
  local current_epoch
  current_epoch=$(date +%s)
  local days_until_expiry
  days_until_expiry=$(( (expiry_epoch - current_epoch) / 86400 ))

  if [[ $days_until_expiry -lt 0 ]]; then
    log "ERROR: Certificate has expired"
    return 1
  elif [[ $days_until_expiry -lt 30 ]]; then
    log "WARNING: Certificate expires in $days_until_expiry days"
  else
    log "Certificate is valid and expires in $days_until_expiry days"
  fi

  log "Certificate validation successful"
  return 0
}

# Function to show certificate information
show_certificate_info() {
  if [[ ! -f "$CERT_FILE" ]]; then
    log "No certificate found at: $CERT_FILE"
    return 1
  fi

  log "Certificate information:"
  echo "----------------------------------------"

  # Basic certificate info
  openssl x509 -in "$CERT_FILE" -noout -text | grep -A 1 "Subject:\|Issuer:\|Not Before:\|Not After:\|DNS:\|IP Address:"

  echo "----------------------------------------"

  # Certificate fingerprints
  echo "SHA1 Fingerprint:"
  openssl x509 -in "$CERT_FILE" -noout -fingerprint -sha1

  echo "SHA256 Fingerprint:"
  openssl x509 -in "$CERT_FILE" -noout -fingerprint -sha256

  echo "----------------------------------------"
}

# Function to backup existing certificates
backup_certificates() {
  local backup_dir
  backup_dir="/tmp/ssl-backup-$(date +%Y%m%d_%H%M%S)"

  if [[ -f "$CERT_FILE" || -f "$KEY_FILE" ]]; then
    log "Creating backup of existing certificates…"

    mkdir -p "$backup_dir"

    [[ -f "$CERT_FILE" ]] && cp "$CERT_FILE" "$backup_dir/"
    [[ -f "$KEY_FILE" ]] && cp "$KEY_FILE" "$backup_dir/"
    [[ -f "$CSR_FILE" ]] && cp "$CSR_FILE" "$backup_dir/"
    [[ -f "$DHPARAM_FILE" ]] && cp "$DHPARAM_FILE" "$backup_dir/"
    [[ -f "$CA_BUNDLE_FILE" ]] && cp "$CA_BUNDLE_FILE" "$backup_dir/"

    log "Certificates backed up to: $backup_dir"
  fi
}

# Function to clean up SSL files
cleanup_ssl() {
  log "Cleaning up SSL files…"

  rm -f "$CERT_FILE" "$KEY_FILE" "$CSR_FILE" "$CA_BUNDLE_FILE"

  log "SSL files cleaned up"
}

# Function to setup complete SSL configuration
setup_ssl() {
  log "Setting up complete SSL configuration…"

  # Create SSL directory
  create_ssl_directory

  # Backup existing certificates
  backup_certificates

  # Generate private key
  generate_private_key

  # Generate self-signed certificate
  generate_self_signed

  # Generate DH parameters
  generate_dhparam

  # Validate the setup
  if validate_certificate; then
    log "SSL setup completed successfully"
    show_certificate_info
    return 0
  else
    log "ERROR: SSL setup validation failed"
    return 1
  fi
}

# Main script logic
main() {
  case "${1:-setup}" in
    "setup"|"")
      setup_ssl
      ;;
    "generate-key")
      create_ssl_directory
      generate_private_key
      ;;
    "generate-csr")
      create_ssl_directory
      [[ ! -f "$KEY_FILE" ]] && generate_private_key
      generate_csr
      ;;
    "generate-self-signed")
      create_ssl_directory
      [[ ! -f "$KEY_FILE" ]] && generate_private_key
      generate_self_signed
      ;;
    "generate-dhparam")
      create_ssl_directory
      generate_dhparam
      ;;
    "install")
      if [[ $# -lt 3 ]]; then
        echo "Usage: $0 install <certificate_file> <private_key_file> [ca_bundle_file]"
        exit 1
      fi
      create_ssl_directory
      install_certificate "$2" "$3" "$4"
      ;;
    "validate")
      validate_certificate
      ;;
    "info")
      show_certificate_info
      ;;
    "backup")
      backup_certificates
      ;;
    "cleanup")
      cleanup_ssl
      ;;
    *)
      echo "Usage: $0 {setup|generate-key|generate-csr|generate-self-signed|generate-dhparam|install|validate|info|backup|cleanup}"
      echo ""
      echo "Commands:"
      echo "  setup              - Complete SSL setup with self-signed certificate (default)"
      echo "  generate-key       - Generate private key only"
      echo "  generate-csr       - Generate certificate signing request"
      echo "  generate-self-signed - Generate self-signed certificate"
      echo "  generate-dhparam   - Generate DH parameters"
      echo "  install <cert> <key> [ca] - Install certificate from files"
      echo "  validate           - Validate existing certificate and key"
      echo "  info               - Show certificate information"
      echo "  backup             - Backup existing certificates"
      echo "  cleanup            - Remove all SSL files"
      echo ""
      echo "Environment variables:"
      echo "  SSL_COUNTRY        - Country code (default: US)"
      echo "  SSL_STATE          - State name (default: State)"
      echo "  SSL_CITY           - City name (default: City)"
      echo "  SSL_ORG            - Organization name (default: Organization)"
      echo "  SSL_OU             - Organizational unit (default: IT Department)"
      echo "  SSL_CN             - Common name (default: localhost)"
      echo "  SSL_EMAIL          - Email address"
      echo "  CERT_VALIDITY      - Certificate validity in days (default: 365)"
      echo "  KEY_SIZE           - Private key size (default: 2048)"
      echo "  DHPARAM_SIZE       - DH parameter size (default: 2048)"
      exit 1
      ;;
  esac
}

# Execute main function
main "$@"
