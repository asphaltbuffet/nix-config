{inputs, ...}: {
  imports = [
    ./.
    ./power.nix
    inputs.nixos-hardware.nixosModules.lenovo-thinkpad-t14-intel-gen1
  ];
}
