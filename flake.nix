{
  description = "Multi-platform Home Manager configuration using Nix Flakes";

  inputs = {
    # Nix Packages collections (unstable channel recommended for latest developer tools)
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";

    # Home Manager framework
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Beads dependency-aware task manager
    beads = {
      url = "github:gastownhall/beads";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, home-manager, beads, ... }:
    let
      forAllSystems = nixpkgs.lib.genAttrs [ "aarch64-darwin" "x86_64-linux" ];
      fontPathCheck = system:
        let
          pkgs = import nixpkgs { inherit system; };
          fontPkg = pkgs.nerd-fonts.jetbrains-mono;
          fontShareDir = "${fontPkg}/share/fonts";
          fontTypeDirs = builtins.attrNames (builtins.readDir fontShareDir);
          fontType = builtins.head fontTypeDirs;
          fontFamilyDir = "${fontShareDir}/${fontType}";
          fontFamilyDirs = builtins.attrNames (builtins.readDir fontFamilyDir);
          fontFamily = builtins.head fontFamilyDirs;
          fontDir = "${fontFamilyDir}/${fontFamily}/${font}";
          font = "JetBrainsMono";
        in
        pkgs.runCommand "font-path-check" { } ''
          test -d "${fontDir}"
          echo "Font path resolved: ${fontDir}"
          touch $out
        '';
    in
    {
      checks = forAllSystems (system: {
        font-path = fontPathCheck system;
      });

      homeConfigurations = {
        # Configuration for macOS hosts
        # Run with: home-manager switch --flake .#macbook
        "macbook" = home-manager.lib.homeManagerConfiguration {
          pkgs = import nixpkgs {
            system = "aarch64-darwin"; # Set to "x86_64-darwin" if on Intel Mac
            config.allowUnfree = true; # Allow proprietary software (e.g. vscode)
          };
          extraSpecialArgs = { inherit beads; };
          modules = [
            ./home.nix
          ];
        };

        # Configuration for Linux hosts (e.g., Ubuntu)
        # Run with: home-manager switch --flake .#linux-workstation
        "linux-workstation" = home-manager.lib.homeManagerConfiguration {
          pkgs = import nixpkgs {
            system = "x86_64-linux"; # Set to "aarch64-linux" for ARM Linux (Raspberry Pi/WSL ARM)
            config.allowUnfree = true;
          };
          extraSpecialArgs = { inherit beads; };
          modules = [
            ./home.nix
          ];
        };
      };
    };
}
