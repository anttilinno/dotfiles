return {
  "zaldih/themery.nvim",
  config = function()
    require("themery").setup({
      themes = {
        {
          name = "Catppuccin Latte",
          colorscheme = "catppuccin-latte",
          before = [[
            vim.opt.background = "light"
          ]],
        },
        {
          name = "Catppuccin Frappe",
          colorscheme = "catppuccin-frappe",
          before = [[
            vim.opt.background = "dark"
          ]],
        },
        {
          name = "Catppuccin Macchiato",
          colorscheme = "catppuccin-macchiato",
          before = [[
            vim.opt.background = "dark"
          ]],
        },
        {
          name = "Catppuccin Mocha",
          colorscheme = "catppuccin-mocha",
          before = [[
            vim.opt.background = "dark"
          ]],
        },
        {
          name = "Gruvbox light",
          colorscheme = "gruvbox",
          before = [[
            vim.opt.background = "light"
          ]],
        },
        {
          name = "Gruvbox dark",
          colorscheme = "gruvbox",
          before = [[
            vim.opt.background = "dark"
          ]],
        },
      },
      themeConfigFile = "~/.config/nvim/lua/config/theme.lua",
      livePreview = true,
    })
  end,
}
