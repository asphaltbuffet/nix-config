# home/roles/dev.nix
{pkgs, ...}: {
  imports = [
    ../modules/claude
    ../modules/crush
    ../modules/delta
    ../modules/elf
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
    nixd
    presenterm
    taplo
    tig
    upx
    uv

    # nur
    nur.repos.goreleaser.goreleaser-pro
  ];
}
