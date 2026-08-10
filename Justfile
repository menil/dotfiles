# ─── Lint ───────────────────────────────────────────────────
lint:
    shellcheck bootstrap.sh .githooks/commit-msg .githooks/pre-commit
    markdownlint .
    statix check .
    nix flake check --impure

# ─── Format ─────────────────────────────────────────────────
format:
    nixpkgs-fmt *.nix modules/*.nix lib/*.nix
    shfmt -w -i 2 -sr bootstrap.sh .githooks/commit-msg .githooks/pre-commit
    shfmt -w -i 2 -sr -ln=zsh src/home/.zshrc
    markdownlint --fix .

# ─── Check Format ───────────────────────────────────────────
check-format:
    nixpkgs-fmt --check *.nix modules/*.nix lib/*.nix
    shfmt -d -i 2 -sr bootstrap.sh .githooks/commit-msg .githooks/pre-commit
    shfmt -d -i 2 -sr -ln=zsh src/home/.zshrc
    markdownlint .

# ─── Validate (lint + check format) ─────────────────────────
validate: lint check-format

# ─── Agents ─────────────────────────────────────────────────
# Sync the src/agents submodule pointer to the latest agent-config commit
sync-agents:
    ./scripts/sync-agents.sh
