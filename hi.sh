#!/usr/bin/env bash

# shellcheck disable=SC1036,SC1088,SC2155,SC2059

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

    path_cache_dir="$HOME/.cache/hello-termux"
    path_cache_theme_list="$path_cache_dir/theme_list"
    path_cache_font_list="$path_cache_dir/font_list"
}

app::fetch() {
    local -n _out="$1"
    local _cache="$2"
    local _url="$3"

    if [[ -s $_cache ]]; then
        _out=$(< "$_cache")
    else
        _out=$(curl -#L "$_url") || return 1
        printf '%s\n' "$_out" > "$_cache"
    fi
}

app::set_deps() {
    declare -ag DEPS=(fzf)
    local missing=$(
        for dep in "${DEPS[@]}"; do
            command -v "$dep" > /dev/null 2>&1 || printf '%s\n' "$dep"
        done | paste -sd ' ' -
    )
    [[ -z $missing ]] || {
        printf "$MSG_dep_installing" "${missing}"
        pkg install -y "${missing}" || {
            printf "$MSG_dep_failed" "${missing}"
            return 1
        }
    }
}

termux::apply_nerd_font() {
    local font_suffix="$1"
    printf "$MSG_font_downloading" "$font_suffix"
    [[ -f $path_termux_font_ttf ]] && cp "$path_termux_font_ttf" "${path_termux_font_ttf}.bak"
    curl -#L "${url_nerd_fonts_download_prefix}/${font_suffix}" -o "$path_termux_font_ttf" && {
        termux-reload-settings
        printf "$MSG_font_applied" "$font_suffix"
        printf "$MSG_font_reload_warn"
    }
}

termux::open_url() {
    xdg-open "$1" || {
        printf "$MSG_open_url_failed" "$1"
        return 1
    }
}

menu::1() { termux-change-repo; }
menu::1::title() {
    local link=$(readlink "$path_termux_mirror_link")
    link="${link##*/}"
    local status
    [[ -z $link ]] && status="$MSG_repo_none" || { printf -v status "$MSG_repo_current" "$link"; }
    printf "${_cat1}%s${_faint}（%s）${_off}" "$MSG_repo_change" "$status"
}

menu::1a() { ln -sf "$PREFIX/etc/termux/mirrors/chinese_mainland" "$path_termux_mirror_link" && printf "$MSG_done"; }
menu::1a::title() { printf '%b' "${_cat1}${MSG_repo_quick_china}${_off}"; }

menu::2() { pkg update -y && apt upgrade -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold"; }
menu::2::title() {
    local _ts=$(find "$PREFIX/var/lib/apt/lists/" -maxdepth 1 -type f -printf '%T@\n' 2> /dev/null | sort -rn | head -1)
    local _date="$MSG_pkg_no_update"
    [[ -n $_ts ]] && _date=$(date -d "@$_ts" +'%Y-%m-%d %H:%M:%S' 2> /dev/null)
    local status
    [[ -n $_ts ]] && { printf -v status "$MSG_pkg_last_update" "$_date"; } || status="$MSG_pkg_no_update"
    printf "${_cat1}%s${_faint}（%s）${_off}" "$MSG_pkg_update" "$status"
}

menu::3() {
    app::set_deps || return 1

    local theme_list
    printf "$MSG_fetching_theme_list" "$url_ht_theme_text"
    app::fetch theme_list "$path_cache_theme_list" "$url_ht_theme_text" || {
        printf "$MSG_fetch_failed" "$url_ht_theme_text"
        return 1
    }
    [[ -n $theme_list ]] || return 1
    local chosen_theme=$(printf '%s\n' "$theme_list" | fzf --prompt="$MSG_theme_search_prompt")

    [[ -n $chosen_theme ]] || return 1
    printf "$MSG_downloading_theme" "$chosen_theme"
    local raw_url="$url_iterm2_color_schemes_prefix/${chosen_theme// /%20}.properties"
    [[ -f $path_termux_colors_properties ]] && cp "$path_termux_colors_properties" "${path_termux_colors_properties}.bak"
    curl -#L "$raw_url" -o "$path_termux_colors_properties" && {
        termux-reload-settings
        printf "$MSG_applied_theme" "$chosen_theme"
    }
}
menu::3::title() { printf '%b' "${_cat2}${MSG_theme_browse}${_faint}（mbadolato/iTerm2-Color-Schemes）${_off}"; }

menu::3a() { termux::open_url "https://github.com/mbadolato/iTerm2-Color-Schemes"; }
menu::3a::title() { printf '%b' "${_cat2}${MSG_theme_browse_browser}${_off}"; }

