{pkgs, ...}: {
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  # Default squashfs compression is zstd level 19; level 6 is ~3x faster to build
  # while still producing a reasonably compact ISO
  isoImage.squashfsCompression = "zstd -Xcompression-level 6";
  image.fileName = "nixos-installer.iso";

  environment.systemPackages = with pkgs; [
    parted
    gptfdisk
    neovim
    curl
    wget
  ];
}
