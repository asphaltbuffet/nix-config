{pkgs, ...}: {
  programs.tmux = {
    enable = true;

    baseIndex = 1;
    clock24 = true;
    escapeTime = 10;
    extraConfig = ''
      bind C-c new-session
      bind - split-window -v
      bind _ split-window -h

      bind -r h select-pane -L
      bind -r j select-pane -D
      bind -r k select-pane -U
      bind -r l select-pane -R
      bind > swap-pane -D
      bind < swap-pane -U

      bind -r H resize-pane -L 2
      bind -r J resize-pane -D 2
      bind -r K resize-pane -U 2
      bind -r L resize-pane -R 2

      unbind n
      unbind p
      bind -r C-h previous-window
      bind -r C-l next-window
    '';
    focusEvents = true;
    historyLimit = 5000;
    plugins = with pkgs; [
      {
        plugin = tmuxPlugins.continuum;
        extraConfig = ''
          set -g @continuum-restore 'on'
          set -g @continuum-save-interval '60'
        '';
      }
      tmuxPlugins.sensible
    ];
    prefix = "C-a";
    secureSocket = true;
    sensibleOnTop = true;
    shell = "${pkgs.zsh}/bin/zsh";
    terminal = "screen-256color";
    keyMode = "vi";
    mouse = true;
  };
}
