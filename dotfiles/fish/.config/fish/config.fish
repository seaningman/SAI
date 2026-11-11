# Tools installed per user (uv tools, Claude Code)
fish_add_path -g ~/.local/bin

# Commands to run in interactive sessions can go here
if status is-interactive
    # No greeting
    set fish_greeting

    # Use starship
    function starship_transient_prompt_func
        starship module character
    end
    if test "$TERM" != "linux"
        starship init fish | source
        enable_transience
    end
    
    # Aliases
    # kitty doesn't clear properly so we need to do this weird printing
    alias clear "printf '\033[2J\033[3J\033[1;1H'"
    alias celar "printf '\033[2J\033[3J\033[1;1H'"
    alias claer "printf '\033[2J\033[3J\033[1;1H'"
    alias pamcan pacman
    if test "$TERM" = "xterm-kitty"
        alias ssh 'kitten ssh'
    end

    # zoxide: the z command (cd itself is left alone)
    if type -q zoxide
        zoxide init fish | source
    end
end

# Colours generated from the central theme (theme-render)
test -f ~/.config/fish/theme.fish; and source ~/.config/fish/theme.fish
