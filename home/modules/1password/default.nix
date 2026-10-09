{
  osConfig,
  lib,
  pkgs,
  ...
}: {
  # The app is only installed where a desktop session runs (laptop profile);
  # headless hosts still get the desktop role, so skip the autostart there.
  xdg.configFile."autostart/1password.desktop" = lib.mkIf osConfig.services.desktopManager.plasma6.enable {
    text = ''
      [Desktop Entry]
      Type=Application
      Name=1Password
      Exec=${pkgs._1password-gui}/bin/1password
      X-GNOME-Autostart-enabled=true
    '';
  };
}
