_: {
  programs._1password.enable = true;
  programs._1password-gui = {
    enable = true;
    polkitPolicyOwners = ["grue"];
  };

  # NixOS wraps Vivaldi, so 1Password doesn't recognise it as a known browser
  # and refuses the extension's native-messaging connection without this.
  environment.etc."1password/custom_allowed_browsers" = {
    text = "vivaldi-bin\n";
    mode = "0755";
  };
}
