#!/usr/bin/env bash
# Build the installer ISO with mkarchiso. Takes the stock "releng" profile, overlays this
# repository (packages, installer, dotfiles) and builds into ./out.
#
#   scripts/build-iso.sh [--dry-run]
# Needs: archiso, rsync, and root (mkarchiso).
set -euo pipefail

REPO=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
DRY_RUN=false
ASSUME_YES=false
export ASSUME_YES
[[ ${1:-} == --dry-run ]] && DRY_RUN=true
TOTAL_STEPS=3
export TOTAL_STEPS
# shellcheck source=../installer/lib/ui.sh
source "$REPO/installer/lib/ui.sh"

RELENG=/usr/share/archiso/configs/releng
WORK=$REPO/build
PROFILE=$WORK/profile

banner "Arch" "ISO build"
step "Preparing the profile"
if ! "$DRY_RUN"; then
    command -v mkarchiso >/dev/null || die "archiso is not installed (pacman -S archiso)"
    [[ -d $RELENG ]] || die "$RELENG not found"
    [[ $EUID -eq 0 ]] || die "mkarchiso needs root (use sudo)"
fi
run rm -rf "$WORK"
run mkdir -p "$WORK"
run cp -r "$RELENG" "$PROFILE"
run_sh "cat '$REPO/iso/packages.extra' | sed -E 's/#.*//; /^[[:space:]]*\$/d' >>'$PROFILE/packages.x86_64'"
run sed -i -e 's|^iso_name=.*|iso_name="arch-distro"|' -e 's|^iso_application=.*|iso_application="Arch installer"|' "$PROFILE/profiledef.sh"
run rsync -a "$REPO/iso/airootfs/" "$PROFILE/airootfs/"
run mkdir -p "$PROFILE/airootfs/opt/distro"
run rsync -a --exclude .git --exclude build --exclude out --exclude iso "$REPO/" "$PROFILE/airootfs/opt/distro/"
run_sh "grep -q '/opt/distro' '$PROFILE/profiledef.sh' || sed -i 's|^file_permissions=(|file_permissions=(\\n  [\"/opt/distro/installer/install.sh\"]=\"0:0:755\"\\n  [\"/opt/distro/installer/desktop-setup.sh\"]=\"0:0:755\"|' '$PROFILE/profiledef.sh'"

step "Building"
run mkarchiso -v -w "$WORK/work" -o "$REPO/out" "$PROFILE"

step "Done"
ok "ISO written to $REPO/out"
