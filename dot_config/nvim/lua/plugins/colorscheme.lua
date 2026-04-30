-- Gruvbox colorscheme that follows the system light/dark theme.
-- The system theme switcher writes "light" or "dark" to ~/.config/themes/current
-- and pokes running Neovim instances via `set background=...`.

local function read_theme()
  local f = io.open(vim.fn.expand("~/.config/themes/current"), "r")
  if not f then
    return "light"
  end
  local t = (f:read("*l") or ""):gsub("%s+", "")
  f:close()
  if t == "dark" then
    return "dark"
  end
  return "light"
end

return {
  {
    "ellisonleao/gruvbox.nvim",
    priority = 1000,
    lazy = false,
    opts = {
      contrast = "soft",
      italic = { strings = false, comments = true, operators = false, folds = true },
      bold = true,
      transparent_mode = false,
    },
    config = function(_, opts)
      require("gruvbox").setup(opts)
      vim.o.background = read_theme()
      vim.cmd.colorscheme("gruvbox")
    end,
  },
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "gruvbox",
    },
  },
}
