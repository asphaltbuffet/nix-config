# home/roles/dev.nix
{
  pkgs,
  lib,
  ...
}: {
  imports = [
    ../modules/delta
    ../modules/go
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
    mise
    presenterm
    taplo
    tig
    uv

    # nur
    nur.repos.goreleaser.goreleaser-pro
  ];
}
