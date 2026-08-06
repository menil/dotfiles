{ config, pkgs, lib, beads, ... }:
let
  helpers = import ./lib/helpers.nix { inherit lib; };
in
{
  imports = [
    ./modules/shell.nix
    ./modules/editor.nix
    ./modules/git.nix
    ./modules/agents.nix
  ];

  # ─── Per-Machine Overrides ─────────────────────────────────
  # To add machine-specific configuration (e.g., a new host):
  #   1. Create a new output in flake.nix's homeConfigurations
  #   2. Add a new module file (e.g., hosts/myhost.nix) and import it
  #      in that output's modules list
  #   3. Use lib.mkDefault / lib.mkOverride in that module to
  #      selectively override values from home.nix or modules/
  # ───────────────────────────────────────────────────────────

  # Home Manager needs a bit of information about you and the paths it should manage.
  # These are set to sensible defaults but can be overridden in host-specific files.
  home.username = lib.mkDefault (builtins.getEnv "USER");
  home.homeDirectory = lib.mkDefault (builtins.getEnv "HOME");

  # This value determines the Home Manager release that your configuration is
  # compatible with. This helps avoid breakage if new Home Manager release
  # introduces backwards incompatible changes.
  home.stateVersion = "25.11";

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;

  # Raw Configuration Files (Symlinked directly from your repo)
  home.file = helpers.toHomeFiles ./src/home;
}