menu::3b() {
    [[ -f $path_termux_colors_properties ]] && cp "$path_termux_colors_properties" "${path_termux_colors_properties}.bak"
    base64 -d <<< 'IyBEcmFjdWxhKwpmb3JlZ3JvdW5kPSNmOGY4ZjIKYmFja2dyb3VuZD0jMjEyMTIxCmN1cnNvcj0jZWNlZmY0Cgpjb2xvcjA9IzIxMjIyYwpjb2xvcjE9I2ZmNTU1NQpjb2xvcjI9IzUwZmE3Ygpjb2xvcjM9I2ZmY2I2Ygpjb2xvcjQ9IzgyYWFmZgpjb2xvcjU9I2M3OTJlYQpjb2xvcjY9IzhiZTlmZApjb2xvcjc9I2Y4ZjhmMgoKY29sb3I4PSM1NDU0NTQKY29sb3I5PSNmZjZlNmUKY29sb3IxMD0jNjlmZjk0CmNvbG9yMTE9I2ZmY2I2Ygpjb2xvcjEyPSNkNmFjZmYKY29sb3IxMz0jZmY5MmRmCmNvbG9yMTQ9I2E0ZmZmZgpjb2xvcjE1PSNmOGY4ZjIK' > "$path_termux_colors_properties"
    termux-reload-settings
}
menu::3b::title() { printf '%b' "${_cat2}${MSG_theme_quick_dracula}${_off}"; }

