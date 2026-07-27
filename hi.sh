#!/usr/bin/env bash

# shellcheck disable=SC1036,SC1088,SC2155,SC2059,SC2016

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

# 将内容块写入 shell 配置文件（完整性检查、diff 预览、用户确认、原子写入）
# $1: 配置文件路径
# $2: 完整内容块
# $3: shell 名称
pure::write_shell_config() {
    local config="$1" content="$2" shell="$3"

    if [[ -f $config ]] && grep -zqF "$content" "$config" 2> /dev/null; then
        i18n::printf "${_cat4}已有完全相同的配置，无需修改。${_off}\n" "${_cat4}Already configured, no changes.${_off}\n"
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

# 扫描 shell 配置，如已有工具痕迹则显示提示，始终放行
# $1: shell (bash/fish)
# $2: grep -E 模式
# $3: 工具名
pure::warn_existing_config() {
    local shell="$1" pattern="$2" tool="$3"
    local scan_target
    case "$shell" in
        bash) scan_target="$HOME/.bashrc" ;;
        fish) scan_target="$HOME/.config/fish/" ;;
    esac

    local scan
    scan=$(grep -rn -C 1 -E "$pattern" "$scan_target" 2> /dev/null |
        awk -v g="$_green" -v o="$_off" '
        /^--$/ { next }
        match($0, /[-:][0-9]+[-:]/) {
            f = substr($0, 1, RSTART-1)
            r = substr($0, RSTART); sub(/^[-:]/, "", r); sub(/[-:]$/, "", r)
            sub(/^[0-9]+/, g "&" o, r)
            if (f != c) { c = f; print c ":" }
            print "  " r
        }
    ')

    if [[ -n $scan ]]; then
        i18n::printf "${_cat4}警告: 在以下位置发现已有的 %s 配置：${_off}\n" "${_cat4}Warning: existing %s config found at:${_off}\n" "$tool"
        printf '%s\n' "$scan"
    fi
}

# 应用一个 nerd font 字体
# $1  用于拼接仓库的后缀
sys::termux_apply_nerd_font() {
    local name="$1"
    pure::cache_resource "$path_cache_fonts" "$name" \
        "${URL_font_prefix}/${name}" || return 1
    cp -f "$path_cache_fonts/$name" "$path_termux_font_ttf"
    termux-reload-settings
    i18n::printf "应用字体 '%s' 成功。\n" "Font '%s' applied successfully.\n" "$name"
}

# 应用一个 iTerm2 颜色主题
# $1  主题名称（用于拼接 URL 后缀）
sys::termux_apply_web_theme() {
    local name="$1"
    pure::cache_resource "$path_cache_themes" "$name" \
        "${URL_theme_prefix}/${name// /%20}" || return 1
    cp -f "$path_cache_themes/$name" "$path_termux_colors_properties"
    termux-reload-settings
    i18n::printf "应用主题 '%s' 成功。\n" "Theme '%s' applied successfully.\n" "$name"
}

# 应用一个按键布局
# $1  按键布局名称（用于拼接 URL 后缀）
sys::termux_apply_keymap() {
    local name="$1"
    pure::cache_resource "$path_cache_keymaps" "$name" \
        "${URL_keymap_prefix}/${name// /%20}" || return 1
    cp -f "$path_cache_keymaps/$name" "$path_termux_key_properties"
    termux-reload-settings
    i18n::printf "应用按键布局 '%s' 成功。\n" "Keymap '%s' applied successfully.\n" "$name"
}

sys::open_url() {
    xdg-open "$1" || {
        i18n::printf "拉起 xdg-open 失败: %s\n" "Failed to open URL: %s\n" "$1"
        return 1
    }
}

