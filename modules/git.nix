{ config, pkgs, lib, ... }: {
  # Git and version control utility packages
  home.packages = with pkgs; [
    gitFull
    git-filter-repo
    lazygit
    delta
    difftastic
  ];

  # gh only discovers extensions in $XDG_DATA_HOME/gh/extensions; a bare
  # `gh-stack` on PATH is never resolved by `gh stack`. Symlink the package's
  # bin dir in so gh registers it as an installed extension.
  xdg.dataFile."gh/extensions/gh-stack" = {
    source = "${pkgs.gh-stack}/bin";
  };
}
