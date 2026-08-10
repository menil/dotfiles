{ pkgs ? import <nixpkgs> { } }:

pkgs.mkShell {
  buildInputs = with pkgs; [
    just
    shellcheck
    shfmt
    nixpkgs-fmt
    statix
    markdownlint-cli
  ];
}
