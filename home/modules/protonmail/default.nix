# home/modules/protonmail/default.nix
{pkgs, ...}: {
  # Proton Mail desktop GUI (Electron app for Mail + Calendar)
  home.packages = [pkgs.protonmail-desktop];

  # Proton Mail Bridge: headless IMAP/SMTP proxy for use with external mail clients.
  # Runs as a systemd user service tied to the graphical session.
  # IMPORTANT: First-time setup requires running interactively once:
  #   protonmail-bridge --cli
  # Log in with Proton credentials, then save the generated app password to
  # 1Password (see secrets.env task below).
  services.protonmail-bridge = {
    enable = true;
    logLevel = "warn";
  };
}
