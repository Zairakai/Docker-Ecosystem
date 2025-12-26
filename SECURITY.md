# Security Policy - Zairakai Docker Ecosystem

[![Security Scanning][security-badge]][security-dashboard]
[![Signed with Cosign][cosign-badge]][cosign]
[![Vulnerabilities][vulnerability-badge]][vulnerability-dashboard]

## Security Overview

The Zairakai Docker Ecosystem implements comprehensive security scanning throughout the CI/CD pipeline to ensure the safety and reliability of our Laravel + Vue.js development stack.

## Security Scanning Tools

### Static Application Security Testing (SAST)

- **Tool**: GitLab SAST with Semgrep engine
- **Coverage**: PHP (Laravel), JavaScript (Vue.js), Dockerfiles
- **Trigger**: Every commit and merge request
- **Reports**: Integrated in GitLab Security Dashboard

### Dependency Scanning

- **Tools**: Gemnasium (universal), Retire.js (npm)
- **Coverage**: Composer dependencies, npm packages, transitive dependencies
- **Frequency**: Every pipeline run
- **Database**: Updated vulnerability database

### Container Scanning

- **Tool**: Trivy scanner
- **Coverage**: All Docker images (PHP, Node.js, MySQL, Redis, Nginx, Services)
- **Severity Levels**: UNKNOWN, LOW, MEDIUM, HIGH, CRITICAL
- **Trigger**: After successful image builds

### License Compliance

- **Approved Licenses**: MIT, Apache-2.0, BSD-3-Clause, BSD-2-Clause, ISC, GPL-3.0, LGPL-3.0
- **Denied Licenses**: GPL-2.0, AGPL-3.0
- **Scope**: All dependencies (Composer + npm)

### Infrastructure as Code (IaC) Scanning

- **Tool**: KICS scanner
- **Coverage**: All Dockerfiles in the ecosystem
- **Rules**: Docker best practices, security hardening

## Security Pipeline Stages

```bash
1. Pre-Build Security (security stage)
   ├── SAST Analysis
   ├── Dependency Scanning
   ├── License Compliance
   └── IaC Scanning

2. Build Stage
   └── Docker Images Build

3. Post-Build Security (security-scan stage)
   ├── Container Scanning (PHP)
   ├── Container Scanning (Node.js)
   ├── Container Scanning (Database)
   └── Security Report Generation

4. Image Signing (sign stage)
   ├── Sign images with Cosign
   └── Verify signatures
```

## 🔐 Image Signing with Cosign