menu::root::m() { termux-change-repo; }
menu::root::m::title() {
    local link=$(readlink "$path_termux_mirror_link" 2> /dev/null)
    link="${link##*/}"
    i18n::printf \
        "${_cat1}${_memu_hl} 更换软件包源${_faint}（镜像: %s）${_off}" \
        "${_cat1}${_memu_hl} Change package mirror${_faint} (mirror: %s)${_off}" \
        "${link:-$(i18n::printf "未设置" "none")}"
}

menu::root::mc() { ln -sf "$path_termux_mirrors_dir/chinese_mainland" "$path_termux_mirror_link" && i18n::printf "设置完成。\n" "Done.\n"; }
menu::root::mc::title() { i18n::printf "${_cat1} 快捷设置中国大陆软件源${_off}" "${_cat1} Quick-set Chinese mainland mirror${_off}"; }

menu::root::u() { pkg update -y && apt upgrade -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold"; }
menu::root::u::title() {
    local ts=$(find "$path_termux_apt_lists/" -maxdepth 1 -type f -printf '%T@\n' 2> /dev/null | sort -rn | head -1)
    local date
    [[ -n $ts ]] && date=$(date -d "@$ts" +'%Y-%m-%d %H:%M:%S' 2> /dev/null)
    i18n::printf \
        "${_cat1}󰏕 更新和升级软件包${_faint}（上次更新: %s）${_off}" \
        "${_cat1}󰏕 Update and upgrade packages${_faint} (last update: %s)${_off}" \
        "${date:-$(i18n::printf "无" "none")}"
}

menu::root::t() {
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

    sys::termux_apply_web_theme "$chosen_theme"
}
menu::root::t::title() { i18n::printf "${_cat3}${_memu_hl} 探索颜色主题${_faint}（mbadolato/iTerm2-Color-Schemes）${_off}" "${_cat3}${_memu_hl} Discover color themes${_faint} (mbadolato/iTerm2-Color-Schemes)${_off}"; }

menu::root::f() {
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

    sys::termux_apply_nerd_font "$chosen"
}
menu::root::f::title() { i18n::printf "${_cat2}${_memu_hl} 探索 Nerd Font 字体${_faint}（ryanoasis/nerd-fonts）${_off}" "${_cat2}${_memu_hl} Discover Nerd Fonts${_faint} (ryanoasis/nerd-fonts)${_off}"; }

menu::root::k() {
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
    sys::termux_apply_keymap "$chosen"
}
menu::root::k::title() { i18n::printf "${_cat4}${_memu_hl}󰌓 探索按键布局${_faint}（miniyu157/Hello-Termux）${_off}" "${_cat4}${_memu_hl}󰌓 Discover keymaps${_faint} (miniyu157/Hello-Termux)${_off}"; }

menu::root::tb() { sys::open_url "https://github.com/mbadolato/iTerm2-Color-Schemes"; }
menu::root::tb::title() { i18n::printf "${_cat3}󰆋 在浏览器预览颜色主题${_off}" "${_cat3}󰆋 Preview color themes in browser${_off}"; }

menu::root::tt() { sys::termux_apply_web_theme "Dracula+.properties"; }
menu::root::tt::title() { i18n::printf "${_cat3} 快捷应用 Dracula+ 主题${_off}" "${_cat3} Quick-apply Dracula+${_off}"; }

menu::root::fb() { sys::open_url "https://www.programmingfonts.org/#oxproto"; }
menu::root::fb::title() { i18n::printf "${_cat2}󰆋 在浏览器预览字体效果${_faint}（programmingfonts.org）${_off}" "${_cat2}󰆋 Preview fonts in browser${_faint} (programmingfonts.org)${_off}"; }

menu::root::ff() { sys::termux_apply_nerd_font "IosevkaTerm/IosevkaTermNerdFont-Regular.ttf"; }
menu::root::ff::title() { i18n::printf "${_cat2} 快捷安装 IosevkaTerm Nerd Font${_off}" "${_cat2} Quick-install IosevkaTerm Nerd Font${_off}"; }

menu::root::kb() { sys::open_url "https://github.com/miniyu157/hello-termux"; }
menu::root::kb::title() { i18n::printf "${_cat4}󰆋 在浏览器预览按键布局${_off}" "${_cat4}󰆋 Preview keymaps in browser${_off}"; }

menu::root::kk() { sys::termux_apply_keymap "Enhanced.properties"; }
menu::root::kk::title() { i18n::printf "${_cat4} 快捷应用实用按键布局${_off}" "${_cat4} Quick-apply enhanced key bindings${_off}"; }

# 检查 fisher 插件是否已安装
# $1  插件名（如 gazorby/fifc）
# 返回 0=已安装  1=未安装  2=fisher 不可用  127=fish 不可用
pure::fisher_plugin_installed() {
    local plugin="$1" list
    command -v fish > /dev/null 2>&1 || return 127
    list=$(fish -c "fisher list" 2> /dev/null)
    [[ -n $list ]] || return 2
    grep -iqF "$plugin" <<< "$list" && return 0
    return 1
}

# ---- fish 配置 ----

# 获取 fisher 插件安装状态的 i18n 文本
# $1  插件名
pure::fisher_plugin_status() {
    local rc
    pure::fisher_plugin_installed "$1"
    rc=$?
    case $rc in
        0) i18n::printf "已安装" "installed" ;;
        127) i18n::printf "fish 不可用" "fish unavailable" ;;
        2) i18n::printf "fisher 不可用" "fisher unavailable" ;;
        *) i18n::printf "未安装" "not installed" ;;
    esac
}

