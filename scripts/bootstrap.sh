#!/usr/bin/env bash
# =============================================================================
# bootstrap.sh — Ephemeral dev environment setup
# Run this once after SSH-ing in, or via cloud-init on first boot.
# =============================================================================
set -euo pipefail

LOG="/tmp/bootstrap.log"
exec > >(tee -a "$LOG") 2>&1

echo "=============================================="
echo " Bootstrap started: $(date)"
echo "=============================================="

# ------------------------------------------------------------------------------
# 1. System packages
# ------------------------------------------------------------------------------
echo "[1/6] Installing system packages..."
sudo apt-get update -qq
sudo apt-get install -y -qq \
  vim \
  git \
  curl \
  wget \
  unzip \
  jq \
  build-essential \
  python3 \
  python3-pip \
  python3-venv

# ------------------------------------------------------------------------------
# 2. Git configuration (reads from env vars set via cloud-init or .env)
# ------------------------------------------------------------------------------
echo "[2/6] Configuring git..."
GIT_NAME="${GIT_NAME:-Your Name}"
GIT_EMAIL="${GIT_EMAIL:-you@example.com}"

git config --global user.name  "$GIT_NAME"
git config --global user.email "$GIT_EMAIL"
git config --global init.defaultBranch main
git config --global pull.rebase false

# ------------------------------------------------------------------------------
# 3. GitHub CLI (gh) — for creating issues and PRs from the terminal
# ------------------------------------------------------------------------------
echo "[3/6] Installing GitHub CLI..."
if ! command -v gh &>/dev/null; then
  curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
    | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
  echo "deb [arch=$(dpkg --print-architecture) \
    signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] \
    https://cli.github.com/packages stable main" \
    | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
  sudo apt-get update -qq
  sudo apt-get install -y -qq gh
fi

# ------------------------------------------------------------------------------
# 4. Claude Code — native binary (Anthropic's recommended method)
# ------------------------------------------------------------------------------
echo "[4/6] Installing Claude Code..."
if ! command -v claude &>/dev/null; then
  curl -fsSL https://claude.ai/install.sh | bash
  # Ensure it's on PATH for the rest of this script
  export PATH="$HOME/.local/bin:$HOME/.claude/bin:$PATH"
fi

# ------------------------------------------------------------------------------
# 5. SSH key for GitHub (optional — skipped if key already exists)
# ------------------------------------------------------------------------------
echo "[5/6] Checking SSH key..."
if [ ! -f "$HOME/.ssh/id_ed25519" ]; then
  echo "  No SSH key found. Generating one..."
  mkdir -p "$HOME/.ssh"
  chmod 700 "$HOME/.ssh"
  ssh-keygen -t ed25519 -C "$GIT_EMAIL" -f "$HOME/.ssh/id_ed25519" -N ""
  echo ""
  echo "  *** Your new public key (add this to GitHub → Settings → SSH Keys): ***"
  cat "$HOME/.ssh/id_ed25519.pub"
  echo ""
else
  echo "  SSH key already exists, skipping."
fi

# Known hosts — prevents interactive prompt on first git clone
ssh-keyscan -H github.com   >> "$HOME/.ssh/known_hosts" 2>/dev/null
ssh-keyscan -H gitlab.com   >> "$HOME/.ssh/known_hosts" 2>/dev/null

# ------------------------------------------------------------------------------
# 6. Shell convenience aliases
# ------------------------------------------------------------------------------
echo "[6/6] Setting up shell aliases..."
cat >> "$HOME/.bashrc" << 'EOF'

# --- Ephemeral dev aliases ---
alias ll='ls -lah --color=auto'
alias gs='git status'
alias gd='git diff'
alias gp='git push'
alias gl='git log --oneline -10'
alias gc='git commit -am'
export PATH="$HOME/.local/bin:$HOME/.claude/bin:$PATH"
EOF

# ------------------------------------------------------------------------------
# Done
# ------------------------------------------------------------------------------
echo ""
echo "=============================================="
echo " Bootstrap complete: $(date)"
echo "=============================================="
echo ""
echo " Next steps:"
echo "   1. Add your SSH key to GitHub if newly generated (shown above)"
echo "   2. Authenticate GitHub CLI:   gh auth login"
echo "   3. Set your Anthropic API key: export ANTHROPIC_API_KEY=sk-ant-..."
echo "   4. Clone your project:         git clone git@github.com:you/project.git"
echo "   5. Start Claude Code:          cd project && claude"
echo ""
