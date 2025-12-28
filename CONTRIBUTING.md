# Contributing Guide

[![PRs Welcome][prs-welcome-badge]][issues]
[![Contributors][contributors-badge]][contributors]
[![Discord][discord-badge]][discord]

Thank you for your interest in contributing to the Zairakai Docker Ecosystem!

This repository generates and maintains **Docker images** for Laravel + Vue.js development. Contributions help improve the quality and security of these images.

## Quick Start for Contributors

### 1. Clone & Branch

```bash
# Clone the repository directly (no fork needed)
git clone https://gitlab.com/zairakai/docker-ecosystem.git
cd docker-ecosystem
git checkout -b feature/your-feature-name
```

### 2. Make Your Changes

**Common contribution types:**

- **Dockerfile improvements** (add extensions, optimize layers)
- **Security updates** (dependencies, base images)
- **Example configurations** (new docker-compose setups)
- **Documentation updates** (README, examples, docs/)

### 3. Test Changes Locally

```bash
# 1. Validate configuration and scripts
make validate-all

# 2. Build specific images locally (if needed)
make build-php-prod      # Build PHP production image
make build-php-dev       # Build PHP development image
make build-node-prod     # Build Node production image
make build-mysql         # Build MySQL image

# 3. Test images (after building)
make test-image-sizes    # Check image sizes
make test-multi-stage    # Verify multi-stage integrity

# 4. Test examples work with registry images
cd examples
docker-compose -f minimal-laravel.yml up -d
docker-compose ps  # Verify all services are running
docker-compose -f minimal-laravel.yml down
```

### 4. Submit Changes

```bash
# Commit with conventional format
git commit -m "feat(php): add imagick extension to dev images"
git commit -m "fix(examples): correct MySQL environment variables"
git commit -m "docs: update architecture documentation"

# Push and create merge request
git push origin feature/your-feature-name
```

## Contribution Types

### **Docker Images**

- Add/remove PHP extensions
- Update base image versions
- Optimize image layers and size
- Improve security configurations

### **Examples**

- Add new docker-compose configurations (examples/compose/)
- Add nginx configurations (examples/nginx/)
- Add testing mode examples (examples/testing-modes/)
- Fix existing example issues
- Improve documentation in examples/

### **Documentation**

- Update README or docs/
- Fix broken links
- Improve clarity and examples

### **Scripts & CI**

- Improve build scripts in `scripts/pipeline/`
- Enhance GitLab CI pipeline (`.gitlab-ci.yml`)
- Add new validation or test scripts
- Optimize existing scripts

**Shell Script Requirements:**

- [x] **ShellCheck 100% compliance** - ZERO warnings tolerated
- [x] **Shebang**: Always use `#!/usr/bin/env bash` (NOT `#!/bin/sh`)
- [x] **Error handling**: Use `set -euo pipefail` at script start
- [x] **Logging**: Use functions from `scripts/common.sh` (`log_info`, `log_error`, etc.)
- [x] **Documentation**: Include usage examples and environment variables
- [x] **Testability**: Scripts must be executable locally (not just in CI)

**Example script structure:**

```bash
#!/usr/bin/env bash
# scripts/pipeline/example.sh
# Brief description of what this script does
#
# Usage:
#   example.sh <arg1> <arg2>
#
# Environment Variables:
#   VAR_NAME - Description (required/optional, default: value)

set -euo pipefail

# Source common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../common.sh"

# Script logic here
log_section "Section Title"
log_info "Processing…"
log_success "Done!"
```

**Testing scripts:**

```bash
# Validate all scripts with ShellCheck
make shellcheck

# Run specific script locally
bash scripts/pipeline/your-script.sh

# Test with CI environment variables
CI_REGISTRY_IMAGE=registry.gitlab.com/zairakai/docker-ecosystem \
  bash scripts/pipeline/your-script.sh
```

## Quality Standards

### **Image Requirements**

- Use official Alpine base images
- Run as non-root user (www:www, node:node)
- Include health checks
- Minimize layer count and size
- Document all changes

### **Example Requirements**

- Use registry images (not build:)
- Include clear documentation
- Test with docker-compose up/down
- Follow naming conventions

### **Documentation**

- Update relevant docs/ files
- Keep examples/ README current
- Use clear, concise language

## Review Process

1. **Automated checks** run via GitLab CI
2. **Security scanning** for all image changes
3. **Manual review** by maintainers
4. **Testing** with example configurations

## Security

- All image changes trigger security scans
- Report security issues via **[Security Policy][security]**
- Follow least-privilege principles
- Keep dependencies updated

## Support

[![Issues][issues-badge]][issues]
[![Discord][discord-badge]][discord]

**Let's build better Docker images together!**

<!-- Reference Links -->
[discord]: https://discord.gg/MAmD5SG8Zu
[issues]: https://gitlab.com/zairakai/docker-ecosystem/-/issues
[security]: ./SECURITY.md
[contributors]: https://gitlab.com/zairakai/docker-ecosystem/-/graphs/main

<!-- Badge Links -->
[prs-welcome-badge]: https://img.shields.io/badge/PRs-welcome-brightgreen.svg?logo=git
[contributors-badge]: https://img.shields.io/gitlab/contributors/zairakai%2Fdocker-ecosystem?logo=gitlab&label=Contributors
[discord-badge]: https://img.shields.io/discord/1260000352699289621?logo=discord&label=Discord&color=5865F2
[issues-badge]: https://img.shields.io/gitlab/issues/open/zairakai%2Fdocker-ecosystem?logo=gitlab&label=Issues
