#!/usr/bin/env bash

# shellcheck disable=SC1036,SC1088,SC2155,SC2059

app::set_resource_service() {
    local service="$1"
    case "$service" in
        cdn.jsdelivr.net)
            APP_RESOURCE_SERVICE="cdn.jsdelivr.net"
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
            APP_RESOURCE_SERVICE="github.com"
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
            APP_RESOURCE_SERVICE="cdn.statically.io"
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
    i18n::printf "正在安装缺少的依赖: %s\n" "Installing missing dependencies: %s\n" "${missing[*]}"
    pkg install -y "${missing[@]}" || {
        i18n::printf "依赖安装未完成。\n" "Dependency installation did not complete.\n"
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
    local a="$1" b="$2" tmp=$(mktemp "$path_termux_tmp/ht_XXXXX")
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
    i18n::printf "应用字体 '%s' 成功。\n" "Font '%s' applied successfully.\n" "$name"
}

# 应用一个 iTerm2 颜色主题
# $1  主题名称（用于拼接 URL 后缀）
termux::apply_web_theme() {
    local name="$1"
    pure::cache_resource "$path_cache_themes" "$name" \
        "${URL_theme_prefix}/${name// /%20}" || return 1
    cp -f "$path_cache_themes/$name" "$path_termux_colors_properties"
    termux-reload-settings
    i18n::printf "应用主题 '%s' 成功。\n" "Theme '%s' applied successfully.\n" "$name"
}

# 应用一个按键布局
# $1  按键布局名称（用于拼接 URL 后缀）
termux::apply_keymap() {
    local name="$1"
    pure::cache_resource "$path_cache_keymaps" "$name" \
        "${URL_keymap_prefix}/${name// /%20}" || return 1
    cp -f "$path_cache_keymaps/$name" "$path_termux_key_properties"
    termux-reload-settings
    i18n::printf "应用按键布局 '%s' 成功。\n" "Keymap '%s' applied successfully.\n" "$name"
}

termux::open_url() {
    xdg-open "$1" || {
        i18n::printf "拉起 xdg-open 失败: %s\n" "Failed to open URL: %s\n" "$1"
        return 1
    }
}

menu::m() { termux-change-repo; }
menu::m::title() {
    local link=$(readlink "$path_termux_mirror_link" 2> /dev/null)
    link="${link##*/}"
    i18n::printf \
        "${_cat1}${_memu_hl} 更换软件包源${_faint}（镜像: %s）${_off}" \
        "${_cat1}${_memu_hl} Change package mirror${_faint} (mirror: %s)${_off}" \
        "${link:-$(i18n::printf "未设置" "none")}"
}

menu::mc() { ln -sf "$path_termux_mirrors_dir/chinese_mainland" "$path_termux_mirror_link" && i18n::printf "设置完成。\n" "Done.\n"; }
menu::mc::title() { i18n::printf "${_cat1} 快捷设置中国大陆软件源${_off}" "${_cat1} Quick-set Chinese mainland mirror${_off}"; }

