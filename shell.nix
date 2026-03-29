{pkgs}:
pkgs.mkShell {
  packages = [
    pkgs.nixd # nix LSP (understands flake option types)
    pkgs.alejandra # nix formatter
    pkgs.statix # nix linter
    pkgs.deadnix # find unused nix code
    pkgs.just # command runner (justfile recipes)
    pkgs.nh # nix helper (build/switch/test wrappers)
    pkgs.nvd # nix diff
    pkgs.cachix # personal nix cache
    pkgs.jujutsu # version control (jj)
    pkgs.gh # github cli
    pkgs.python3 # required by hookify claude plugin
    pkgs.nodejs # provides npx for MCP servers (e.g. context7)
    pkgs.uv # python package manager (used by serena MCP server)
    pkgs.nodePackages.mermaid-cli
  ];
}
