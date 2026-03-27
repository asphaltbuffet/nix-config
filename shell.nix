{pkgs}:
pkgs.mkShell {
  packages = [
    pkgs.nixd # nix LSP (understands flake option types)
    pkgs.alejandra # nix formatter
    pkgs.statix # nix linter
    pkgs.deadnix # find unused nix code
    pkgs.just # command runner (justfile recipes)
    pkgs.nh # nix helper (build/switch/test wrappers)
    pkgs.cachix # personal nix cache
    pkgs.jujutsu # version control (jj)
    pkgs.gh # github cli
    pkgs.phoronix-test-suite # benchmarking
    pkgs.p7zip # benchmark dependency
    pkgs.python3 # required by hookify claude plugin
    pkgs.nodejs # provides npx for MCP servers (e.g. context7)
    pkgs.nodePackages.mermaid-cli
  ];
  # phoronix-test-suite compiles test suites at runtime and needs these
  # as buildInputs so their headers/libs are on the compiler search paths
  buildInputs = [
    pkgs.libaio # required by pts/fio
    pkgs.openssl # required by pts/openssl (libressl lacks expected paths)
  ];
  shellHook = ''
    echo "nix-config dev shell"
    echo "  nixd       - nix language server"
    echo "  alejandra / statix / deadnix - format, lint, dead-code"
    echo "  just       - run: just <build|switch|test|fmt|check>"
    echo "  nh         - nix helper (used by just recipes)"
    echo "  jj         - jujutsu version control"
    echo "  npx        - node package runner (for MCP servers)"
  '';
}
