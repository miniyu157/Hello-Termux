#!/usr/bin/env bash

# shellcheck disable=SC1036,SC1088,SC2155,SC2059

app::set_resource_service() {
    local service="$1"
    case "$service" in
        cdn.jsdelivr.net)
            app_resource_service="cdn.jsdelivr.net"
            URL_theme_list="https://cdn.jsdelivr.net/gh/miniyu157/hello-termux@main/theme_list.txt"
            URL_theme_prefix="https://cdn.jsdelivr.net/gh/mbadolato/iTerm2-Color-Schemes@master/termux"
            URL_font_list="https://cdn.jsdelivr.net/gh/miniyu157/hello-termux@main/font_list.txt"
            URL_font_prefix="https://cdn.jsdelivr.net/gh/ryanoasis/nerd-fonts@master/patched-fonts"
            URL_keymap_list="https://cdn.jsdelivr.net/gh/miniyu157/hello-termux@main/keymap_list.txt"
            URL_keymap_prefix="https://cdn.jsdelivr.net/gh/miniyu157/hello-termux@main/keymaps"
            URL_exe="https://cdn.jsdelivr.net/gh/miniyu157/hello-termux@main/hi.sh"
            URL_shell_cells="https://cdn.jsdelivr.net/gh/miniyu157/hello-termux@main/shell_cells/"
            ;;
        github.com)
            app_resource_service="github.com"
            URL_theme_list="https://github.com/miniyu157/hello-termux/raw/main/theme_list.txt"
            URL_theme_prefix="https://raw.githubusercontent.com/mbadolato/iTerm2-Color-Schemes/master/termux"
            URL_font_list="https://github.com/miniyu157/hello-termux/raw/main/font_list.txt"
            URL_font_prefix="https://raw.githubusercontent.com/ryanoasis/nerd-fonts/master/patched-fonts"
            URL_keymap_list="https://github.com/miniyu157/hello-termux/raw/main/keymap_list.txt"
            URL_keymap_prefix="https://github.com/miniyu157/hello-termux/raw/main/keymaps"
            URL_exe="https://github.com/miniyu157/hello-termux/raw/main/hi.sh"
            URL_shell_cells="https://github.com/miniyu157/hello-termux/raw/main/shell_cells/"
            ;;
        cdn.statically.io)
            app_resource_service="cdn.statically.io"
            URL_theme_list="https://cdn.statically.io/gh/miniyu157/hello-termux/main/theme_list.txt"
            URL_theme_prefix="https://cdn.statically.io/gh/mbadolato/iTerm2-Color-Schemes/master/termux"
            URL_font_list="https://cdn.statically.io/gh/miniyu157/hello-termux/main/font_list.txt"
            URL_font_prefix="https://cdn.statically.io/gh/ryanoasis/nerd-fonts/master/patched-fonts"
            URL_keymap_list="https://cdn.statically.io/gh/miniyu157/hello-termux/main/keymap_list.txt"
            URL_keymap_prefix="https://cdn.statically.io/gh/miniyu157/hello-termux/main/keymaps"
            URL_exe="https://cdn.statically.io/gh/miniyu157/hello-termux/main/hi.sh"
            URL_shell_cells="https://cdn.statically.io/gh/miniyu157/hello-termux/main/shell_cells/"
            ;;
    esac
}