# 获取命令是否可用的 i18n 状态文本
# $1  命令名
pure::command_status() {
    if command -v "$1" > /dev/null 2>&1; then
        i18n::printf "已安装" "installed"
    else
        i18n::printf "未安装" "not installed"
    fi
}

menu::root::fish() {
    app::set_deps fish || return 1
    chsh -s fish && i18n_msg::shell_changed fish
}
menu::root::fish::title() { i18n::printf "${_green}${_memu_hl} 安装友好交互的 Shell - fish${_faint}（%s）${_off}" "${_green}${_memu_hl} Install the friendly interactive shell — fish${_faint} (%s)${_off}" "$(pure::command_status fish)"; }

menu::ffff() { i18n::printf "${_green}󰻳 关于 fish 的 fisher 插件${_off}" "${_green}󰻳 About fish's fisher plugins${_off}"; }

menu::ffff::f() {
    local fisher_func="$HOME/.config/fish/functions/fisher.fish"
    if [[ ! -f $fisher_func ]]; then
        fish -c "curl -sL https://raw.githubusercontent.com/jorgebucaran/fisher/main/functions/fisher.fish | source && fisher install jorgebucaran/fisher" || return 1
    fi
    i18n::printf "已安装 fisher，可以使用 '${_hl}fisher${_off}' 命令管理 fish 插件，也可以用于卸载自身。\n" "fisher is installed. Use '${_hl}fisher${_off}' to manage fish plugins, or to uninstall itself.\n"
}
menu::ffff::f::title() { i18n::printf "${_green}${_memu_hl}󰐱 安装 fisher 插件管理器${_faint}（%s）${_off}" "${_green}${_memu_hl}󰐱 Install fisher plugin manager${_faint} (%s)${_off}" "$(pure::fisher_plugin_status "jorgebucaran/fisher")"; }

menu::ffff::a() { fish -c "fisher install gazorby/fifc"; }
menu::ffff::a::title() { i18n::printf "${_green}gazorby/fifc — 智能补全${_faint}（%s）${_off}" "${_green}gazorby/fifc — smart completions${_faint} (%s)${_off}" "$(pure::fisher_plugin_status "gazorby/fifc")"; }

menu::ffff::b() { fish -i -c "fisher install IlanCosman/tide@v6" < /dev/tty; }
menu::ffff::b::title() { i18n::printf "${_green}IlanCosman/tide@v6 — 优秀主题${_faint}（%s）${_off}" "${_green}IlanCosman/tide@v6 — a beautiful prompt${_faint} (%s)${_off}" "$(pure::fisher_plugin_status "IlanCosman/tide")"; }

