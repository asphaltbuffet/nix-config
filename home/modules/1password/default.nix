{pkgs, ...}: {
  xdg.configFile."autostart/1password.desktop".text = ''
    [Desktop Entry]
    Type=Application
    Name=1Password
    Exec=${pkgs._1password-gui}/bin/1password
    X-GNOME-Autostart-enabled=true
  '';
}
