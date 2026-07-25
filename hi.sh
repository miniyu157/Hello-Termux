#!/usr/bin/env bash

# shellcheck disable=SC1036,SC1088,SC2155,SC2059

app::set_resource_service() {
    local service="$1"
    case "$service" in
        cdn.jsdelivr.net)
            app_resource_service="cdn.jsdelivr.net"
            url_ht_properties="https://cdn.jsdelivr.net/gh/miniyu157/hello-termux@main/termux.properties"
            url_ht_theme_text="https://cdn.jsdelivr.net/gh/miniyu157/hello-termux@main/theme_list.txt"
            url_iterm2_color_schemes_prefix="https://cdn.jsdelivr.net/gh/mbadolato/iTerm2-Color-Schemes@master/termux"
            url_ht_font_text="https://cdn.jsdelivr.net/gh/miniyu157/hello-termux@main/font_list.txt"
            url_nerd_fonts_download_prefix="https://cdn.jsdelivr.net/gh/ryanoasis/nerd-fonts@master/patched-fonts"
            url_ht_self="https://cdn.jsdelivr.net/gh/miniyu157/hello-termux@main/hi.sh"
            ;;
        github.com)
            app_resource_service="github.com"
            url_ht_properties="https://github.com/miniyu157/hello-termux/raw/main/termux.properties"
            url_ht_theme_text="https://github.com/miniyu157/hello-termux/raw/main/theme_list.txt"
            url_iterm2_color_schemes_prefix="https://raw.githubusercontent.com/mbadolato/iTerm2-Color-Schemes/master/termux"
            url_ht_font_text="https://github.com/miniyu157/hello-termux/raw/main/font_list.txt"
            url_nerd_fonts_download_prefix="https://raw.githubusercontent.com/ryanoasis/nerd-fonts/master/patched-fonts"
            url_ht_self="https://github.com/miniyu157/hello-termux/raw/main/hi.sh"
            ;;
        cdn.statically.io)
            app_resource_service="cdn.statically.io"
            url_ht_properties="https://cdn.statically.io/gh/miniyu157/hello-termux/main/termux.properties"
            url_ht_theme_text="https://cdn.statically.io/gh/miniyu157/hello-termux/main/theme_list.txt"
            url_iterm2_color_schemes_prefix="https://cdn.statically.io/gh/mbadolato/iTerm2-Color-Schemes/master/termux"
            url_ht_font_text="https://cdn.statically.io/gh/miniyu157/hello-termux/main/font_list.txt"
            url_nerd_fonts_download_prefix="https://cdn.statically.io/gh/ryanoasis/nerd-fonts/master/patched-fonts"
            url_ht_self="https://cdn.statically.io/gh/miniyu157/hello-termux/main/hi.sh"
            ;;
    esac
}

