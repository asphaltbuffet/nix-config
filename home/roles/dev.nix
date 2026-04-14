# home/roles/dev.nix
{
  pkgs,
  inputs,
  ...
}: {
  imports = [
    ../modules/claude
    ../modules/crush
    ../modules/delta
    ../modules/direnv
    ../modules/gh
    ../modules/jj
    ../modules/mise
    ../modules/nvim
  ];

  home.packages =
    (with pkgs; [
      gum
      ijq
      jq
      yq
      presenterm
    ])
    ++ [inputs.serena.packages.${pkgs.stdenv.hostPlatform.system}.serena];
}
