# home/modules/wishlist/default.nix
{pkgs, ...}: {
  # wishlist: TUI SSH directory. Reads hosts from ~/.ssh/config automatically.
  # Tailscale hosts are defined in home/modules/ssh/default.nix as matchBlocks.
  # Usage: wishlist
  home.packages = [pkgs.wishlist];
}
