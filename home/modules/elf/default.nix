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
    package = inputs.elf.packages.${pkgs.system}.default;

    settings = {
      language = "go";
    };
  };
}
