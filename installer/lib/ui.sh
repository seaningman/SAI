# shellcheck shell=bash
# Shared helpers: Tokyo Night coloured output, prompts, dry-run aware `run`.
# Colours are read from the central theme file, so the installer matches the desktop.
# Expects REPO (repository root), DRY_RUN and ASSUME_YES to be set by the caller.

THEME_FILE=${THEME_FILE:-$REPO/dotfiles/themes/.config/theme/themes/tokyo-night/colors.toml}

_hex() { sed -n "s/^$1 *= *\"#\([0-9a-fA-F]\{6\}\)\".*/\1/p" "$THEME_FILE" 2>/dev/null; }
_fg() { # _fg <hex> -> 24-bit foreground escape
    local h=${1:-ffffff}
    printf '\e[38;2;%d;%d;%dm' "0x${h:0:2}" "0x${h:2:2}" "0x${h:4:2}"
}

if [[ -t 1 && -z ${NO_COLOR:-} ]]; then
    C_ACCENT=$(_fg "$(_hex accent)")
    C_FG=$(_fg "$(_hex foreground)")
    C_BRIGHT=$(_fg "$(_hex bright_foreground)")
    C_DIM=$(_fg "$(_hex dark_foreground)")
    C_OK=$(_fg "$(_hex green)")
    C_WARN=$(_fg "$(_hex yellow)")
    C_ERR=$(_fg "$(_hex red)")
    C_RST=$'\e[0m'
    C_BOLD=$'\e[1m'
else
    C_ACCENT='' C_FG='' C_BRIGHT='' C_DIM='' C_OK='' C_WARN='' C_ERR='' C_RST='' C_BOLD=''
fi

STEP=0
TOTAL_STEPS=${TOTAL_STEPS:-1}
NOTES=()

# banner <title> <subtitle>: a centred, bordered header (plain text, no logo).
banner() {
    local title=$1 sub=${2:-} width=56 line
    line=$(printf '─%.0s' $(seq 1 "$width"))
    printf '\n%s╭%s╮%s\n' "$C_ACCENT" "$line" "$C_RST"
    printf '%s│%s%s%s%*s%s│%s\n' "$C_ACCENT" "$C_BOLD$C_BRIGHT" "$(_center "$title" "$width")" "$C_RST" 0 '' "$C_ACCENT" "$C_RST"
    [[ -n $sub ]] && printf '%s│%s%s%s%s│%s\n' "$C_ACCENT" "$C_DIM" "$(_center "$sub" "$width")" "$C_ACCENT" "" "$C_RST"
    printf '%s╰%s╯%s\n\n' "$C_ACCENT" "$line" "$C_RST"
}
_center() { # _center <text> <width>
    local text=$1 width=$2 pad_l pad_r
    pad_l=$(((width - ${#text}) / 2))
    pad_r=$((width - ${#text} - pad_l))
    printf '%*s%s%*s' "$pad_l" '' "$text" "$pad_r" ''
}

step() { STEP=$((STEP + 1)); printf '\n%s%s ▌ [%d/%d] %s%s\n' "$C_ACCENT" "$C_BOLD" "$STEP" "$TOTAL_STEPS" "$1" "$C_RST"; }
info() { printf '    %s%s%s\n' "$C_FG" "$*" "$C_RST"; }
ok()   { printf '    %s✓ %s%s\n' "$C_OK" "$*" "$C_RST"; }
warn() { printf '    %s! %s%s\n' "$C_WARN" "$*" "$C_RST"; }
die()  { printf '%s✗ error:%s %s\n' "$C_ERR" "$C_RST" "$*" >&2; exit 1; }
note() { NOTES+=("$*"); }

# run <cmd...>: print the command; execute it unless this is a dry run.
run() {
    printf '    %s$ %s%s\n' "$C_DIM" "$(printf '%q ' "$@")" "$C_RST"
    "$DRY_RUN" || "$@"
}

# run_sh <shell string>: like run, for pipelines and redirects.
run_sh() {
    printf '    %s$ %s%s\n' "$C_DIM" "$1" "$C_RST"
    "$DRY_RUN" || bash -c "$1"
}

# ask <question> <y|n>: yes/no prompt. --yes, --dry-run and non-interactive runs take the default.
ask() {
    local question=$1 default=$2 reply hint='[y/N]'
    [[ $default == y ]] && hint='[Y/n]'
    if "$ASSUME_YES" || "$DRY_RUN" || [[ ! -t 0 ]]; then
        info "$question $hint -> $default (default)"
        [[ $default == y ]]
        return
    fi
    read -r -p "    $question $hint " reply
    reply=${reply:-$default}
    [[ $reply =~ ^[Yy] ]]
}

# prompt <question> <default> -> echoes the answer
prompt() {
    local question=$1 default=$2 reply
    if "$ASSUME_YES" || [[ ! -t 0 ]]; then printf '%s' "$default"; return; fi
    read -r -p "    $question [$default] " reply
    printf '%s' "${reply:-$default}"
}

# prompt_secret <question> -> echoes the answer (not shown while typing)
prompt_secret() {
    local reply
    read -r -s -p "    $1: " reply
    printf '\n' >&2
    printf '%s' "$reply"
}

# read_list <file>: one entry per line; blank lines and # comments skipped.
read_list() { [[ -f $1 ]] && sed -E 's/#.*//; s/[[:space:]]+$//; /^$/d' "$1" || true; }

print_notes() {
    ((${#NOTES[@]})) || return 0
    printf '\n%s%sNext steps%s\n' "$C_ACCENT" "$C_BOLD" "$C_RST"
    local n
    for n in "${NOTES[@]}"; do info "• $n"; done
}