menu::u() { pkg update -y && apt upgrade -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold"; }
menu::u::title() {
    local ts=$(find "$path_termux_apt_lists/" -maxdepth 1 -type f -printf '%T@\n' 2> /dev/null | sort -rn | head -1)
    local date
    [[ -n $ts ]] && date=$(date -d "@$ts" +'%Y-%m-%d %H:%M:%S' 2> /dev/null)
    i18n::printf \
        "${_cat1}󰏕 更新和升级软件包${_faint}（上次更新: %s）${_off}" \
        "${_cat1}󰏕 Update and upgrade packages${_faint} (last update: %s)${_off}" \
        "${date:-$(i18n::printf "无" "none")}"
}

menu::t() {
    app::set_deps fzf || return 1

    local theme_list
    pure::fetch_cached theme_list "$path_cache_theme_list" "$URL_theme_list" || {
        i18n::printf "拉取失败: %s\n" "Failed to fetch: %s\n" "$URL_theme_list"
        return 1
    }

    local chosen_theme=$(printf '%s\n' "$theme_list" | awk '{full=$0; sub(/\.properties$/,""); print $0 "\t" full}' | fzf --prompt="$(i18n::printf "搜索主题 > " "Search themes > ")" --with-nth=1 --delimiter='\t' | cut -f2)
    [[ -n $chosen_theme ]] || {
        MENU_QUICK=1
        return 1
    }

    termux::apply_web_theme "$chosen_theme"
}
menu::t::title() { i18n::printf "${_cat3}${_memu_hl} 探索颜色主题${_faint}（mbadolato/iTerm2-Color-Schemes）${_off}" "${_cat3}${_memu_hl} Discover color themes${_faint} (mbadolato/iTerm2-Color-Schemes)${_off}"; }

menu::f() {
    app::set_deps fzf || return 1

    local font_list
    pure::fetch_cached font_list "$path_cache_font_list" "$URL_font_list" || {
        i18n::printf "拉取失败: %s\n" "Failed to fetch: %s\n" "$URL_font_list"
        return 1
    }

    local chosen=$(printf '%s\n' "$font_list" | awk -F/ '{full=$0; ext=$NF; sub(/\.[^.]+$/,"",ext); print ext "\t" full}' | fzf --prompt="$(i18n::printf "搜索字体 > " "Search fonts > ")" --with-nth=1 --delimiter='\t' | cut -f2)
    [[ -n $chosen ]] || {
        MENU_QUICK=1
        return 1
    }

    termux::apply_nerd_font "$chosen"
}
menu::f::title() { i18n::printf "${_cat2}${_memu_hl} 探索 Nerd Font 字体${_faint}（ryanoasis/nerd-fonts）${_off}" "${_cat2}${_memu_hl} Discover Nerd Fonts${_faint} (ryanoasis/nerd-fonts)${_off}"; }

menu::k() {
    app::set_deps fzf || return 1

    local keymap_list
    pure::fetch_cached keymap_list "$path_cache_keymap_list" "$URL_keymap_list" || {
        i18n::printf "拉取失败: %s\n" "Failed to fetch: %s\n" "$URL_keymap_list"
        return 1
    }

    local chosen=$(printf '%s\n' "$keymap_list" | awk '{full=$0; sub(/\.properties$/,""); print $0 "\t" full}' | fzf --prompt="$(i18n::printf "搜索按键布局 > " "Search keymaps > ")" --with-nth=1 --delimiter='\t' | cut -f2)
    [[ -n $chosen ]] || {
        MENU_QUICK=1
        return 1
    }
    termux::apply_keymap "$chosen"
}
menu::k::title() { i18n::printf "${_cat4}${_memu_hl}󰌓 探索按键布局${_faint}（miniyu157/Hello-Termux）${_off}" "${_cat4}${_memu_hl}󰌓 Discover keymaps${_faint} (miniyu157/Hello-Termux)${_off}"; }

menu::tb() { termux::open_url "https://github.com/mbadolato/iTerm2-Color-Schemes"; }
menu::tb::title() { i18n::printf "${_cat3}󰆋 在浏览器预览颜色主题${_off}" "${_cat3}󰆋 Preview color themes in browser${_off}"; }

menu::tt() { termux::apply_web_theme "Dracula+.properties"; }
menu::tt::title() { i18n::printf "${_cat3} 快捷应用 Dracula+ 主题${_off}" "${_cat3} Quick-apply Dracula+${_off}"; }

menu::fb() { termux::open_url "https://www.programmingfonts.org/#oxproto"; }
menu::fb::title() { i18n::printf "${_cat2}󰆋 在浏览器预览字体效果${_faint}（programmingfonts.org）${_off}" "${_cat2}󰆋 Preview fonts in browser${_faint} (programmingfonts.org)${_off}"; }

menu::ff() { termux::apply_nerd_font "IosevkaTerm/IosevkaTermNerdFont-Regular.ttf"; }
menu::ff::title() { i18n::printf "${_cat2} 快捷安装 IosevkaTerm Nerd Font${_off}" "${_cat2} Quick-install IosevkaTerm Nerd Font${_off}"; }

menu::kb() { termux::open_url "https://github.com/miniyu157/hello-termux"; }
menu::kb::title() { i18n::printf "${_cat4}󰆋 在浏览器预览按键布局${_off}" "${_cat4}󰆋 Preview keymaps in browser${_off}"; }

menu::kk() { termux::apply_keymap "Enhanced.properties"; }
menu::kk::title() { i18n::printf "${_cat4} 快捷应用实用按键布局${_off}" "${_cat4} Quick-apply enhanced key bindings${_off}"; }

menu::fish() {
    app::set_deps fish || return 1
    chsh -s fish && i18n_msg::shell_changed fish
}
menu::fish::title() { i18n::printf "${_green}${_memu_hl} 安装友好交互的 Shell - fish${_off}" "${_green}${_memu_hl} Install the friendly interactive shell — fish${_off}"; }

menu::ffff() {
    local fisher_func="$HOME/.config/fish/functions/fisher.fish"
    if [[ ! -f $fisher_func ]]; then
        fish -c "curl -sL https://raw.githubusercontent.com/jorgebucaran/fisher/main/functions/fisher.fish | source && fisher install jorgebucaran/fisher" || return 1
    fi
    i18n::printf "已安装 fisher，可以使用 '${_hl}fisher${_off}' 命令管理 fish 插件，也可以卸载自身。\n\n推荐:\n- 智能补全插件 gazorby/fifc\n- 优秀主题 IlanCosman/tide@v6\n\n探索开源社区以了解更多信息！\n" "fisher is installed. Use '${_hl}fisher${_off}' to manage fish plugins, or to uninstall itself.\n\nRecommended:\n- gazorby/fifc — smart completions\n- IlanCosman/tide@v6 — a beautiful prompt\n\nExplore the community for more!\n"
}
menu::ffff::title() { i18n::printf "${_green}󰻳 为 fish 安装 fisher 插件${_off}" "${_green}󰻳 Install fisher plugin manager for fish${_off}"; }

menu::eza() {
    app::set_deps eza gum || return 1

    local shell=$(gum choose --header="$(i18n::printf "需要为哪个 shell 设置 %s？" "Which shell to configure for %s?" "eza")" bash fish)
    [[ -n $shell ]] || {
        MENU_QUICK=1
        return 1
    }

    local remote="${URL_shell_cells}eza_alias.${shell}"
    local cache="$path_cache_dir/eza_alias_${shell}"

    local content
    pure::fetch_cached content "$cache" "$remote" || {
        i18n::printf "拉取失败: %s\n" "Failed to fetch: %s\n" "$remote"
        return 1
    }

    local config
    case "$shell" in
        bash) config="$HOME/.bashrc" ;;
        fish) config="$HOME/.config/fish/conf.d/eza_alias.fish" ;;
    esac

    local first="# -- eza alias {{ --" last="# -- }} eza alias --"

    if [[ -f $config ]] && grep -qF "$first" "$config" && grep -qF "$last" "$config"; then
        i18n::printf "已有配置，未修改。\n" "Already configured, no changes.\n"
        return 0
    fi

    mkdir -p "$(dirname "$config")"

    local tmp=$(mktemp "$path_termux_tmp/ht_XXXXX.tmp")

    [[ -f $config ]] && cp "$config" "$tmp"
    [[ -s $tmp ]] && echo >> "$tmp"
    printf '%s\n' "$content" >> "$tmp"

    local src="$config"
    [[ -f $config ]] || src=/dev/null
    diff --color=always -u "$src" "$tmp" 2> /dev/null || true

    gum confirm "$(i18n::printf "是否接受以上更改？" "Accept the above changes?")" || {
        rm -f "$tmp"
        MENU_QUICK=1
        return 1
    }

    if [[ -f $config ]]; then
        pure::swap_file "$tmp" "$config"
        i18n::printf "修改前的配置位于 %s\n" "Previous config saved at %s\n" "$tmp"
    else
        mv "$tmp" "$config"
        i18n::printf "已新建文件: %s\n" "Created new file: %s\n" "$config"
    fi
    i18n_msg::shell_changed "$shell"
}
menu::eza::title() { i18n::printf "${_purple} 安装 eza，并为 bash/fish 配置实用别名${_off}" "${_purple} Install eza and configure aliases for bash/fish${_off}"; }

