{
  inputs,
  pkgs,
  ...
}: {
  imports = [
    inputs.elf.homeManagerModules.default
  ];

  programs.elf = {
    enable = true;
    package = inputs.elf.packages.${pkgs.stdenv.hostPlatform.system}.default;

    settings = {
      language = "go";
    };
  };
}
