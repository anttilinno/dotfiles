return {
  "folke/which-key.nvim",
  event = "VeryLazy",
  config = function()
    vim.o.timeout = true
    vim.o.timeoutlen = 300

    local wk = require("which-key")

    wk.setup({})

    wk.register({
      ["<leader>"] = {
        ["x"] = { "<cmd>bdelete<CR>", "Kill Buffer" },
        -- Telescope
        f = {
          name = "+file",
          f = { "<cmd>Telescope find_files<cr>", "Find File" },
          g = { "<cmd>Telescope live_grep<cr>", "Grep files" },
          n = { "<cmd>enew<cr>", "New File" },
          r = { "<cmd>Telescope oldfiles<cr>", "Open Recent File" },
        },
        -- Toggle Term
        t = {
          name = "Terminal",
          f = { "<cmd>ToggleTerm direction=float<cr>", "Float" }, -- Floating Terminal
          h = { "<cmd>ToggleTerm size=10 direction=horizontal<cr>", "Horizontal" }, -- Horizontal Terminal,
          v = { "<cmd>ToggleTerm size=80 direction=vertical<cr>", "Vertical" }, -- Vertical Terminal
        },
        -- Flash Search
        -- stylua: ignore
        l = {
          name = "flash",
          s = { function () require("flash").jump() end, "Flash Jump" },
          t = { function () require("flash").treesitter() end, "Flash Treesitter" },
          r = { function () require("flash").treesitter_search() end, "Flash Treesitter Search" },
          f = { function () require("flash").toggle() end, "Flash Toggle" },
        },
        -- Visual Related things
        -- stylua: ignore
        a = {
          name = "visual",
          t = { "<cmd>Themery<cr>", "Theme Switcher" },
        },
      },
    })
  end,
}