menu::zox() {
    app::set_deps zoxide gum || return 1

    local shell=$(gum choose --header="$(i18n::printf "需要为哪个 shell 设置 %s？" "Which shell to configure for %s?" "zoxide")" bash fish)
    [[ -n $shell ]] || {
        MENU_QUICK=1
        return 1
    }

    local config
    case "$shell" in
        bash) config="$HOME/.bashrc" ;;
        fish) config="$HOME/.config/fish/conf.d/zoxide.fish" ;;
    esac

    local first="# -- zoxide init {{ --" last="# -- }} zoxide init --"

    if [[ -f $config ]] && grep -qF "$first" "$config" && grep -qF "$last" "$config"; then
        i18n::printf "已有配置，未修改。\n" "Already configured, no changes.\n"
        return 0
    fi

    local content
    case "$shell" in
        bash) content=$(printf '%s\n%s\n%s' "$first" 'eval "$(zoxide init bash)"' "$last") ;;
        fish) content=$(printf '%s\n%s\n    %s\n%s\n%s' "$first" 'if status is-interactive' 'zoxide init fish | source' 'end' "$last") ;;
    esac

    mkdir -p "$(dirname "$config")"

    local tmp=$(mktemp "$path_termux_tmp/ht_XXXXX.tmp")

    [[ -f $config ]] && cp "$config" "$tmp"
    [[ -s $tmp ]] && echo >> "$tmp"
    printf '%s\n' "$content" >> "$tmp"

    local src="$config"
    [[ -f $config ]] || src=/dev/null
    diff --color=always -u "$src" "$tmp" 2> /dev/null || true

    gum confirm "$(i18n::printf "是否接受以上更改？" "Accept the above changes?")" || {
        rm -f "$tmp"
        MENU_QUICK=1
        return 1
    }

    if [[ -f $config ]]; then
        pure::swap_file "$tmp" "$config"
        i18n::printf "修改前的配置位于 %s\n" "Previous config saved at %s\n" "$tmp"
    else
        mv "$tmp" "$config"
        i18n::printf "已新建文件: %s\n" "Created new file: %s\n" "$config"
    fi
    i18n_msg::shell_changed "$shell"
}
menu::zox::title() { i18n::printf "${_purple} 安装配置 zoxide${_off}" "${_purple} Install and configure zoxide${_off}"; }

