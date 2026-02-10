-- Leader key (vim-bootstrap convention)
vim.g.mapleader = ","
vim.g.maplocalleader = ","

-- Indentation
vim.opt.tabstop = 4
vim.opt.softtabstop = 4
vim.opt.shiftwidth = 4
vim.opt.expandtab = true

-- Line numbers
vim.opt.number = true
vim.opt.relativenumber = true

-- Search
vim.opt.hlsearch = true
vim.opt.incsearch = true
vim.opt.ignorecase = true
vim.opt.smartcase = true

-- Buffers & windows
vim.opt.hidden = true
vim.opt.splitbelow = true
vim.opt.splitright = true
vim.opt.scrolloff = 3

-- Mouse
vim.opt.mouse = "a"

-- Clipboard (system)
vim.opt.clipboard = "unnamedplus"

-- UI
vim.opt.termguicolors = true
vim.opt.signcolumn = "yes"
vim.opt.cursorline = true
vim.opt.laststatus = 2
vim.opt.title = true
vim.opt.wildmenu = true

-- Persistent undo
vim.opt.undofile = true

-- Editorconfig (built-in since nvim 0.9)
vim.g.editorconfig = true

-- File handling
vim.opt.fileformats = "unix,dos,mac"
vim.opt.fileencoding = "utf-8"
vim.opt.autoread = true

-- Disable blinking cursor in GUI
vim.opt.guicursor = "a:blinkon0"

-- Disable error bells
vim.opt.errorbells = false
vim.opt.visualbell = false

-- Filetype-specific autocmds
local augroup = vim.api.nvim_create_augroup
local autocmd = vim.api.nvim_create_autocmd

augroup("ft_go", { clear = true })
autocmd("FileType", {
  group = "ft_go",
  pattern = "go",
  callback = function()
    vim.opt_local.expandtab = false
    vim.opt_local.tabstop = 4
    vim.opt_local.shiftwidth = 4
  end,
})

augroup("ft_python", { clear = true })
autocmd("FileType", {
  group = "ft_python",
  pattern = "python",
  callback = function()
    vim.opt_local.expandtab = true
    vim.opt_local.shiftwidth = 4
    vim.opt_local.tabstop = 8
    vim.opt_local.softtabstop = 4
    vim.opt_local.colorcolumn = "79"
  end,
})

augroup("ft_prose", { clear = true })
autocmd("FileType", {
  group = "ft_prose",
  pattern = { "markdown", "gitcommit" },
  callback = function()
    vim.opt_local.spell = true
  end,
})

augroup("ft_make", { clear = true })
autocmd("FileType", {
  group = "ft_make",
  pattern = "make",
  callback = function()
    vim.opt_local.expandtab = false
  end,
})
