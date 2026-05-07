# nixos/profiles/laptop.nix
{pkgs, ...}: {
  services = {
    #### Display server / desktop environment ####
    xserver = {
      enable = true;
      xkb = {
        layout = "us";
        options = "caps:swapescape";
        variant = "";
      };
    };

    # Display manager
    displayManager.sddm.enable = true;

    # Desktop environment (KDE Plasma 6)
    desktopManager.plasma6.enable = true;

    #### Optional desktop services ####
    blueman.enable = true;

    # Printing — both printers support IPP Everywhere (driverless IPP/Mopria);
    # no host-side driver packages are needed.
    printing = {
      enable = true;
      # auto-creates CUPS queues for discovered network printers (no manual lpadmin needed)
      browsed.enable = true;
    };

    # mDNS/Bonjour — auto-discovers network printers advertising via DNS-SD
    avahi = {
      enable = true;
      nssmdns4 = true; # allows resolving .local hostnames for printer discovery
      openFirewall = true; # opens UDP 5353 for mDNS; intentional for LAN printer discovery
    };

    #### VPN ####
    mullvad-vpn = {
      enable = true;
      package = pkgs.mullvad-vpn; # includes GUI + CLI (default is CLI-only pkgs.mullvad)
      enableEarlyBootBlocking = true; # block traffic before network stack initializes, preventing boot-time leaks
    };

    # Grant the active console user access to the PC speaker evdev node without
    # adding them to the broad `input` group (which would expose all input devices).
    udev.extraRules = ''
      SUBSYSTEM=="input", ATTRS{name}=="PC Speaker", TAG+="uaccess"
    '';
  };

  hardware.bluetooth.enable = true;

  # cups-browsed has a race condition on first boot: it may start before Avahi
  # has fully resolved .local hostnames, leaving queues with no destination.
  # Explicitly ordering it after avahi-daemon.service prevents this.
  systemd.services.cups-browsed = {
    after = ["avahi-daemon.service"];
    requires = ["avahi-daemon.service"];
  };

  #### Desktop-related system packages ####
  environment.systemPackages = with pkgs; [
    beep
    xdg-utils # useful for opening URLs
    pavucontrol # audio control GUI
    # Add any desktop apps you want every graphical system to have
  ];

  #### XDG integration ####
  xdg.portal = {
    enable = true;
    extraPortals = with pkgs; [
      xdg-desktop-portal-gtk
    ];
  };

  #### Fonts, input, and editor ####
  fonts.packages = with pkgs; [
    fira-code
    roboto-mono
  ];

  programs.vim = {
    enable = true;
    defaultEditor = true;
    package = (pkgs.vim-full.override {}).customize {
      name = "vim";
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
}
