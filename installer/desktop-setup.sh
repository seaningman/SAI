#!/usr/bin/env bash
# Desktop setup, run as your normal user (automatically on first login, or any time later).
# Installs yay, AUR + Flatpak apps, links the dotfiles with GNU stow, renders the theme and
# offers the /etc extras. Safe to run twice. Every change to /etc asks first and shows a diff.
#
#   ./desktop-setup.sh [--dry-run] [--yes] [--skip-packages] [--help]
set -euo pipefail

REPO=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
DRY_RUN=false
ASSUME_YES=false
SKIP_PACKAGES=false
TOTAL_STEPS=7 # used by lib/ui.sh
export TOTAL_STEPS
STAMP=$(date +%Y%m%d-%H%M%S)
BACKUP_DIR="$HOME/.config-backup-$STAMP"
STATE_DIR="$HOME/.local/state/arch-distro"

for arg in "$@"; do
    case $arg in
        --dry-run) DRY_RUN=true ;;
        --yes) ASSUME_YES=true ;;
        --skip-packages) SKIP_PACKAGES=true ;;
        --help | -h)
            sed -n '2,6p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
            exit 0
            ;;
        *) echo "unknown option: $arg (try --help)" >&2; exit 1 ;;
    esac
done

# shellcheck source=lib/ui.sh
source "$REPO/installer/lib/ui.sh"

CONFIRM=()
"$ASSUME_YES" && CONFIRM=(--noconfirm)

# ------------------------------------------------------------------ 1. checks
banner "Arch" "desktop setup"
step "Checking the system"
[[ -f /etc/arch-release ]] || die "this only supports Arch Linux"
[[ $EUID -ne 0 ]] || die "run as your normal user; sudo is used where needed"
command -v sudo >/dev/null || die "sudo is not installed"
if ! "$DRY_RUN"; then
    sudo -v || die "sudo does not work for $USER"
    ping -c1 -W3 archlinux.org >/dev/null 2>&1 || die "no internet connection"
fi
ok "Arch Linux, user $USER"

# ------------------------------------------------------------------ 2. multilib
step "Package sources"
if grep -Eq '^\[multilib\]' /etc/pacman.conf; then
    info "[multilib] is enabled"
    HAVE_MULTILIB=true
else
    HAVE_MULTILIB=false
    info "[multilib] is off. Steam needs it; this would uncomment the two lines in /etc/pacman.conf:"
    info "    [multilib]"
    info "    Include = /etc/pacman.d/mirrorlist"
    if ask "Enable multilib?" n; then
        run sudo cp /etc/pacman.conf "/etc/pacman.conf.bak-$STAMP"
        run sudo sed -i '/^#\[multilib\]$/,/^#Include/ s/^#//' /etc/pacman.conf
        HAVE_MULTILIB=true
    fi
fi

# ------------------------------------------------------------------ 3. packages
step "Packages"
if "$SKIP_PACKAGES"; then
    info "skipped (--skip-packages)"
