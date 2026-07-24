# nixos/profiles/arcade.nix
# Arcade cabinet system machinery. Import alongside base.nix.
# Holds ONLY privileged system plumbing — the emulators, front-end, and X
# session live in the `arcade` home-manager role (home/roles/arcade.nix).
#
# Inherited from base.nix, so NOT repeated here: networkmanager, tailscale,
# nix substituters, openssh enable. See ADR-0009 (bare X kiosk) and
# ADR-0010 (config/content boundary).
#
# Do NOT import server.nix or laptop/ — this is a standalone host type.
{...}: {
  imports = [
    ../common/ssh-hardened.nix
  ];

  # GL for MAME / RetroArch. Generic Mesa enable covers Intel/AMD.
  # NVIDIA would additionally need hardware.nvidia + videoDrivers; deferred.
  hardware.graphics.enable = true;

  # Audio. The cabinet has no Plasma desktop to pull PipeWire in implicitly
  # (unlike the laptop hosts), so configure it explicitly here.
  security.rtkit.enable = true;
  services = {
    pulseaudio.enable = false;
    pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
    };

    # Kiosk boot: autologin the arcade user on tty1. The user's login shell
    # (managed in the arcade home-manager role) runs `exec startx` there, and
    # the X session execs attract-mode. No display manager, no desktop.
    getty.autologinUser = "arcade";

    xserver = {
      enable = true;
      displayManager.startx.enable = true;
    };
  };
}
