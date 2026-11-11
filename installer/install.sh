#!/usr/bin/env bash
# System installer: run from the live ISO. Partitions a disk, sets up LUKS2, installs
# Arch with systemd-boot, your packages and the dotfiles. The desktop (AUR, Flatpak,
# stow, /etc extras) is finished on first login by desktop-setup.sh.
#
#   ./install.sh [--dry-run] [--yes] [--help]
#
# Non-interactive values can be preset with environment variables:
#   DISK HOSTNAME_ USERNAME_ USER_PASSWORD LUKS_PASSPHRASE USE_LUKS TIMEZONE LOCALE KEYMAP ENABLE_MULTILIB
set -euo pipefail

REPO=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
DRY_RUN=false
ASSUME_YES=false
TOTAL_STEPS=8
export TOTAL_STEPS
MNT=/mnt

for arg in "$@"; do
    case $arg in
        --dry-run) DRY_RUN=true ;;
        --yes) ASSUME_YES=true ;;
        --help | -h)
            sed -n '2,10p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
            exit 0
            ;;
        *) echo "unknown option: $arg (try --help)" >&2; exit 1 ;;
    esac
done

# shellcheck source=lib/ui.sh
source "$REPO/installer/lib/ui.sh"

part() { # part <disk> <n>: partition device name (nvme0n1p1 vs sda1)
    case $1 in *[0-9]) printf '%sp%s' "$1" "$2" ;; *) printf '%s%s' "$1" "$2" ;; esac
}

# ------------------------------------------------------------------ 1. checks
banner "Arch" "installer"
step "Checking the live environment"
if ! "$DRY_RUN"; then
    [[ $EUID -eq 0 ]] || die "run as root (from the live ISO)"
    [[ -d /sys/firmware/efi ]] || die "not booted in UEFI mode; systemd-boot needs UEFI"
    for t in sgdisk cryptsetup pacstrap arch-chroot genfstab mkfs.fat mkfs.ext4; do
        command -v "$t" >/dev/null || die "missing tool: $t"
    done
    ping -c1 -W3 archlinux.org >/dev/null 2>&1 || die "no internet connection"
else
    info "dry run: nothing below is executed"
fi
ok "environment looks fine"

# ----------------------------------------------------------------- 2. answers
step "A few questions"
if [[ -z ${DISK:-} ]]; then
    lsblk -dpno NAME,SIZE,MODEL | grep -v -E 'loop|sr[0-9]|zram' | sed 's/^/      /' || true
    DISK=$(prompt "Install to which disk?" "/dev/nvme0n1")
fi
HOSTNAME_=${HOSTNAME_:-$(prompt "Hostname" "arch")}
USERNAME_=${USERNAME_:-$(prompt "Username" "user")}
TIMEZONE=${TIMEZONE:-$(prompt "Timezone" "Europe/Berlin")}
LOCALE=${LOCALE:-$(prompt "Locale" "en_US.UTF-8")}
KEYMAP=${KEYMAP:-$(prompt "Console keymap" "de-latin1")}
# Switch the live console to it now, so the passphrase and password are typed with the
# same layout they will be entered with at boot (y/z and symbols differ between layouts).
"$DRY_RUN" || loadkeys "$KEYMAP" 2>/dev/null || warn "could not load keymap $KEYMAP; the live console stays on its default layout"
if [[ -z ${USE_LUKS:-} ]]; then
    if ask "Encrypt the disk with LUKS2?" y; then USE_LUKS=yes; else USE_LUKS=no; fi
fi
if ask "Enable [multilib] on the new system (needed for Steam)?" y; then
    ENABLE_MULTILIB=${ENABLE_MULTILIB:-yes}
else
    ENABLE_MULTILIB=no
fi
if "$DRY_RUN" || "$ASSUME_YES" && [[ -z ${USER_PASSWORD:-} ]]; then
    USER_PASSWORD=${USER_PASSWORD:-changeme}
