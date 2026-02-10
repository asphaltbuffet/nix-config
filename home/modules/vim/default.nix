# Vim configuration
# Split into:
#   - plugins.nix  : plugin list
#   - settings.nix : editor settings
#   - keymaps.nix  : keybindings and plugin config
{...}: {
  imports = [
    ./plugins.nix
    ./settings.nix
    ./keymaps.nix
  ];

  programs.vim = {
    enable = true;
    defaultEditor = false;
  };
}
