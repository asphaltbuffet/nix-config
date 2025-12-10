# nixos/profiles/base.nix
{
  inputs,
  config,
  pkgs,
  lib,
  ...
}: {
  imports = [
    inputs.home-manager.nixosModules.home-manager
    inputs.agenix.nixosModules.default
    ../common/1password.nix
    ../common/firefox.nix
    ../common/tailscale.nix
  ];

  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;

  # Set your time zone.
  time.timeZone = "America/New_York";

  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Enable networking
  networking.networkmanager.enable = true;
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

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
  services.tailscale.enable = lib.mkDefault true;
  services.openssh.enable = lib.mkDefault true;
  services.printing.enable = lib.mkDefault true;

  services.xserver.xkb = {
    layout = "us";
    options = "caps:swapescape";
    variant = "";
  };

  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];
    warn-dirty = false;
    auto-optimise-store = true;
  };

  programs.nh = {
    enable = true;
    clean.enable = true;
    clean.extraArgs = lib.mkDefault "--keep-since 4d --keep 3";
  };

  # system.autoUpgrade.enable = true;
  # system.autoUpgrade.dates = "*-*-* *:04:00";
  # system.autoUpgrade.flake = "github:asphaltbuffet/nix-config#${config.networking.hostName}";
  # system.autoUpgrade.flags = ["--refresh"];
  # system.autoUpgrade.randomizedDelaySec = "5m";

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

  environment.systemPackages = with pkgs; [
    curl
    git
    rclone
    wget
    wireguard-tools
  ];
}
