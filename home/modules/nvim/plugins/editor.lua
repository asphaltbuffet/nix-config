-- Which-key: keybinding hints popup
require("which-key").setup({})

-- Comment.nvim (gc/gcc)
require("Comment").setup({})

-- Surround (ys/ds/cs)
require("nvim-surround").setup({})

-- Autopairs (integrate with cmp)
local autopairs = require("nvim-autopairs")
autopairs.setup({})
local cmp_autopairs = require("nvim-autopairs.completion.cmp")
require("cmp").event:on("confirm_done", cmp_autopairs.on_confirm_done())

-- Flash.nvim (directional jump, replacing easymotion)
local flash = require("flash")
vim.keymap.set({ "n", "x", "o" }, "s", flash.jump, { desc = "Flash jump" })
vim.keymap.set("n", "<Leader>j", function()
  flash.jump({ search = { forward = true } })
end, { desc = "Flash jump down" })
vim.keymap.set("n", "<Leader>k", function()
  flash.jump({ search = { forward = false } })
end, { desc = "Flash jump up" })
