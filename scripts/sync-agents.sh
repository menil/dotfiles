#!/usr/bin/env bash
# Sync the src/agents submodule to the latest agent-config commit and publish
# the new pointer so fresh clones of the public repo resolve to current
# agent-config. Runs automatically as part of `hms` and manually via
# `just sync-agents`. Privacy is preserved: the public repo only ever records
# a gitlink (commit SHA), never the private content itself.
set -euo pipefail

DOTFILES="${DOTFILES_DIR:-$HOME/workspace/dotfiles}"
SUBMODULE="src/agents"

# Fresh clones may not have the submodule checked out yet; nothing to sync.
git -C "$DOTFILES/$SUBMODULE" rev-parse --git-dir >/dev/null 2>&1 || exit 0

# Pull the latest agent-config commit from its remote (submodule.<name>.branch).
# A transient failure (network, SSH auth) must not abort `hms`, so warn and
# keep the previously recorded pointer rather than silently pretending the
# submodule is up to date.
if ! git -C "$DOTFILES" submodule update --remote --quiet "$SUBMODULE"; then
  echo "warning: failed to update $SUBMODULE submodule; keeping recorded pointer" >&2
  exit 0
fi

# Publish only from the default branch: a pointer committed on a feature branch
# would never be merged and would clutter that branch's history. The local
# submodule checkout above already tracks latest, so a non-main branch just
# skips the commit/push.
BRANCH="$(git -C "$DOTFILES" symbolic-ref --short -q HEAD 2>/dev/null)" || exit 0
if [[ "$BRANCH" != "main" ]]; then
  echo "warning: on '$BRANCH', not 'main'; keeping pointer local" >&2
  exit 0
fi

# Record the new pointer only if it actually moved; skip commit when unchanged.
git -C "$DOTFILES" add "$SUBMODULE"
git -C "$DOTFILES" diff --cached --quiet -- "$SUBMODULE" && exit 0

# --no-verify: this is a mechanical gitlink-only commit; the repo's full
# validation (nix flake check, markdownlint) is irrelevant to it.
git -C "$DOTFILES" commit --no-verify --only \
  -m "chore: sync $SUBMODULE to $(git -C "$DOTFILES/$SUBMODULE" rev-parse --short HEAD)" \
  -- "$SUBMODULE" || exit 0

# Publish so authorized clones of the public repo pick up the pointer. Non-fatal.
git -C "$DOTFILES" push >/dev/null 2>&1 || true