menu::sh() { i18n::printf "${_purple} 更多 Shell 辅助套件${_off}" "${_purple} More Shell utilities${_off}"; }

menu::sh::eza() {
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

    pure::warn_existing_config "$shell" 'alias.*eza' 'eza'

    pure::write_shell_config "$config" "$content" "$shell"
}
menu::sh::eza::title() { i18n::printf "${_purple}安装 eza，并为 bash/fish 配置实用别名${_off}" "${_purple}Install eza and configure aliases for bash/fish${_off}"; }

menu::sh::zox() {
    app::set_deps zoxide gum || return 1

    local shell=$(gum choose --header="$(i18n::printf "需要为哪个 shell 设置 %s？" "Which shell to configure for %s?" "zoxide")" bash fish)
    [[ -n $shell ]] || {
        MENU_QUICK=1
        return 1
    }

    local config content
    case "$shell" in
        bash)
            config="$HOME/.bashrc"
            content='# -- zoxide init {{ --
eval "$(zoxide init bash)"
# -- }} zoxide init --'
            ;;
        fish)
            config="$HOME/.config/fish/conf.d/zoxide.fish"
            content='# -- zoxide init {{ --
if status is-interactive
    zoxide init fish | source
end
# -- }} zoxide init --'
            ;;
    esac

    pure::warn_existing_config "$shell" 'zoxide init' 'zoxide'

    pure::write_shell_config "$config" "$content" "$shell"
}
menu::sh::zox::title() { i18n::printf "${_purple}安装 zoxide，并为 bash/fish 配置 hook${_off}" "${_purple}Install zoxide and configure hook for bash/fish${_off}"; }

menu::sh::atu() {
    app::set_deps atuin gum || return 1

    local shell=$(gum choose --header="$(i18n::printf "需要为哪个 shell 设置 %s？" "Which shell to configure for %s?" "atuin")" bash fish)
    [[ -n $shell ]] || {
        MENU_QUICK=1
        return 1
    }

    local config content
    case "$shell" in
        bash)
            config="$HOME/.bashrc"
            content='# -- atuin init {{ --
eval "$(atuin init bash --disable-up-arrow)"
# -- }} atuin init --'
            ;;
        fish)
            config="$HOME/.config/fish/conf.d/atuin.fish"
            content='# -- atuin init {{ --
if status is-interactive
    atuin init fish --disable-up-arrow | source
end
# -- }} atuin init --'
            ;;
    esac

    pure::warn_existing_config "$shell" 'atuin init' 'atuin'

    pure::write_shell_config "$config" "$content" "$shell"
}
menu::sh::atu::title() { i18n::printf "${_purple}安装 atuin，并为 bash/fish 配置 hook${_off}" "${_purple}Install atuin and configure hook for bash/fish${_off}"; }

menu::root::s() {
    case "$APP_RESOURCE_SERVICE" in
        cdn.jsdelivr.net) app::set_resource_service github.com ;;
        github.com) app::set_resource_service cdn.statically.io ;;
        cdn.statically.io) app::set_resource_service cdn.jsdelivr.net ;;
    esac
    MENU_QUICK=1
}
menu::root::s::title() { i18n::printf "󰛍 切换程序资源服务器${_faint}（当前: %s）${_off}" "󰛍 Switch resource server${_faint} (current: %s)${_off}" "$APP_RESOURCE_SERVICE"; }

menu::root::i() {
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
menu::root::i::title() { i18n::printf " 将此程序安装到本地" " Install this program locally"; }

menu::root::l() {
    case "$APP_LANG" in
        zh) APP_LANG="en" ;;
        *) APP_LANG="zh" ;;
    esac
    MENU_QUICK=1
}
menu::root::l::title() { i18n::printf " 切换语言${_faint}（目前：中文）${_off}" " Switch Language${_faint} (Current: English)${_off}"; }

