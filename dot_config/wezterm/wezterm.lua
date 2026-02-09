local wezterm = require 'wezterm'
local config = wezterm.config_builder()

config.enable_tab_bar = false

-- Load color scheme from theme switcher
local ok, scheme = pcall(dofile, os.getenv("HOME") .. "/.config/wezterm/colors.lua")
if ok and scheme then
    config.color_scheme = scheme
end

return config
