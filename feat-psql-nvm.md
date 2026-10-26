# AI Decision Record: Add psql and pinned nvm via Home Manager

## Context & Goal

The shell environment needed `psql` (PostgreSQL client) and `nvm` for
switching Node versions. The dotfiles are managed declaratively with
Home Manager, so both should be reproducible rather than installed by
hand. `nvm` is not packaged in nixpkgs or Home Manager, and its scripts
expect to write Node versions into `NVM_DIR`, which cannot live in the
read-only Nix store.

## Architecture & Key Decisions

- **`postgresql` in `home.packages`**: provides `psql`. It is the
  standard nixpkgs package, so no custom code is needed.
- **nvm pinned with `pkgs.fetchFromGitHub` (v0.40.8)**: gives a
  reproducible, hash-verified source that updates only when the pin is
  bumped deliberately.
- **Stable symlink `~/.local/share/nvm-sh`** (via `home.file`): points
  at the pinned scripts so `.zshrc` has a path that does not change when
  the store hash does.
- **Separate writable `NVM_DIR=~/.nvm`**: nvm installs Node versions
  into `NVM_DIR`, so it must be writable. `.zshrc` creates it and
  sources `nvm.sh` and `bash_completion` from the read-only symlink.
- Sourcing is guarded by `[ -s ... ]` so shells still start cleanly if
  the Home Manager profile has not been activated yet.

## Alternatives Considered & Rejected

- **Upstream `curl | bash` installer**: not reproducible, mutates
  dotfiles on its own, and bypasses the declarative setup.
- **Pointing `NVM_DIR` straight at the Nix store path**: the store is
  read-only, so `nvm install` would fail.
- **Relying only on the Nix-provided `nodejs`**: already present, but
  it is a single fixed version and cannot be switched per project.
- **Other version managers packaged in nixpkgs (fnm, volta, mise)**:
  not evaluated in depth; nvm was the tool requested for this change.
