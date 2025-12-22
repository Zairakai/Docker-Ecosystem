## Production-ready Docker images for Laravel + Vue.js development
## Registry: registry.gitlab.com/zairakai/docker-ecosystem

# Default target
.DEFAULT_GOAL := help

# Use bash as shell for all recipes
SHELL := /bin/bash

# Execute all recipe lines in a single shell (allows sourcing once per target)
.ONESHELL:

# Exit on error and enable pipefail
.SHELLFLAGS := -eu -o pipefail -c

# ANSI colors helper (sourced when needed)
ANSI := scripts/ansi.sh

.PHONY: help
help: ## ❓ Show this help message
	@bash scripts/makefile-help.sh

.PHONY: docs
docs: ## 📚 Show available documentation
	@bash -c 'source $(ANSI) && info "Documentation files:" && \
	for doc in README.md docs/ARCHITECTURE.md SECURITY.md CONTRIBUTING.md; do \
		if [ -f "$$doc" ]; then \
			ok "  $$doc"; \
		else \
			warn "  $$doc (missing)"; \
		fi; \
	done'

## ────────────────────────────────────────────────────────────────────
## VALIDATION TARGETS
## ────────────────────────────────────────────────────────────────────
.PHONY: validate
validate: ## ✅ Validate Dockerfiles and scripts
	@bash scripts/pipeline/validate-config.sh

.PHONY: shellcheck
shellcheck: ## 🐚 Run shellcheck on all shell scripts (100% compliance)
	@bash scripts/pipeline/validate-shellcheck.sh

.PHONY: validate-all
validate-all: validate shellcheck ## ✅ Run all validation checks
	@bash -c 'source $(ANSI) && ok "All validation checks passed"'

## ────────────────────────────────────────────────────────────────────
## BUILD TARGETS
## ────────────────────────────────────────────────────────────────────
.PHONY: build-php-prod
build-php-prod: ## 🔨 Build PHP 8.3 production image
	@CI_REGISTRY_IMAGE=registry.gitlab.com/zairakai/docker-ecosystem \
		IMAGE_SUFFIX=-local \
		bash scripts/pipeline/build-image.sh images/php/8.3 php 8.3-prod

.PHONY: build-php-dev
build-php-dev: ## 🔨 Build PHP 8.3 development image
	@CI_REGISTRY_IMAGE=registry.gitlab.com/zairakai/docker-ecosystem \
		IMAGE_SUFFIX=-local \
		bash scripts/pipeline/build-image.sh images/php/8.3 php 8.3-dev

.PHONY: build-node-prod
build-node-prod: ## 🔨 Build Node.js 20 production image
	@CI_REGISTRY_IMAGE=registry.gitlab.com/zairakai/docker-ecosystem \
		IMAGE_SUFFIX=-local \
		bash scripts/pipeline/build-image.sh images/node/20 node 20-prod

.PHONY: build-mysql
build-mysql: ## 🔨 Build MySQL 8.0 image
	@CI_REGISTRY_IMAGE=registry.gitlab.com/zairakai/docker-ecosystem \
		IMAGE_SUFFIX=-local \
		bash scripts/pipeline/build-image.sh images/database/mysql/8.0 database mysql-8.0

## ────────────────────────────────────────────────────────────────────
## TEST TARGETS
## ────────────────────────────────────────────────────────────────────
.PHONY: test-image-sizes
test-image-sizes: ## 📊 Test image sizes and generate report
	@CI_REGISTRY_IMAGE=registry.gitlab.com/zairakai/docker-ecosystem \
		IMAGE_SUFFIX=-local \
		bash scripts/pipeline/test-image-sizes.sh

.PHONY: test-multi-stage
test-multi-stage: ## 🔍 Test multi-stage build integrity
	@CI_REGISTRY_IMAGE=registry.gitlab.com/zairakai/docker-ecosystem \
		IMAGE_SUFFIX=-local \
		bash scripts/pipeline/test-multi-stage.sh

.PHONY: test-all
test-all: test-image-sizes test-multi-stage ## 🧪 Run all tests
	@bash -c 'source $(ANSI) && ok "All tests passed"'

## ────────────────────────────────────────────────────────────────────
## CI/CD TARGETS
## ────────────────────────────────────────────────────────────────────
.PHONY: ci-local
ci-local: validate-all ## ♾️  Run CI validation suite locally
	@bash -c 'source $(ANSI) && ok "Local CI validation passed"'

## ────────────────────────────────────────────────────────────────────
.PHONY: dry
dry-run: ## 📜 Show what would be built
	@echo "Dry run: showing what would be built…"
	DRY_RUN=true \
	DOCKER_REGISTRY=registry.gitlab.com/zairakai/docker-ecosystem \
	PLATFORM=linux/amd64 \
	DEBUG=true \
	./scripts/build-all-images.sh
