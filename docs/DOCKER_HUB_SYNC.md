# Docker Hub Synchronization & Description Updates

<!-- CI/CD & Quality -->
[![License][license-badge]][license]
[![Pipeline][pipeline-badge]][pipeline]

This document explains how Docker images are synchronized to Docker Hub with automatic description updates.

---

## Overview

The Docker Ecosystem automatically:

1. **Mirrors images** from GitLab Container Registry to Docker Hub
2. **Updates descriptions** from README files located in each image directory
3. **Maintains consistency** between registry and documentation

---

## How It Works

### Pipeline Flow

```text
Tag push (vX.Y.Z) → Build → Test → Promote → Sync to Docker Hub
                                               ↓
                                      Update Descriptions (API)
```

### Architecture

```text
images/
├── php/8.3/
│   ├── Dockerfile
│   └── README.md          ← Pushed to Docker Hub as description
├── node/20/
│   ├── Dockerfile
│   └── README.md          ← Pushed to Docker Hub as description
├── database/
│   ├── mysql/8.0/README.md
│   └── redis/7/README.md
├── web/
│   └── nginx/1.26/README.md
└── services/
    ├── mailhog/README.md
    ├── minio/README.md
    ├── e2e-testing/README.md
    └── performance-testing/README.md
```

---

## Implementation Details

### 1. Script: `scripts/pipeline/sync-dockerhub.sh`

**Features:**

- Docker Hub login via CLI (for image push)
- Docker Hub API authentication (for description updates)
- Automatic README detection per image
- Graceful fallback if README doesn't exist

**Key Functions:**

```bash
# Authenticates to Docker Hub API and retrieves JWT token
DOCKERHUB_JWT_TOKEN=$(curl -s -X POST \
  https://hub.docker.com/v2/users/login/ \
  -H "Content-Type: application/json" \
  -d "{\"username\":\"${DOCKERHUB_USERNAME}\",\"password\":\"${DOCKERHUB_TOKEN}\"}")

# Updates repository description via PATCH API
update_dockerhub_description() {
  local namespace="$1"        # e.g., "zairakai"
  local repository="$2"       # e.g., "php"
  local readme_path="$3"      # e.g., "images/php/8.3/README.md"

  # Reads README, escapes JSON, sends PATCH request
  curl -X PATCH \
    "https://hub.docker.com/v2/repositories/${namespace}/${repository}/" \
    -H "Authorization: Bearer ${DOCKERHUB_JWT_TOKEN}" \
    -d "{\"full_description\":${description}}"
}
```

### 2. GitLab CI Job: `sync:dockerhub`

**Location:** `.gitlab-ci.yml` → `promote` stage

**Dependencies:**

- `bash` - Shell scripting
- `jq` - JSON processing (escape markdown for API)
- `curl` - HTTP client for API calls
- `docker` - Image pull/tag/push

**Trigger:** Only on version tags (`vX.Y.Z`)

**Configuration:**

```yaml
sync:dockerhub:
  stage: promote
  image: docker:27-cli
  needs:
    - promote:tags
  before_script:
    - apk add --no-cache bash jq curl
    - echo $CI_REGISTRY_PASSWORD | docker login -u $CI_REGISTRY_USER --password-stdin $CI_REGISTRY
  script:
    - bash scripts/pipeline/sync-dockerhub.sh
  rules:
    - if: $CI_COMMIT_TAG =~ /^v\d+\.\d+\.\d+$/
  allow_failure: true  # Don't block release if Docker Hub sync fails
```

---

## Image to README Mapping

