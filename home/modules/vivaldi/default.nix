# Per-login Vivaldi install. Enforced settings (extensions, telemetry,
# password manager) are Browser policies in nixos/common/vivaldi.nix —
# Vivaldi rewrites its own Preferences JSON at runtime, so it can't be
# managed from here.
{pkgs, ...}: {
  programs.vivaldi = {
    enable = true;
    package = pkgs.vivaldi.override {
      proprietaryCodecs = true; # H.264/AAC for embedded video
      enableWidevine = true; # DRM for streaming services
    };
    # Native Wayland under Plasma 6; falls back to X11 elsewhere.
    commandLineArgs = ["--ozone-platform-hint=auto"];
  };
}
