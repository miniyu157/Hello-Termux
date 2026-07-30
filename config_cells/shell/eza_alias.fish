# -- eza alias {{ --
if status is-interactive
    set -l _eza_base "eza --icons --group-directories-first --hyperlink --time-style=relative"
    alias ls="eza"
    alias l="$_eza_base"
    alias la="$_eza_base -a"
    alias lt="$_eza_base -T"
    alias lt2="$_eza_base -T -L2"
    alias lta="$_eza_base -aT"
    alias lta2="$_eza_base -aT -L2"
    alias ll="$_eza_base -l --git --header --no-user"
    alias llu="$_eza_base -l --git --header -g"
    alias lla="$_eza_base -la --git --header --no-user"
    alias llau="$_eza_base -la --git --header -g"
    alias llt="$_eza_base -lT --git --no-user"
    alias lltu="$_eza_base -lT --git -g"
    alias llt2="$_eza_base -lT -L2 --git --no-user"
    alias lltu2="$_eza_base -lT -L2 --git -g"
    alias llta="$_eza_base -laT --git --header --no-user"
    alias lltau="$_eza_base -laT --git --header -g"
    alias llta2="$_eza_base -laT -L2 --git --header --no-user"
    alias lltau2="$_eza_base -laT -L2 --git --header -g"
    set -e _eza_base
end
# -- }} eza alias --