app::set_paths() {
    path_termux_mirrors_dir="$PREFIX/etc/termux/mirrors"
    path_termux_mirror_link="$PREFIX/etc/termux/chosen_mirrors"
    path_termux_key_properties="$HOME/.termux/termux.properties"
    path_termux_colors_properties="$HOME/.termux/colors.properties"
    path_termux_font_ttf="$HOME/.termux/font.ttf"

    path_termux_apt_lists="$PREFIX/var/lib/apt/lists"

    path_cache_dir="$HOME/.cache/hello-termux"
    path_cache_theme_list="$path_cache_dir/theme_list"
    path_cache_font_list="$path_cache_dir/font_list"

    path_ht_install_bin="$PREFIX/bin/hi"
    path_ht_uninstall_bin="$PREFIX/bin/hi-uninstall"

    mkdir -p "$path_cache_dir"
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

pure::fetch_cached() {
    local -n _out="$1"
    local _cache="$2" _url="$3"

    if [[ -s $_cache ]] && [[ -z $(find "$_cache" -mtime +30 2> /dev/null) ]]; then
        _out=$(< "$_cache")
    else
        _out=$(curl -#L "$_url") || return 1
        printf '%s\n' "$_out" > "$_cache"
    fi
}

pure::backup_file() { [[ -f $1 ]] && cp "$1" "${1}.$(date +%Y%m%d%H%M%S).bak"; }

termux::apply_nerd_font() {
    local font_suffix="$1"
    printf "$MSG_font_downloading" "$font_suffix"
    pure::backup_file "$path_termux_font_ttf"
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
    printf "$MSG_MENU_repo_change" "${link:-$MSG_MENU_repo_change_none}"
}

menu::1a() { ln -sf "$path_termux_mirrors_dir/chinese_mainland" "$path_termux_mirror_link" && printf "$MSG_done"; }
menu::1a::title() { printf "$MSG_MENU_repo_quick_china"; }

menu::2() { pkg update -y && apt upgrade -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold"; }
menu::2::title() {
    local _ts=$(find "$path_termux_apt_lists/" -maxdepth 1 -type f -printf '%T@\n' 2> /dev/null | sort -rn | head -1)
    local _date
    [[ -n $_ts ]] && _date=$(date -d "@$_ts" +'%Y-%m-%d %H:%M:%S' 2> /dev/null)
    printf "$MSG_MENU_pkg_update" "${_date:-$MSG_MENU_pkg_update_none}"
}

menu::3() {
    app::set_deps || return 1

    local theme_list
    printf "$MSG_fetching_theme_list" "$url_ht_theme_text"
    pure::fetch_cached theme_list "$path_cache_theme_list" "$url_ht_theme_text" || {
        printf "$MSG_fetch_failed" "$url_ht_theme_text"
        return 1
    }
    [[ -n $theme_list ]] || return 1
    local chosen_theme=$(printf '%s\n' "$theme_list" | fzf --prompt="$MSG_theme_search_prompt")

    [[ -n $chosen_theme ]] || return 1
    printf "$MSG_downloading_theme" "$chosen_theme"
    local raw_url="$url_iterm2_color_schemes_prefix/${chosen_theme// /%20}.properties"
    pure::backup_file "$path_termux_colors_properties"
    curl -#L "$raw_url" -o "$path_termux_colors_properties" && {
        termux-reload-settings
        printf "$MSG_applied_theme" "$chosen_theme"
    }
}
menu::3::title() { printf "$MSG_MENU_theme_browse"; }

menu::3a() { termux::open_url "https://github.com/mbadolato/iTerm2-Color-Schemes"; }
menu::3a::title() { printf "$MSG_MENU_theme_browse_browser"; }

menu::3b() {
    pure::backup_file "$path_termux_colors_properties"
    base64 -d <<< 'IyBEcmFjdWxhKwpmb3JlZ3JvdW5kPSNmOGY4ZjIKYmFja2dyb3VuZD0jMjEyMTIxCmN1cnNvcj0jZWNlZmY0Cgpjb2xvcjA9IzIxMjIyYwpjb2xvcjE9I2ZmNTU1NQpjb2xvcjI9IzUwZmE3Ygpjb2xvcjM9I2ZmY2I2Ygpjb2xvcjQ9IzgyYWFmZgpjb2xvcjU9I2M3OTJlYQpjb2xvcjY9IzhiZTlmZApjb2xvcjc9I2Y4ZjhmMgoKY29sb3I4PSM1NDU0NTQKY29sb3I5PSNmZjZlNmUKY29sb3IxMD0jNjlmZjk0CmNvbG9yMTE9I2ZmY2I2Ygpjb2xvcjEyPSNkNmFjZmYKY29sb3IxMz0jZmY5MmRmCmNvbG9yMTQ9I2E0ZmZmZgpjb2xvcjE1PSNmOGY4ZjIK' > "$path_termux_colors_properties"
    termux-reload-settings
}
menu::3b::title() { printf "$MSG_MENU_theme_quick_dracula"; }

menu::4() {
    app::set_deps || return 1

    local font_list
    printf "$MSG_fetching_font_list" "$url_ht_font_text"
    pure::fetch_cached font_list "$path_cache_font_list" "$url_ht_font_text" || {
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
menu::4::title() { printf "$MSG_MENU_font_browse"; }

menu::4a() { termux::open_url "https://www.programmingfonts.org/#oxproto"; }
menu::4a::title() { printf "$MSG_MENU_font_browse_browser"; }

menu::4b() { termux::apply_nerd_font "IosevkaTerm/IosevkaTermNerdFont-Regular.ttf"; }
menu::4b::title() { printf "$MSG_MENU_font_quick_iosevka"; }

menu::k() {
    pure::backup_file "$path_termux_key_properties"
    printf "$MSG_fetching_keymap" "$url_ht_properties"
    curl -#L "$url_ht_properties" -o "$path_termux_key_properties" && {
        termux-reload-settings
        printf "$MSG_done"
    }
}
menu::k::title() { printf "$MSG_MENU_keymap_apply"; }

menu::s() {
    case "$app_resource_service" in
        cdn.jsdelivr.net) app::set_resource_service github.com ;;
        github.com) app::set_resource_service cdn.statically.io ;;
        cdn.statically.io) app::set_resource_service cdn.jsdelivr.net ;;
    esac
    MENU_QUICK=1
}
menu::s::title() { printf "$MSG_MENU_resource_switch" "$app_resource_service"; }