fi
if [[ -z ${USER_PASSWORD:-} ]]; then
    USER_PASSWORD=$(prompt_secret "Password for $USERNAME_")
    [[ -n $USER_PASSWORD ]] || die "empty password"
fi
if [[ $USE_LUKS == yes && -z ${LUKS_PASSPHRASE:-} ]]; then
    if "$DRY_RUN"; then
        LUKS_PASSPHRASE=dry-run
    else
        LUKS_PASSPHRASE=$(prompt_secret "Disk encryption passphrase")
        [[ -n $LUKS_PASSPHRASE ]] || die "empty passphrase"
    fi
fi

info "Disk       $DISK (will be erased)"
info "Host/user  $HOSTNAME_ / $USERNAME_"
info "Encrypted  $USE_LUKS    multilib  $ENABLE_MULTILIB"
info "Boot       systemd-boot (UEFI)"

# -------------------------------------------------------------- 3. partitions
step "Partitioning $DISK"
if "$DRY_RUN"; then
    info "a real run asks you to type the disk name to confirm the erase"
else
    [[ -b $DISK ]] || die "$DISK is not a block device"
    if findmnt -rn -S "$DISK" >/dev/null || lsblk -rno MOUNTPOINT "$DISK" | grep -q .; then
        die "$DISK or one of its partitions is mounted"
    fi
    printf '    %sALL DATA ON %s WILL BE DESTROYED.%s\n' "$C_ERR" "$DISK" "$C_RST"
    read -r -p "    Type the disk name to continue: " typed
    [[ $typed == "$DISK" ]] || die "confirmation did not match, nothing was changed"
fi
ESP=$(part "$DISK" 1)
ROOT_PART=$(part "$DISK" 2)
run sgdisk --zap-all "$DISK"
run sgdisk -n 1:0:+1G -t 1:ef00 -c 1:ESP "$DISK"
run sgdisk -n 2:0:0 -t 2:8309 -c 2:root "$DISK"
run partprobe "$DISK"

# ------------------------------------------------------------------ 4. format
step "Formatting and mounting"
ROOT_DEV=$ROOT_PART
if [[ $USE_LUKS == yes ]]; then
    if "$DRY_RUN"; then
        info "$ printf %s <passphrase> | cryptsetup luksFormat --type luks2 $ROOT_PART -"
        info "$ cryptsetup open $ROOT_PART cryptroot -"
    else
        printf '%s' "$LUKS_PASSPHRASE" | cryptsetup luksFormat --type luks2 --batch-mode "$ROOT_PART" -
        printf '%s' "$LUKS_PASSPHRASE" | cryptsetup open "$ROOT_PART" cryptroot -
    fi
    ROOT_DEV=/dev/mapper/cryptroot
fi
run mkfs.fat -F32 "$ESP"
run mkfs.ext4 -F -L root "$ROOT_DEV"
run mount "$ROOT_DEV" "$MNT"
run mount --mkdir "$ESP" "$MNT/boot"

# ------------------------------------------------------------------ 5. packages
step "Installing the base system and packages"
mapfile -t BASE < <(read_list "$REPO/packages/base.txt")
mapfile -t PKGS < <(read_list "$REPO/packages/pacman.txt")
mapfile -t GPU < <(read_list "$REPO/packages/gpu-intel.txt")
run pacstrap -K "$MNT" "${BASE[@]}" "${PKGS[@]}" "${GPU[@]}"
run_sh "genfstab -U $MNT >$MNT/etc/fstab"

# ------------------------------------------------------------------ 6. configure
step "Configuring the new system"
if [[ $ENABLE_MULTILIB == yes ]]; then
    run sed -i '/^#\[multilib\]$/,/^#Include/ s/^#//' "$MNT/etc/pacman.conf"
