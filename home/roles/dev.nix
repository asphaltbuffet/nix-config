# home/roles/dev.nix
{
  pkgs,
  lib,
  ...
}: {
  imports = [
    ../modules/delta
    ../modules/mise
  ];

  home.packages = with pkgs; [
    # go
    gccgo15

    git-absorb
    go-task
    gum
    ijq
    jq
    jujutsu
    presenterm
    taplo
    tig
    uv

    # nur
    nur.repos.goreleaser.goreleaser-pro
  ];
}
