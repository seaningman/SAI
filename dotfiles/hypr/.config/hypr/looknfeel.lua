local t = require("theme")

hl.config({
  general = {
    gaps_in = t.gaps_in,
    gaps_out = t.gaps_out,
    border_size = t.border,
    col = { active_border = t.active_border, inactive_border = t.inactive_border },
    resize_on_border = true,
    allow_tearing = false,
    layout = "dwindle",
  },
  decoration = {
    rounding = t.rounding,
    shadow = { enabled = false },
    blur = { enabled = false },
  },
  animations = { enabled = true },
  dwindle = { preserve_split = true, force_split = 2 },
  misc = {
    disable_hyprland_logo = true,
    disable_splash_rendering = true,
    background_color = t.background,
    focus_on_activate = true,
  },
})

hl.curve("easeOutQuint", { type = "bezier", points = { { 0.23, 1 }, { 0.32, 1 } } })
hl.curve("linear", { type = "bezier", points = { { 0, 0 }, { 1, 1 } } })
hl.curve("almostLinear", { type = "bezier", points = { { 0.5, 0.5 }, { 0.75, 1.0 } } })
hl.curve("quick", { type = "bezier", points = { { 0.15, 0 }, { 0.1, 1 } } })

hl.animation({ leaf = "global", enabled = true, speed = 8, bezier = "default" })
hl.animation({ leaf = "border", enabled = true, speed = 4.3, bezier = "easeOutQuint" })
hl.animation({ leaf = "windows", enabled = true, speed = 3.0, bezier = "easeOutQuint" })
hl.animation({ leaf = "windowsIn", enabled = true, speed = 3.3, bezier = "easeOutQuint", style = "popin 87%" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 1.2, bezier = "linear", style = "popin 87%" })
hl.animation({ leaf = "fadeIn", enabled = true, speed = 1.4, bezier = "almostLinear" })
hl.animation({ leaf = "fadeOut", enabled = true, speed = 1.2, bezier = "almostLinear" })
hl.animation({ leaf = "fade", enabled = true, speed = 2.4, bezier = "quick" })
hl.animation({ leaf = "layers", enabled = true, speed = 3.0, bezier = "easeOutQuint" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 2.5, bezier = "easeOutQuint", style = "slide" })
