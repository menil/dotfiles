#!/usr/bin/env bash

# Multi-platform dotfiles bootstrap script

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Dotfiles Bootstrapping Script ===${NC}"

# 1. Detect Operating System
OS="$(uname -s)"
case "${OS}" in
Darwin)
  TARGET="macbook"
  echo -e "Detected OS: ${GREEN}macOS (Darwin)${NC}"
  echo -e "Configuring macOS system defaults..."
  defaults write dev.warp.Warp-Stable ApplePressAndHoldEnabled -bool false

  echo -e "Disabling macOS smart substitutions..."
  defaults write -g NSAutomaticCapitalizationEnabled -bool false
  defaults write -g NSAutomaticDashSubstitutionEnabled -bool false
  defaults write -g NSAutomaticPeriodSubstitutionEnabled -bool false
  defaults write -g NSAutomaticQuoteSubstitutionEnabled -bool false
  defaults write -g NSAutomaticSpellingCorrectionEnabled -bool false
  ;;
Linux)
  TARGET="linux-workstation"
  echo -e "Detected OS: ${GREEN}Linux${NC}"
  ;;
*)
  echo -e "${RED}Unsupported OS: ${OS}${NC}"
  exit 1
  ;;
esac

# 2. Check if Nix is installed
if ! command -v nix &> /dev/null; then
  echo -e "${RED}Nix package manager is not installed!${NC}"
  echo -e "We recommend the installer by Determinate Systems:"
  echo -e "${BLUE}curl --proto '=https' --tlsv1.2 -sSf -L https://install.lix.systems/lix | sh -s -- install${NC}"
  echo -e "Please install Nix, restart your terminal, and run this bootstrap script again."
  exit 1
else
  echo -e "Nix package manager is ${GREEN}installed${NC}."
fi

# 3. Configure Git hooks and submodules (only if inside a Git repository)
if git rev-parse --is-inside-work-tree &> /dev/null; then
  echo -e "Configuring git hooks path..."
  git config core.hooksPath .githooks

  echo -e "Initializing git submodules..."
  if ! err=$(git submodule update --init --recursive 2>&1); then
    echo -e "${RED}Warning: Failed to initialize private submodules: ${err}. Using public agent configuration defaults.${NC}"
  fi
fi

# 4. Configure local Git user details if not present
GITCONFIG_LOCAL="${HOME}/.gitconfig.local"
if [ ! -f "${GITCONFIG_LOCAL}" ]; then
  echo -e "\n${BLUE}Setting up local Git user configuration...${NC}"
  git_name=""
  git_email=""
  if [ -t 0 ]; then
    read -rp "Enter your full name for Git: " git_name || true
    read -rp "Enter your email for Git: " git_email || true
  fi

  # Fallback to global Git config values if available
  if [ -z "${git_name}" ]; then
    git_name="$(git config --global user.name || echo "")"
  fi
  if [ -z "${git_email}" ]; then
    git_email="$(git config --global user.email || echo "")"
  fi

  # If still empty, use placeholder defaults
  if [ -z "${git_name}" ]; then
    git_name="Your Name"
  fi
  if [ -z "${git_email}" ]; then
    git_email="your.email@example.com"
  fi

  cat << EOF > "${GITCONFIG_LOCAL}"
[user]
	name = ${git_name}
	email = ${git_email}
EOF
  echo -e "Created ${GREEN}${GITCONFIG_LOCAL}${NC}."
fi

# 5. Prompt for Activation
echo -e "\nReady to apply Home Manager configuration!"
echo -e "This will download and run Home Manager to symlink configuration files and install packages."
echo -e "To activate the configuration, run the following command:"
echo -e "\n${GREEN}nix run github:nix-community/home-manager -- switch --flake .#${TARGET} --impure${NC}\n"

echo -e "Note: If you have existing files like ~/.zshrc, Home Manager will ask you to rename or back them up before succeeding."
