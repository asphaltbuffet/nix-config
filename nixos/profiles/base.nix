# nixos/profiles/base.nix
{
  inputs,
  pkgs,
  lib,
  config,
  ...
}: {
  imports = [
    inputs.home-manager.nixosModules.home-manager
    ../common/1password.nix
    ../common/alerts.nix
    ../common/autodeploy.nix
    ../common/firefox.nix
    ../common/host.nix
    ../common/nas.nix
    ../common/restic-backup.nix
    ../common/nixos-metrics.nix
    ../common/smartd.nix
    ../common/tailscale.nix
    ../common/compat.nix
  ];

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    extraSpecialArgs = {inherit inputs;}; # pass flake inputs to home-manager
    backupFileExtension = "hm-bak"; # rename conflicts instead of failing
    sharedModules = [
      {home.stateVersion = config.system.stateVersion;}
    ];
  };

  environment.localBinInPath = true;

  # Set your time zone.
  time.timeZone = "America/New_York";

  # Bootloader.
  boot = {
    loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
    };
    # Enable NFS for automounting
    supportedFilesystems = ["nfs"];
  };

  networking.networkmanager.enable = true;

  # Select internationalisation properties.
  i18n = {
    defaultLocale = "en_US.UTF-8";
    extraLocaleSettings = {
      LC_ADDRESS = "en_US.UTF-8";
      LC_IDENTIFICATION = "en_US.UTF-8";
      LC_MEASUREMENT = "en_US.UTF-8";
      LC_MONETARY = "en_US.UTF-8";
      LC_NAME = "en_US.UTF-8";
      LC_NUMERIC = "en_US.UTF-8";
      LC_PAPER = "en_US.UTF-8";
      LC_TELEPHONE = "en_US.UTF-8";
      LC_TIME = "en_US.UTF-8";
    };
  };

  security.sudo.wheelNeedsPassword = false;

  users.defaultUserShell = pkgs.zsh;

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  services = {
    envfs.enable = true;
    nixosMetrics.enable = true; # also enables prometheus.exporters.node
    fwupd.enable = true;
    tailscale.enable = lib.mkDefault true;
    openssh = {
      enable = lib.mkDefault true;
      settings = {
        PasswordAuthentication = false;
        KbdInteractiveAuthentication = false;
        PermitRootLogin = "no";
      };
      # Restrict to ed25519 only — removes weaker RSA/ECDSA/DSA host keys.
      # nixos-bootstrap pre-generates this key (ADR-0006).
      hostKeys = [
        {
          path = "/etc/ssh/ssh_host_ed25519_key";
          type = "ed25519";
        }
      ];
    };
  };

  # Refresh fwupd metadata weekly; only on AC power to avoid draining battery.
  # Persistent=true ensures it runs on next boot if the scheduled time was missed.
  systemd = {
    # Keep /etc/ssh traversable: sshd reads authorized_keys.d/%u as the target
    # user, so a 700 dir silently rejects every key — a lockout with password
    # auth off (#231). `z` only fixes the mode of an existing path.
    tmpfiles.rules = ["z /etc/ssh 0755 root root -"];
    timers.fwupd-refresh = {
      wantedBy = ["timers.target"];
      timerConfig = {
        OnCalendar = "weekly";
        Persistent = true;
        RandomizedDelaySec = "2h";
        ConditionACPower = true;
      };
    };
    services.fwupd-refresh = {
      description = "Refresh fwupd metadata";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${pkgs.fwupd}/bin/fwupdmgr refresh --force";
      };
    };
  };

  # Enable Docker
  virtualisation.docker.enable = true;

  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];
    warn-dirty = false;
    auto-optimise-store = true;
    extra-substituters = [
      "https://nix-config-grue.cachix.org"
      "https://asphaltbuffet.cachix.org"
    ];
    extra-trusted-public-keys = [
      "nix-config-grue.cachix.org-1:9VBdph98gMqkzdSO5mCh3ReESB3IbvyQ08jzT1fB1Q8="
      "asphaltbuffet.cachix.org-1:X7blz7HiaFpaq9Om6pYaKHWAaq7jAbjdQdareQQpJmU="
    ];
    trusted-users = ["root" "grue"];
  };

  programs = {
    zsh.enable = true;
    nh = {
      enable = true;
      clean.enable = true;
      clean.extraArgs = lib.mkDefault "--keep-since 4d --keep 3";
    };
    nix-ld.enable = true;
  };

  environment = {
    pathsToLink = ["/share/zsh"]; # enable zsh completion for system packages
    shells = with pkgs; [zsh];
    systemPackages = with pkgs; [
      curl
      git
      rclone
      wget
      wireguard-tools
    ];
  };
}