menu::i() {
    printf "$MSG_fetching_keymap" "$url_ht_self"
    curl -#L "$url_ht_self" -o "$path_ht_install_bin" || {
        printf "$MSG_fetch_failed" "$url_ht_self"
        return 1
    }
    chmod +x "$path_ht_install_bin"
    cat > "$path_ht_uninstall_bin" << EOF
#!/usr/bin/env bash
rm -f "$path_ht_install_bin" "$path_ht_uninstall_bin"
printf 'hi has been uninstalled.\n'
EOF
    chmod +x "$path_ht_uninstall_bin"
    printf "$MSG_install_done"
}
menu::i::title() { printf "${MSG_MENU_install}"; }

menu::l() {
    case "$APP_LANG" in
        zh) APP_LANG="en" ;;
        *) APP_LANG="zh" ;;
    esac
    app::i18n_load
    MENU_QUICK=1
}
menu::l::title() { printf "$MSG_MENU_lang_switch"; }

menu::cl() {
    printf '%s\n' "$path_cache_dir"
    rm -rf "$path_cache_dir"
    mkdir -p "$path_cache_dir"
    printf "$MSG_done"
}
menu::cl::title() { printf "${MSG_MENU_cache_clear}"; }

menu::q() { exit 0; }
menu::q::title() { printf "${MSG_MENU_quit}"; }

# -- i18n --

app::set_lang() { case "$(getprop persist.sys.locale 2> /dev/null)" in zh-*) APP_LANG="zh" ;; *) APP_LANG="en" ;; esac }

