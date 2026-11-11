-- Hyprland entry point. Colours and layout tokens come from theme.lua, which
-- `theme-render` generates from ~/.config/theme/current/colors.toml.
-- Files are stow symlinks into the repo, and Lua resolves requires relative to the real path.
-- Point it at the live config dir so the generated theme.lua is found.
local cfg = (os.getenv("XDG_CONFIG_HOME") or (os.getenv("HOME") .. "/.config")) .. "/hypr"
package.path = cfg .. "/?.lua;" .. package.path

require("env")
require("monitors")
require("input")
require("looknfeel")
require("rules")
require("bindings")
require("autostart")
