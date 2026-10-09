{
  config,
  lib,
  ...
}: {
  programs._1password-gui = {
    enable = true;
    # Every login on the host may unlock with system auth (fingerprint or
    # account password); hardcoding names left new users out (#227).
    polkitPolicyOwners = lib.attrNames (lib.filterAttrs (_: u: u.isNormalUser) config.users.users);
  };

  # NixOS wraps Vivaldi, so 1Password doesn't recognise it as a known browser
  # and refuses the extension's native-messaging connection without this.
  environment.etc."1password/custom_allowed_browsers" = {
    text = "vivaldi-bin\n";
    mode = "0755";
  };
}
