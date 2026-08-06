# Multi-Platform Home Manager Dotfiles Configuration

A clean, modern, and robust starter template to manage user configurations, packages, and raw dotfiles on macOS and Linux using **Nix Flakes** and **Home Manager**.

---

## Features

- **Cross-Platform:** Single configuration repo supporting macOS (`aarch64-darwin` / `x86_64-darwin`) and Linux (`x86_64-linux`).
- **Nix-Managed Symlinks:** Keep editing your configurations in plain text. Nix automatically and recursively symlinks everything from the `src/home/` directory to the correct location in your `$HOME` directory.
- **Modern CLI & Developer Tools:**
  - `starship` - Fast, customizable, and intelligent cross-shell prompt.
  - `bat` - A `cat` clone with syntax highlighting and Git integration.
  - `eza` - Modern replacement for `ls` with file icons, colors, and trees.
  - `delta` - High-performance syntax-highlighting pager for git diffs, status, and merges.
  - `fzf` - Command-line fuzzy finder with syntax-highlighted previews.
  - `btop` - Interactive process and system resource monitor.
  - `dust` - Visual disk usage analyzer (replacement for `du`).
  - `jless` - Interactive, command-line JSON viewer and explorer.
  - `direnv` & `nix-direnv` - Automatically load Nix shell environments upon entering directories.
- **Shell & Editor Enhancements:**
  - Custom `.zshrc` setup with interactive auto-suggestions (`zsh-autosuggestions`), syntax highlighting (`zsh-syntax-highlighting`), custom LS colors, and handy aliases.
  - Neovim configured with Lua, persistent line numbering, modern defaults, and responsive navigation.
  - Automatically configured fonts (e.g. JetBrainsMono Nerd Font on macOS).
- **Shared AI Agent Instructions & Submodule Integration:**
  - Syncs global rules, safe command whitelists, and custom workflows to all local AI coding agents (Claude Code, OpenCode, Antigravity). Supports private configurations via Git Submodules with automatic public fallback defaults.
- **Mandatory Repository Quality:**
  - Automated formatting and linting workflows built in (`nixpkgs-fmt`, `shfmt`, `shellcheck`, and `markdownlint`).
  - Pre-configured git hooks to validate style and formatting on commit, and enforce Conventional Commits.

---

## Directory Structure

```text
.
├── flake.nix             # Main entry point mapping machine profiles to configs
├── home.nix              # Common packages, variables, and file mappings
├── Justfile              # Command recipe runner (linting/formatting tasks)
├── shell.nix             # Nix development shell containing repository tools
├── bootstrap.sh          # Setup helper script to initialize git and hooks
├── .markdownlint.json    # Markdown linting preferences
├── .githooks/            # Repository git hooks
│   ├── commit-msg        # Enforces conventional commit messages
│   └── pre-commit        # Runs linting/formatting checks before committing
└── src/
    ├── agents/           # [SUBMODULE] Private agent configurations (whitelists, rules, skills)
    ├── allowed-commands.json # Public fallback whitelist of safe commands for coding agents
    ├── shared-rules.md   # Public fallback rules and standards for AI coding agents
    └── home/             # Raw plain-text dotfiles (mapped recursively to your home directory)
        ├── .zshrc        # Custom Zsh shell configuration
        ├── .gitconfig    # Git settings (configures git-delta as the default pager)
        └── .config/
            └── starship.toml # Custom Starship prompt configuration
```

---

## Setup & Activation

### 1. Install Nix

If Nix is not already installed, run the recommended installer:

```bash
curl --proto '=https' --tlsv1.2 -sSf -L https://install.lix.systems/lix | sh -s -- install
```

### 2. Run the Bootstrap Script

Run the helper script from the root of your dotfiles repository to initialize git, stage configurations, and configure git hooks:

```bash
./bootstrap.sh
```

### 3. Activate Configurations

To apply configurations to your machine, use the standard command printed by the bootstrap script:

**On macOS:**

```bash
nix run github:nix-community/home-manager -- switch --flake .#macbook
```

**On Linux:**

```bash
nix run github:nix-community/home-manager -- switch --flake .#linux-workstation
```

---

## Repository Maintenance

The repository includes a development nix shell (`shell.nix`) and a `Justfile` recipe runner to verify code formatting and standards.

### Working inside the Nix Shell

To launch a shell containing all required linting and formatting utilities (`shellcheck`, `shfmt`, `nixpkgs-fmt`, `markdownlint-cli`, and `just`), run:

```bash
nix-shell
```

From within the Nix Shell (or by prefixing commands with `nix-shell --run`), you can run the following tasks:

- **Lint Code:**

  ```bash
  just lint
  ```

- **Automatically Format Code:**

  ```bash
  just format
  ```

- **Validate Repository Standards (Lint + Format check):**

  ```bash
  just validate
  ```

### Git Hooks

The repository uses custom Git hooks:

- **`pre-commit`**: Automatically runs `just validate` within the Nix shell to ensure that unstaged changes follow all repository standards and formats before allowing the commit.
- **`commit-msg`**: Validates that your commit messages follow [Conventional Commits](https://www.conventionalcommits.org/) standards and do not exceed line length limits.

---

## How to Customize

### Add a Raw Dotfile

1. Put the plain text file inside the `src/home/` directory (matching the path you want in your home directory). For example, `src/home/.tmux.conf` will map to `~/.tmux.conf`.
2. Stage the new file in Git (Nix Flakes ignore files that aren't tracked):

   ```bash
   git add src/home/.tmux.conf
   ```

3. Re-apply the changes:

   ```bash
   home-manager switch --flake .#macbook
   ```

### Add a Symlinked Configuration Directory

If you have a folder of raw files (like a Neovim configuration in `.config/nvim`), you can simply place the directory inside `src/home/.config/nvim/`.

1. Move the folder to `src/home/.config/nvim/`.
2. Stage and apply:

   ```bash
   git add src/home/.config/nvim
   home-manager switch --flake .#macbook
   ```

*(Note: The `toHomeFiles` helper function in `home.nix` dynamically maps all files inside `./src/home` recursively.)*

### Add Packages

Add any Nix packages to the `home.packages` list in `home.nix`. You can find package names at [search.nixos.org/packages](https://search.nixos.org/packages).
