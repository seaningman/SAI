# arch-distro

A lightweight, self-installing Arch Linux setup: Hyprland with Waybar, fuzzel, mako, SwayOSD,
hyprlock, hypridle, swaybg and Kitty, themed from one colours file (Tokyo Night by default).
Built for a ThinkPad X13 Gen 3 (Intel Iris Xe, fingerprint reader), but nothing is hard-wired to it.

## What is in the repo

| Path | What it is |
|---|---|
| `iso/`, `scripts/build-iso.sh` | archiso overlay and build script for a bootable installer ISO |
| `installer/install.sh` | disk installer for the live ISO: LUKS2, ext4, systemd-boot, packages, user |
| `installer/desktop-setup.sh` | runs on first login (and any time later): AUR, Flatpak, stow, theme, `/etc` extras |
| `packages/` | `pacman.txt`, `aur.txt`, `flatpak.txt`, `gpu-intel.txt`, `multilib.txt`, `base.txt` |
| `dotfiles/` | GNU stow packages (hypr, waybar, fuzzel, mako, swayosd, kitty, fish, starship, mpv, btop, fastfetch, ...) |

## Install

1. Build the ISO (on an Arch machine): `sudo pacman -S archiso` then `sudo scripts/build-iso.sh`
   (`--dry-run` prints the steps). Write `out/*.iso` to a USB stick.
2. Boot it in UEFI mode. The installer starts on tty1 and asks for disk, user, passphrase and so on.
   LUKS2 encryption is on by default; the disk is only touched after you type its name.
   Preview first with `/opt/distro/installer/install.sh --dry-run`.
3. Reboot, log in on tty1. The desktop setup runs once, asks before every change to `/etc`, then Hyprland starts.

Already running Arch? Clone the repo and run `installer/desktop-setup.sh --dry-run`, then without
`--dry-run`. Existing configs that would be replaced are moved to `~/.config-backup-<date>/`.
Running it twice is safe.

## Keybindings

`Super + K` shows this list at any time.

| Keys | Action |
|---|---|
| Super + Return | Terminal (Kitty) |
| Super + Space | Launcher (fuzzel) |
| Super + E | File manager (yazi in Kitty) |
| Super + B | Browser (Zen) |
| Super + C | VS Code |
| Super + Shift + N | Notes (Obsidian) |
| Super + Shift + T | System monitor (btop) |
| Super + Shift + C | Calculator |
| Super + Shift + A | Audio mixer |
| Super + Ctrl + V | Clipboard history |
| Super + Ctrl + T | Wallpaper picker (coverflow) |
| Super + Ctrl + Alt + T | Random wallpaper |
| Super + Ctrl + Shift + T | Switch theme |
| Super + L | Lock |
| Super + Shift + Esc | Power menu |
| Super + Q / W | Close window |
| Super + F | Fullscreen |
| Super + V | Floating on/off |
| Super + J / P | Toggle split / pseudo-tile |
| Super + arrows | Focus (Shift moves the window) |
| Super + 1…0 | Workspace 1-10 (Shift sends the window) |
| Super + Tab / Shift + Tab | Next / previous workspace |
| Super + S / Alt + S | Scratchpad / send to scratchpad |
| Print, Super + Shift + S | Screenshot region to clipboard (Shift+Print window, Ctrl+Print screen) |
| Super + Shift + P | Colour picker |
| Super + mouse drag | Move (left) / resize (right) |
| Alt + Shift | Switch keyboard layout (German ↔ Finnish) |
| Volume, brightness, media keys | With on-screen display |

## Themes

All colours live in `~/.config/theme/themes/<name>/colors.toml`. `theme-render` fills the templates in
`~/.config/theme/templates/` for Hyprland, Waybar, fuzzel, mako, hyprlock, SwayOSD, Kitty, btop, fish, starship, yazi and the wallpaper
picker, and reloads what it can (`targets.conf` lists them).

```
theme-set            # list themes
theme-set tokyo-night
Super + Ctrl + Shift + T   # pick from a menu
```

Included themes: tokyo-night, catppuccin, catppuccin-latte, ethereal, everforest, flexoki-light, gruvbox,
hackerman, jade-horse, kanagawa, last-horizon, lumon, lupine, matte-black, miasma, nord, retro-82, ristretto,
rose-pine, solitude, starship, vantablack, white. Palettes follow their upstream projects (Catppuccin, Gruvbox,
Everforest, Kanagawa, Flexoki, Nord, Rosé Pine and so on); light themes work the same way.

New theme: copy `themes/tokyo-night` to `themes/<name>`, change the colours, run `theme-set <name>`.
The installer's own colours come from the same file.

## Wallpapers

Put images in `~/Wallpapers`. `Super + Ctrl + T` opens the coverflow picker, a small standalone
Quickshell config (`~/.config/quickshell/wallpaper`) ported from
[pocket-dots](https://github.com/diegoMalagrida/pocket-dots) (GPL-3.0). It sets the wallpaper with swaybg and crossfades from the old one.
The pixel-colony and outline shader transitions of the old shell are not carried over.

## Laptop extras

- `charge-limit 80` sets the battery charge stop threshold (the installer offers the udev rule that allows it).
- Fingerprint: `fprintd-enroll`; hyprlock uses it, and `desktop-setup.sh` offers it for sudo.

## Credits and licence

Tokyo Night palette by folke ([tokyonight.nvim](https://github.com/folke/tokyonight.nvim), MIT).
The wallpaper picker is derived from pocket-dots (GPL-3.0); mpv Anime4K shaders are from
[Anime4K](https://github.com/bloc97/Anime4K) (MIT). The rest is MIT, see `LICENSE`.
