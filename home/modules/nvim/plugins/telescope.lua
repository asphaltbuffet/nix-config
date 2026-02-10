local telescope = require("telescope")
local builtin = require("telescope.builtin")

telescope.setup({
  defaults = {
    layout_strategy = "horizontal",
    layout_config = {
      horizontal = {
        prompt_position = "bottom",
        preview_width = 0.6,
      },
      height = 0.4,
      anchor = "S",
    },
    mappings = {
      i = {
        ["<C-t>"] = require("telescope.actions").select_tab,
        ["<C-x>"] = require("telescope.actions").select_horizontal,
        ["<C-v>"] = require("telescope.actions").select_vertical,
      },
    },
  },
})

-- Load fzf-native sorter
telescope.load_extension("fzf")

-- Keybindings (replacing fzf-vim)
vim.keymap.set("n", "<Leader>e", builtin.find_files, { desc = "Find files" })
vim.keymap.set("n", "<Leader>b", builtin.buffers, { desc = "Buffer list" })
vim.keymap.set("n", "<Leader>f", builtin.live_grep, { desc = "Live grep" })
vim.keymap.set("n", "<Leader>y", builtin.command_history, { desc = "Command history" })
vim.keymap.set("n", "<F4>", builtin.lsp_document_symbols, { desc = "Document symbols" })
