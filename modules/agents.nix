{ config, pkgs, lib, ... }:
let
  # Private agent configurations live in the src/agents submodule. Nix flakes do
  # not copy submodule contents into the flake source, so resolve them against
  # the live checkout via DOTFILES_DIR (set in .zshrc) and fall back to the
  # sanitized in-repo defaults when unavailable.
  repoRoot = builtins.getEnv "DOTFILES_DIR";
  # privateDir resolves to a string to keep live checkout symlinking.
  # Any localized Nix store copy is performed selectively in derivations.
  privateDir = if repoRoot != "" then repoRoot + "/src/agents" else null;
  hasPrivateConfig = privateDir != null && builtins.pathExists (privateDir + "/allowed-commands.json");

  # Resolve paths dynamically
  allowedCommandsPath = if hasPrivateConfig then privateDir + "/allowed-commands.json" else ../src/allowed-commands.json;
  sharedRulesPath =
    if hasPrivateConfig && builtins.pathExists (privateDir + "/shared-rules.md") then privateDir + "/shared-rules.md"
    else ../src/shared-rules.md;
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

  # Sandbox allowed read paths for container execution
  sandboxSettings = {
    filesystem = {
      allowRead = [
        "/nix/store"
        "/System/Volumes/Data/nix/store"
      ];
    };
  };

  # Generate Claude Code settings
  claudeSettingsJson = builtins.toJSON {
    permissions = {
      # Use "acceptEdits" to allow the agent to modify workspace files automatically,
      # but prompt the user for execution of any shell commands not explicitly whitelisted.
      defaultMode = "acceptEdits";
      allow = map (cmd: "Bash(${cmd})") allowedCommands;
    };
    sandbox = sandboxSettings;
    # sox (required for audio capture) is installed in modules/shell.nix.
    voiceEnabled = true;
    # Omit the "Co-Authored-By: Claude" trailer and "Generated with Claude Code" line from commits and PRs.
    includeCoAuthoredBy = false;
  };
  claudeSettingsBase = pkgs.writeText "claude-settings-base.json" claudeSettingsJson;

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
      # OpenCode auto-loads skills from ~/.claude/skills/ and ~/.agents/skills/ in
      # addition to its own dirs, and it ignores Claude Code's
      # disable-model-invocation flag. Command-only workflows would therefore be
      # advertised to the model as auto-loadable skills AND registered as slash
      # commands, making argument handling (e.g. $ARGUMENTS) nondeterministic.
      # deny removes them from <available_skills> while the deployed slash
      # commands keep working. See isCommandOnly below.
      skill = lib.genAttrs commandOnlySkills (name: "deny");
    };
  };

  # Generate Antigravity settings
  antigravitySettingsJson = builtins.toJSON {
    permissions = {
      allow = map (cmd: "command(${cmd})") allowedCommands ++ [
        "read_file(/nix/store/)"
        "read_file(/System/Volumes/Data/nix/store/)"
      ];
    };
    # Configure preferred editor aligning with EDITOR env, falling back to nvim.
    editor = let envEditor = builtins.getEnv "EDITOR"; in if envEditor != "" then envEditor else "nvim";
    sandbox = sandboxSettings;
  };

  # Generate Codex settings (TOML format).
  # Codex uses OS-native sandboxing with permission profiles rather than a
  # per-command allowlist.  The custom "dotfiles-dev" profile extends the
  # built-in :workspace profile and adds /nix/store read access plus network
  # access for gh, git push, and package manager operations.
  #
  # NOTE: TOML is read from a separate file rather than inlined as a Nix
  # multi-line string because nixpkgs-fmt re-indents string content, which
  # breaks TOML parsing (bare keys must start at column 0).
  codexSettingsToml = builtins.readFile ../src/codex-config.toml;

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

  # Skills marked "disable-model-invocation: true" in their frontmatter are meant
  # to be triggered explicitly via slash command only. OpenCode ignores that flag:
  # it would advertise them as auto-loadable skills AND register them as slash
  # commands, making argument handling (e.g. `$ARGUMENTS`) nondeterministic.
  # Deploy those to OpenCode as commands only, not as skills.
  #
  # The flag is matched only inside the YAML frontmatter block so that the phrase
  # appearing in a skill's body text cannot cause a false positive.
  isCommandOnly = name:
    if skillsDir == null then false
    else
      let
        contents = builtins.readFile (skillsDir + "/${name}/SKILL.md");
        # `builtins.split` yields [prefix, ["---\n"], frontmatter, ["---\n"], body, ...].
        # Fall back to "" when there is no closing fence so frontmatter-less files
        # default to "not command-only" rather than being searched in full.
        frontmatter =
          let parts = builtins.split "---\n" contents;
          in if builtins.length parts < 4 then "" else builtins.elemAt parts 2;
      in
      lib.hasInfix "disable-model-invocation" frontmatter;

  commandOnlySkills = builtins.filter isCommandOnly skillDirs;

  # Set-based membership keeps classification linear in the number of skills.
  commandOnlySkillsSet = lib.genAttrs commandOnlySkills (name: true);

  # Locates the shared subagents definition file.
  # Note: The 'self-review' skill coordinates the same panel of subagents defined in the
  # 'review' skill, so both draw from the review/subagents.md configuration to avoid duplication.
  subagentsPath = if skillsDir != null then skillsDir + "/review/subagents.md" else null;
  hasSubagents = subagentsPath != null && builtins.pathExists subagentsPath;
  subagentsContent = if hasSubagents then builtins.readFile subagentsPath else "";

  # Inline subagents.md contents into SKILL.md for review-related skills.
  # This pre-processing is necessary because agent platforms (like Claude Code, OpenCode,
  # and Gemini) only parse and load the main SKILL.md file, ignoring relative links to
  # external markdown documents when preparing the system prompt context.
  # Replaces a block of text enclosed by startMarker and endMarker with replacement
  replaceBlock = startMarker: endMarker: replacement: contents:
    let
      parts = lib.splitString startMarker contents;
    in
    if builtins.length parts < 2 then contents
    else
      let
        prefix = builtins.elemAt parts 0;
        rest = lib.splitString endMarker (builtins.elemAt parts 1);
      in
      if builtins.length rest < 2 then contents
      else
        let
          suffix = lib.concatStringsSep endMarker (builtins.tail rest);
        in
        "${prefix}${replacement}${suffix}";

  # Inline subagents.md contents into SKILL.md for review-related skills.
  # This pre-processing is necessary because agent platforms (like Claude Code, OpenCode,
  # and Gemini) only parse and load the main SKILL.md file, ignoring relative links to
  # external markdown documents when preparing the system prompt context.
  inlineSubagents = name: contents:
    if (name == "review" || name == "self-review") && hasSubagents then
      let
        replacement = ''
          The subagent prompt descriptions, synthesis logic, output formatting rules, and strict validation restrictions (including the command execution ban) are defined below.

          - **In Antigravity**: Use the `invoke_subagent` tool to spawn 8 separate review subagents concurrently, one for each pass defined below.
          - **In Claude Code / OpenCode**: Emulate parallel execution by performing 8 distinct independent passes over the diff using the prompt definitions defined below and merge their results into the final summary matching the output format specified below.
        '';
        inlined = replaceBlock "<!-- SUBAGENTS_START -->\n" "<!-- SUBAGENTS_END -->" replacement contents;
      in
      "${inlined}\n\n${subagentsContent}"
    else
      contents;

  # Resolves the skill source path.
  # For 'review' and 'self-review' skills, we compile a new directory with the inlined SKILL.md.
  # For other skills, we symlink the original source directory directly.
  skillSource = name:
    if skillsDir == null then null
    else
      let
        originalSkillDir = skillsDir + "/${name}";
        # Coerce the string path to a Nix path type so that the Nix sandboxed
        # builder can copy the skill files from the Nix store during derivation build.
        originalSkillPath = /. + originalSkillDir;
      in
      if (name == "review" || name == "self-review") && hasSubagents then
        let
          originalSkillMd = builtins.readFile (originalSkillDir + "/SKILL.md");
          modifiedSkillMd = inlineSubagents name originalSkillMd;
        in
        pkgs.runCommand "skill-${name}"
          {
            inherit modifiedSkillMd;
            passAsFile = [ "modifiedSkillMd" ];
          } ''
          mkdir -p "$out"
          cp -rf "${originalSkillPath}/." "$out/"
          rm -f "$out/SKILL.md" "$out/subagents.md"
          cp -f "$modifiedSkillMdPath" "$out/SKILL.md"

          # Assert that all subagents.md references were successfully inlined and replaced
          if grep -Ei "subagents\.md" "$out/SKILL.md"; then
            echo "Error: Found unresolved subagents.md references in inlined SKILL.md for skill: ${name}" >&2
            exit 1
          fi
        ''
      else
        originalSkillDir;

  # Generate Home Manager mappings for all discovered skills.
  # It symlinks the entire directory recursively to allow auxiliary resources (scripts, references) to be mapped.
  skillMappings = lib.listToAttrs (lib.concatMap
    (name:
      let
        skillPath = skillSource name;
        # OpenCode auto-loads skills from skills/, so command-only skills deploy
        # as slash commands only (see isCommandOnly above).
        opencodeSkillMapping = lib.optional (!builtins.hasAttr name commandOnlySkillsSet)
          { name = ".config/opencode/skills/${name}"; value = { source = skillPath; }; };
      in
      [
        { name = ".claude/skills/${name}"; value = { source = skillPath; }; }
      ] ++ opencodeSkillMapping ++ [
        # OpenCode registers slash commands from flat markdown files inside the commands/ directory
        { name = ".config/opencode/commands/${name}.md"; value = { source = skillPath + "/SKILL.md"; }; }
        { name = ".gemini/config/skills/${name}"; value = { source = skillPath; }; }
        { name = ".pi/agent/skills/${name}"; value = { source = skillPath; }; }
        # Codex uses $skill-name for invocation; deploy all skills unconditionally
        { name = ".codex/skills/${name}"; value = { source = skillPath; }; }
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
    ".pi/agent/AGENTS.md".source = sharedRulesPath;
    ".codex/AGENTS.md".source = sharedRulesPath;

    # Dynamically generated configurations from the shared allowedCommands list.
    # ".claude/settings.json" is deliberately NOT deployed here (see the
    # claudeSettingsFile activation script below) because Claude Code writes
    # runtime state back into that file (e.g. /voice's hold/tap preference,
    # mic-permission flag, dictation-language hints) — a home.file symlink into
    # the read-only Nix store would make every such write fail.
    ".config/opencode/opencode.json".text = opencodeSettingsJson;
    ".gemini/antigravity-cli/settings.json".text = antigravitySettingsJson;
    ".codex/config.toml".text = codexSettingsToml;
  } // skillMappings;

  # Deploy .claude/settings.json as a real writable file instead of a symlink,
  # merging our managed keys (permissions, sandbox, voiceEnabled) on top of
  # whatever Claude Code has already written there at runtime, so those writes
  # survive across `home-manager switch` instead of being clobbered or, on a
  # symlinked file, failing outright.
  home.activation.claudeSettingsFile = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    claudeSettingsTarget="$HOME/.claude/settings.json"
    mkdir -p "$(dirname "$claudeSettingsTarget")"
    if [ -e "$claudeSettingsTarget" ] && [ ! -L "$claudeSettingsTarget" ]; then
      $DRY_RUN_CMD ${pkgs.jq}/bin/jq -s '.[0] * .[1]' "$claudeSettingsTarget" ${claudeSettingsBase} > "$claudeSettingsTarget.tmp"
      $DRY_RUN_CMD mv "$claudeSettingsTarget.tmp" "$claudeSettingsTarget"
    else
      $DRY_RUN_CMD rm -f "$claudeSettingsTarget"
      $DRY_RUN_CMD cp ${claudeSettingsBase} "$claudeSettingsTarget"
    fi
    $DRY_RUN_CMD chmod u+w "$claudeSettingsTarget"
  '';
}