menu::atu() {
    app::set_deps atuin gum || return 1

    local shell=$(gum choose --header="$(i18n::printf "需要为哪个 shell 设置 %s？" "Which shell to configure for %s?" "atuin")" bash fish)
    [[ -n $shell ]] || {
        MENU_QUICK=1
        return 1
    }

    local config
    case "$shell" in
        bash) config="$HOME/.bashrc" ;;
        fish) config="$HOME/.config/fish/conf.d/atuin.fish" ;;
    esac

    local first="# -- atuin init {{ --" last="# -- }} atuin init --"

    if [[ -f $config ]] && grep -qF "$first" "$config" && grep -qF "$last" "$config"; then
        i18n::printf "已有配置，未修改。\n" "Already configured, no changes.\n"
        return 0
    fi

    local content
    case "$shell" in
        bash) content=$(printf '%s\n%s\n%s' "$first" 'eval "$(atuin init bash --disable-up-arrow)"' "$last") ;;
        fish) content=$(printf '%s\n%s\n    %s\n%s\n%s' "$first" 'if status is-interactive' 'atuin init fish --disable-up-arrow | source' 'end' "$last") ;;
    esac

    mkdir -p "$(dirname "$config")"

    local tmp=$(mktemp "$path_termux_tmp/ht_XXXXX.tmp")

    [[ -f $config ]] && cp "$config" "$tmp"
    [[ -s $tmp ]] && echo >> "$tmp"
    printf '%s\n' "$content" >> "$tmp"

    local src="$config"
    [[ -f $config ]] || src=/dev/null
    diff --color=always -u "$src" "$tmp" 2> /dev/null || true

    gum confirm "$(i18n::printf "是否接受以上更改？" "Accept the above changes?")" || {
        rm -f "$tmp"
        MENU_QUICK=1
        return 1
    }

    if [[ -f $config ]]; then
        pure::swap_file "$tmp" "$config"
        i18n::printf "修改前的配置位于 %s\n" "Previous config saved at %s\n" "$tmp"
    else
        mv "$tmp" "$config"
        i18n::printf "已新建文件: %s\n" "Created new file: %s\n" "$config"
    fi
    i18n_msg::shell_changed "$shell"
}
menu::atu::title() { i18n::printf "${_purple} 安装配置 atuin${_off}" "${_purple} Install and configure atuin${_off}"; }

menu::s() {
    case "$APP_RESOURCE_SERVICE" in
        cdn.jsdelivr.net) app::set_resource_service github.com ;;
        github.com) app::set_resource_service cdn.statically.io ;;
        cdn.statically.io) app::set_resource_service cdn.jsdelivr.net ;;
    esac
    MENU_QUICK=1
}
menu::s::title() { i18n::printf "󰛍 切换程序资源服务器${_faint}（当前: %s）${_off}" "󰛍 Switch resource server${_faint} (current: %s)${_off}" "$APP_RESOURCE_SERVICE"; }

