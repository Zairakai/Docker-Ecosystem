#!/bin/bash
set -euo pipefail

# Development environment setup script
# Configures Node.js development environment with tools and preferences

# Color codes for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Logging functions
log_info() {
  echo -e "${GREEN}[DEV-SETUP]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_warn() {
  echo -e "${YELLOW}[DEV-SETUP]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1" >&2
}

log_error() {
  echo -e "${RED}[DEV-SETUP]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1" >&2
}

log_step() {
  echo -e "${BLUE}[DEV-SETUP]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

# Setup functions
setup_git_config() {
  log_step "Setting up Git configuration…"

  # Create git config directory if it doesn't exist
  mkdir -p ~/.gitconfig.d

  # Basic git configuration
  cat > ~/.gitconfig << 'EOF'
[user]
  # User will override these in their project
  name = Docker Developer
  email = dev@example.com

[core]
  editor = nano
  autocrlf = input
  safecrlf = warn
  excludesfile = ~/.gitignore_global

[init]
  defaultBranch = main

[pull]
  rebase = false

[push]
  default = simple

[merge]
  tool = vimdiff

[alias]
  st = status
  ci = commit
  co = checkout
  br = branch
  unstage = reset HEAD --
  last = log -1 HEAD
  visual = !gitk
  lg = log --oneline --graph --decorate --all
  ll = log --pretty=format:"%C(yellow)%h%Cred%d\\ %Creset%s%Cblue\\ [%cn]" --decorate --numstat

[color]
  ui = auto
  branch = auto
  diff = auto
  status = auto

[color "branch"]
  current = yellow reverse
  local = yellow
  remote = green

[color "diff"]
  meta = yellow bold
  frag = magenta bold
  old = red bold
  new = green bold

[color "status"]
  added = yellow
  changed = green
  untracked = cyan

[include]
  path = ~/.gitconfig.d/local
EOF

  # Create global gitignore
  cat > ~/.gitignore_global << 'EOF'
# OS generated files
.DS_Store
.DS_Store?
._*
.Spotlight-V100
.Trashes
ehthumbs.db
Thumbs.db

# IDE files
.vscode/
.idea/
*.swp
*.swo
*~

# Node.js
node_modules/
npm-debug.log*
yarn-debug.log*
yarn-error.log*
.npm
.yarn-integrity

# Environment files
.env
.env.local
.env.development.local
.env.test.local
.env.production.local

# Logs
logs
*.log

# Runtime data
pids
*.pid
*.seed
*.pid.lock

# Coverage directory used by tools like istanbul
coverage/
.nyc_output

# Dependency directories
jspm_packages/

# Optional npm cache directory
.npm

# Optional eslint cache
.eslintcache

# Microbundle cache
.rpt2_cache/
.rts2_cache_cjs/
.rts2_cache_es/
.rts2_cache_umd/

# Optional REPL history
.node_repl_history

# Output of 'npm pack'
*.tgz

# Yarn Integrity file
.yarn-integrity
EOF

  log_info "Git configuration completed"
}

setup_npm_config() {
  log_step "Setting up npm configuration…"

  # Create npm configuration for development
  cat > ~/.npmrc << 'EOF'
# Development npm configuration

# Registry and authentication
registry=https://registry.npmjs.org/

# Cache configuration
cache=/home/node/.npm
cache-min=10

# Development settings
save=true
save-exact=false
save-prefix=^
package-lock=true

# Progress and logging
progress=true
loglevel=info
unicode=true

# Performance
maxsockets=50
fetch-retries=3
fetch-retry-factor=10
fetch-retry-mintimeout=10000
fetch-retry-maxtimeout=60000

# Development flags
fund=true
audit-level=moderate

# Optional dependencies
optional=true
dev=true
EOF

  log_info "npm configuration completed"
}

setup_yarn_config() {
  log_step "Setting up Yarn configuration…"

  # Create yarn configuration directory
  mkdir -p ~/.config/yarn

  # Create yarn configuration
  cat > ~/.config/yarn/config << 'EOF'
# Yarn configuration for development

# Network settings
registry "https://registry.npmjs.org/"
network-timeout 300000
network-concurrency 16

# Cache settings
cache-folder "/home/node/.cache/yarn"
global-folder "/home/node/.config/yarn/global"

# Installation preferences
save-prefix "^"
exact false

# Development settings
progress true
emoji true
silent false

# Security
disable-self-update-check true
EOF

  log_info "Yarn configuration completed"
}

setup_shell_environment() {
  log_step "Setting up shell environment…"

  # Create bash profile for development
  cat > ~/.bashrc << 'EOF'
# Node.js development environment

# Colors
export TERM=xterm-256color
export CLICOLOR=1

# Node.js environment
export NODE_ENV=development
export NODE_OPTIONS="--max-old-space-size=1024 --inspect=0.0.0.0:9229"

# Development tools
export EDITOR=nano
export PAGER=less

# Path additions
export PATH="$HOME/.local/bin:$PATH"
export PATH="./node_modules/.bin:$PATH"

# Aliases
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'
alias ..='cd ..'
alias …='cd ../..'
alias grep='grep --color=auto'
alias fgrep='fgrep --color=auto'
alias egrep='egrep --color=auto'

# Node.js aliases
alias ni='npm install'
alias ns='npm start'
alias nt='npm test'
alias nb='npm run build'
alias nd='npm run dev'
alias yi='yarn install'
alias ys='yarn start'
alias yt='yarn test'
alias yb='yarn build'
alias yd='yarn dev'

# Git aliases
alias g='git'
alias gs='git status'
alias ga='git add'
alias gc='git commit'
alias gp='git push'
alias gl='git pull'
alias gd='git diff'
alias gco='git checkout'
alias gb='git branch'

# Development helpers
alias ports='netstat -tuln'
alias serve='python3 -m http.server'
alias json='python3 -m json.tool'

# History settings
export HISTSIZE=10000
export HISTFILESIZE=20000
export HISTCONTROL=ignoredups:erasedups
shopt -s histappend

# Auto-completion
if [ -f /etc/bash_completion ] && ! shopt -oq posix; then
  . /etc/bash_completion
fi

# Welcome message
echo "🚀 Node.js Development Environment Ready!"
echo "Node.js: $(node --version 2>/dev/null || echo 'Not available')"
echo "npm: $(npm --version 2>/dev/null || echo 'Not available')"
echo "Yarn: $(yarn --version 2>/dev/null || echo 'Not available')"
echo ""
EOF

  # Create ash profile for Alpine compatibility
  ln -sf ~/.bashrc ~/.profile

  log_info "Shell environment completed"
}

setup_development_tools() {
  log_step "Setting up development tools…"

  # Create directories for tools
  mkdir -p ~/.local/bin
  mkdir -p ~/.cache/yarn
  mkdir -p ~/.config/yarn/global

  # Create a simple development helper script
  cat > ~/.local/bin/dev-helper << 'EOF'
#!/bin/bash
# Development helper script

case "${1:-help}" in
  "start")
    echo "Starting development server…"
    if [ -f "package.json" ]; then
      if npm run dev 2>/dev/null; then
        echo "Started with npm run dev"
      elif npm start 2>/dev/null; then
        echo "Started with npm start"
      else
        echo "No dev/start script found"
      fi
    else
      echo "No package.json found"
    fi
    ;;
  "test")
    echo "Running tests…"
    if [ -f "package.json" ]; then
      npm test
    else
      echo "No package.json found"
    fi
    ;;
  "install")
    echo "Installing dependencies…"
    if [ -f "yarn.lock" ]; then
      yarn install
    elif [ -f "package-lock.json" ]; then
      npm install
    elif [ -f "package.json" ]; then
      npm install
    else
      echo "No package.json found"
    fi
    ;;
  "clean")
    echo "Cleaning project…"
    rm -rf node_modules package-lock.json yarn.lock
    npm cache clean --force 2>/dev/null || true
    yarn cache clean 2>/dev/null || true
    echo "Project cleaned"
    ;;
  "info")
    echo "Project information:"
    echo "Node.js: $(node --version)"
    echo "npm: $(npm --version)"
    echo "Yarn: $(yarn --version)"
    echo "Working directory: $(pwd)"
    if [ -f "package.json" ]; then
      echo "Package: $(node -e 'console.log(JSON.parse(require("fs").readFileSync("package.json", "utf8")).name)' 2>/dev/null || echo 'Unknown')"
      echo "Version: $(node -e 'console.log(JSON.parse(require("fs").readFileSync("package.json", "utf8")).version)' 2>/dev/null || echo 'Unknown')"
    fi
    ;;
  "help"|*)
    echo "Development Helper"
    echo "Usage: dev-helper [command]"
    echo ""
    echo "Commands:"
    echo "  start  - Start development server"
    echo "  test   - Run tests"
    echo "  install  - Install dependencies"
    echo "  clean  - Clean project files"
    echo "  info   - Show project information"
    echo "  help   - Show this help"
    ;;
