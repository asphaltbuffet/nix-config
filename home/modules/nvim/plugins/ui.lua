-- Carbonfox colorscheme (from nightfox.nvim)
require("nightfox").setup({
  options = {
    styles = {
      comments = "italic",
    },
  },
})
vim.cmd.colorscheme("carbonfox")

-- Lualine statusline
require("lualine").setup({
  options = {
    theme = "carbonfox",
    section_separators = "",
    component_separators = "|",
  },
  sections = {
    lualine_a = { "mode" },
    lualine_b = { "branch", "diff", "diagnostics" },
    lualine_c = { { "filename", path = 1 } },
    lualine_x = { "filetype" },
    lualine_y = { "progress" },
    lualine_z = { "location" },
  },
})

-- Indent blankline
require("ibl").setup({
  indent = { char = "┆" },
  scope = { enabled = true },
})

-- Todo comments
require("todo-comments").setup({})
