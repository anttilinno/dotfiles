-- load defaults i.e lua_lsp
require("nvchad.configs.lspconfig").defaults()

local lspconfig = require "lspconfig"

local servers = { "bashls", "pyright", "vtsls" }
local nvlsp = require "nvchad.configs.lspconfig"

local function lsp_client(name)
  return assert(
    vim.lsp.get_clients({ bufnr = vim.api.nvim_get_current_buf(), name = name })[1],
    ("No %s client found for the current buffer"):format(name)
  )
end

-- lsps with default config
for _, lsp in ipairs(servers) do
  lspconfig[lsp].setup {
    on_attach = nvlsp.on_attach,
    on_init = nvlsp.on_init,
    capabilities = nvlsp.capabilities,
  }
end

require("lspconfig").ruff.setup {
  init_options = {
    settings = {
      -- Ruff language server settings go here
      configuration = "~/.config/nvim/ruff.toml",
    },
  },
  commands = {
    RuffAutofix = {
      function()
        lsp_client("ruff").request("workspace/executeCommand", {
          command = "ruff.applyAutofix",
          arguments = {
            { uri = vim.uri_from_bufnr(0), version = 0 },
          },
        })
      end,
      description = "Ruff: Fix all auto-fixable problems",
    },
    RuffOrganizeImports = {
      function()
        lsp_client("ruff").request("workspace/executeCommand", {
          command = "ruff.applyOrganizeImports",
          arguments = {
            { uri = vim.uri_from_bufnr(0), version = 0 },
          },
        })
      end,
      description = "Ruff: Format imports",
    },
  },
  on_attach = function(client, bufnr)
    -- Disable hover in favor of Pyright
    client.server_capabilities.hoverProvider = false

    vim.keymap.set("n", "<A-O>", "<cmd> RuffOrganizeImports <cr>", { desc = "Organize imports", buffer = bufnr })
    vim.keymap.set("n", "<A-F>", "<cmd> RuffAutofix <cr>", { desc = "Fix issues found by ruff", buffer = bufnr })
  end,
}

require("lspconfig").pyright.setup {
  commands = {},
  settings = {
    pyright = {
      -- Using Ruff's import organizer
      disableOrganizeImports = true,
    },
    python = {
      analysis = {
        -- Ignore all files for analysis to exclusively use Ruff for linting
        ignore = { "*" },
      },
    },
  },
}
