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
in
{
  home.packages = [ unstable.graphify ];

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
    skills.graphify = graphifySkill;
  };
}
