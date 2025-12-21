# Contributing Guide

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
# Test examples work with registry images
cd examples
docker-compose -f minimal-laravel.yml up -d
docker-compose ps  # Verify all services are running
docker-compose -f minimal-laravel.yml down

# Test build scripts only if you modify them
./scripts/build/build-all-images.sh
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

- Improve build scripts
- Enhance GitLab CI pipeline
- Add new checks or tests

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

## Need Help?

- **[Discord][discord]** - Community discussions (*🖥️・Developers* role)
- **[GitLab Issues][issues]** - Bug reports and feature requests
- **[Documentation][docs]** - Architecture and reference guides
- **[Examples][examples]** - Usage patterns and configurations

---

**Let's build better Docker images together!**

<!-- Reference Links -->
[discord]: https://discord.gg/MAmD5SG8Zu
[issues]: https://gitlab.com/zairakai/docker-ecosystem/-/issues
[security]: ./SECURITY.md
[docs]: docs/
[examples]: examples/
