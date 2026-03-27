# nixos/profiles/base.nix
{
  inputs,
  pkgs,
  lib,
  ...
}: {
  imports = [
    inputs.home-manager.nixosModules.home-manager
    ../common/1password.nix
    ../common/autodeploy.nix
    ../common/firefox.nix
    ../common/nas.nix
    ../common/tailscale.nix
  ];

  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;
  home-manager.extraSpecialArgs = {inherit inputs;}; # pass flake inputs to home-manager
  home-manager.backupFileExtension = "hm-bak"; # rename conflicts instead of failing

  # Set your time zone.
  time.timeZone = "America/New_York";

  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.networkmanager.enable = true;

  # Enable NFS for automounting
  boot.supportedFilesystems = ["nfs"];

  fonts.packages = with pkgs; [
    fira-code
    roboto-mono
  ];

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";

  i18n.extraLocaleSettings = {
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

  security.sudo.wheelNeedsPassword = false;

  users.defaultUserShell = pkgs.zsh;
  programs.zsh.enable = true;
  environment.pathsToLink = ["/share/zsh"]; # enable zsh completion for system packages
  environment.shells = with pkgs; [
    zsh
  ];

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # List services that you want to enable:
  services.envfs.enable = true;
  services.fwupd.enable = true;

  # Refresh fwupd metadata weekly; only on AC power to avoid draining battery.
  # Persistent=true ensures it runs on next boot if the scheduled time was missed.
  systemd.timers.fwupd-refresh = {
    wantedBy = ["timers.target"];
    timerConfig = {
      OnCalendar = "weekly";
      Persistent = true;
      RandomizedDelaySec = "2h";
      ConditionACPower = true;
    };
  };
  systemd.services.fwupd-refresh = {
    description = "Refresh fwupd metadata";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.fwupd}/bin/fwupdmgr refresh --force";
    };
  };
  services.tailscale.enable = lib.mkDefault true;
  services.openssh = {
    enable = lib.mkDefault true;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "no";
    };
    # Restrict to ed25519 only — removes weaker RSA/ECDSA/DSA host keys.
    # NixOS generates this key automatically on first boot.
    hostKeys = [
      {
        path = "/etc/ssh/ssh_host_ed25519_key";
        type = "ed25519";
      }
    ];
  };
  services.printing.enable = lib.mkDefault true;

  services.xserver.xkb = {
    layout = "us";
    options = "caps:swapescape";
    variant = "";
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
    extra-substituters = ["https://nix-config-grue.cachix.org"];
    extra-trusted-public-keys = ["nix-config-grue.cachix.org-1:9VBdph98gMqkzdSO5mCh3ReESB3IbvyQ08jzT1fB1Q8="];
  };

  programs.nh = {
    enable = true;
    clean.enable = true;
    clean.extraArgs = lib.mkDefault "--keep-since 4d --keep 3";
  };

  programs.vim = {
    enable = true;
    defaultEditor = true;
    package = (pkgs.vim-full.override {}).customize {
      name = "vim";
      # Install plugins for example for syntax highlighting of nix files
      vimrcConfig.packages.myplugins = with pkgs.vimPlugins; {
        start = [
          vim-sensible
          vim-nix
          vim-lastplace
          vim-surround
          vim-commentary
          vim-repeat
          vim-unimpaired
        ];
        opt = [];
      };
      vimrcConfig.customRC = ''
        set gcr=a:blinkon0
        let mapleader=','
        set hlsearch
        set fileformats=unix,dos,mac

        noremap <leader>h :<C-u>split<CR>
        noremap <leader>v :<C-u>vsplit<CR>
      '';
    };
  };

  programs.nix-ld.enable = true;

  # Grant the active console user access to the PC speaker evdev node without
  # adding them to the broad `input` group (which would expose all input devices).
  services.udev.extraRules = ''
    SUBSYSTEM=="input", ATTRS{name}=="PC Speaker", TAG+="uaccess"
  '';

  environment.systemPackages = with pkgs; [
    beep
    curl
    git
    rclone
    wget
    wireguard-tools
  ];
}