else
    mapfile -t PKGS < <(read_list "$REPO/packages/pacman.txt")
    run sudo pacman -Syu --needed "${CONFIRM[@]}" "${PKGS[@]}"
    if lspci 2>/dev/null | grep -Eqi 'vga|3d|display' && lspci | grep -Eqi 'intel'; then
        mapfile -t GPU < <(read_list "$REPO/packages/gpu-intel.txt")
        run sudo pacman -S --needed "${CONFIRM[@]}" "${GPU[@]}"
    fi
    if "$HAVE_MULTILIB"; then
        mapfile -t ML < <(read_list "$REPO/packages/multilib.txt")
        run sudo pacman -S --needed "${CONFIRM[@]}" "${ML[@]}"
    fi
    if ! command -v yay >/dev/null; then
        info "yay is not installed; building it from the AUR"
        BUILD=$(mktemp -d)
        run git clone https://aur.archlinux.org/yay-bin.git "$BUILD/yay-bin"
        if ! "$DRY_RUN"; then (cd "$BUILD/yay-bin" && makepkg -si --needed "${CONFIRM[@]}"); fi
        rm -rf "$BUILD"
    fi
    mapfile -t AUR < <(read_list "$REPO/packages/aur.txt")
    if ((${#AUR[@]})); then run yay -S --needed "${CONFIRM[@]}" "${AUR[@]}"; fi
    mapfile -t FLAT < <(read_list "$REPO/packages/flatpak.txt")
    if ((${#FLAT[@]})); then
        run flatpak remote-add --if-not-exists --user flathub https://dl.flathub.org/repo/flathub.flatpakrepo
        run flatpak install --user -y flathub "${FLAT[@]}"
    fi
fi

# ------------------------------------------------------------------ 4. dotfiles
step "Linking the dotfiles with GNU stow"
command -v stow >/dev/null || "$DRY_RUN" || die "stow is not installed"
# Generated theme files are written by theme-render, not stowed.
PACKAGES=(hypr waybar fuzzel mako swayosd kitty fish mpv btop fastfetch fontconfig xdg themes bin wallpaper-picker)

backup_conflicts() { # move real files that block a stow link into the backup dir
    local pkg=$1 src rel target
    while IFS= read -r -d '' src; do
        rel=${src#"$REPO/dotfiles/$pkg/"}
        target="$HOME/$rel"
        if [[ -e $target || -L $target ]] && [[ ! -L $target || $(readlink -f "$target") != "$(readlink -f "$src")" ]]; then
            if [[ -L $target && $(readlink -f "$target" || true) == "$REPO/dotfiles/"* ]]; then continue; fi
            run mkdir -p "$BACKUP_DIR/$(dirname "$rel")"
            run mv "$target" "$BACKUP_DIR/$rel"
            BACKED_UP=true
        fi
    done < <(find "$REPO/dotfiles/$pkg" \( -type f -o -type l \) -print0)
}
BACKED_UP=false
for pkg in "${PACKAGES[@]}"; do
    backup_conflicts "$pkg"
    run stow --no-folding --restow --dir "$REPO/dotfiles" --target "$HOME" "$pkg"
done
"$BACKED_UP" && note "Existing files were moved to $BACKUP_DIR"

# ------------------------------------------------------------------ 5. theme
step "Theme and wallpapers"
run mkdir -p "$HOME/Wallpapers" "$STATE_DIR"
for img in "$REPO"/wallpapers/*.{png,jpg,jpeg,webp}; do
    [[ -e $img && ! -e $HOME/Wallpapers/$(basename -- "$img") ]] && run cp -- "$img" "$HOME/Wallpapers/"
done
if "$DRY_RUN"; then
    info "$ theme-render --no-reload"
else
    PATH="$HOME/.local/bin:$PATH" theme-render --no-reload
fi
note "Put wallpapers in ~/Wallpapers, then press Super+Ctrl+T to choose one."

# ------------------------------------------------------------------ 6. system extras
step "System extras (each change to /etc asks first)"

pam_login_with_keyring() {
    awk '
        { lines[NR] = $0 }
        $1 == "auth" || $1 == "-auth" { last_auth = NR }
        $1 == "session" || $1 == "-session" { last_session = NR }
        END {
            for (i = 1; i <= NR; i++) {
                print lines[i]
                if (i == last_auth) print "auth       optional     pam_gnome_keyring.so"
                if (i == last_session) print "session    optional     pam_gnome_keyring.so auto_start"
            }
        }' /etc/pam.d/login
}

if grep -q pam_gnome_keyring /etc/pam.d/login 2>/dev/null; then
    info "the keyring is already unlocked at login"
elif [[ -f /etc/pam.d/login ]]; then
    info "to unlock the keyring at TTY login, /etc/pam.d/login would change like this:"
    new_pam=$(mktemp)
    pam_login_with_keyring >"$new_pam"
    diff -u /etc/pam.d/login "$new_pam" | sed 's/^/      /' || true
    if ask "Apply this edit to /etc/pam.d/login?" y; then
        run sudo cp /etc/pam.d/login "/etc/pam.d/login.bak-$STAMP"
        run sudo install -m 644 "$new_pam" /etc/pam.d/login
    fi
    rm -f "$new_pam"
fi

if command -v lsusb >/dev/null && grep -Eiq 'fingerprint|06cb:|27c6:|138a:|1c7a:|04f3:0c' <<<"$(lsusb)"; then
    info "fingerprint reader found"
    if grep -q pam_fprintd /etc/pam.d/sudo 2>/dev/null; then
        info "sudo already accepts a fingerprint"
    else
        info "to use it for sudo, this line would be added at the top of /etc/pam.d/sudo (the password keeps working):"
        info "    auth       sufficient   pam_fprintd.so"
        if ask "Apply this edit to /etc/pam.d/sudo?" n; then
            run sudo cp /etc/pam.d/sudo "/etc/pam.d/sudo.bak-$STAMP"
            run sudo sed -i '0,/^auth/s//auth       sufficient   pam_fprintd.so\n&/' /etc/pam.d/sudo
        fi
    fi
    note "Enrol a finger with: fprintd-enroll (hyprlock picks it up automatically)."
else
    info "no fingerprint reader found"
fi

if compgen -G "/sys/class/power_supply/BAT*/charge_control_end_threshold" >/dev/null; then
    if [[ -f /etc/udev/rules.d/90-battery-charge-limit.rules ]]; then
        info "the battery charge limit rule is already installed"
    else
        info "charge-limit needs write access to the battery thresholds;"
        info "this would install installer/system/90-battery-charge-limit.rules to /etc/udev/rules.d/"
        if ask "Install the udev rule?" y; then
            run sudo install -m 644 "$REPO/installer/system/90-battery-charge-limit.rules" /etc/udev/rules.d/
            run sudo udevadm control --reload
            run sudo udevadm trigger --subsystem-match=power_supply
        fi
    fi
    note "Limit charging to 80% with: charge-limit 80"
else
    info "no battery with charge thresholds found"
fi

info "services to enable: bluetooth, power-profiles-daemon, fprintd is socket-activated"
if ask "Enable bluetooth and power-profiles-daemon?" y; then
    run sudo systemctl enable --now bluetooth.service power-profiles-daemon.service
fi

# ------------------------------------------------------------------ 7. login
step "Login"
if [[ $(getent passwd "$USER" | cut -d: -f7) != /usr/bin/fish ]] && command -v fish >/dev/null; then
    if ask "Make fish your login shell?" y; then run chsh -s /usr/bin/fish; fi
fi
if ask "Start Hyprland automatically when you log in on tty1?" y; then
    run mkdir -p "$STATE_DIR"
    run touch "$STATE_DIR/autostart-hyprland"
fi
run touch "$STATE_DIR/setup-done"
ok "setup finished"
note "Log out and back in on tty1 (or run: start-hyprland)."
print_notes
