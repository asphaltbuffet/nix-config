{
  pkgs,
  lib,
  ...
}: {
  imports = [../common/compat.nix];

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  # Default squashfs compression is zstd level 19; level 6 is ~3x faster to build
  # while still producing a reasonably compact ISO
  isoImage.squashfsCompression = "zstd -Xcompression-level 6";
  # The ISO builder names its output from image.baseName (image.fileName is
  # derived metadata it never reads), and iso-image.nix sets baseName itself.
  image.baseName = lib.mkForce "nixos-installer";

  environment.systemPackages = with pkgs; [
    parted
    gptfdisk
    neovim
    curl
    wget
  ];
}
