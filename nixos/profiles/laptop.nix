# nixos/profiles/laptop.nix
{ config, pkgs, lib, ... }:
{
  #### Display server / desktop environment ####
  services.xserver.enable = true;

  # Display manager
  services.displayManager.sddm.enable = true;

  # Desktop environment (KDE Plasma 6)
  services.desktopManager.plasma6.enable = true;

  #### Optional desktop services ####
  hardware.bluetooth.enable = true;
  services.blueman.enable = true;

  # Printing (already enabled in base.nix, but can strengthen here)
  services.printing.enable = lib.mkDefault true;

  #### Desktop-related system packages ####
  environment.systemPackages = with pkgs; [
    xdg-utils        # useful for opening URLs
    pavucontrol      # audio control GUI
    # Add any desktop apps you want every graphical system to have
  ];

  #### XDG integration ####
  xdg.portal.enable = true;
  xdg.portal.extraPortals = with pkgs; [
    xdg-desktop-portal-gtk
  ];
}

