{ config, pkgs, lib, ... }:
let
  # Private agent configurations live in the src/agents submodule. Nix flakes do
  # not copy submodule contents into the flake source, so resolve them against
  # the live checkout via DOTFILES_DIR (set in .zshrc) and fall back to the
  # sanitized in-repo defaults when unavailable.
  repoRoot = builtins.getEnv "DOTFILES_DIR";
  privateDir = if repoRoot != "" then repoRoot + "/src/agents" else null;
  hasPrivateConfig = privateDir != null && builtins.pathExists (privateDir + "/allowed-commands.json");

  # Resolve paths dynamically
  allowedCommandsPath = if hasPrivateConfig then privateDir + "/allowed-commands.json" else ../src/allowed-commands.json;
  sharedRulesPath = if hasPrivateConfig then privateDir + "/shared-rules.md" else ../src/shared-rules.md;
  skillsDir =
    if hasPrivateConfig && builtins.pathExists (privateDir + "/skills") then privateDir + "/skills"
    else if builtins.pathExists ../src/skills then ../src/skills
    else null;

  # Read commands from the resolved allowed-commands.json file
  allowedCommands = builtins.fromJSON (builtins.readFile allowedCommandsPath);

  # Commands that are safe to auto-approve with arguments (read-only, no side effects).
  # OpenCode uses last-match-wins wildcard matching, so bare "git diff" won't match
  # "git diff HEAD...main". These prefixes get additional "cmd *" entries.
  readOnlyPrefixes = [
    "git diff"
    "git status"
    "git log"
    "git show"
    "git rev-parse"
    "git show-ref"
    "git rev-list"
    "git ls-files"
    "git diff-index"
    "git diff-files"
    "git diff-tree"
    "ls"
    "rg"
    "grep"
    "pwd"
    "which"
    "file"
    "head"
    "tail"
    "sort"
    "uniq"
    "wc"
    "gh pr"
  ];

  # Check if a command starts with any read-only prefix
  isReadOnly = cmd: lib.any (prefix: lib.hasPrefix prefix cmd) readOnlyPrefixes;

  # Generate Claude Code settings
  claudeSettingsJson = builtins.toJSON {
    permissions = {
      # Use "acceptEdits" to allow the agent to modify workspace files automatically,
      # but prompt the user for execution of any shell commands not explicitly whitelisted.
      defaultMode = "acceptEdits";
      allow = map (cmd: "Bash(${cmd})") allowedCommands;
    };
  };

  # Generate OpenCode settings
  opencodeSettingsJson = builtins.toJSON {
    "$schema" = "https://opencode.ai/config.json";
    permission = {
      bash = {
        "*" = "ask";
      } // lib.listToAttrs (
        (map (cmd: { name = cmd; value = "allow"; }) allowedCommands)
          ++ (map (cmd: { name = "${cmd} *"; value = "allow"; }) (lib.filter isReadOnly allowedCommands))
      );
    };
  };

  # Generate Antigravity settings
  antigravitySettingsJson = builtins.toJSON {
    permissions = {
      allow = map (cmd: "command(${cmd})") allowedCommands ++ [
        "read_file(/nix/store)"
      ];
    };
    # Configure the agent's preferred editor to align dynamically with the host's EDITOR environment
    # variable, falling back to neovim ("nvim") if it is unset or empty.
    editor = let envEditor = builtins.getEnv "EDITOR"; in if envEditor != "" then envEditor else "nvim";
  };

  # Dynamically discover only directories under skillsDir that contain a SKILL.md file.
  # Path addition is used instead of string interpolation to adhere to the flake check requirements.
  # If no private or public skills directory exists, no skills are mapped.
  skillDirs = if skillsDir == null then [ ] else
  builtins.attrNames (
    lib.filterAttrs
      (name: type:
        type == "directory" && builtins.pathExists (skillsDir + "/${name}/SKILL.md")
      )
      (builtins.readDir skillsDir)
  );

  # Generate Home Manager mappings for all discovered skills.
  # This uses lib.concatMap and lib.listToAttrs for linear O(N) evaluation complexity.
  # It symlinks the entire directory recursively to allow auxiliary resources (scripts, references) to be mapped.
  skillMappings = lib.listToAttrs (lib.concatMap
    (name:
      let
        skillPath = skillsDir + "/${name}";
      in
      [
        { name = ".claude/skills/${name}"; value = { source = skillPath; }; }
        { name = ".config/opencode/skills/${name}"; value = { source = skillPath; }; }
        # OpenCode registers slash commands from flat markdown files inside the commands/ directory
        { name = ".config/opencode/commands/${name}.md"; value = { source = skillPath + "/SKILL.md"; }; }
        { name = ".gemini/config/skills/${name}"; value = { source = skillPath; }; }
      ]
    )
    skillDirs);
in
{
  home.file = {
    # Symlink the shared rules file to all your AI agents
    ".claude/CLAUDE.md".source = sharedRulesPath;
    ".opencode/instructions.md".source = sharedRulesPath;
    ".gemini/config/AGENTS.md".source = sharedRulesPath;

    # Dynamically generated configurations from the shared allowedCommands list
    ".claude/settings.json".text = claudeSettingsJson;
    ".config/opencode/opencode.json".text = opencodeSettingsJson;
    ".gemini/antigravity-cli/settings.json".text = antigravitySettingsJson;
  } // skillMappings;
}
