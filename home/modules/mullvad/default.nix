{...}:
{
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
}