app::set_paths() {
    path_termux_mirrors_dir="$PREFIX/etc/termux/mirrors"
    path_termux_mirror_link="$PREFIX/etc/termux/chosen_mirrors"
    path_termux_apt_lists="$PREFIX/var/lib/apt/lists"

    path_termux_key_properties="$HOME/.termux/termux.properties"
    path_termux_colors_properties="$HOME/.termux/colors.properties"
    path_termux_font_ttf="$HOME/.termux/font.ttf"

    path_cache_dir="$HOME/.cache/hello-termux"
    path_cache_theme_list="$path_cache_dir/theme_list"
    path_cache_font_list="$path_cache_dir/font_list"
    path_cache_keymap_list="$path_cache_dir/keymap_list"

    path_cache_themes="$HOME/.termux/cache/themes"
    path_cache_fonts="$HOME/.termux/cache/fonts"
    path_cache_keymaps="$HOME/.termux/cache/keymaps"

    path_termux_tmp="$PREFIX/tmp"

    path_install_bin="$PREFIX/bin/hi"
    path_uninstall_bin="$PREFIX/bin/hi-uninstall"

    mkdir -p "$path_cache_dir" "$path_cache_themes" "$path_cache_fonts" "$path_cache_keymaps"
}

app::set_deps() {
    local missing=()
    for dep in "$@"; do
        command -v "$dep" > /dev/null 2>&1 || missing+=("$dep")
    done
    ((${#missing[@]})) || return 0
    printf "$MSG_dep_installing" "${missing[*]}"
    pkg install -y "${missing[@]}" || {
        printf "$MSG_dep_failed"
        return 1
    }
}

pure::fetch_cached() {
    local -n _ref_out="$1"
    local cache="$2" url="$3" ttl="${4:-30}"

    if [[ -s $cache ]] && [[ -z $(find "$cache" -mtime "+$ttl" 2> /dev/null) ]]; then
        _ref_out=$(< "$cache")
    else
        _ref_out=$(curl -#L "$url") || return 1
        printf '%s\n' "$_ref_out" > "$cache"
    fi
}

pure::cache_resource() {
    local cache_dir="$1" name="$2" url="$3"
    local dest="${cache_dir}/${name}"
    [[ -f $dest ]] && return 0
    mkdir -p "$(dirname "$dest")"
    curl -#L "$url" -o "${dest}.tmp" && mv "${dest}.tmp" "$dest"
}

# Swap two files
pure::swap_file() {
    local a="$1" b="$2" tmp
    tmp=$(mktemp "$path_termux_tmp/ht_XXXXX") || return 1
    mv "$a" "$tmp" && mv "$b" "$a" && mv "$tmp" "$b"
}

# 应用一个 nerd font 字体
# $1  用于拼接仓库的后缀
termux::apply_nerd_font() {
    local name="$1"
    pure::cache_resource "$path_cache_fonts" "$name" \
        "${URL_font_prefix}/${name}" || return 1
    cp -f "$path_cache_fonts/$name" "$path_termux_font_ttf"
    termux-reload-settings
    printf "$MSG_applied_font" "$name"
}

# 应用一个 iTerm2 颜色主题
# $1  主题名称（用于拼接 URL 后缀）
termux::apply_web_theme() {
    local name="$1"
    pure::cache_resource "$path_cache_themes" "$name" \
        "${URL_theme_prefix}/${name// /%20}" || return 1
    cp -f "$path_cache_themes/$name" "$path_termux_colors_properties"
    termux-reload-settings
    printf "$MSG_applied_theme" "$name"
}

# 应用一个按键布局
# $1  按键布局名称（用于拼接 URL 后缀）
termux::apply_keymap() {
    local name="$1"
    pure::cache_resource "$path_cache_keymaps" "$name" \
        "${URL_keymap_prefix}/${name// /%20}" || return 1
    cp -f "$path_cache_keymaps/$name" "$path_termux_key_properties"
    termux-reload-settings
    printf "$MSG_applied_keymap" "$name"
}

termux::open_url() {
    xdg-open "$1" || {
        printf "$MSG_open_url_failed" "$1"
        return 1
    }
}

menu::m() { termux-change-repo; }
menu::m::title() {
    local link=$(readlink "$path_termux_mirror_link" 2> /dev/null)
    link="${link##*/}"
    printf "$MSG_MENU_repo_change" "${link:-$MSG_MENU_repo_change_none}"
}

menu::mc() { ln -sf "$path_termux_mirrors_dir/chinese_mainland" "$path_termux_mirror_link" && printf "$MSG_done"; }
menu::mc::title() { printf "$MSG_MENU_repo_quick_china"; }

menu::u() { pkg update -y && apt upgrade -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold"; }
menu::u::title() {
    local ts=$(find "$path_termux_apt_lists/" -maxdepth 1 -type f -printf '%T@\n' 2> /dev/null | sort -rn | head -1)
    local date
    [[ -n $ts ]] && date=$(date -d "@$ts" +'%Y-%m-%d %H:%M:%S' 2> /dev/null)
    printf "$MSG_MENU_pkg_update" "${date:-$MSG_MENU_pkg_update_none}"
}

menu::t() {
    app::set_deps fzf || return 1

    local theme_list
    pure::fetch_cached theme_list "$path_cache_theme_list" "$URL_theme_list" || {
        printf "$MSG_fetch_failed" "$URL_theme_list"
        return 1
    }

    local chosen_theme=$(printf '%s\n' "$theme_list" | awk '{full=$0; sub(/\.properties$/,""); print $0 "\t" full}' | fzf --prompt="$MSG_theme_search_prompt" --with-nth=1 --delimiter='\t' | cut -f2)
    [[ -n $chosen_theme ]] || {
        MENU_QUICK=1
        return 1
    }

    termux::apply_web_theme "$chosen_theme"
}
menu::t::title() { printf "$MSG_MENU_theme_browse"; }

menu::f() {
    app::set_deps fzf || return 1

    local font_list
    pure::fetch_cached font_list "$path_cache_font_list" "$URL_font_list" || {
        printf "$MSG_fetch_failed" "$URL_font_list"
        return 1
    }

    local chosen=$(printf '%s\n' "$font_list" | awk -F/ '{full=$0; ext=$NF; sub(/\.[^.]+$/,"",ext); print ext "\t" full}' | fzf --prompt="$MSG_font_search_prompt" --with-nth=1 --delimiter='\t' | cut -f2)
    [[ -n $chosen ]] || {
        MENU_QUICK=1
        return 1
    }

    termux::apply_nerd_font "$chosen"
}
menu::f::title() { printf "$MSG_MENU_font_browse"; }

menu::k() {
    app::set_deps fzf || return 1

    local keymap_list
    pure::fetch_cached keymap_list "$path_cache_keymap_list" "$URL_keymap_list" || {
        printf "$MSG_fetch_failed" "$URL_keymap_list"
        return 1
    }

    local chosen=$(printf '%s\n' "$keymap_list" | awk '{full=$0; sub(/\.properties$/,""); print $0 "\t" full}' | fzf --prompt="$MSG_keymap_search_prompt" --with-nth=1 --delimiter='\t' | cut -f2)
    [[ -n $chosen ]] || {
        MENU_QUICK=1
        return 1
    }
    termux::apply_keymap "$chosen"
}
menu::k::title() { printf "$MSG_MENU_keymap_browse"; }

menu::tb() { termux::open_url "https://github.com/mbadolato/iTerm2-Color-Schemes"; }
menu::tb::title() { printf "$MSG_MENU_theme_browse_browser"; }

menu::tt() { termux::apply_web_theme "Dracula+.properties"; }
menu::tt::title() { printf "$MSG_MENU_theme_quick"; }

menu::fb() { termux::open_url "https://www.programmingfonts.org/#oxproto"; }
menu::fb::title() { printf "$MSG_MENU_font_browse_browser"; }

menu::ff() { termux::apply_nerd_font "IosevkaTerm/IosevkaTermNerdFont-Regular.ttf"; }
menu::ff::title() { printf "$MSG_MENU_font_quick"; }

menu::kb() { termux::open_url "https://github.com/miniyu157/hello-termux"; }
menu::kb::title() { printf "$MSG_MENU_keymap_browse_browser"; }

menu::kk() { termux::apply_keymap "Enhanced.properties"; }
menu::kk::title() { printf "$MSG_MENU_keymap_quick"; }

menu::fish() {
    app::set_deps fish || return 1
    chsh -s fish && printf "$MSG_shell_changed" fish
}
menu::fish::title() { printf "$MSG_MENU_fish_setup"; }

menu::ffff() {
    local fisher_func="$HOME/.config/fish/functions/fisher.fish"
    if [[ ! -f "$fisher_func" ]]; then
        fish -c "curl -sL https://raw.githubusercontent.com/jorgebucaran/fisher/main/functions/fisher.fish | source && fisher install jorgebucaran/fisher" || return 1
    fi
    printf "$MSG_fisher_installed"
}
menu::ffff::title() { printf "$MSG_MENU_fisher_setup"; }

menu::eza() {
    app::set_deps eza gum || return 1

    local shell
    shell=$(gum choose --header="$(printf "$MSG_choose_shell_for" "eza")" bash fish) || {
        MENU_QUICK=1
        return 1
    }

    local remote="${URL_shell_cells}eza_alias.${shell}"
    local cache="$path_cache_dir/eza_alias_${shell}"

    local content
    pure::fetch_cached content "$cache" "$remote" || {
        printf "$MSG_fetch_failed" "$remote"
        return 1
    }

    local config
    case "$shell" in
        bash) config="$HOME/.bashrc" ;;
        fish) config="$HOME/.config/fish/conf.d/config.fish" ;;
    esac

    local first="# -- eza alias {{ --"
    local last="# -- }} eza alias --"

    if [[ -f "$config" ]] && grep -qF "$first" "$config" && grep -qF "$last" "$config"; then
        printf "$MSG_already_configured"
        return 0
    fi

    mkdir -p "$(dirname "$config")"

    local tmp
    tmp=$(mktemp "$path_termux_tmp/ht_XXXXX.tmp") || return 1

    if [[ -f "$config" ]]; then
        cat "$config" > "$tmp"
    fi
    [[ -s "$tmp" ]] && echo >> "$tmp"
    printf '%s\n' "$content" >> "$tmp"

    local src="$config"
    [[ -f "$config" ]] || src=/dev/null
    diff --color=always -u "$src" "$tmp" 2>/dev/null || true

    gum confirm "$MSG_accept_changes" || {
        rm -f "$tmp"
        MENU_QUICK=1
        return 1
    }

    if [[ -f "$config" ]]; then
        pure::swap_file "$tmp" "$config"
        printf "$MSG_backup_config_path" "$tmp"
    else
        mv "$tmp" "$config"
        printf "$MSG_file_created" "$config"
    fi
    printf "$MSG_shell_changed" "$shell"
}
menu::eza::title() { printf "$MSG_MENU_eza_setup"; }

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
    printf "$MSG_fetching_file" "$URL_exe"
    curl -#L "$URL_exe" -o "$path_install_bin" || {
        printf "$MSG_fetch_failed" "$URL_exe"
        return 1
    }
    chmod +x "$path_install_bin"
    cat > "$path_uninstall_bin" << EOF
#!/usr/bin/env bash
rm -f "$path_install_bin" "$path_uninstall_bin"
printf 'hi has been uninstalled.\n'
EOF
    chmod +x "$path_uninstall_bin"
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
    rm -rf "$path_cache_dir"
    mkdir -p "$path_cache_dir"
    printf "$MSG_cache_cleared" "$path_cache_dir"
}
menu::cl::title() { printf "${MSG_MENU_cache_clear}"; }

menu::is() { termux::open_url "https://github.com/miniyu157/hello-termux/issues"; }
menu::is::title() { printf "$MSG_MENU_issues"; }

menu::gh() { termux::open_url "https://github.com/miniyu157/hello-termux"; }
menu::gh::title() { printf "$MSG_MENU_gh"; }

menu::q() { exit 0; }
menu::q::title() { printf "${MSG_MENU_quit}"; }

# -- i18n --

app::set_lang() { case "$(getprop persist.sys.locale 2> /dev/null)" in zh-*) APP_LANG="zh" ;; *) APP_LANG="en" ;; esac }

