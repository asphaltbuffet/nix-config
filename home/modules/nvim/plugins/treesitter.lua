-- Grammars are installed by Nix (withAllGrammars), not by treesitter itself.
-- The nvim-treesitter plugin API was restructured; highlighting and indentation
-- are now handled via vim.treesitter built-ins.

-- Enable treesitter-based highlighting for all buffers with a known parser
vim.api.nvim_create_autocmd("FileType", {
  callback = function()
    pcall(vim.treesitter.start)
  end,
})