| Docker Hub Repository | README Location | Description |
| --------------------- | --------------- | ----------- |
| `zairakai/php` | `images/php/8.3/README.md` | PHP 8.3 FPM (prod/dev/test) |
| `zairakai/node` | `images/node/20/README.md` | Node.js 20 LTS (prod/dev/test) |
| `zairakai/mysql` | `images/database/mysql/8.0/README.md` | MySQL 8.0 with HA |
| `zairakai/redis` | `images/database/redis/7/README.md` | Redis 7 with Sentinel |
| `zairakai/nginx` | `images/web/nginx/1.26/README.md` | Nginx 1.26 reverse proxy |
| `zairakai/mailhog` | `images/services/mailhog/README.md` | Email testing tool |
| `zairakai/minio` | `images/services/minio/README.md` | S3-compatible storage |
| `zairakai/e2e-testing` | `images/services/e2e-testing/README.md` | Playwright + Gherkin |
| `zairakai/performance-testing` | `images/services/performance-testing/README.md` | Artillery, k6, Locust |

---

## README Guidelines

### Structure

Each README should follow this structure:

```markdown
# Image Name - Brief Description

[![Badges]](links)

Overview paragraph.

---

## Quick Start

Basic docker pull and run commands.

---

## Available Tags (if applicable)

Table of image variants.

---

## Docker Compose

Full example with related services.

---

## Key Features

Bullet list of main features.

---

## Configuration

Environment variables, config files.

---

## Use Cases

When to use this image.

---

## Documentation

Links to ecosystem docs.

---

## Related Images

Table of companion images.
```

### Content Guidelines

1. **Keep it concise** - Docker Hub displays ~4000 characters comfortably
2. **Use badges** - Image size, pulls, pipeline status
3. **Provide examples** - Working Docker Compose snippets
4. **Link to full docs** - Reference main ecosystem documentation
5. **Cross-reference** - Mention related images (PHP ↔ Nginx ↔ MySQL)
6. **Use tables** - For variants, env vars, comparisons
7. **Include code blocks** - Show actual commands and config

### Markdown Support

Docker Hub supports **GitHub-flavored Markdown**:

- ✅ Headers, lists, tables
- ✅ Code blocks with syntax highlighting
- ✅ Links and images
- ✅ Badges via shields.io
- ❌ HTML (stripped)
- ❌ Custom CSS

---

## Environment Variables

Required secrets in GitLab CI/CD:

| Variable | Description | Example |
| -------- | ----------- | ------- |
| `DOCKERHUB_USERNAME` | Docker Hub username | `zairakai` |
| `DOCKERHUB_TOKEN` | Docker Hub access token | `dckr_pat_abc123...` |
| `CI_REGISTRY_IMAGE` | GitLab registry prefix | `registry.gitlab.com/zairakai/docker-ecosystem` |

**Security:**

- Tokens are stored as GitLab CI/CD variables (Settings → CI/CD → Variables)
- Never commit tokens to repository
- Use Docker Hub **access tokens**, not account password

---

## API Endpoints Used

### 1. Authentication

```http
POST https://hub.docker.com/v2/users/login/
Content-Type: application/json

{
  "username": "zairakai",
  "password": "dckr_pat_..."
}

Response:
{
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
}
```

### 2. Update Description

```http
PATCH https://hub.docker.com/v2/repositories/zairakai/php/
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
Content-Type: application/json

{
  "full_description": "# PHP 8.3\n\nMarkdown content..."
}

Response: 200 OK
```

---

## Troubleshooting

### Description Not Updating

**Problem:** Image syncs but description unchanged on Docker Hub.

**Diagnosis:**

1. Check GitLab CI logs for `sync:dockerhub` job
2. Look for `✓ Description updated successfully` or warnings

**Common Causes:**

- README file missing or wrong path
- Invalid JWT token (credentials expired)
- API rate limiting (rare)
- Malformed JSON (special characters not escaped)

**Solution:**

```bash
# Test locally
export DOCKERHUB_USERNAME="zairakai"
export DOCKERHUB_TOKEN="dckr_pat_..."
export CI_REGISTRY_IMAGE="registry.gitlab.com/zairakai/docker-ecosystem"

bash scripts/pipeline/sync-dockerhub.sh
```

### ShellCheck Errors

**Problem:** Pipeline fails at `validate:shellcheck` stage.