app::i18n_load() {
    case "$APP_LANG" in
        zh)
            MSG_LOOPMENU_prompt="${_uline}键入需要的工具回车运行:${_off}\n"
            MSG_LOOPMENU_done=" 工具运行结束，退出码: %s\n"
            MSG_LOOPMENU_continue="  按回车键继续..."

            MSG_fetching_file="拉取文件: %s\n"
            MSG_fetch_failed="拉取失败: %s\n"
            MSG_dep_installing="正在安装缺少的依赖: %s\n"
            MSG_dep_failed="依赖安装未完成。\n"
            MSG_open_url_failed="拉起 xdg-open 失败: %s\n"
            MSG_done="设置完成。\n"

            MSG_MENU_repo_change="${_cat1}${_memu_hl} 更换软件包源${_faint}（镜像: %s）${_off}"
            MSG_MENU_repo_change_none="未设置"

            MSG_MENU_repo_quick_china="${_cat1} 快捷设置中国大陆软件源${_off}"
            MSG_MENU_pkg_update="${_cat1}󰏕 更新和升级软件包${_faint}（上次更新: %s）${_off}"
            MSG_MENU_pkg_update_none="无"

            MSG_applied_font="应用字体 '%s' 成功。\n"
            MSG_applied_theme="应用主题 '%s' 成功。\n"
            MSG_applied_keymap="应用按键布局 '%s' 成功。\n"

            MSG_theme_search_prompt="搜索主题 > "
            MSG_font_search_prompt="搜索字体 > "
            MSG_keymap_search_prompt="搜索按键布局 > "

            MSG_MENU_font_browse="${_cat2}${_memu_hl} 探索 Nerd Font 字体${_faint}（ryanoasis/nerd-fonts）${_off}"
            MSG_MENU_font_browse_browser="${_cat2}󰆋 在浏览器预览字体效果${_faint}（programmingfonts.org）${_off}"
            MSG_MENU_font_quick="${_cat2} 快捷安装 IosevkaTerm Nerd Font${_off}"

            MSG_MENU_theme_browse="${_cat3}${_memu_hl} 探索颜色主题${_faint}（mbadolato/iTerm2-Color-Schemes）${_off}"
            MSG_MENU_theme_browse_browser="${_cat3}󰆋 在浏览器预览颜色主题${_off}"
            MSG_MENU_theme_quick="${_cat3} 快捷应用 Dracula+ 主题${_off}"

            MSG_MENU_keymap_browse="${_cat4}${_memu_hl}󰌓 探索按键布局${_faint}（miniyu157/Hello-Termux）${_off}"
            MSG_MENU_keymap_browse_browser="${_cat4}󰆋 在浏览器预览按键布局${_off}"
            MSG_MENU_keymap_quick="${_cat4} 快捷应用实用按键布局${_off}"

            MSG_choose_shell_for="需要为哪个 shell 设置 %s？"
            MSG_MENU_eza_setup="${_green} 配置 eza 和实用别名${_off}"
            MSG_already_configured="已有配置，未修改。\n"
            MSG_accept_changes="是否接受以上更改？"
            MSG_backup_config_path="修改前的配置位于 %s\n"
            MSG_file_created="已新建文件: %s\n"

            MSG_MENU_fish_setup="${_green}${_memu_hl} 设置终端自动补全 -- fish${_off}"
            MSG_MENU_fisher_setup="${_green}󰻳 为 fish 安装 fisher 插件${_off}"
            MSG_fisher_installed="已安装 fisher，可以使用 '${_hl}fisher${_off}' 命令管理 fish 插件，也可以卸载自身。\n\n推荐:\n- 智能补全插件 gazorby/fifc\n- 优秀主题 IlanCosman/tide@v6\n\n探索开源社区以了解更多信息！\n"
            MSG_shell_changed="${_ok}>${_off} 已更改 shell 配置，使用以下操作均可查看效果：\n- 开启新会话\n- 重启终端应用\n- 运行 '${_hl}exec %s${_off}'\n"

            MSG_MENU_resource_switch="󰛍 切换程序资源服务器${_faint}（当前: %s）${_off}"
            MSG_MENU_lang_switch=" 切换语言${_faint}（目前：中文）${_off}"
            MSG_MENU_install=" 将此程序安装到本地"
            MSG_install_done="安装完成。使用 hi 启动。\n使用 hi-uninstall 卸载。\n"

            MSG_MENU_cache_clear=" 清除下载缓存${_faint}（TTL: 30天）${_off}"
            MSG_cache_cleared="清理: %s\n"
            MSG_MENU_issues="󰭻 前往 Issues 页面"
            MSG_MENU_gh="󰊤 前往 Hello Termux 的仓库"
            MSG_MENU_quit="󰩈 退出程序"
            ;;
        *)
            MSG_LOOPMENU_prompt="${_uline}Type a key and press Enter to run:${_off}\n"
            MSG_LOOPMENU_done=" Tool finished, exit code: %s\n"
            MSG_LOOPMENU_continue="  Press Enter to continue..."

            MSG_fetching_file="Fetching file: %s\n"
            MSG_fetch_failed="Failed to fetch: %s\n"
            MSG_dep_installing="Installing missing dependencies: %s\n"
            MSG_dep_failed="Dependency installation did not complete.\n"
            MSG_open_url_failed="Failed to open URL: %s\n"
            MSG_done="Done.\n"

            MSG_MENU_repo_change="${_cat1}${_memu_hl} Change package mirror${_faint} (mirror: %s)${_off}"
            MSG_MENU_repo_change_none="none"

            MSG_MENU_repo_quick_china="${_cat1} Quick-set Chinese mainland mirror${_off}"
            MSG_MENU_pkg_update="${_cat1}󰏕 Update and upgrade packages${_faint} (last update: %s)${_off}"
            MSG_MENU_pkg_update_none="none"

            MSG_applied_font="Font '%s' applied successfully.\n"
            MSG_applied_theme="Theme '%s' applied successfully.\n"
            MSG_applied_keymap="Keymap '%s' applied successfully.\n"

            MSG_theme_search_prompt="Search themes > "
            MSG_font_search_prompt="Search fonts > "
            MSG_keymap_search_prompt="Search keymaps > "

            MSG_MENU_font_browse="${_cat2}${_memu_hl} Discover Nerd Fonts${_faint} (ryanoasis/nerd-fonts)${_off}"
            MSG_MENU_font_browse_browser="${_cat2}󰆋 Preview fonts in browser${_faint} (programmingfonts.org)${_off}"
            MSG_MENU_font_quick="${_cat2} Quick-install IosevkaTerm Nerd Font${_off}"

            MSG_MENU_theme_browse="${_cat3}${_memu_hl} Discover color themes${_faint} (mbadolato/iTerm2-Color-Schemes)${_off}"
            MSG_MENU_theme_browse_browser="${_cat3}󰆋 Preview color themes in browser${_off}"
            MSG_MENU_theme_quick="${_cat3} Quick-apply Dracula+${_off}"

            MSG_MENU_keymap_browse="${_cat4}${_memu_hl}󰌓 Discover keymaps${_faint} (miniyu157/Hello-Termux)${_off}"
            MSG_MENU_keymap_browse_browser="${_cat4}󰆋 Preview keymaps in browser${_off}"
            MSG_MENU_keymap_quick="${_cat4} Quick-apply enhanced key bindings${_off}"

            MSG_choose_shell_for="Which shell to configure for %s?"
            MSG_MENU_eza_setup="${_green} Configure eza and useful aliases${_off}"
            MSG_already_configured="Already configured, no changes.\n"
            MSG_accept_changes="Accept the above changes?"
            MSG_backup_config_path="Previous config saved at %s\n"
            MSG_file_created="Created new file: %s\n"

            MSG_MENU_fish_setup="${_green}${_memu_hl} Set up terminal autocomplete -- fish${_off}"
            MSG_MENU_fisher_setup="${_green}󰻳 Install fisher plugin manager for fish${_off}"
            MSG_fisher_installed="fisher is installed. Use '${_hl}fisher${_off}' to manage fish plugins, or to uninstall itself.\n\nRecommended:\n- gazorby/fifc — smart completions\n- IlanCosman/tide@v6 — a beautiful prompt\n\nExplore the community for more!\n"
            MSG_shell_changed="${_ok}>${_off} Shell configuration changed. To see the effect:\n- Start a new session\n- Restart the terminal app\n- Run '${_hl}exec %s${_off}'\n"

            MSG_MENU_resource_switch="󰛍 Switch resource server${_faint} (current: %s)${_off}"
            MSG_MENU_lang_switch=" Switch Language${_faint} (Current: English)${_off}"
            MSG_MENU_install=" Install this program locally"
            MSG_install_done="Done. Run 'hi' to start.\nRun 'hi-uninstall' to uninstall.\n"

            MSG_MENU_cache_clear=" Clear download cache${_faint} (TTL: 30 days)${_off}"
            MSG_cache_cleared="Cleared: %s\n"
            MSG_MENU_issues="󰭻 Go to Issues page"
            MSG_MENU_gh="󰊤 Go to Hello Termux repository"
            MSG_MENU_quit="󰩈 Exit"
            ;;
    esac
}