menu::root::cl() {
    rm -rf "$path_cache_dir"
    mkdir -p "$path_cache_dir"
    i18n::printf "清理: %s\n" "Cleared: %s\n" "$path_cache_dir"
}
menu::root::cl::title() { i18n::printf " 清除下载缓存${_faint}（TTL: 30天）${_off}" " Clear download cache${_faint} (TTL: 30 days)${_off}"; }

menu::root::is() { sys::open_url "https://github.com/miniyu157/hello-termux/issues"; }
menu::root::is::title() { i18n::printf "󰭻 前往 Issues 页面" "󰭻 Go to Issues page"; }

menu::root::gh() { sys::open_url "https://github.com/miniyu157/hello-termux"; }
menu::root::gh::title() { i18n::printf "󰊤 前往 Hello Termux 的仓库" "󰊤 Go to Hello Termux repository"; }

menu::root::q() { exit 0; }
menu::root::q::title() { i18n::printf "󰩈 退出程序" "󰩈 Exit"; }

menu::root() { printf "Hello Termux${_off}\n${_faint}https://github.com/miniyu157/Hello-Termux${_off}"; }

# -- i18n --

app::set_lang() {
    local android_locale
    android_locale="$(getprop persist.sys.locale 2> /dev/null)"

    if [[ $android_locale == zh-* ]] || [[ ${LANG:-} == zh_* ]]; then
        APP_LANG="zh"
    else
        APP_LANG="en"
    fi
}

i18n::printf() {
    local fmt="$1"
    [[ $APP_LANG != zh ]] && fmt="$2"
    printf -- "$fmt" "${@:3}"
}

i18n_msg::shell_changed() { i18n::printf "${_ok}>${_off} 已更改 shell 配置，使用以下操作均可查看效果：\n- 开启新会话\n- 重启终端应用\n- 运行 '${_hl}exec %s${_off}'\n" "${_ok}>${_off} Shell configuration changed. To see the effect:\n- Start a new session\n- Restart the terminal app\n- Run '${_hl}exec %s${_off}'\n" "$1"; }

# -- loop menu --

# 剥离 S-表达式最外层括号：(a b c) → a b c
pure::strip_parens() {
    local s="${1#(}"
    printf '%s\n' "${s%)}"
}

# 按括号深度将扁平常量解析为逐行子节点
# "a (g1 b (g2 c)) f" → a \n (g1 b (g2 c)) \n f
pure::parse_children() {
    local input="$1" depth=0 current='' i=0 ch
    while ((i < ${#input})); do
        ch="${input:i:1}"
        case "$ch" in
            '(')
                ((depth++))
                current+="$ch"
                ;;
            ')')
                ((depth--))
                current+="$ch"
                ;;
            ' ')
                if ((depth == 0)); then
                    [[ -n $current ]] && printf '%s\n' "$current"
                    current=''
                else
                    current+="$ch"
                fi
                ;;
            *) current+="$ch" ;;
        esac
        ((i++))
    done
    [[ -n $current ]] && printf '%s\n' "$current"
}

