{ config, pkgs, lib, ... }: {
  # Git and version control utility packages
  home.packages = with pkgs; [
    gitFull
    git-filter-repo
    lazygit
    delta
    difftastic
  ];
}