fi
run_sh "echo '$HOSTNAME_' >$MNT/etc/hostname"
run_sh "echo 'KEYMAP=$KEYMAP' >$MNT/etc/vconsole.conf"
run_sh "echo 'LANG=$LOCALE' >$MNT/etc/locale.conf"
run sed -i "s/^#\\($LOCALE \\)/\\1/" "$MNT/etc/locale.gen"
run_sh "echo '%wheel ALL=(ALL:ALL) ALL' >$MNT/etc/sudoers.d/10-wheel && chmod 440 $MNT/etc/sudoers.d/10-wheel"

HOOKS='base systemd autodetect microcode modconf kms keyboard sd-vconsole block filesystems fsck'
[[ $USE_LUKS == yes ]] && HOOKS='base systemd autodetect microcode modconf kms keyboard sd-vconsole block sd-encrypt filesystems fsck'
run_sh "echo 'HOOKS=($HOOKS)' >$MNT/etc/mkinitcpio.conf.d/arch-distro.conf"

if "$DRY_RUN"; then
    ROOT_UUID="<uuid-of-$ROOT_PART>"
else
    ROOT_UUID=$(blkid -s UUID -o value "$ROOT_PART")
fi
if [[ $USE_LUKS == yes ]]; then
    CMDLINE="rd.luks.name=$ROOT_UUID=cryptroot root=/dev/mapper/cryptroot rw quiet"
else
    CMDLINE="root=UUID=$ROOT_UUID rw quiet"
fi
run_sh "mkdir -p $MNT/boot/loader/entries && printf 'default arch.conf\ntimeout 3\nconsole-mode max\neditor no\n' >$MNT/boot/loader/loader.conf"
run_sh "printf 'title   Arch Linux\nlinux   /vmlinuz-linux\ninitrd  /initramfs-linux.img\noptions %s\n' '$CMDLINE' >$MNT/boot/loader/entries/arch.conf"

run arch-chroot "$MNT" ln -sf "/usr/share/zoneinfo/$TIMEZONE" /etc/localtime
run arch-chroot "$MNT" hwclock --systohc
run arch-chroot "$MNT" locale-gen
run arch-chroot "$MNT" mkinitcpio -P
run arch-chroot "$MNT" bootctl install
run arch-chroot "$MNT" systemctl enable NetworkManager systemd-timesyncd
run arch-chroot "$MNT" useradd -m -G wheel,video,input -s /usr/bin/fish "$USERNAME_"
if "$DRY_RUN"; then
    info "$ echo '$USERNAME_:<password>' | arch-chroot $MNT chpasswd"
else
    printf '%s:%s\n' "$USERNAME_" "$USER_PASSWORD" | arch-chroot "$MNT" chpasswd
fi

# ------------------------------------------------------------------ 7. dotfiles
step "Copying the dotfiles and first-boot setup"
HOME_DIR="$MNT/home/$USERNAME_"
run mkdir -p "$HOME_DIR/.dotfiles" "$HOME_DIR/.config/fish/conf.d" "$HOME_DIR/.local/state/arch-distro"
run rsync -a --exclude .git --exclude iso --exclude build --exclude out --exclude vm "$REPO/" "$HOME_DIR/.dotfiles/"
# Runs desktop-setup.sh once on the first TTY login, then removes itself.
run_sh "cat >$HOME_DIR/.config/fish/conf.d/00-first-boot.fish <<'FISH'
if status is-login; and status is-interactive; and test -f ~/.dotfiles/installer/desktop-setup.sh
    if not test -e ~/.local/state/arch-distro/setup-done
        ~/.dotfiles/installer/desktop-setup.sh; and rm -f ~/.config/fish/conf.d/00-first-boot.fish
    end
end
FISH"
run arch-chroot "$MNT" chown -R "$USERNAME_:$USERNAME_" "/home/$USERNAME_"

# ------------------------------------------------------------------ 8. finish
step "Finishing"
run umount -R "$MNT"
[[ $USE_LUKS == yes ]] && run cryptsetup close cryptroot
ok "installation finished"
note "Remove the installation medium and reboot."
note "Log in on tty1: the desktop setup (AUR, Flatpak, configs) runs once, then Hyprland starts."
print_notes
