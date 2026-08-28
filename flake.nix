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
      # Builds every generated agent-instruction file and skill directory from
      # modules/agents.nix (not the full home-manager activation, which pulls in
      # the whole package set). This is the only thing that actually exercises
      # buildInlinedSkill's marker-splicing and its "unresolved reference"
      # assertion, so a broken PERSONAS_START/END or SUBAGENTS_START/END marker
      # fails `nix flake check` instead of only surfacing on a live
      # `home-manager switch`.
      agentSkillsCheck = system:
        let
          pkgs = import nixpkgs { inherit system; };
          inherit (pkgs) lib;
          agents = import ./modules/agents.nix { inherit pkgs lib; config = { }; };
          sourcedFiles = lib.filterAttrs (_: v: v ? source) agents.home.file;
        in
        pkgs.linkFarm "agent-skills-check" (
          lib.mapAttrsToList (name: v: { inherit name; path = v.source; }) sourcedFiles
        );
    in
    {
      checks = forAllSystems (system: {
        font-path = fontPathCheck system;
        agent-skills = agentSkillsCheck system;
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
