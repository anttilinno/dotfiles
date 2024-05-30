return {
  "nvim-treesitter/nvim-treesitter",
  config = function()
    local treesitter = require "nvim-treesitter.configs"
    treesitter.setup {
      ensure_installed = { "bash", "go", "lua", "python", "vim" },
      sync_install = false,
      auto_install = true,
    }
  end,
}