# -- init --

declare -g _refresh=$'\e[H\e[J' _b=$'\e[1m' _faint=$'\e[2m' _italic=$'\e[3m' _memu_hl=$'\e[1m' _uline=$'\e[4m' _off=$'\e[0m' _ok=$'\e[38;2;101;255;101m' _hl=$'\e[38;2;255;174;193m' _cat1=$'\e[38;2;255;115;108m' _cat2=$'\e[38;2;121;167;252m' _cat3=$'\e[38;2;255;174;193m' _cat4=$'\e[38;2;255;226;2m' _green=$'\e[38;2;173;255;184m'

app::set_lang
app::i18n_load

app::set_paths
app::set_resource_service github.com

# -- loop menu --

while true; do
    cat << EOF
${_refresh}
${_b}  ✦ Hello Termux ✦ ${_off}
${_faint}    https://github.com/miniyu157/Hello-Termux${_off}
─────────────────────────────────────────────────
$(
        menu_keys=(m mc u f fb ff t tb tt k kb kk fish eza ffff s l i cl is gh q)
        for _id in "${menu_keys[@]}"; do
            printf "${_faint}${_italic}%4s${_off} %s\n" "$_id" "$("menu::${_id}::title")"
        done
    )
${_faint}─────────────────────────────────────────────────${_off}
EOF
    printf "$MSG_LOOPMENU_prompt"
    read -e -r choice < /dev/tty || {
        printf "\n"
        exit 0
    }
    [[ -z $choice ]] && continue
    compgen -A function -- "menu::${choice}" | grep -qx "menu::${choice}" || continue
    history -s -- "$choice"
    MENU_QUICK=0
    "menu::${choice}"
    _rc=$?
    ((MENU_QUICK)) || {
        _p="$_ok>"
        ((_rc)) && _p="${_cat1}×"
        printf "${_p}${_off}${MSG_LOOPMENU_done}" "$_rc"
        printf "$MSG_LOOPMENU_continue"
        read -r _ < /dev/tty
    }
done
