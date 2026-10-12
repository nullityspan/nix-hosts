# Coding agents and the MCP servers every project gets. Servers are declared
# once in programs.mcp; agents opt in via enableMcpIntegration.
{
  inputs,
  pkgs,
  ...
}:
let
  unstable = import inputs.nixpkgs-unstable {
    inherit (pkgs.stdenv.hostPlatform) system;
    config.allowUnfree = true;
  };
  # The package ships the skill as skill.md beside its references.
  graphifySkill = pkgs.runCommand "graphify-skill" { } ''
    src=$(echo ${unstable.graphify}/lib/python*/site-packages/graphify)
    mkdir $out
    cp $src/skill.md $out/SKILL.md
    cp -r $src/skills/claude/references $out/
  '';
  # Model ids or aliases (opus, sonnet, haiku) for the delegate skill.
  models = {
    orchestrator = "opus";
    worker = "haiku";
  };
  grill = "${inputs.mattpocock-skills}/skills/productivity";
in
{
  home.packages = [
    unstable.graphify
    unstable.nodejs
  ];

  programs.mcp = {
    enable = true;
    servers = {
      nixos.command = "${pkgs.mcp-nixos}/bin/mcp-nixos";
      context7.command = "${pkgs.context7-mcp}/bin/context7-mcp";
      fetch.command = "${pkgs.mcp-server-fetch}/bin/mcp-server-fetch";
      git.command = "${pkgs.mcp-server-git}/bin/mcp-server-git";
    };
  };

  programs.claude-code = {
    enable = true;
    package = unstable.claude-code;
    enableMcpIntegration = true;
    plugins = [
      inputs.caveman
      inputs.ponytail
    ];
    skills = {
      graphify = graphifySkill;
      # grill-me only forwards to grilling, so both ship.
      grill-me = "${grill}/grill-me";
      grilling = "${grill}/grilling";
      delegate = ''
        ---
        name: delegate
        description: Plan a task and hand its independent pieces to cheap worker subagents. Use when the user says "delegate", "/delegate", or asks to farm work out to subagents.
        model: ${models.orchestrator}
        ---

        You are the orchestrator. Keep judgment here; push mechanical work to workers.

        1. Read only what you need to split the task. Break it into self-contained pieces, each with a clear done condition.
        2. Spawn one `delegate-worker` subagent per piece with the Agent tool. Send independent pieces in a single message so they run in parallel. Each prompt must stand alone: goal, exact files or paths, constraints, and what to report back.
        3. Keep for yourself: design decisions, cross-file reasoning, anything security-sensitive, and pieces that depend on another piece's result.
        4. Review every worker report against its done condition. Re-delegate or fix inline when a report is wrong or incomplete.
        5. Report the combined result to the user. Say which pieces failed or went unchecked.
      '';
    };
    agents.delegate-worker = ''
      ---
      name: delegate-worker
      description: Cheap worker for one well-scoped piece of a delegated task. Spawned by the delegate skill.
      model: ${models.worker}
      ---

      Do exactly the task in the prompt, nothing more. Do not widen scope or refactor surrounding code.
      If the prompt is ambiguous or the task needs a design decision, stop and report the question instead of guessing.
      Finish with a short report: what you changed (file:line), what you verified, and anything left undone.
    '';
  };
}
