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
{pkgs, ...}: let
  # Rebuild attract-mode romlists to match what's on the ROM drive. Loops the
  # drive's per-system folders (the source of truth for "what ROMs exist") and
  # builds each; the folder name matches the emulator .cfg name by convention
  # (mkEmulatorCfg sets rompath /mnt/roms/<name>). A folder with no ROMs or no
  # emulator config is a harmless no-op. NOTE: a `mame` folder triggers an
  # expensive `mame -listxml` scan — accepted. writeShellApplication gives us
  # set -euo pipefail + build-time shellcheck and puts `attract` on PATH.
  romlistBuilder = pkgs.writeShellApplication {
    name = "arcade-romlists";
    runtimeInputs = [pkgs.attract-mode];
    text = ''
      shopt -s nullglob
      for dir in /mnt/roms/*/; do
        name=''${dir%/}
        name=''${name##*/}
        echo "Building romlist: $name"
        attract --build-romlist "$name" || echo "  (build failed for $name, continuing)"
      done
    '';
  };
in {
  imports = [
    ../common/ssh-hardened.nix
  ];

  # GL for MAME / RetroArch. Generic Mesa enable covers Intel/AMD.
  # NVIDIA would additionally need hardware.nvidia + videoDrivers; deferred.
  hardware.graphics.enable = true;

  # ROM library drive (ext4, internal HDD). nofail so a dead/absent drive
  # never hangs cabinet boot — attract-mode just shows empty lists instead.
  # rompaths in home/roles/arcade/ reference /mnt/roms/<system>.
  fileSystems."/mnt/roms" = {
    device = "/dev/disk/by-uuid/5f92cc77-57b8-40ee-836b-4be51b0755c7";
    fsType = "ext4";
    options = ["nofail"];
  };

  # Rebuild attract-mode romlists from /mnt/roms at boot, and on demand via
  # `systemctl start arcade-romlists`. Runs as arcade after the ROM drive
  # mounts. See romlistBuilder above.
  systemd.services.arcade-romlists = {
    description = "Rebuild attract-mode romlists from /mnt/roms";
    after = ["mnt-roms.mount"];
    wants = ["mnt-roms.mount"];
    wantedBy = ["multi-user.target"];
    serviceConfig = {
      Type = "oneshot";
      User = "arcade";
      Group = "arcade";
      ExecStart = "${romlistBuilder}/bin/arcade-romlists";
    };
  };

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