All Docker images are cryptographically signed using [Cosign](https://github.com/sigstore/cosign) to ensure authenticity and integrity.

### Why Image Signing?

- **Authenticity**: Verify images were built by Zairakai CI/CD
- **Integrity**: Detect tampering or unauthorized modifications
- **Supply Chain Security**: Prevent malicious image substitution
- **Compliance**: Meet regulatory requirements for signed artifacts

### Setup (CI/CD)

#### 1. Generate Cosign Key Pair

```bash
# Install Cosign (one-time setup)
curl -O -L "https://github.com/sigstore/cosign/releases/latest/download/cosign-linux-amd64"
sudo mv cosign-linux-amd64 /usr/local/bin/cosign
sudo chmod +x /usr/local/bin/cosign

# Generate key pair
cosign generate-key-pair

# This creates:
# - cosign.key (private key - keep secret!)
# - cosign.pub (public key - share publicly)

# You'll be prompted for a password to encrypt the private key
```

#### 2. Configure GitLab CI/CD Variables

Add these as **protected** and **masked** variables in GitLab Settings → CI/CD → Variables:

| Variable | Type | Description |
| -------- | ---- | ----------- |
| `COSIGN_PRIVATE_KEY` | File | Contents of `cosign.key` |
| `COSIGN_PUBLIC_KEY` | File | Contents of `cosign.pub` |
| `COSIGN_PASSWORD` | Variable | Password for private key |

**⚠️ IMPORTANT**: The private key must be **protected** and **masked** to prevent exposure in logs.

#### 3. CI/CD Pipeline

The `.gitlab-ci.yml` includes automatic signing for all tagged releases:

```yaml
sign:images:
  stage: sign
  image: gcr.io/projectsigstore/cosign:v2.2.2
  script:
    - echo "$COSIGN_PRIVATE_KEY" > /tmp/cosign.key
    - echo "$COSIGN_PASSWORD" | cosign sign --key /tmp/cosign.key --yes \
        $CI_REGISTRY_IMAGE/php:8.3-prod \
        $CI_REGISTRY_IMAGE/node:20-prod
    - rm -f /tmp/cosign.key
  rules:
    - if: $CI_COMMIT_TAG =~ /^v\d+\.\d+\.\d+$/
```

### Verification (Users)

#### Download Public Key

```bash
# Download public key from repository
curl -O https://gitlab.com/zairakai/docker-ecosystem/-/raw/main/.cosign/cosign.pub
```

Or get it from this repository:

```bash
-----BEGIN PUBLIC KEY-----
MFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAE…
-----END PUBLIC KEY-----
```

*(Public key will be added after initial key generation)*

#### Verify Image Signature

```bash
# Verify a signed image
cosign verify \
  --key cosign.pub \
  registry.gitlab.com/zairakai/docker-ecosystem/php:8.3-prod

# Verify and extract signature metadata
cosign verify \
  --key cosign.pub \
  --output json \
  registry.gitlab.com/zairakai/docker-ecosystem/php:8.3-prod | jq

# Verify with certificate transparency log (keyless)
cosign verify \
  --certificate-identity-regexp ".*@zairakai\\.com" \
  --certificate-oidc-issuer "https://gitlab.com" \
  registry.gitlab.com/zairakai/docker-ecosystem/php:8.3-prod
```

#### Docker Compose with Signature Verification

```yaml

services:
  php:
    image: registry.gitlab.com/zairakai/docker-ecosystem/php:8.3-prod
    # Signature verification happens before container start
    # Use a pre-pull verification script:
    entrypoint:
      - /bin/sh
      - -c
      - |
        # This would be in your entrypoint or init script
        if ! cosign verify --key /cosign/cosign.pub registry.gitlab.com/zairakai/docker-ecosystem/php:8.3-prod; then
          echo "ERROR: Image signature verification failed!"
          exit 1
        fi
        exec php-fpm
    volumes:
      - ./cosign.pub:/cosign/cosign.pub:ro
```

#### Kubernetes with Cosign Policy

```yaml
# Use Sigstore Policy Controller
apiVersion: policy.sigstore.dev/v1beta1
kind: ClusterImagePolicy
metadata:
  name: zairakai-images-policy
spec:
  images:
    - glob: "registry.gitlab.com/zairakai/docker-ecosystem/**"
  authorities:
    - key:
        data: |
          -----BEGIN PUBLIC KEY-----
          MFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAE…
          -----END PUBLIC KEY-----
```

### Signed Images Badge

All released images include a signature badge:

![Signed with Cosign](https://img.shields.io/badge/signed-cosign-blue)

### Signature Metadata

Signatures include the following metadata:

```json
{
  "critical": {
    "identity": {
      "docker-reference": "registry.gitlab.com/zairakai/docker-ecosystem/php:8.3-prod"
    },
    "type": "cosign container image signature"
  },
  "optional": {
    "CI_COMMIT_SHA": "abc123…",
    "CI_COMMIT_TAG": "v1.0.0",
    "CI_PIPELINE_URL": "https://gitlab.com/zairakai/docker-ecosystem/-/pipelines/123456",
    "BUILD_DATE": "2025-09-30T14:23:45Z"
  }
}
```

### Troubleshooting

#### Error: "signature verification failed"

**Causes:**

- Image was not signed (only tagged releases are signed)
- Using wrong public key
- Image was modified after signing
- Network issues accessing signature storage

**Solutions:**

```bash
# Check if image is signed
cosign tree registry.gitlab.com/zairakai/docker-ecosystem/php:8.3-prod

# View signature without verifying
cosign verify --insecure-ignore-tlog \
  registry.gitlab.com/zairakai/docker-ecosystem/php:8.3-prod

# Download signature manifest
cosign download signature \
  registry.gitlab.com/zairakai/docker-ecosystem/php:8.3-prod
```

#### Error: "failed to verify certificate"

This means you're trying keyless verification but the image was signed with a key. Use `--key cosign.pub` instead.

#### Error: "UNAUTHORIZED: authentication required"

You need to authenticate to the registry:

```bash
# Docker login
docker login registry.gitlab.com

# Cosign uses Docker credentials
cosign verify --key cosign.pub registry.gitlab.com/zairakai/docker-ecosystem/php:8.3-prod
```

### Best Practices

#### ✅ DO

- **Always verify** image signatures in production
- **Automate verification** in CI/CD pipelines
- **Rotate signing keys** annually or after suspected compromise
- **Store private keys** in secure vaults (GitLab Variables, HashiCorp Vault, AWS Secrets Manager)
- **Use admission controllers** (Kyverno, OPA Gatekeeper) to enforce signature verification in Kubernetes
- **Document public key** distribution method
- **Monitor signature** verification failures

#### ❌ DON'T

- **Never commit** private keys to Git
- **Never share** private keys via email or Slack
- **Don't skip** signature verification in production
- **Don't use** unsigned images in production
- **Don't disable** signature verification to "fix" deployment issues

## 📊 Security Reporting

### Automated Reports

- **Security Dashboard**: Available in GitLab project security tab
- **Vulnerability Reports**: Generated for each pipeline
- **Compliance Report**: License and policy compliance status
- **Artifacts**: Downloadable security reports (30-day retention)

### Manual Security Review

Security scans run automatically but require manual review for:

- **HIGH and CRITICAL** vulnerabilities
- **License compliance** violations
- **New security findings** in dependencies

## 🔧 Security Configuration

### Thresholds

- **CRITICAL vulnerabilities**: Block pipeline
- **HIGH vulnerabilities**: Require review
- **MEDIUM/LOW vulnerabilities**: Warning only

### Exclusions

- Test files and directories
- Development-only dependencies
- Generated/vendor files
- Documentation and examples

## Security Best Practices

### Docker Security

- Non-root user execution (`www:www`, `node:node`)
- Health checks in all containers
- Multi-stage builds (prod → dev → test)
- Minimal base images (Alpine Linux)
- No hardcoded secrets
- Latest security patches

### Application Security

- Static code analysis for common vulnerabilities
- Dependency vulnerability scanning
- License compliance verification
- Secure defaults in configurations

### CI/CD Security

- Registry authentication with tokens
- Encrypted environment variables
- Pipeline isolation and sandboxing
- Artifact signing and verification

## Incident Response

### High/Critical Vulnerability Process

1. **Detection**: GitLab scanners identify and report vulnerabilities
2. **Assessment**: Review findings in GitLab Security Dashboard
3. **Prioritization**: Focus on HIGH and CRITICAL severity issues first
4. **Remediation**: Update dependencies, base images, or code as needed
5. **Verification**: Re-run pipeline to confirm fixes

### Contact Information

- **[Discord][discord]**: Community discussions (*🖥️・Developers* role)
- **[GitLab Issues][issues]**: Report vulnerabilities and security concerns
- **Security Findings**: Review security reports in GitLab Security Dashboard
- **Critical Issues**: Address immediately based on scanner findings

## Compliance Standards

Our security implementation follows:

- **OWASP Top 10** vulnerability prevention
- **CIS Docker Benchmark** for container security
- **GitLab Security Best Practices** for CI/CD
- **NIST Cybersecurity Framework** principles

## Security Updates

- **Vulnerability Database**: Updated automatically by GitLab scanners
- **Security Policies**: Reviewed as needed based on findings
- **Scanner Updates**: Automatic with GitLab CI/CD pipeline runs
- **Base Images**: Updated when new stable versions are released
- **Manual Review**: Security findings require manual assessment and action

<!-- Reference Links -->
[discord]: https://discord.gg/MAmD5SG8Zu
[issues]: https://gitlab.com/zairakai/docker-ecosystem/-/issues

<!-- Badges -->
[security-badge]: https://img.shields.io/badge/security-scanned-green.svg
[security-dashboard]: https://gitlab.com/zairakai/docker-ecosystem/-/security/dashboard
[cosign-badge]: https://img.shields.io/badge/signed-cosign-blue?logo=keycdn
[cosign]: https://github.com/sigstore/cosign
[vulnerability-badge]: https://img.shields.io/badge/vulnerabilities-monitored-orange?logo=gitlab
[vulnerability-dashboard]: https://gitlab.com/zairakai/docker-ecosystem/-/security/vulnerabilities