menu::i() {
    i18n::printf "拉取文件: %s\n" "Fetching file: %s\n" "$URL_exe"
    curl -#L "$URL_exe" -o "$path_install_bin" || {
        i18n::printf "拉取失败: %s\n" "Failed to fetch: %s\n" "$URL_exe"
        return 1
    }
    chmod +x "$path_install_bin"
    cat > "$path_uninstall_bin" << EOF
#!/usr/bin/env bash
rm -f "$path_install_bin" "$path_uninstall_bin"
printf 'hi has been uninstalled.\n'
EOF
    chmod +x "$path_uninstall_bin"
    i18n::printf "安装完成。使用 hi 启动。\n使用 hi-uninstall 卸载。\n" "Done. Run 'hi' to start.\nRun 'hi-uninstall' to uninstall.\n"
}
menu::i::title() { i18n::printf " 将此程序安装到本地" " Install this program locally"; }

menu::l() {
    case "$APP_LANG" in
        zh) APP_LANG="en" ;;
        *) APP_LANG="zh" ;;
    esac
    MENU_QUICK=1
}
menu::l::title() { i18n::printf " 切换语言${_faint}（目前：中文）${_off}" " Switch Language${_faint} (Current: English)${_off}"; }

menu::cl() {
    rm -rf "$path_cache_dir"
    mkdir -p "$path_cache_dir"
    i18n::printf "清理: %s\n" "Cleared: %s\n" "$path_cache_dir"
}
menu::cl::title() { i18n::printf " 清除下载缓存${_faint}（TTL: 30天）${_off}" " Clear download cache${_faint} (TTL: 30 days)${_off}"; }

menu::is() { termux::open_url "https://github.com/miniyu157/hello-termux/issues"; }
menu::is::title() { i18n::printf "󰭻 前往 Issues 页面" "󰭻 Go to Issues page"; }

menu::gh() { termux::open_url "https://github.com/miniyu157/hello-termux"; }
menu::gh::title() { i18n::printf "󰊤 前往 Hello Termux 的仓库" "󰊤 Go to Hello Termux repository"; }

menu::q() { exit 0; }
menu::q::title() { i18n::printf "󰩈 退出程序" "󰩈 Exit"; }

# -- i18n --

app::set_lang() { case "$(getprop persist.sys.locale 2> /dev/null)" in zh-*) APP_LANG="zh" ;; *) APP_LANG="en" ;; esac }

i18n::printf() {
    local fmt="$1"
    [[ $APP_LANG != zh ]] && fmt="$2"
    printf -- "$fmt" "${@:3}"
}

i18n_msg::shell_changed() { i18n::printf "${_ok}>${_off} 已更改 shell 配置，使用以下操作均可查看效果：\n- 开启新会话\n- 重启终端应用\n- 运行 '${_hl}exec %s${_off}'\n" "${_ok}>${_off} Shell configuration changed. To see the effect:\n- Start a new session\n- Restart the terminal app\n- Run '${_hl}exec %s${_off}'\n" "$1"; }

# -- init --

declare -g _refresh=$'\e[H\e[J' _b=$'\e[1m' _faint=$'\e[2m' _italic=$'\e[3m' _memu_hl=$'\e[1m' _uline=$'\e[4m' _off=$'\e[0m' _ok=$'\e[38;2;101;255;101m' _hl=$'\e[38;2;255;174;193m' _cat1=$'\e[38;2;255;115;108m' _cat2=$'\e[38;2;121;167;252m' _cat3=$'\e[38;2;255;174;193m' _cat4=$'\e[38;2;255;226;2m' _green=$'\e[38;2;173;255;184m' _purple=$'\e[38;2;243;159;249m'

app::set_lang
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
        menu_keys=(m mc u f fb ff t tb tt k kb kk fish ffff eza zox atu s l i cl is gh q)
        for _id in "${menu_keys[@]}"; do
            printf "${_faint}${_italic}%4s${_off} %s\n" "$_id" "$("menu::${_id}::title")"
        done
    )
${_faint}─────────────────────────────────────────────────${_off}
EOF
    i18n::printf "${_uline}键入需要的工具回车运行:${_off}\n" "${_uline}Type a key and press Enter to run:${_off}\n"
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
        i18n::printf "${_p}${_off} 工具运行结束，退出码: %s\n" "${_p}${_off} Tool finished, exit code: %s\n" "$_rc"
        i18n::printf "  按回车键继续..." "  Press Enter to continue..."
        read -r _ < /dev/tty
    }
done
