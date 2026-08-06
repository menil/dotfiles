{ config, pkgs, lib, beads, ... }:
let
  fontPkg = pkgs.nerd-fonts.jetbrains-mono;
  fontShareDir = "${fontPkg}/share/fonts";
  fontTypeDirs = builtins.attrNames (builtins.readDir fontShareDir);
  fontType = builtins.head fontTypeDirs;
  fontFamilyDir = "${fontShareDir}/${fontType}";
  fontFamilyDirs = builtins.attrNames (builtins.readDir fontFamilyDir);
  fontFamily = builtins.head fontFamilyDirs;
  fontDir = "${fontFamilyDir}/${fontFamily}";
  font = "JetBrainsMono";
in
{
  home.packages = with pkgs; [
    # Core terminal utilities
    ripgrep
    fd
    htop
    curl
    jq

    # Syntax highlighting and colorized utilities
    eza
    bat
    sourceHighlight
    zsh-syntax-highlighting
    fzf
    zsh-autosuggestions
    jless
    btop
    dust
    starship
    zellij
    tealdeer
    fastfetch

    # Fonts
    nerd-fonts.jetbrains-mono

    # Development languages and tools
    nodejs
    direnv
    nix-direnv
    beads.packages.${pkgs.system}.default
  ] ++ (lib.optionals pkgs.stdenv.isDarwin [
    # macOS-only packages
    terminal-notifier
  ]) ++ (lib.optionals pkgs.stdenv.isLinux [
    # Linux-only packages
    inotify-tools
  ]);

  # Platform-specific configurations
  home.file = lib.optionalAttrs pkgs.stdenv.isDarwin {
    "Library/Fonts/JetBrainsMono" = {
      source = "${fontDir}/${font}";
      recursive = true;
    };
  };

  # Environment Variables
  home.sessionVariables = {
    AI_CONFIG_ROOT = "${config.home.homeDirectory}/.config/ai";
    OS_TYPE = if pkgs.stdenv.isDarwin then "darwin" else "linux"; # Platform detection for host-specific scripts
  };
}
