_: {
  # CLI only — `op signin` works headless. The desktop app lives in
  # 1password-gui.nix, imported by the laptop profile.
  programs._1password.enable = true;
}