app::i18n_load() {
    case "$APP_LANG" in
        zh)
            MSG_dep_installing="正在安装缺少的依赖: %s\n"
            MSG_dep_failed="依赖安装失败: %s\n"
            MSG_font_downloading="下载字体 '%s'...\n"
            MSG_font_applied="应用字体 '%s' 成功。\n"
            MSG_font_reload_warn="更改字体后建议重启 Termux，否则可能会闪退导致丢失数据。\n"
            MSG_open_url_failed="拉起 xdg-open 失败: %s\n"
            MSG_MENU_repo_change="${_cat1}更换软件包源${_faint}（镜像: %s）${_off}"
            MSG_MENU_repo_change_none="未设置"
            MSG_done="设置完成。\n"
            MSG_install_done="安装完成。使用 hi 启动。\n使用 hi-uninstall 卸载。\n"
            MSG_MENU_repo_quick_china="${_cat1}快捷设置中国大陆软件源${_off}"
            MSG_MENU_pkg_update="${_cat1}更新和升级软件包${_faint}（上次更新: %s）${_off}"
            MSG_MENU_pkg_update_none="无"
            MSG_fetch_failed="获取失败: %s\n"
            MSG_fetching_theme_list="拉取主题列表: %s\n"
            MSG_downloading_theme="下载主题 '%s'...\n"
            MSG_applied_theme="应用主题 '%s' 成功。\n"
            MSG_MENU_theme_browse="${_cat2}探索颜色主题${_faint}（mbadolato/iTerm2-Color-Schemes）${_off}"
            MSG_MENU_theme_browse_browser="${_cat2}在浏览器预览颜色主题${_off}"
            MSG_MENU_theme_quick_dracula="${_cat2}快捷应用 Dracula+ 主题${_off}"
            MSG_theme_search_prompt="搜索主题 > "
            MSG_fetching_font_list="拉取字体列表: %s\n"
            MSG_font_invalid="无效选择: %s\n"
            MSG_MENU_font_browse="${_cat3}探索 Nerd Font 字体${_faint}（ryanoasis/nerd-fonts）${_off}"
            MSG_MENU_font_browse_browser="${_cat3}在浏览器预览字体效果${_faint}（programmingfonts.org）${_off}"
            MSG_MENU_font_quick_iosevka="${_cat3}快捷安装 IosevkaTerm Nerd Font${_off}"
            MSG_font_search_prompt="搜索字体 > "
            MSG_fetching_keymap="拉取文件: %s\n"
            MSG_MENU_keymap_apply="${_cat4}应用实用按键布局${_faint}（miniyu157/Hello-Termux）${_off}"
            MSG_MENU_resource_switch="${_cat4}切换程序资源服务器${_faint}（当前: %s）${_off}"
            MSG_MENU_install="将此程序安装到本地"
            MSG_MENU_cache_clear="清除下载缓存"
            MSG_MENU_lang_switch="${_cat4}切换语言（目前：中文）${_off}"
            MSG_MENU_quit="退出程序"
            MSG_menu_prompt="键入需要的工具回车运行:\n"
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
            MSG_MENU_repo_change="${_cat1}Change package mirror${_faint} (mirror: %s)${_off}"
            MSG_MENU_repo_change_none="none"
            MSG_done="Done.\n"
            MSG_install_done="Done. Run 'hi' to start.\nRun 'hi-uninstall' to uninstall.\n"
            MSG_MENU_repo_quick_china="${_cat1}Quick-set Chinese mainland mirror${_off}"
            MSG_MENU_pkg_update="${_cat1}Update and upgrade packages${_faint} (last update: %s)${_off}"
            MSG_MENU_pkg_update_none="none"
            MSG_fetch_failed="Failed to fetch: %s\n"
            MSG_fetching_theme_list="Fetching theme list: %s\n"
            MSG_downloading_theme="Downloading theme '%s'...\n"
            MSG_applied_theme="Theme '%s' applied successfully.\n"
            MSG_MENU_theme_browse="${_cat2}Discover color themes${_faint} (mbadolato/iTerm2-Color-Schemes)${_off}"
            MSG_MENU_theme_browse_browser="${_cat2}Preview color themes in browser${_off}"
            MSG_MENU_theme_quick_dracula="${_cat2}Quick-apply Dracula+${_off}"
            MSG_theme_search_prompt="Search themes > "
            MSG_fetching_font_list="Fetching font list: %s\n"
            MSG_font_invalid="Invalid selection: %s\n"
            MSG_MENU_font_browse="${_cat3}Discover Nerd Fonts${_faint} (ryanoasis/nerd-fonts)${_off}"
            MSG_MENU_font_browse_browser="${_cat3}Preview fonts in browser${_faint} (programmingfonts.org)${_off}"
            MSG_MENU_font_quick_iosevka="${_cat3}Quick-install IosevkaTerm Nerd Font${_off}"
            MSG_font_search_prompt="Search fonts > "
            MSG_fetching_keymap="Fetching file: %s\n"
            MSG_MENU_keymap_apply="${_cat4}Apply enhanced key bindings${_faint} (miniyu157/Hello-Termux)${_off}"
            MSG_MENU_resource_switch="${_cat4}Switch resource server${_faint} (current: %s)${_off}"
            MSG_MENU_install="Install this program locally"
            MSG_MENU_cache_clear="Clear download cache"
            MSG_MENU_lang_switch="${_cat4}Switch Language (Current: English)${_off}"
            MSG_MENU_quit="Exit"
            MSG_menu_prompt="Type a key and press Enter to run:\n"
            MSG_menu_done=" Tool finished, exit code: %s\n"
            MSG_menu_continue="  Press Enter to continue..."
            ;;
    esac
}

# -- init --

declare -g _refresh=$'\e[H\e[J' _b=$'\e[1m' _faint=$'\e[2m' _italic=$'\e[3m' _off=$'\e[0m' _ok=$'\e[38;2;101;255;101m' _cat1=$'\e[1;38;2;255;115;108m' _cat2=$'\e[1;38;2;121;167;252m' _cat3=$'\e[1;38;2;255;174;193m' _cat4=$'\e[1;38;2;255;226;2m'

app::set_lang
app::i18n_load

app::set_paths
app::set_resource_service cdn.jsdelivr.net

# -- loop menu --

while true; do
    cat << EOF
${_refresh}
${_b}  ✦ Hello Termux ✦ ${_off}
${_faint}    https://github.com/miniyu157/Hello-Termux${_off}
─────────────────────────────────────────────────
$(
        menu_keys=(1 1a 2 3 3a 3b 4 4a 4b k l s i cl q)
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
    ((MENU_QUICK)) || {
        printf "${_ok}>${_off}${MSG_menu_done}" "$?"
        printf "$MSG_menu_continue"
        read -r _ < /dev/tty
    }
done
