{ pkgs ? import <nixpkgs> { } }:

pkgs.mkShell {
  buildInputs = with pkgs; [
    just
    shellcheck
    shfmt
    nixpkgs-fmt
    markdownlint-cli
  ];
}