esac
EOF

  chmod +x ~/.local/bin/dev-helper

  log_info "Development tools setup completed"
}

setup_debugging_config() {
  log_step "Setting up debugging configuration…"

  # Create directory for debugging configs
  mkdir -p ~/.config/debug

  # Create Node.js inspector configuration
  cat > ~/.config/debug/inspector.json << 'EOF'
{
  "inspector": {
  "host": "0.0.0.0",
  "port": 9229,
  "break": false
  },
  "debugger": {
  "auto_attach": true,
  "wait_for_debugger": false,
  "ignore_breakpoints": false
  },
  "source_maps": {
  "enabled": true,
  "inline": true,
  "resolve_source_map_locations": [
    "${workspaceFolder}/**",
    "!**/node_modules/**"
  ]
  }
}
EOF

  log_info "Debugging configuration completed"
}

verify_setup() {
  log_step "Verifying development setup…"

  local errors=0

  # Check required tools
  local tools=("node" "npm" "yarn" "git")
  for tool in "${tools[@]}"; do
    if command -v "$tool" >/dev/null 2>&1; then
      log_info "✓ $tool is available"
    else
      log_error "✗ $tool is not available"
      errors=$((errors + 1))
    fi
  done

  # Check configuration files
  local configs=(
    "$HOME/.bashrc"
    "$HOME/.npmrc"
    "$HOME/.gitconfig"
    "$HOME/.config/yarn/config"
  )

  for config in "${configs[@]}"; do
    if [ -f "$config" ]; then
      log_info "✓ Configuration file exists: $config"
    else
      log_warn "✗ Configuration file missing: $config"
    fi
  done

  # Check directories
  local dirs=(
    "$HOME/.npm"
    "$HOME/.cache/yarn"
    "$HOME/.local/bin"
    "$HOME/.config/yarn/global"
  )

  for dir in "${dirs[@]}"; do
    if [ -d "$dir" ]; then
      log_info "✓ Directory exists: $dir"
    else
      log_warn "✗ Directory missing: $dir"
    fi
  done

  if [ $errors -eq 0 ]; then
    log_info "All required tools are available"
    return 0
  else
    log_error "$errors required tools are missing"
    return 1
  fi
}

# Main setup function
main() {
  log_info "Starting development environment setup…"
  log_info "User: $(whoami)"
  log_info "Home: $HOME"
  log_info "Working directory: $(pwd)"

  # Run setup functions
  setup_git_config
  setup_npm_config
  setup_yarn_config
  setup_shell_environment
  setup_development_tools
  setup_debugging_config

  # Verify setup
  if verify_setup; then
    log_info "Development environment setup completed successfully"
    log_info "Please restart your shell or run 'source ~/.bashrc' to apply changes"
  else
    log_warn "Development environment setup completed with warnings"
  fi
}

# Execute main function
main "$@"
