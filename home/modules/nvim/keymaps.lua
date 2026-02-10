local map = vim.keymap.set

-- Command typo fixes
vim.cmd([[
  cnoreabbrev W! w!
  cnoreabbrev Q! q!
  cnoreabbrev Qall! qall!
  cnoreabbrev Wq wq
  cnoreabbrev Wa wa
  cnoreabbrev wQ wq
  cnoreabbrev WQ wq
  cnoreabbrev W w
  cnoreabbrev Q q
  cnoreabbrev Qall qall
]])

-- Splits
map("n", "<Leader>h", ":<C-u>split<CR>", { desc = "Horizontal split" })
map("n", "<Leader>v", ":<C-u>vsplit<CR>", { desc = "Vertical split" })

-- Window navigation (Ctrl-hjkl)
map("n", "<C-j>", "<C-w>j", { desc = "Window down" })
map("n", "<C-k>", "<C-w>k", { desc = "Window up" })
map("n", "<C-l>", "<C-w>l", { desc = "Window right" })
map("n", "<C-h>", "<C-w>h", { desc = "Window left" })

-- Buffer navigation
map("n", "<Tab>", ":bnext<CR>", { silent = true, desc = "Next buffer" })
map("n", "<S-Tab>", ":bprevious<CR>", { silent = true, desc = "Previous buffer" })
map("n", "<S-t>", ":tabnew<CR>", { silent = true, desc = "New tab" })
map("n", "<Leader>z", ":bprevious<CR>", { silent = true, desc = "Previous buffer" })
map("n", "<Leader>q", ":bprevious<CR>", { silent = true, desc = "Previous buffer" })
map("n", "<Leader>x", ":bnext<CR>", { silent = true, desc = "Next buffer" })
map("n", "<Leader>w", ":bnext<CR>", { silent = true, desc = "Next buffer" })
map("n", "<Leader>c", ":bd<CR>", { silent = true, desc = "Close buffer" })

-- Clipboard (explicit register for non-unnamedplus contexts)
map("n", "YY", '"+y<CR>', { desc = "Copy to clipboard" })
map("n", "<Leader>p", '"+gP<CR>', { desc = "Paste from clipboard" })
map("n", "XX", '"+x<CR>', { desc = "Cut to clipboard" })

-- Clear search highlight
map("n", "<Leader><space>", ":noh<CR>", { silent = true, desc = "Clear search" })

-- Center search results
map("n", "n", "nzzzv", { desc = "Next match (centered)" })
map("n", "N", "Nzzzv", { desc = "Prev match (centered)" })

-- Visual mode: maintain selection after indent
map("v", "<", "<gv", { desc = "Indent left" })
map("v", ">", ">gv", { desc = "Indent right" })

-- Visual mode: move block
map("v", "J", ":m '>+1<CR>gv=gv", { silent = true, desc = "Move block down" })
map("v", "K", ":m '<-2<CR>gv=gv", { silent = true, desc = "Move block up" })

-- Terminal
map("n", "<Leader>sh", ":terminal<CR>", { silent = true, desc = "Open terminal" })

-- EasyAlign
map("x", "ga", "<Plug>(EasyAlign)", { desc = "EasyAlign" })
map("n", "ga", "<Plug>(EasyAlign)", { desc = "EasyAlign" })

-- Format file (conform.nvim)
map("n", "<Leader>af", function()
  require("conform").format({ async = true, lsp_fallback = true })
end, { desc = "Format file" })

-- Set working directory to current file
map("n", "<Leader>.", ":lcd %:p:h<CR>", { desc = "Set cwd to file dir" })

-- FixWhitespace command
vim.api.nvim_create_user_command("FixWhitespace", [[%s/\s\+$//e]], {})
