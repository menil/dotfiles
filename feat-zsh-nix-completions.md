# AI Decision Record: Nix and Home Manager Zsh Completion Path Configuration

## Context & Goal
CLI utilities installed via Nix profiles (user profile at `~/.nix-profile`, system default profile at `/nix/var/nix/profiles/default`) and Homebrew on macOS (`/opt/homebrew`) install completion definitions into `<prefix>/share/zsh/site-functions`. In interactive shell sessions, Zsh completion (`compinit`) was not discovering these completions unless the directories were explicitly added to `fpath` prior to `compinit` initialization.

## Architecture & Key Decisions
- **Fpath Pre-population Loop**: Iterate over candidate completion directories (`$HOME/.nix-profile/share/zsh/site-functions`, `/nix/var/nix/profiles/default/share/zsh/site-functions`, `/opt/homebrew/share/zsh/site-functions`), check for directory existence (`-d`), and prepend them to `fpath`.
- **Explicit compinit Invocation**: Initialize Zsh completion system via `autoload -Uz compinit && compinit` directly following the `fpath` configuration.
- **Cross-platform Compatibility**: Checks ensure only valid, existing directories on the active host (macOS Apple Silicon or Linux) are appended without generating warnings or invalid lookups.

## Alternatives Considered & Rejected
- *Static Fpath Assignment*: Hardcoding paths without checking directory existence was rejected to avoid bloating `fpath` with missing paths across diverse environments.
- *Relying solely on Home Manager zsh module*: Standalone tools installed imperatively or through separate nix profiles wouldn't have their completion functions discovered.
