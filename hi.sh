#!/usr/bin/env bash

# shellcheck disable=SC1036,SC1088,SC2155

app::set_env() {
    local service="$1"
    case "$service" in
        cdn.jsdelivr.net)
            app_resource_service="cdn.jsdelivr.net"

            url_ht_properties="https://cdn.jsdelivr.net/gh/miniyu157/hello-termux@main/termux.properties"
            url_ht_theme_text="https://cdn.jsdelivr.net/gh/miniyu157/hello-termux@main/theme_list.txt"
            url_iterm2_color_schemes_prefix="https://cdn.jsdelivr.net/gh/mbadolato/iTerm2-Color-Schemes@master/termux"
            url_ht_font_text="https://cdn.jsdelivr.net/gh/miniyu157/hello-termux@main/font_list.txt"
            url_nerd_fonts_download_prefix="https://cdn.jsdelivr.net/gh/ryanoasis/nerd-fonts@master/patched-fonts"
            ;;
        github.com)
            app_resource_service="github.com"

            url_ht_properties="https://github.com/miniyu157/hello-termux/raw/main/termux.properties"
            url_ht_theme_text="https://github.com/miniyu157/hello-termux/raw/main/theme_list.txt"
            url_iterm2_color_schemes_prefix="https://raw.githubusercontent.com/mbadolato/iTerm2-Color-Schemes/master/termux"
            url_ht_font_text="https://github.com/miniyu157/hello-termux/raw/main/font_list.txt"
            url_nerd_fonts_download_prefix="https://raw.githubusercontent.com/ryanoasis/nerd-fonts/master/patched-fonts"
            ;;
    esac

    path_termux_mirror_link="$PREFIX/etc/termux/chosen_mirrors"
    path_termux_key_properties="$HOME/.termux/termux.properties"
    path_termux_colors_properties="$HOME/.termux/colors.properties"
    path_termux_font_ttf="$HOME/.termux/font.ttf"
}

app::set_deps() {
    declare -ag DEPS=(fzf)
    local missing=$(
        for dep in "${DEPS[@]}"; do
            command -v "$dep" > /dev/null 2>&1 || printf '%s\n' "$dep"
        done | paste -sd ' ' -
    )
    [[ -z $missing ]] || {
        printf "正在安装缺少的依赖: %s\n" "${missing}"
        pkg install -y "${missing}" || {
            printf "依赖安装失败: %s\n" "${missing}"
            return 1
        }
    }
}

termux::apply_nerd_font() {
    local font_suffix="$1"
    printf "下载字体 '%s'...\n" "$font_suffix"
    [[ -f $path_termux_font_ttf ]] && cp "$path_termux_font_ttf" "${path_termux_font_ttf}.bak"
    curl -#L "${url_nerd_fonts_download_prefix}/${font_suffix}" -o "$path_termux_font_ttf" && {
        termux-reload-settings
        printf "应用字体 '%s' 成功。\n" "$font_suffix"
        printf "更改字体后建议重启 Termux，否则可能会闪退导致丢失数据。\n"
    }
}

termux::open_url() {
    xdg-open "$1" || {
        printf "拉起 xdg-open 失败: %s\n" "$1"
        return 1
    }
}

menu::1() { termux-change-repo; }
menu::1::title() {
    local link=$(readlink "$path_termux_mirror_link")
    link="${link##*/}"
    printf "${_cat1}更换软件包源${_faint}（目前: %s）${_off}" "${link:-未设置任何源}"
}

menu::1a() { ln -sf "$PREFIX/etc/termux/mirrors/chinese_mainland" "$path_termux_mirror_link" && printf "设置完成。\n"; }
menu::1a::title() { printf '%b' "${_cat1}快捷设置 Chinese 源${_off}"; }

menu::2() { pkg update -y && apt upgrade -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold"; }
menu::2::title() {
    local _ts=$(find "$PREFIX/var/lib/apt/lists/" -maxdepth 1 -type f -printf '%T@\n' 2> /dev/null | sort -rn | head -1)
    local _date="无"
    [[ -n $_ts ]] && _date=$(date -d "@$_ts" +'%Y-%m-%d %H:%M:%S' 2> /dev/null)
    printf "${_cat1}更新和升级软件包${_faint}（上次更新: %s）${_off}" "$_date"
}

menu::3() {
    app::set_deps || return 1

    printf "拉取主题列表: %s\n" "$url_ht_theme_text"
    local theme_list="$(curl -#L "$url_ht_theme_text")"
    [[ -n $theme_list ]] || return 1
    local chosen_theme=$(printf '%s\n' "$theme_list" | fzf --prompt="搜索主题 > ")

    [[ -n $chosen_theme ]] || return 1
    printf "下载主题 '%s'...\n" "$chosen_theme"
    local raw_url="$url_iterm2_color_schemes_prefix/${chosen_theme// /%20}.properties"
    [[ -f $path_termux_colors_properties ]] && cp "$path_termux_colors_properties" "${path_termux_colors_properties}.bak"
    curl -#L "$raw_url" -o "$path_termux_colors_properties" && {
        termux-reload-settings
        printf "应用主题 '%s' 成功。\n" "$chosen_theme"
    }
}
menu::3::title() { printf '%b' "${_cat2}探索颜色主题${_faint}（mbadolato/iTerm2-Color-Schemes）${_off}"; }

menu::3a() { termux::open_url "https://github.com/mbadolato/iTerm2-Color-Schemes"; }
menu::3a::title() { printf '%b' "${_cat2}在浏览器预览颜色主题${_off}"; }

