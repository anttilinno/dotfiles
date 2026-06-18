-- Go power-up on top of the LazyVim `lang.go` extra (gopls, gofumpt, delve, neotest).
-- Adds gopls-driven commands: GoFillStruct, GoImpl, GoTestFunc, struct-tag tools, etc.
return {
  {
    "ray-x/go.nvim",
    dependencies = {
      "ray-x/guihua.lua",
      "neovim/nvim-lspconfig",
      "nvim-treesitter/nvim-treesitter",
    },
    ft = { "go", "gomod" },
    build = ':lua require("go.install").update_all_sync()',
    opts = {},
  },
}
