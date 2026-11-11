-- bind(keys, description, action [, opts]); keybinds-help lists these lines.
local function bind(keys, desc, action, opts)
  opts = opts or {}
  opts.description = desc
  hl.bind(keys, action, opts)
end
local function run(cmd) return hl.dsp.exec_cmd(cmd) end

-- Apps
bind("SUPER + Return", "Terminal", run("kitty"))
bind("SUPER + Space", "Launcher", run("fuzzel"))
bind("SUPER + E", "File manager (yazi)", run("kitty -1 yazi"))
bind("SUPER + B", "Browser", run("zen-browser"))
bind("SUPER + C", "Code editor", run("code"))
bind("SUPER + SHIFT + N", "Notes", run("obsidian"))
bind("SUPER + SHIFT + T", "System monitor", run("kitty -1 btop"))
bind("SUPER + SHIFT + C", "Calculator", run("qalculate-gtk"))
bind("SUPER + SHIFT + A", "Audio mixer", run("pavucontrol"))

-- Menus
bind("SUPER + K", "Show keybindings", run("keybinds-help"))
bind("SUPER + CTRL + V", "Clipboard history", run("clipboard-menu"))
bind("SUPER + CTRL + T", "Wallpaper picker", run("wallpaper-picker"))
bind("SUPER + CTRL + ALT + T", "Random wallpaper", run("wallpaper-random"))
bind("SUPER + CTRL + SHIFT + T", "Switch theme", run("theme-menu"))

-- Session
bind("SUPER + L", "Lock screen", run("loginctl lock-session"))
bind("SUPER + SHIFT + Escape", "Power menu", run("power-menu"))
bind("SUPER + CTRL + ALT + R", "Reload Hyprland", run("hyprctl reload"))

-- Windows
bind("SUPER + Q", "Close window", hl.dsp.window.close())
bind("SUPER + W", "Close window", hl.dsp.window.close())
bind("SUPER + F", "Fullscreen", hl.dsp.window.fullscreen({ mode = "fullscreen", action = "toggle" }))
bind("SUPER + V", "Toggle floating", hl.dsp.window.float({ action = "toggle" }))
bind("SUPER + J", "Toggle split", hl.dsp.layout("togglesplit"))
bind("SUPER + P", "Pseudo-tile", hl.dsp.window.pseudo())
bind("SUPER + mouse:272", "Move window", hl.dsp.window.drag(), { mouse = true })
bind("SUPER + mouse:273", "Resize window", hl.dsp.window.resize(), { mouse = true })

local arrows = { Left = "l", Right = "r", Up = "u", Down = "d" }
for key, dir in pairs(arrows) do
  bind("SUPER + " .. key, "Focus " .. dir, hl.dsp.focus({ direction = dir }))
  bind("SUPER + SHIFT + " .. key, "Move window " .. dir, hl.dsp.window.move({ direction = dir }))
end

-- Workspaces 1-10
for i = 1, 10 do
  local key = "code:" .. tostring(i + 9)
  bind("SUPER + " .. key, "Workspace " .. i, hl.dsp.focus({ workspace = i }))
  bind("SUPER + SHIFT + " .. key, "Send window to workspace " .. i, hl.dsp.window.move({ workspace = i }))
end
bind("SUPER + Tab", "Next workspace", hl.dsp.focus({ workspace = "e+1" }))
bind("SUPER + SHIFT + Tab", "Previous workspace", hl.dsp.focus({ workspace = "e-1" }))
bind("SUPER + S", "Scratchpad", hl.dsp.workspace.toggle_special("scratchpad"))
bind("SUPER + ALT + S", "Send to scratchpad", hl.dsp.window.move({ workspace = "special:scratchpad", follow = false }))

-- Screenshots and colour picker
bind("Print", "Screenshot region", run("hyprshot -m region --clipboard-only"))
bind("SHIFT + Print", "Screenshot window", run("hyprshot -m window --clipboard-only"))
bind("CTRL + Print", "Screenshot screen", run("hyprshot -m output --clipboard-only"))
bind("SUPER + SHIFT + S", "Screenshot region", run("hyprshot -m region --clipboard-only"))
bind("SUPER + SHIFT + P", "Colour picker", run("hyprpicker -a"))

-- Volume, brightness, media (on-screen display via swayosd)
local locked_rep = { locked = true, repeating = true }
bind("XF86AudioRaiseVolume", "Volume up", run("swayosd-client --output-volume raise"), locked_rep)
bind("XF86AudioLowerVolume", "Volume down", run("swayosd-client --output-volume lower"), locked_rep)
bind("XF86AudioMute", "Mute", run("swayosd-client --output-volume mute-toggle"), { locked = true })
bind("XF86AudioMicMute", "Mute microphone", run("swayosd-client --input-volume mute-toggle"), { locked = true })
bind("XF86MonBrightnessUp", "Brightness up", run("swayosd-client --brightness raise"), locked_rep)
bind("XF86MonBrightnessDown", "Brightness down", run("swayosd-client --brightness lower"), locked_rep)
bind("XF86AudioPlay", "Play/pause", run("playerctl play-pause"), { locked = true })
bind("XF86AudioPause", "Play/pause", run("playerctl play-pause"), { locked = true })
bind("XF86AudioNext", "Next track", run("playerctl next"), { locked = true })
bind("XF86AudioPrev", "Previous track", run("playerctl previous"), { locked = true })
bind("XF86KbdBrightnessUp", "Keyboard backlight up", run("brightnessctl -d '*::kbd_backlight' set +1"), locked_rep)
bind("XF86KbdBrightnessDown", "Keyboard backlight down", run("brightnessctl -d '*::kbd_backlight' set 1-"), locked_rep)
