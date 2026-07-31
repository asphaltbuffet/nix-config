{pkgs, ...}: {
  programs.mullvad-vpn = {
    enable = true;

    settings = {
      autoConnect = true;
      # enableSystemNotifications = true;
      # monochromaticIcon = false;
      startMinimized = true;
      # browsedForSplitTunnelingApplications = [];
      # animateMap = true;
    };
  };

  xdg.configFile."autostart/mullvad-vpn.desktop".text = ''
    [Desktop Entry]
    Type=Application
    Name=Mullvad VPN
    Exec=${pkgs.mullvad-vpn}/bin/mullvad-vpn
    X-GNOME-Autostart-enabled=true
  '';
}
