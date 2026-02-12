-- Fidget: LSP progress indicator
require("fidget").setup({})

-- Diagnostics: show virtual text with source and error codes
vim.diagnostic.config({
  virtual_text = {
    prefix = "●",
    source = true,
  },
  signs = {
    text = {
      [vim.diagnostic.severity.ERROR] = " ",
      [vim.diagnostic.severity.WARN] = " ",
      [vim.diagnostic.severity.HINT] = " ",
      [vim.diagnostic.severity.INFO] = " ",
    },
  },
  underline = true,
  update_in_insert = false,
  severity_sort = true,
  float = {
    border = "rounded",
    source = true,
  },
})

-- Merge cmp-nvim-lsp capabilities into the default
local capabilities = require("cmp_nvim_lsp").default_capabilities()

-- LSP keybindings (applied when any server attaches)
vim.api.nvim_create_autocmd("LspAttach", {
  callback = function(ev)
    local map = function(keys, func, desc)
      vim.keymap.set("n", keys, func, { buffer = ev.buf, desc = desc })
    end

    map("gd", vim.lsp.buf.definition, "Go to definition")
    map("gr", vim.lsp.buf.references, "Find references")
    map("gI", vim.lsp.buf.implementation, "Go to implementation")
    map("K", vim.lsp.buf.hover, "Hover documentation")
    map("<Leader>rn", vim.lsp.buf.rename, "Rename symbol")
    map("<Leader>ca", vim.lsp.buf.code_action, "Code action")
    map("<Leader>D", vim.lsp.buf.type_definition, "Type definition")
    map("[d", vim.diagnostic.goto_prev, "Previous diagnostic")
    map("]d", vim.diagnostic.goto_next, "Next diagnostic")
    map("<Leader>e", vim.diagnostic.open_float, "Show diagnostic float")
    map("<Leader>q", vim.diagnostic.setloclist, "Diagnostics to loclist")

    -- Enable inlay hints if the server supports them
    local client = vim.lsp.get_client_by_id(ev.data.client_id)
    if client and client:supports_method("textDocument/inlayHint") then
      vim.lsp.inlay_hint.enable(true, { bufnr = ev.buf })
    end
  end,
})

-- Server configs using vim.lsp.config (nvim 0.11+)
vim.lsp.config("gopls", {
  capabilities = capabilities,
  settings = {
    gopls = {
      analyses = {
        unusedparams = true,
        shadow = true,
      },
      staticcheck = true,
      gofumpt = true,
      hints = {
        assignVariableTypes = true,
        compositeLiteralFields = true,
        compositeLiteralTypes = true,
        constantValues = true,
        functionTypeParameters = true,
        parameterNames = true,
        rangeVariableTypes = true,
      },
    },
  },
})

vim.lsp.config("nixd", {
  capabilities = capabilities,
})

vim.lsp.config("pyright", {
  capabilities = capabilities,
})

vim.lsp.config("lua_ls", {
  capabilities = capabilities,
  settings = {
    Lua = {
      runtime = { version = "LuaJIT" },
      workspace = { checkThirdParty = false },
      telemetry = { enable = false },
    },
  },
})

-- Enable all configured servers
vim.lsp.enable({ "gopls", "nixd", "pyright", "lua_ls" })