menu::3b() {
    [[ -f $path_termux_colors_properties ]] && cp "$path_termux_colors_properties" "${path_termux_colors_properties}.bak"
    base64 -d <<< 'IyBEcmFjdWxhKwpmb3JlZ3JvdW5kPSNmOGY4ZjIKYmFja2dyb3VuZD0jMjEyMTIxCmN1cnNvcj0jZWNlZmY0Cgpjb2xvcjA9IzIxMjIyYwpjb2xvcjE9I2ZmNTU1NQpjb2xvcjI9IzUwZmE3Ygpjb2xvcjM9I2ZmY2I2Ygpjb2xvcjQ9IzgyYWFmZgpjb2xvcjU9I2M3OTJlYQpjb2xvcjY9IzhiZTlmZApjb2xvcjc9I2Y4ZjhmMgoKY29sb3I4PSM1NDU0NTQKY29sb3I5PSNmZjZlNmUKY29sb3IxMD0jNjlmZjk0CmNvbG9yMTE9I2ZmY2I2Ygpjb2xvcjEyPSNkNmFjZmYKY29sb3IxMz0jZmY5MmRmCmNvbG9yMTQ9I2E0ZmZmZgpjb2xvcjE1PSNmOGY4ZjIK' > "$path_termux_colors_properties"
    termux-reload-settings
}
menu::3b::title() { printf '%b' "${_cat2}快捷应用 Dracula+ 主题${_off}"; }

menu::4() {
    app::set_deps || return 1

    printf "拉取字体列表: %s\n" "$url_ht_font_text"
    local font_list=$(curl -#L "$url_ht_font_text")
    [[ -n $font_list ]] || return 1
    local chosen=$(printf '%s\n' "$font_list" | fzf --prompt="搜索字体 > ")

    [[ -n $chosen ]] || return 1
    [[ $chosen == */* ]] || {
        printf "无效选择: %s\n" "$chosen"
        return 1
    }
    termux::apply_nerd_font "$chosen"
}
menu::4::title() { printf '%b' "${_cat3}安装 Nerd Font 字体${_faint}（ryanoasis/nerd-fonts）${_off}"; }

menu::4a() { termux::open_url "https://www.programmingfonts.org/#oxproto"; }
menu::4a::title() { printf '%b' "${_cat3}在浏览器预览字体效果${_faint}（programmingfonts.org）${_off}"; }

menu::4b() { termux::apply_nerd_font "IosevkaTerm/IosevkaTermNerdFont-Regular.ttf"; }
menu::4b::title() { printf '%b' "${_cat3}快捷安装 IosevkaTerm Nerd Font${_off}"; }

menu::k() {
    [[ -f $path_termux_key_properties ]] && cp "$path_termux_key_properties" "${path_termux_key_properties}.bak"
    printf "拉取文件: %s\n" "$url_ht_properties"
    curl -#L "$url_ht_properties" -o "$path_termux_key_properties" && {
        termux-reload-settings
        printf "设置完成。\n"
    }
}
menu::k::title() { printf '%b' "${_cat4}应用实用按键布局${_faint}（miniyu157/hello-termux）${_off}"; }

menu::s() {
    [[ $app_resource_service != "github.com" ]] && {
        app::set_env github.com
        MENU_QUICK=1
        return 0
    }

    [[ $app_resource_service != "cdn.jsdelivr.net" ]] && {
        app::set_env cdn.jsdelivr.net
        MENU_QUICK=1
        return 0
    }
}
menu::s::title() { printf "${_cat4}切换程序资源服务器${_faint}（目前: %s）${_off}" "$app_resource_service"; }

menu::q() { exit 0; }
menu::q::title() { printf '%b' "${_cat4}退出程序${_off}"; }

# -- init --

declare -g _refresh=$'\e[H\e[J' _b=$'\e[1m' _faint=$'\e[2m' _italic=$'\e[3m' _off=$'\e[0m' _ok=$'\e[38;2;101;255;101m' _cat1=$'\e[1;38;2;255;115;108m' _cat2=$'\e[1;38;2;121;167;252m' _cat3=$'\e[1;38;2;255;174;193m' _cat4=$'\e[1;38;2;255;226;2m'

app::set_env cdn.jsdelivr.net

# -- loop menu --

while true; do
    cat << EOF
${_refresh}
${_b}  ✦ Hello Termux ✦ ${_off}
${_faint}    https://github.com/miniyu157/Hello-Termux${_off}
─────────────────────────────────────────────────
$(
    menu_keys=(1 1a 2 3 3a 3b 4 4a 4b k s q)
    for _id in "${menu_keys[@]}"; do
        if compgen -A function -- "menu::${_id}::title" > /dev/null; then
            printf "${_faint}${_italic}%3s${_off} %s\n" "$_id" "$("menu::${_id}::title")"
        fi
    done
)
${_faint}─────────────────────────────────────────────────${_off}
EOF
    printf "键入需要的工具回车运行\n"
    read -e -r choice < /dev/tty || {
        printf "\n"
        exit 0
    }
    [[ -z $choice ]] && continue
    compgen -A function -- "menu::${choice}" > /dev/null || continue
    history -s -- "$choice"
    MENU_QUICK=0
    "menu::${choice}"
    (( MENU_QUICK )) || {
        printf "${_ok}>${_off} 工具运行结束，退出码: %s\n" "$?"
        printf "  按回车键继续..."
        read -r _ < /dev/tty
    }
done
