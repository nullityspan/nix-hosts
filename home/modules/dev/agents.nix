# Coding agents and the MCP servers every project gets. Servers are declared
# once in programs.mcp; agents opt in via enableMcpIntegration.
{
  inputs,
  unstable,
  pkgs,
  ...
}:
let
  # Without a pinned seed, `graphify update` re-execs `python -m graphify`,
  # which loses the site dirs the Nix wrapper injects ("No module named graphify").
  graphify = pkgs.symlinkJoin {
    name = "graphify";
    paths = [ graphifyPatched ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = "wrapProgram $out/bin/graphify --set-default PYTHONHASHSEED 0";
  };
  # graphify has no Nix parser; graphify-nix.py adds one. --replace-fail makes
  # an upstream change that moves an anchor break the build, not the parser.
  graphifyPatched = unstable.graphify.overridePythonAttrs (old: {
    postPatch = (old.postPatch or "") + ''
      substitute ${./graphify-nix.py} graphify/extractors/nix.py \
        --replace-fail @grammar@ ${unstable.tree-sitter-grammars.tree-sitter-nix}/parser
      substituteInPlace graphify/detect.py \
        --replace-fail "'.zig'," "'.zig', '.nix',"
      substituteInPlace graphify/extract.py \
        --replace-fail 'from graphify.extractors.zig import extract_zig' \
          'from graphify.extractors.zig import extract_zig; from graphify.extractors.nix import extract_nix' \
        --replace-fail '".zig": extract_zig,' '".zig": extract_zig, ".nix": extract_nix,'
      substituteInPlace graphify/cli.py \
        --replace-fail "'.sh', '.md'," "'.nix', '.sh', '.md',"
    '';
  });
  # The skill needs a Python that imports graphify. Its own detection reads the
  # shebang of bin/graphify, which is a bash wrapper here, then tries pip.
  graphifyPython = unstable.python3.withPackages (p: [ (p.toPythonModule graphifyPatched) ]);
  # The package ships the skill as skill.md beside its references.
  graphifySkill = pkgs.runCommand "graphify-skill" { } ''
    src=$(echo ${graphifyPatched}/lib/python*/site-packages/graphify)
    mkdir $out
    substitute $src/skill.md $out/SKILL.md \
      --replace-fail 'PYTHON=""' 'PYTHON="${graphifyPython}/bin/python3"'
    cp -r $src/skills/claude/references $out/
  '';
  # Model ids or aliases. The daily driver (opus, medium effort) is chosen in
  # Claude Code itself; these are the roles agents and skills pin.
  models = {
    orchestrator = "opus";
    worker = "haiku";
    vision = "sonnet";
  };
in
{
  home.packages = [
    graphify
    unstable.nodejs
  ];

  programs.mcp = {
    enable = true;
    servers = {
      nixos.command = "${pkgs.mcp-nixos}/bin/mcp-nixos";
      context7.command = "${pkgs.context7-mcp}/bin/context7-mcp";
    };
  };

  programs.claude-code = {
    enable = true;
    package = unstable.claude-code;
    enableMcpIntegration = true;
    plugins = [ inputs.ponytail ];
    skills = {
      graphify = graphifySkill;
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
    agents.vision = ''
      ---
      name: vision
      description: Reads images, screenshots, plots and scanned PDFs and reports what they show. Use when a task depends on visual content.
      model: ${models.vision}
      ---

      Describe only what is visible in the files named in the prompt. Quote text exactly.
      Say plainly when something is unreadable or ambiguous instead of guessing.
      Finish with a short report that answers the question in the prompt.
    '';
  };
}
