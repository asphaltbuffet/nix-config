{ pkgs, ... }: {

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";

  i18n.extraLocaleSettings = {
    LC_ADDRESS        = "en_US.UTF-8";
    LC_IDENTIFICATION = "en_US.UTF-8";
    LC_MEASUREMENT    = "en_US.UTF-8";
    LC_MONETARY       = "en_US.UTF-8";
    LC_NAME           = "en_US.UTF-8";
    LC_NUMERIC        = "en_US.UTF-8";
    LC_PAPER          = "en_US.UTF-8";
    LC_TELEPHONE      = "en_US.UTF-8";
    LC_TIME           = "en_US.UTF-8";
  };

  # Enable CUPS to print documents.
  services.printing.enable = true;

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users = {
    grue    = import ../users/grue/default.nix;
    jsquats = import ../users/jsquats/default.nix;
    sukey   = import ../users/sukey/default.nix;
  };

  users.defaultUserShell = pkgs.zsh;

  security.sudo.extraConfig = ''
    %wheel ALL=(ALL) NOPASSWD: ALL
  '';

  programs.zsh.enable = true;

  environment.shells = with pkgs; [
    zsh
  ];

  # install tailscale
  services.tailscale.enable = true;

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    curl
    git
    wget

    nixfmt-rfc-style
    nh
  ];

  programs.vim = {
    enable = true;
    defaultEditor = true;
    package = (pkgs.vim_configurable.override {  }).customize{
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

  # List services that you want to enable:
  services.openssh.enable = true;
  services.envfs.enable = true;

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

}
