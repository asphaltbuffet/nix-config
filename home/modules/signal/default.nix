{pkgs, ...}: {
  home.packages = [pkgs.signal-desktop];

  xdg.configFile."autostart/signal-desktop.desktop".text = ''
    [Desktop Entry]
    Type=Application
    Name=Signal
    Exec=${pkgs.signal-desktop}/bin/signal-desktop
    X-GNOME-Autostart-enabled=true
  '';
}
