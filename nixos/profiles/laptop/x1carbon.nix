{inputs, ...}: {
  imports = [
    ./. # laptop/default.nix: KDE, bluetooth, sddm, etc.
    ./power.nix # TLP + logind (adjust thresholds as needed)
    inputs.nixos-hardware.nixosModules.lenovo-thinkpad-x1-6th-gen
  ];
}