menu::4() {
    app::set_deps || return 1

    local font_list
    printf "$MSG_fetching_font_list" "$url_ht_font_text"
    app::fetch font_list "$path_cache_font_list" "$url_ht_font_text" || {
        printf "$MSG_fetch_failed" "$url_ht_font_text"
        return 1
    }
    [[ -n $font_list ]] || return 1
    local chosen=$(printf '%s\n' "$font_list" | fzf --prompt="$MSG_font_search_prompt")

    [[ -n $chosen ]] || return 1
    [[ $chosen == */* ]] || {
        printf "$MSG_font_invalid" "$chosen"
        return 1
    }
    termux::apply_nerd_font "$chosen"
}
menu::4::title() { printf '%b' "${_cat3}${MSG_font_browse}${_faint}（ryanoasis/nerd-fonts）${_off}"; }

menu::4a() { termux::open_url "https://www.programmingfonts.org/#oxproto"; }
menu::4a::title() { printf '%b' "${_cat3}${MSG_font_browse_browser}${_faint}（programmingfonts.org）${_off}"; }

menu::4b() { termux::apply_nerd_font "IosevkaTerm/IosevkaTermNerdFont-Regular.ttf"; }
menu::4b::title() { printf '%b' "${_cat3}${MSG_font_quick_iosevka}${_off}"; }

menu::k() {
    [[ -f $path_termux_key_properties ]] && cp "$path_termux_key_properties" "${path_termux_key_properties}.bak"
    printf "$MSG_fetching_keymap" "$url_ht_properties"
    curl -#L "$url_ht_properties" -o "$path_termux_key_properties" && {
        termux-reload-settings
        printf "$MSG_done"
    }
}
menu::k::title() { printf '%b' "${_cat4}${MSG_keymap_apply}${_faint}（miniyu157/hello-termux）${_off}"; }

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
menu::s::title() { printf "${_cat4}%s${_faint}（${MSG_repo_current}）${_off}" "$MSG_resource_switch" "$app_resource_service"; }

menu::l() {
    case "$_lang" in
        zh) _lang="en" ;;
        *)  _lang="zh" ;;
    esac
    app::i18n_load
    MENU_QUICK=1
}
menu::l::title() {
    case "$_lang" in
        zh) printf "${_cat4}切换语言${_faint}（目前：中文）${_off}" ;;
        *)  printf "${_cat4}Switch Language${_faint} (Current: English)${_off}" ;;
    esac
}

menu::q() { exit 0; }
menu::q::title() { printf '%b' "${_cat4}${MSG_menu_quit}${_off}"; }

# -- i18n --

app::i18n_load() {
    case "$_lang" in
        zh)
            MSG_dep_installing="正在安装缺少的依赖: %s\n"
            MSG_dep_failed="依赖安装失败: %s\n"
            MSG_font_downloading="下载字体 '%s'...\n"
            MSG_font_applied="应用字体 '%s' 成功。\n"
            MSG_font_reload_warn="更改字体后建议重启 Termux，否则可能会闪退导致丢失数据。\n"
            MSG_open_url_failed="拉起 xdg-open 失败: %s\n"
            MSG_repo_change="更换软件包源"
            MSG_repo_current="目前: %s"
            MSG_repo_none="未设置任何源"
            MSG_done="设置完成。\n"
            MSG_repo_quick_china="快捷设置 Chinese 源"
            MSG_pkg_update="更新和升级软件包"
            MSG_pkg_last_update="上次更新: %s"
            MSG_pkg_no_update="无"
            MSG_fetch_failed="获取失败: %s\n"
            MSG_fetching_theme_list="拉取主题列表: %s\n"
            MSG_downloading_theme="下载主题 '%s'...\n"
            MSG_applied_theme="应用主题 '%s' 成功。\n"
            MSG_theme_browse="探索颜色主题"
            MSG_theme_browse_browser="在浏览器预览颜色主题"
            MSG_theme_quick_dracula="快捷应用 Dracula+ 主题"
            MSG_theme_search_prompt="搜索主题 > "
            MSG_fetching_font_list="拉取字体列表: %s\n"
            MSG_font_invalid="无效选择: %s\n"
            MSG_font_browse="探索 Nerd Font 字体"
            MSG_font_browse_browser="在浏览器预览字体效果"
            MSG_font_quick_iosevka="快捷安装 IosevkaTerm Nerd Font"
            MSG_font_search_prompt="搜索字体 > "
            MSG_fetching_keymap="拉取文件: %s\n"
            MSG_keymap_apply="应用实用按键布局"
            MSG_resource_switch="切换程序资源服务器"
            MSG_menu_quit="退出程序"
            MSG_menu_prompt="键入需要的工具回车运行\n"
            MSG_menu_done=" 工具运行结束，退出码: %s\n"
            MSG_menu_continue="  按回车键继续..."
            ;;
        *)
            MSG_dep_installing="Installing missing dependencies: %s\n"
            MSG_dep_failed="Failed to install dependencies: %s\n"
            MSG_font_downloading="Downloading font '%s'...\n"
            MSG_font_applied="Font '%s' applied successfully.\n"
            MSG_font_reload_warn="Restart Termux after changing fonts — otherwise it may crash and cause data loss.\n"
            MSG_open_url_failed="Failed to open URL: %s\n"
            MSG_repo_change="Change package mirror"
            MSG_repo_current="Current: %s"
            MSG_repo_none="No mirror set"
            MSG_done="Done.\n"
            MSG_repo_quick_china="Quick-set Chinese mainland mirror"
            MSG_pkg_update="Update and upgrade packages"
            MSG_pkg_last_update="Last update: %s"
            MSG_pkg_no_update="None"
            MSG_fetch_failed="Failed to fetch: %s\n"
            MSG_fetching_theme_list="Fetching theme list: %s\n"
            MSG_downloading_theme="Downloading theme '%s'...\n"
            MSG_applied_theme="Theme '%s' applied successfully.\n"
            MSG_theme_browse="Discover color themes"
            MSG_theme_browse_browser="Preview color themes in browser"
            MSG_theme_quick_dracula="Quick-apply Dracula+"
            MSG_theme_search_prompt="Search themes > "
            MSG_fetching_font_list="Fetching font list: %s\n"
            MSG_font_invalid="Invalid selection: %s\n"
            MSG_font_browse="Discover Nerd Fonts"
            MSG_font_browse_browser="Preview fonts in browser"
            MSG_font_quick_iosevka="Quick-install IosevkaTerm Nerd Font"
            MSG_font_search_prompt="Search fonts > "
            MSG_fetching_keymap="Fetching file: %s\n"
            MSG_keymap_apply="Apply enhanced key bindings"
            MSG_resource_switch="Switch resource server"
            MSG_menu_quit="Exit"
            MSG_menu_prompt="Type a key and press Enter to run\n"
            MSG_menu_done=" Tool finished, exit code: %s\n"
            MSG_menu_continue="  Press Enter to continue..."
            ;;
    esac
}

# -- init --

declare -g _refresh=$'\e[H\e[J' _b=$'\e[1m' _faint=$'\e[2m' _italic=$'\e[3m' _off=$'\e[0m' _ok=$'\e[38;2;101;255;101m' _cat1=$'\e[1;38;2;255;115;108m' _cat2=$'\e[1;38;2;121;167;252m' _cat3=$'\e[1;38;2;255;174;193m' _cat4=$'\e[1;38;2;255;226;2m'

_loc=$(getprop persist.sys.locale 2>/dev/null) || true
case "${_loc:-}" in zh-*) _lang="zh" ;; *) _lang="en" ;; esac
app::i18n_load

app::set_env cdn.jsdelivr.net
mkdir -p "$path_cache_dir"

# -- loop menu --

while true; do
    cat << EOF
${_refresh}
${_b}  ✦ Hello Termux ✦ ${_off}
${_faint}    https://github.com/miniyu157/Hello-Termux${_off}
─────────────────────────────────────────────────
$(
    menu_keys=(1 1a 2 3 3a 3b 4 4a 4b k l s q)
    for _id in "${menu_keys[@]}"; do
        if compgen -A function -- "menu::${_id}::title" > /dev/null; then
            printf "${_faint}${_italic}%3s${_off} %s\n" "$_id" "$("menu::${_id}::title")"
        fi
    done
)
${_faint}─────────────────────────────────────────────────${_off}
EOF
    printf "$MSG_menu_prompt"
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
        printf "${_ok}>${_off}${MSG_menu_done}" "$?"
        printf "$MSG_menu_continue"
        read -r _ < /dev/tty
    }
done
