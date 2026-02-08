# Vim settings
{...}: {
  programs.vim.settings = {
    # Search
    ignorecase = true;
    smartcase = true;

    # Indentation
    tabstop = 4;
    shiftwidth = 4;
    expandtab = true;

    # Buffers & display
    hidden = true;
    number = true;
    background = "dark";

    # Mouse
    mouse = "a";
    mousemodel = "popup";

    # Misc
    modeline = true;
  };
}
