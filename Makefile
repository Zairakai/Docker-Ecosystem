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
.PHONY: validate
validate: ## ✅ Validate Dockerfiles and scripts
	@bash -c 'source $(ANSI) && info "Validating Docker Ecosystem configuration…" && \
	DOCKERFILES=$$(find images/ -name "Dockerfile" | wc -l) && \
	info "Found $$DOCKERFILES Dockerfiles" && \
	test -f scripts/build-all-images.sh && \
	test -f scripts/common.sh && \
	test -f scripts/docker-functions.sh && \
	ok "Configuration validation passed"'

.PHONY: shellcheck
shellcheck: ## 🐚 Run shellcheck on all shell scripts
	@bash -c 'source $(ANSI) && info "Running shellcheck on all shell scripts…" && \
	command -v shellcheck >/dev/null 2>&1 || { err "shellcheck not installed. Install with: apt-get install shellcheck"; exit 1; } && \
	find . -name "*.sh" -type f -exec shellcheck --severity=warning {} + && \
	ok "Shellcheck validation passed"'

## ────────────────────────────────────────────────────────────────────
test-ci: validate shellcheck ## ♾️  Run CI validation suite locally
	@bash -c 'source $(ANSI) && info "Running CI validation tests…" && ok "All CI tests passed"'

## ────────────────────────────────────────────────────────────────────
.PHONY: dry
dry-run: ## 📜 Show what would be built
	@echo "Dry run: showing what would be built…"
	DRY_RUN=true \
	DOCKER_REGISTRY=registry.gitlab.com/zairakai/docker-ecosystem \
	PLATFORM=linux/amd64 \
	DEBUG=true \
	./scripts/build-all-images.sh
