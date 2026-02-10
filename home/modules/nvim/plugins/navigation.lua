-- nvim-tree (replaces NERDTree)
require("nvim-tree").setup({
  view = {
    width = 50,
  },
  filters = {
    dotfiles = false,
    git_ignored = true,
  },
  renderer = {
    icons = {
      show = {
        git = true,
        file = true,
        folder = true,
        folder_arrow = true,
      },
    },
  },
})

vim.keymap.set("n", "<F2>", ":NvimTreeFindFile<CR>", { silent = true, desc = "Find file in tree" })
vim.keymap.set("n", "<F3>", ":NvimTreeToggle<CR>", { silent = true, desc = "Toggle file tree" })

-- Gitsigns (git gutter, works with jj's colocated git)
require("gitsigns").setup({
  signs = {
    add = { text = "+" },
    change = { text = "~" },
    delete = { text = "_" },
    topdelete = { text = "‾" },
    changedelete = { text = "~" },
  },
})

-- nvim-lastplace (restore cursor position)
require("nvim-lastplace").setup({})
