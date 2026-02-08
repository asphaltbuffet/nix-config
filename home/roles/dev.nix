# home/roles/dev.nix
{
  pkgs,
  lib,
  ...
}: {
  imports = [
    ../modules/claude
    ../modules/delta
    ../modules/jj
    ../modules/mise
    ../modules/nvim
  ];

  home.packages = with pkgs; [
    # go
    gccgo15

    git-absorb
    go-task
    gum
    ijq
    jq
    presenterm
    taplo
    tig
    uv

    # nur
    nur.repos.goreleaser.goreleaser-pro
  ];
}