**Solution:**

```bash
# Run locally
shellcheck scripts/pipeline/sync-dockerhub.sh

# Only SC1091 (info) is acceptable (source file not followed)
# All other warnings/errors MUST be fixed
```

### JSON Escaping Issues

**Problem:** Description contains special characters breaking JSON.

**Root Cause:** README has unescaped quotes or backslashes.

**Solution:** The script uses `jq -Rs .` which handles escaping automatically:

```bash
# Correct (used in script)
description=$(jq -Rs . < "${readme_path}")

# Incorrect (breaks on special chars)
description=$(cat "${readme_path}")
```

---

## Updating Descriptions

### Automatic (Recommended)

1. Edit README file in `images/{service}/README.md`
2. Commit and push changes
3. Create and push a version tag:

   ```bash
   git tag v1.2.3
   git push origin v1.2.3
   ```

4. GitLab CI automatically:
   - Builds images
   - Syncs to Docker Hub
   - Updates descriptions

### Manual (Emergency)

If you need to update a description immediately without releasing:

```bash
# 1. Authenticate
TOKEN=$(curl -s -X POST https://hub.docker.com/v2/users/login/ \
  -H "Content-Type: application/json" \
  -d '{"username":"zairakai","password":"dckr_pat_..."}' \
  | jq -r .token)

# 2. Update description
DESCRIPTION=$(jq -Rs . < images/php/8.3/README.md)

curl -X PATCH https://hub.docker.com/v2/repositories/zairakai/php/ \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  -d "{\"full_description\":${DESCRIPTION}}"
```

---

## Best Practices

### Version Control

- ✅ Commit README changes with image Dockerfile changes
- ✅ Review README in PR before merging
- ✅ Keep README up-to-date with features
- ❌ Don't edit descriptions directly on Docker Hub (will be overwritten)

### Content Quality

- ✅ Test all code examples before committing
- ✅ Update version numbers when bumping image versions
- ✅ Verify links work (docs, examples, related images)
- ✅ Use relative links for ecosystem docs
- ❌ Don't include sensitive information (passwords, keys)

### Performance

- ✅ Keep README files under 50KB (Docker Hub limit: 100KB)
- ✅ Optimize badge images (use shields.io)
- ✅ Minimize external image embeds
- ❌ Don't inline base64 images (bloats API payload)

---

## Future Enhancements

Potential improvements to consider:

1. **README Templates**: Generate READMEs from templates + metadata
2. **Validation**: Pre-push hook to validate README markdown
3. **Preview**: Local preview tool to render README as Docker Hub would
4. **Short Description**: Update `description` field (100 char limit) separately
5. **Tags Description**: Auto-generate tag-specific descriptions
6. **Metrics**: Track view counts, pull stats per description update

---

## References

- **[Docker Hub API Docs](https://docs.docker.com/docker-hub/api/latest/)**
- **[GitLab CI/CD Variables](https://docs.gitlab.com/ee/ci/variables/)**
- **[GitHub-Flavored Markdown](https://github.github.com/gfm/)**
- **[Shields.io Badges](https://shields.io/)**

---

## Support

[![Issues][issues-badge]][issues]
[![Discord][discord-badge]][discord]

<!-- Badge References -->
[pipeline-badge]: https://gitlab.com/zairakai/docker-ecosystem/badges/main/pipeline.svg
[pipeline]: https://gitlab.com/zairakai/docker-ecosystem/-/pipelines
[license-badge]: https://img.shields.io/badge/license-MIT-blue.svg
[license]: ../LICENSE
[discord-badge]: https://img.shields.io/discord/1260000352699289621?logo=discord&label=Discord&color=5865F2
[discord]: https://discord.gg/MAmD5SG8Zu
[issues-badge]: https://img.shields.io/gitlab/issues/open-raw/zairakai%2Fdocker-ecosystem?logo=gitlab&label=Issues
[issues]: https://gitlab.com/zairakai/docker-ecosystem/-/issues
