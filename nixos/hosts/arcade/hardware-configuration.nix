# nixos/hosts/arcade/hardware-configuration.nix
# PLACEHOLDER — replace with the output of `nixos-generate-config` generated
# on the physical cabinet during bootstrap (real filesystems, kernel modules,
# and CPU microcode go here). This stub only lets the flake evaluate before
# the machine is installed. Do NOT deploy with this stub in place.
{lib, ...}: {
  boot.initrd.availableKernelModules = ["xhci_pci" "ahci" "nvme" "usbhid" "sd_mod"];
  boot.loader.systemd-boot.enable = lib.mkDefault true;

  # Placeholder root filesystem — the real device/UUID comes from bootstrap.
  fileSystems."/" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "ext4";
  };

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
