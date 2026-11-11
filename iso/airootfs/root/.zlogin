# fix for screen readers (kept from the stock profile)
if grep -Fqa 'accessibility=' /proc/cmdline &> /dev/null; then
    setopt SINGLE_LINE_ZLE
fi

# Start the installer on the first console login. Press Ctrl+C in it to get a shell.
if [[ -z $DISPLAY && $(tty) == /dev/tty1 && -x /opt/distro/installer/install.sh ]]; then
    /opt/distro/installer/install.sh
fi