# 递归菜单渲染器
# $1  S-表达式，如 "(root m mc u (ffff f a b) q)"
app::loop_menu() {
    local raw_expr="$1" flat parent children_flat
    flat=$(pure::strip_parens "$(printf '%s' "$raw_expr" | tr '\n' ' ' | sed 's/[[:space:]]\{1,\}/ /g; s/^ //; s/ $//')")
    parent="${flat%% *}" children_flat="${flat#* }"
    [[ $children_flat == "$parent" ]] && children_flat=''

    while true; do
        # 调用 menu::<parent>，第一行作为主标题（✦ 包裹），剩余行作为副标题（4空格缩进）
        local header_text first_line rest_lines
        header_text=$("menu::${parent}" 2> /dev/null || true)
        [[ -z $header_text ]] && first_line="$parent" || first_line="${header_text%%$'\n'*}"
        [[ $header_text == *$'\n'* ]] && rest_lines="${header_text#*$'\n'}"
        printf '%s\n' "${_refresh}"
        printf "${_b}  ✦ %s ✦ ${_off}\n" "$first_line"
        [[ -n ${rest_lines:-} ]] && printf '    %s\n' "${rest_lines//$'\n'/$'\n'    }"
        printf '%s\n' "─────────────────────────────────────────────────"

        # 渲染子节点
        local child inner gname title_func
        while IFS= read -r child; do
            [[ -z $child ]] && continue
            if [[ $child == '('*')' ]]; then
                inner=$(pure::strip_parens "$child") gname="${inner%% *}"
                printf "${_faint}${_italic}%4s${_off} %s\n" "$gname" "$("menu::${gname}" 2> /dev/null)"
            else
                title_func="menu::${parent}::${child}::title"
                printf "${_faint}${_italic}%4s${_off} %s\n" "$child" "$($title_func 2> /dev/null)"
            fi
        done < <(pure::parse_children "$children_flat")

        # Footer + 输入
        printf '%s\n' "${_faint}─────────────────────────────────────────────────${_off}"
        if [[ $parent == "root" ]]; then
            i18n::printf "${_uline}键入需要的工具回车运行:${_off}\n" "${_uline}Type a key and press Enter to run:${_off}\n"
        else
            i18n::printf "${_uline}键入选项或留空返回:${_off}\n" "${_uline}Type a choice or leave empty to go back:${_off}\n"
        fi
        read -e -r choice < /dev/tty || {
            printf "\n"
            return
        }
        [[ -z $choice ]] && { [[ $parent == "root" ]] && continue || return; }

        # 再次解析子节点，匹配用户输入；未匹配 → 继续循环（重新渲染）
        while IFS= read -r child; do
            [[ -z $child ]] && continue
            if [[ $child == '('*')' ]]; then
                inner=$(pure::strip_parens "$child")
                gname="${inner%% *}"
                if [[ $gname == "$choice" ]]; then
                    history -s -- "$choice"
                    app::loop_menu "$child"
                    break
                fi
            elif [[ $child == "$choice" ]]; then
                local action_func="menu::${parent}::${choice}"
                if compgen -A function -- "$action_func" | grep -qx "$action_func"; then
                    history -s -- "$choice"
                    MENU_QUICK=0
                    "$action_func"
                    local _rc=$?
                    ((MENU_QUICK)) || {
                        local _p="$_ok>"
                        ((_rc)) && _p="${_cat1}×"
                        i18n::printf "${_p}${_off} 工具运行结束，退出码: %s\n" "${_p}${_off} Tool finished, exit code: %s\n" "$_rc"
                        i18n::printf "  按回车键继续..." "  Press Enter to continue..."
                        read -r _ < /dev/tty
                    }
                fi
                break
            fi
        done < <(pure::parse_children "$children_flat")
    done
}

declare -g _refresh=$'\e[H\e[J' _b=$'\e[1m' _faint=$'\e[2m' _italic=$'\e[3m' _memu_hl=$'\e[1m' _uline=$'\e[4m' _off=$'\e[0m' _ok=$'\e[38;2;101;255;101m' _hl=$'\e[38;2;255;174;193m' _cat1=$'\e[38;2;255;115;108m' _cat2=$'\e[38;2;121;167;252m' _cat3=$'\e[38;2;255;174;193m' _cat4=$'\e[38;2;255;226;2m' _green=$'\e[38;2;173;255;184m' _purple=$'\e[38;2;243;159;249m'

app::set_lang
app::set_paths
app::set_resource_service github.com

app::loop_menu '(root
m  mc  u
f  fb  ff
t  tb  tt
k  kb  kk
fish
(ffff
  f  a  b)
(sh
  eza  zox  atu)
s  l  i
cl  is  gh
q
)'
