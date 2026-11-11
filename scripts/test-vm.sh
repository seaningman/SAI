#!/usr/bin/env bash
# Boot the built ISO in QEMU (UEFI, KVM) with a blank 40 GB disk to test the installer.
#   scripts/test-vm.sh [--fresh|--disk]
#   --fresh  new blank disk, boot the ISO     --disk  boot the installed disk (no ISO)
set -euo pipefail
REPO=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
VM=$REPO/vm
mkdir -p "$VM"
ISO=$(find "$REPO/out" -name "*.iso" -printf "%T@ %p\n" 2>/dev/null | sort -rn | head -n1 | cut -d" " -f2-)
[[ -n $ISO || ${1:-} == --disk ]] || { echo "no ISO in out/ (run: sudo scripts/build-iso.sh)" >&2; exit 1; }
[[ ${1:-} == --fresh || ! -f $VM/disk.qcow2 ]] && { rm -f "$VM"/disk.qcow2 "$VM"/OVMF_VARS.fd; qemu-img create -f qcow2 "$VM/disk.qcow2" 40G >/dev/null; }
[[ -f $VM/OVMF_VARS.fd ]] || cp /usr/share/edk2/x64/OVMF_VARS.4m.fd "$VM/OVMF_VARS.fd"

BOOT=(-cdrom "$ISO" -boot d)
[[ ${1:-} == --disk ]] && BOOT=()

exec qemu-system-x86_64 -enable-kvm -cpu host -smp 4 -m 6G \
    -drive if=pflash,format=raw,readonly=on,file=/usr/share/edk2/x64/OVMF_CODE.4m.fd \
    -drive if=pflash,format=raw,file="$VM/OVMF_VARS.fd" \
    -drive file="$VM/disk.qcow2",if=virtio \
    "${BOOT[@]}" \
    -device virtio-vga-gl -display gtk,gl=on \
    -device qemu-xhci -device usb-tablet -device virtio-net-pci,netdev=n -netdev user,id=n
