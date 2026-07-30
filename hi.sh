#!/usr/bin/env bash

# shellcheck disable=SC2155,SC2317

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

sys::set_deps() {
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

sys::io::fetch_cached() {
    local -n _ref_out="$1"
    local cache="$2" url="$3" ttl="${4:-30}"

    if [[ -s $cache ]] && [[ -z $(find "$cache" -mtime "+$ttl" 2> /dev/null) ]]; then
        _ref_out=$(< "$cache")
    else
        _ref_out=$(curl -#L "$url") || return 1
        printf '%s\n' "$_ref_out" > "$cache"
    fi
}

sys::io::cache_resource() {
    local cache_dir="$1" name="$2" url="$3"
    local dest="${cache_dir}/${name}"
    [[ -f $dest ]] && return 0
    mkdir -p "$(dirname "$dest")"
    curl -#L "$url" -o "${dest}.tmp" && mv "${dest}.tmp" "$dest"
}

# Swap two files
sys::io::swap_file() {
    local a="$1" b="$2" tmp=$(mktemp "$path_termux_tmp/ht_XXXXX")
    mv "$a" "$tmp" && mv "$b" "$a" && mv "$tmp" "$b"
}

# 扫描目标路径，如已有工具痕迹则显示提示，始终放行
# $1: 扫描目标（文件或目录路径）
# $2: grep -E 模式
sys::io::warn_existing_config() {
    local scan_target="$1" pattern="$2"
    local scan=$(grep -rn -C 1 -E "$pattern" "$scan_target" 2> /dev/null |
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
        i18n::printf "${_cat4}警告: 在以下位置发现已有配置：${_off}\n" "${_cat4}Warning: existing config found at:${_off}\n"
        printf '%s\n' "$scan"
    fi
}

# 将内容块写入配置文件（完整性检查、diff 预览、用户确认、原子写入）
# $1: 配置文件路径
# $2: 完整内容块
sys::io::write_user_config() {
    local config="$1" content="$2"

    if [[ -f $config ]] && grep -zqF "$content" "$config" 2> /dev/null; then
        i18n::printf "${_cat4}已有完全相同的配置，无需修改。${_off}\n" "${_cat4}Already configured, no changes.${_off}\n"
        return 1
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
        sys::io::swap_file "$tmp" "$config"
        i18n::printf "修改前的配置位于 %s\n" "Previous config saved at %s\n" "$tmp"
    else
        mv "$tmp" "$config"
        i18n::printf "已新建文件: %s\n" "Created new file: %s\n" "$config"
    fi
}

# 编排 warn_existing_config + write_user_config 的组合写入
# $1: 扫描目标（文件或目录路径）
# $2: grep -E 模式
# $3: 配置文件路径
# $4: 完整内容块
sys::io::write_config() {
    local scan_target="$1" pattern="$2" config="$3" content="$4"
    sys::io::warn_existing_config "$scan_target" "$pattern"
    sys::io::write_user_config "$config" "$content"
}

# 应用一个 nerd font 字体
# $1  用于拼接仓库的后缀
sys::termux_apply_nerd_font() {
    local name="$1"
    sys::io::cache_resource "$path_cache_fonts" "$name" \
        "${URL_font_prefix}/${name}" || return 1
    cp -f "$path_cache_fonts/$name" "$path_termux_font_ttf"
    termux-reload-settings
    i18n::printf "应用字体 '%s' 成功。\n" "Font '%s' applied successfully.\n" "$name"
}

# 应用一个 iTerm2 颜色主题
# $1  主题名称（用于拼接 URL 后缀）
sys::termux_apply_web_theme() {
    local name="$1"
    sys::io::cache_resource "$path_cache_themes" "$name" \
        "${URL_theme_prefix}/${name// /%20}" || return 1
    cp -f "$path_cache_themes/$name" "$path_termux_colors_properties"
    termux-reload-settings
    i18n::printf "应用主题 '%s' 成功。\n" "Theme '%s' applied successfully.\n" "$name"
}

# 应用一个按键布局
# $1  按键布局名称（用于拼接 URL 后缀）
sys::termux_apply_keymap() {
    local name="$1"
    sys::io::cache_resource "$path_cache_keymaps" "$name" \
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

# 获取 fisher 插件安装状态的 i18n 文本
# $1  插件名
pure::fisher_plugin_status() {
    local plugin="$1" list rc
    command -v fish > /dev/null 2>&1 || rc=127
    if [[ -z ${rc:-} ]]; then
        list=$(fish -c "fisher list" 2> /dev/null)
        if [[ -n $list ]]; then
            grep -iqF "$plugin" <<< "$list" && rc=0 || rc=1
        else
            rc=2
        fi
    fi
    case $rc in
        0) i18n::printf "已安装" "installed" ;;
        127) i18n::printf "fish 不可用" "fish unavailable" ;;
        2) i18n::printf "fisher 不可用" "fisher unavailable" ;;
        *) i18n::printf "未安装" "not installed" ;;
    esac
}

# 获取命令是否可用的 i18n 状态文本
pure::command_status() {
    local _v="${2:-}"
    if command -v "$1" > /dev/null 2>&1; then
        i18n::printf ${_v:+-v "$_v"} "已安装" "installed"
    else
        i18n::printf ${_v:+-v "$_v"} "未安装" "not installed"
    fi
}

# ==== 业务菜单函数开始 ====
menu::root() { printf -v "$1" '%b\n%b' "Hello Termux${_off}" "${_faint}https://github.com/miniyu157/Hello-Termux${_off}"; }

menu::root::m() { termux-change-repo; }
menu::root::m::title() {
    local link=$(readlink "$path_termux_mirror_link" 2> /dev/null)
    link="${link##*/}"
    i18n::printf -v "$1" \
        "${_cat1}${_memu_hl} 更换软件包源${_faint}（镜像: %s）${_off}" \
        "${_cat1}${_memu_hl} Change package mirror${_faint} (mirror: %s)${_off}" \
        "${link:-$(i18n::printf "未设置" "none")}"
}

menu::root::mc() { ln -sf "$path_termux_mirrors_dir/chinese_mainland" "$path_termux_mirror_link" && i18n::printf "设置完成。\n" "Done.\n"; }
menu::root::mc::title() { i18n::printf -v "$1" "${_cat1} 快捷设置中国大陆软件源${_off}" "${_cat1} Quick-set Chinese mainland mirror${_off}"; }

menu::root::u() { pkg update -y && apt upgrade -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold"; }
menu::root::u::title() { i18n::printf -v "$1" "${_cat1}󰏕 更新和升级软件包${_off}" "${_cat1}󰏕 Update and upgrade packages${_off}"; }

# ---- 字体菜单 ----
menu::f() { i18n::printf -v "$1" "${_cat2}${_memu_hl} 浏览/探索/更改字体${_off}" "${_cat2}${_memu_hl} Browse / discover / change fonts${_off}"; }
menu::f::b() { sys::open_url "https://www.programmingfonts.org/#oxproto"; }
menu::f::b::title() { i18n::printf -v "$1" "${_cat2}󰆋 在浏览器预览字体效果${_faint}（programmingfonts.org）${_off}" "${_cat2}󰆋 Preview fonts in browser${_faint} (programmingfonts.org)${_off}"; }
menu::f::f1() { sys::termux_apply_nerd_font "IosevkaTerm/IosevkaTermNerdFont-Regular.ttf"; }
menu::f::f1::title() { i18n::printf -v "$1" "${_cat2} 快捷安装 IosevkaTerm Nerd Font${_off}" "${_cat2} Quick-install IosevkaTerm Nerd Font${_off}"; }
menu::f::f2() { sys::termux_apply_nerd_font "IosevkaTerm/IosevkaTermNerdFont-BoldItalic.ttf"; }
menu::f::f2::title() { i18n::printf -v "$1" "${_cat2} 快捷安装 IosevkaTerm Nerd Font Bold Italic${_off}" "${_cat2} Quick-install IosevkaTerm Nerd Font Bold Italic${_off}"; }
menu::f::f() {
    sys::set_deps fzf || return 1

    local font_list
    sys::io::fetch_cached font_list "$path_cache_font_list" "$URL_font_list" || {
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
menu::f::f::title() { i18n::printf -v "$1" "${_cat2}${_memu_hl} 探索 Nerd Font 字体${_faint}（ryanoasis/nerd-fonts）${_off}" "${_cat2}${_memu_hl} Discover Nerd Fonts${_faint} (ryanoasis/nerd-fonts)${_off}"; }
menu::f::ff() {
    sys::set_deps fzf || return 1

    local cached=$(cd "$path_cache_fonts" 2> /dev/null && find . -type f ! -name '*.tmp' | sed 's|^\./||' | sort)
    [[ -n $cached ]] || {
        i18n::printf "没有已缓存的字体: %s\n" "No cached fonts: %s\n" "$path_cache_fonts"
        return 1
    }

    local chosen=$(printf '%s\n' "$cached" | awk -F/ '{full=$0; ext=$NF; sub(/\.[^.]+$/,"",ext); print ext "\t" full}' | fzf --prompt="$(i18n::printf "搜索已缓存字体 > " "Search cached fonts > ")" --with-nth=1 --delimiter='\t' | cut -f2)
    [[ -n $chosen ]] || {
        MENU_QUICK=1
        return 1
    }

    sys::termux_apply_nerd_font "$chosen"
}
menu::f::ff::title() { i18n::printf -v "$1" "${_cat2} 浏览已缓存的字体${_faint}（~/.termux/cache）${_off}" "${_cat2} Browse cached fonts${_faint} (~/.termux/cache)${_off}"; }

# ----颜色主题菜单 ----
menu::t() { i18n::printf -v "$1" "${_cat3}${_memu_hl} 浏览/探索/更改颜色主题${_off}" "${_cat3}${_memu_hl} Browse / discover / change color themes${_off}"; }
menu::t::b() { sys::open_url "https://github.com/mbadolato/iTerm2-Color-Schemes"; }
menu::t::b::title() { i18n::printf -v "$1" "${_cat3}󰆋 在浏览器预览颜色主题${_faint}（mbadolato/iTerm2-Color-Schemes）${_off}" "${_cat3}󰆋 Preview color themes in browser${_faint} (mbadolato/iTerm2-Color-Schemes)${_off}"; }
menu::t::t1() { sys::termux_apply_web_theme "Dracula+.properties"; }
menu::t::t1::title() { i18n::printf -v "$1" "${_cat3} 快捷应用 Dracula+ 主题${_off}" "${_cat3} Quick-apply Dracula+${_off}"; }
menu::t::t2() { sys::termux_apply_web_theme "Gruvbox Dark.properties"; }
menu::t::t2::title() { i18n::printf -v "$1" "${_cat3} 快捷应用 Gruvbox Dark 主题${_off}" "${_cat3} Quick-apply Gruvbox Dark${_off}"; }
menu::t::t() {
    sys::set_deps fzf || return 1

    local theme_list
    sys::io::fetch_cached theme_list "$path_cache_theme_list" "$URL_theme_list" || {
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
menu::t::t::title() { i18n::printf -v "$1" "${_cat3}${_memu_hl} 探索颜色主题${_faint}（mbadolato/iTerm2-Color-Schemes）${_off}" "${_cat3}${_memu_hl} Discover color themes${_faint} (mbadolato/iTerm2-Color-Schemes)${_off}"; }
menu::t::tt() {
    sys::set_deps fzf || return 1

    local cached=$(cd "$path_cache_themes" 2> /dev/null && find . -type f ! -name '*.tmp' | sed 's|^\./||' | sort)
    [[ -n $cached ]] || {
        i18n::printf "没有已缓存的主题: %s\n" "No cached themes: %s\n" "$path_cache_themes"
        return 1
    }

    local chosen=$(printf '%s\n' "$cached" | awk '{full=$0; sub(/\.properties$/,""); print $0 "\t" full}' | fzf --prompt="$(i18n::printf "搜索已缓存主题 > " "Search cached themes > ")" --with-nth=1 --delimiter='\t' | cut -f2)
    [[ -n $chosen ]] || {
        MENU_QUICK=1
        return 1
    }

    sys::termux_apply_web_theme "$chosen"
}
menu::t::tt::title() { i18n::printf -v "$1" "${_cat3} 浏览已缓存的主题${_faint}（~/.termux/cache）${_off}" "${_cat3} Browse cached themes${_faint} (~/.termux/cache)${_off}"; }

# ---- 按键布局菜单 ----
menu::k() { i18n::printf -v "$1" "${_cat4}${_memu_hl}󰌓 浏览/探索/更改按键布局${_off}" "${_cat4}${_memu_hl}󰌓 Browse / discover / change keymaps${_off}"; }
menu::k::b() { sys::open_url "https://github.com/miniyu157/hello-termux"; }
menu::k::b::title() { i18n::printf -v "$1" "${_cat4}󰆋 在浏览器预览按键布局${_faint}（miniyu157/Hello-Termux）${_off}" "${_cat4}󰆋 Preview keymaps in browser${_faint} (miniyu157/Hello-Termux)${_off}"; }
menu::k::k1() { sys::termux_apply_keymap "Enhanced.properties"; }
menu::k::k1::title() { i18n::printf -v "$1" "${_cat4} 快捷应用实用按键布局${_off}" "${_cat4} Quick-apply enhanced key bindings${_off}"; }
menu::k::k() {
    sys::set_deps fzf || return 1

    local keymap_list
    sys::io::fetch_cached keymap_list "$path_cache_keymap_list" "$URL_keymap_list" || {
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
menu::k::k::title() { i18n::printf -v "$1" "${_cat4}${_memu_hl}󰌓 探索按键布局${_faint}（miniyu157/Hello-Termux）${_off}" "${_cat4}${_memu_hl}󰌓 Discover keymaps${_faint} (miniyu157/Hello-Termux)${_off}"; }
menu::k::kk() {
    sys::set_deps fzf || return 1

    local cached=$(cd "$path_cache_keymaps" 2> /dev/null && find . -type f ! -name '*.tmp' | sed 's|^\./||' | sort)
    [[ -n $cached ]] || {
        i18n::printf "没有已缓存的按键布局: %s\n" "No cached keymaps: %s\n" "$path_cache_keymaps"
        return 1
    }

    local chosen=$(printf '%s\n' "$cached" | awk '{full=$0; sub(/\.properties$/,""); print $0 "\t" full}' | fzf --prompt="$(i18n::printf "搜索已缓存按键布局 > " "Search cached keymaps > ")" --with-nth=1 --delimiter='\t' | cut -f2)
    [[ -n $chosen ]] || {
        MENU_QUICK=1
        return 1
    }

    sys::termux_apply_keymap "$chosen"
}
menu::k::kk::title() { i18n::printf -v "$1" "${_cat4} 浏览已缓存的按键布局${_faint}（~/.termux/cache）${_off}" "${_cat4} Browse cached keymaps${_faint} (~/.termux/cache)${_off}"; }

# ---- fish 安装 ----

menu::root::fish() {
    sys::set_deps fish || return 1
    chsh -s fish && i18n_msg::shell_changed fish
}
menu::root::fish::title() {
    local _status=''
    pure::command_status fish _status
    i18n::printf -v "$1" "${_green}${_memu_hl} 安装友好交互的 Shell - fish${_faint}（%s）${_off}" "${_green}${_memu_hl} Install the friendly interactive shell — fish${_faint} (%s)${_off}" "$_status"
}

# ---- fish 插件 ----

menu::ffff() { i18n::printf -v "$1" "${_green}${_memu_hl}󰻳 关于 fish 的 fisher 插件${_off}" "${_green}${_memu_hl}󰻳 About fish's fisher plugins${_off}"; }
menu::ffff::f() {
    local fisher_func="$HOME/.config/fish/functions/fisher.fish"
    if [[ ! -f $fisher_func ]]; then
        fish -c "curl -sL https://raw.githubusercontent.com/jorgebucaran/fisher/main/functions/fisher.fish | source && fisher install jorgebucaran/fisher" || return 1
    fi
    i18n::printf "已安装 fisher，可以使用 '${_hl}fisher${_off}' 命令管理 fish 插件，也可以用于卸载自身。\n" "fisher is installed. Use '${_hl}fisher${_off}' to manage fish plugins, or to uninstall itself.\n"
}
menu::ffff::f::title() { i18n::printf -v "$1" "${_green}${_memu_hl}󰐱 安装 fisher 插件管理器${_faint}（%s）${_off}" "${_green}${_memu_hl}󰐱 Install fisher plugin manager${_faint} (%s)${_off}" "$(pure::fisher_plugin_status "jorgebucaran/fisher")"; }
menu::ffff::a() { fish -c "fisher install gazorby/fifc"; }
menu::ffff::a::title() { i18n::printf -v "$1" "${_green}gazorby/fifc — 智能补全${_faint}（%s）${_off}" "${_green}gazorby/fifc — smart completions${_faint} (%s)${_off}" "$(pure::fisher_plugin_status "gazorby/fifc")"; }
menu::ffff::b() { fish -i -c "fisher install IlanCosman/tide@v6" < /dev/tty; }
menu::ffff::b::title() { i18n::printf -v "$1" "${_green}IlanCosman/tide@v6 — 优秀主题${_faint}（%s）${_off}" "${_green}IlanCosman/tide@v6 — a beautiful prompt${_faint} (%s)${_off}" "$(pure::fisher_plugin_status "IlanCosman/tide")"; }

# ---- Shell 辅助套件 ----

menu::sh() { i18n::printf -v "$1" \
    "${_purple}${_memu_hl} 更多 Shell 辅助套件${_off}
${_faint}将显示 diff 更改供审阅，自动备份旧配置${_off}" \
    "${_purple}${_memu_hl} More Shell utilities${_off}
${_faint}Shows diff before applying, auto-backs up old config${_off}"; }
menu::sh::eza() {
    sys::set_deps eza gum || return 1

    local shell=$(gum choose --header="$(i18n::printf "需要为哪个 shell 设置 %s？" "Which shell to configure for %s?" "eza")" bash fish)
    [[ -n $shell ]] || {
        MENU_QUICK=1
        return 1
    }

    local remote="${URL_shell_cells}eza_alias.${shell}"
    local cache="$path_cache_dir/eza_alias_${shell}"

    local content
    sys::io::fetch_cached content "$cache" "$remote" || {
        i18n::printf "拉取失败: %s\n" "Failed to fetch: %s\n" "$remote"
        return 1
    }

    local config scan_target
    case "$shell" in
        bash)
            config="$HOME/.bashrc"
            scan_target="$HOME/.bashrc"
            ;;
        fish)
            config="$HOME/.config/fish/conf.d/eza_alias.fish"
            scan_target="$HOME/.config/fish/"
            ;;
    esac

    sys::io::write_config "$scan_target" 'alias.*eza' "$config" "$content" &&
        i18n_msg::shell_changed "$shell"
}
menu::sh::eza::title() { i18n::printf -v "$1" "${_purple}安装 eza，并为 bash/fish 配置实用别名${_off}" "${_purple}Install eza and configure aliases for bash/fish${_off}"; }
menu::sh::zox() {
    sys::set_deps zoxide gum || return 1

    local shell=$(gum choose --header="$(i18n::printf "需要为哪个 shell 设置 %s？" "Which shell to configure for %s?" "zoxide")" bash fish)
    [[ -n $shell ]] || {
        MENU_QUICK=1
        return 1
    }

    local config content scan_target
    case "$shell" in
        bash)
            config="$HOME/.bashrc"
            scan_target="$HOME/.bashrc"
            # shellcheck disable=SC2016
            content='# -- zoxide init {{ --
eval "$(zoxide init bash)"
# -- }} zoxide init --'
            ;;
        fish)
            config="$HOME/.config/fish/conf.d/zoxide.fish"
            scan_target="$HOME/.config/fish/"
            content='# -- zoxide init {{ --
if status is-interactive
    zoxide init fish | source
end
# -- }} zoxide init --'
            ;;
    esac

    sys::io::write_config "$scan_target" 'zoxide init' "$config" "$content" &&
        i18n_msg::shell_changed "$shell"
}
menu::sh::zox::title() { i18n::printf -v "$1" "${_purple}安装 zoxide，并为 bash/fish 配置 hook${_off}" "${_purple}Install zoxide and configure hook for bash/fish${_off}"; }
menu::sh::atu() {
    sys::set_deps atuin gum || return 1

    local shell=$(gum choose --header="$(i18n::printf "需要为哪个 shell 设置 %s？" "Which shell to configure for %s?" "atuin")" bash fish)
    [[ -n $shell ]] || {
        MENU_QUICK=1
        return 1
    }

    local config content scan_target
    case "$shell" in
        bash)
            config="$HOME/.bashrc"
            scan_target="$HOME/.bashrc"
            # shellcheck disable=SC2016
            content='# -- atuin init {{ --
eval "$(atuin init bash --disable-up-arrow)"
# -- }} atuin init --'
            ;;
        fish)
            config="$HOME/.config/fish/conf.d/atuin.fish"
            scan_target="$HOME/.config/fish/"
            content='# -- atuin init {{ --
if status is-interactive
    atuin init fish --disable-up-arrow | source
end
# -- }} atuin init --'
            ;;
    esac

    sys::io::write_config "$scan_target" 'atuin init' "$config" "$content" &&
        i18n_msg::shell_changed "$shell"
}
menu::sh::atu::title() { i18n::printf -v "$1" "${_purple}安装 atuin，并为 bash/fish 配置 hook${_off}" "${_purple}Install atuin and configure hook for bash/fish${_off}"; }

# ---- 程序设置 ----

menu::root::s() {
    case "$APP_RESOURCE_SERVICE" in
        cdn.jsdelivr.net) app::set_resource_service github.com ;;
        github.com) app::set_resource_service cdn.statically.io ;;
        cdn.statically.io) app::set_resource_service cdn.jsdelivr.net ;;
    esac
    MENU_QUICK=1
}
menu::root::s::title() { i18n::printf -v "$1" "󰛍 切换程序资源服务器${_faint}（当前: %s）${_off}" "󰛍 Switch resource server${_faint} (current: %s)${_off}" "$APP_RESOURCE_SERVICE"; }

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
menu::root::i::title() { i18n::printf -v "$1" " 将此程序安装到本地" " Install this program locally"; }

menu::root::l() {
    case "$APP_LANG" in
        zh) APP_LANG="en" ;;
        *) APP_LANG="zh" ;;
    esac
    MENU_QUICK=1
}
menu::root::l::title() { i18n::printf -v "$1" " 切换语言${_faint}（目前：中文）${_off}" " Switch Language${_faint} (Current: English)${_off}"; }

menu::root::cl() {
    rm -rf "$path_cache_dir"
    mkdir -p "$path_cache_dir"
    i18n::printf "清理: %s\n" "Cleared: %s\n" "$path_cache_dir"
}
menu::root::cl::title() { i18n::printf -v "$1" " 清除缓存目录${_faint}（~/.cache/hello-termux）${_off}" " Clear cache directory${_faint} (~/.cache/hello-termux)${_off}"; }

menu::root::is() { sys::open_url "https://github.com/miniyu157/hello-termux/issues"; }
menu::root::is::title() { i18n::printf -v "$1" "󰭻 前往 Issues 页面" "󰭻 Go to Issues page"; }

menu::root::gh() { sys::open_url "https://github.com/miniyu157/hello-termux"; }
menu::root::gh::title() { i18n::printf -v "$1" "󰊤 前往源代码仓库" "󰊤 Go to source repository"; }

menu::root::q() { exit 0; }
menu::root::q::title() { i18n::printf -v "$1" "󰩈 退出程序" "󰩈 Exit"; }

# ---- i18n ----

app::set_lang() {
    [[ -n ${APP_LANG} ]] && return
    local android_locale="$(getprop persist.sys.locale 2> /dev/null)"

    if [[ $android_locale == zh-* ]] || [[ ${LANG:-} == zh_* ]]; then
        APP_LANG="zh"
    else
        APP_LANG="en"
    fi
}

i18n::printf() {
    local _v=''
    if [[ $1 == -v ]]; then
        _v="$2"
        shift 2
    fi
    local fmt="$1"
    [[ $APP_LANG != zh ]] && fmt="$2"
    if [[ -n $_v ]]; then
        # shellcheck disable=SC2059
        printf -v "$_v" -- "$fmt" "${@:3}"
    else
        # shellcheck disable=SC2059
        printf -- "$fmt" "${@:3}"
    fi
}

i18n_msg::shell_changed() { i18n::printf "${_ok}>${_off} 已更改 shell 配置，使用以下操作均可查看效果：\n- 开启新会话\n- 重启终端应用\n- 运行 '${_hl}exec %s${_off}'\n" "${_ok}>${_off} Shell configuration changed. To see the effect:\n- Start a new session\n- Restart the terminal app\n- Run '${_hl}exec %s${_off}'\n" "$1"; }

# -- loop menu --

# 剥离 S-表达式最外层括号：(a b c) → a b c
pure::strip_parens() {
    local s="${1#(}" _v="${2:-}"
    if [[ -n $_v ]]; then
        printf -v "$_v" '%s' "${s%)}"
    else
        printf '%s\n' "${s%)}"
    fi
}

# 按括号深度将扁平常量解析为逐行子节点
# "a (g1 b (g2 c)) f" → a \n (g1 b (g2 c)) \n f
pure::parse_children() {
    local input="$1" depth=0 current='' i=0 ch
    local -n _out="$2"
    _out=()
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
                    [[ -n $current ]] && _out+=("$current")
                    current=''
                else
                    current+="$ch"
                fi
                ;;
            *) current+="$ch" ;;
        esac
        ((i++))
    done
    [[ -n $current ]] && _out+=("$current")
}

# Shell 风格引号解析：单/双引号内空格保留为同一参数，引号本身不进入结果
# $1  输入字符串
# $2  输出数组变量名（nameref）
pure::split_args() {
    local input="$1"
    # shellcheck disable=SC2178
    local -n _out="$2"
    _out=()
    local state='NONE' current='' ch i=0
    while ((i < ${#input})); do
        ch="${input:i:1}"
        case "$state" in
            NONE)
                case "$ch" in
                    "'") state='SINGLE' ;;
                    '"') state='DOUBLE' ;;
                    ' ' | $'\t')
                        [[ -n $current ]] && _out+=("$current")
                        current=''
                        ;;
                    *) current+="$ch" ;;
                esac
                ;;
            SINGLE)
                case "$ch" in
                    "'") state='NONE' ;;
                    *) current+="$ch" ;;
                esac
                ;;
            DOUBLE)
                case "$ch" in
                    '"') state='NONE' ;;
                    \\)
                        ((i++))
                        current+="${input:i:1}"
                        ;; # match literal backslash
                    *) current+="$ch" ;;
                esac
                ;;
        esac
        ((i++))
    done
    [[ -n $current ]] && _out+=("$current")
}

# 递归菜单渲染器
# $1  S-表达式，如 "(root m mc u (ffff f a b) q)"
# $2  根名称（首层自动从 $1 提取，递归时透传）
app::loop_menu() {
    local raw_expr="$1" root_name="${2:-}"

    # 规范化 S-表达式
    local flat="$(pure::strip_parens "$(printf '%s' "$raw_expr" | sed 's/;.*//' | tr '\n' ' ' | sed 's/[[:space:]]\{1,\}/ /g; s/^ //; s/ $//')")"
    local parent="${flat%% *}" children_flat="${flat#* }"
    [[ $children_flat == "$parent" ]] && children_flat=''
    [[ -z $root_name ]] && root_name="$parent"

    local -a children_arr=()
    pure::parse_children "$children_flat" children_arr

    while true; do
        # 准备 buf
        local buf='' _line=''

        # 调用 menu::<parent> 渲染标题，第一行作为主标题（✦ 包裹的加粗），剩余行作为副标题（4空格缩进）
        local header_text='' first_line rest_lines
        "menu::${parent}" header_text 2> /dev/null || true
        [[ -z $header_text ]] && first_line="$parent" || first_line="${header_text%%$'\n'*}"
        [[ $header_text == *$'\n'* ]] && rest_lines="${header_text#*$'\n'}"
        buf+="${_b}  ✦ ${first_line} ✦ ${_off}"$'\n'
        [[ -n ${rest_lines:-} ]] && buf+='    '${rest_lines//$'\n'/$'\n'    }$'\n'
        buf+="─────────────────────────────────────────────────"$'\n'

        # 渲染子节点
        local child _in='' _gt='' _lt=''
        for child in "${children_arr[@]}"; do
            if [[ $child == '('*')' ]]; then
                pure::strip_parens "$child" _in
                local gname="${_in%% *}" _gt=''
                "menu::${gname}" _gt 2> /dev/null
                _gt="${_gt%%$'\n'*}"
                printf -v _line "${_faint}${_italic}%4s${_off} %s\n" "$gname" "$_gt"
            else
                local title_func="menu::${parent}::${child}::title" _lt=''
                declare -F "menu::${parent}::${child}" > /dev/null 2>&1 ||
                    title_func="menu::_::${child}::title"
                "$title_func" _lt 2> /dev/null
                printf -v _line "${_faint}${_italic}%4s${_off} %s\n" "$child" "$_lt"
            fi
            buf+="$_line"
        done

        # Footer
        buf+="${_faint}─────────────────────────────────────────────────${_off}"$'\n'
        if [[ $parent == "$root_name" ]]; then
            i18n::printf -v _line "${_uline}键入需要的工具回车运行:${_off}\n" "${_uline}Type a key and press Enter to run:${_off}\n"
        else
            i18n::printf -v _line "${_uline}键入选项或留空返回:${_off}\n" "${_uline}Type a choice or leave empty to go back:${_off}\n"
        fi
        buf+="$_line"

        printf '%s' "${_refresh}${buf}"

        read -r choice < /dev/tty || {
            printf "\n"
            return
        }
        [[ -z $choice ]] && { [[ $parent == "$root_name" ]] && continue || return; }

        # 拆分用户输入：第一项为 key，剩余为业务参数
        local key='' parts=()
        pure::split_args "$choice" parts
        key="${parts[0]:-}"
        set -- "${parts[@]:1}"

        # 匹配用户输入；未匹配 → 继续循环（重新渲染）
        for child in "${children_arr[@]}"; do
            if [[ $child == '('*')' ]]; then
                local inner
                pure::strip_parens "$child" inner
                [[ ${inner%% *} == "$key" ]] && {
                    app::loop_menu "$child" "$root_name"
                    break
                }
            elif [[ $child == "$key" ]]; then
                local action_func="menu::${parent}::${key}"
                declare -F "$action_func" > /dev/null 2>&1 ||
                    action_func="menu::_::${key}"
                if declare -F "$action_func" > /dev/null 2>&1; then
                    MENU_QUICK=0
                    "$action_func" "$@"
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
        done
    done
}

declare -g _refresh=$'\e[H\e[J' _b=$'\e[1m' _faint=$'\e[2m' _italic=$'\e[3m' _memu_hl=$'\e[1m' _uline=$'\e[4m' _off=$'\e[0m' _ok=$'\e[38;2;101;255;101m' _hl=$'\e[38;2;255;174;193m' _cat1=$'\e[38;2;255;115;108m' _cat2=$'\e[38;2;121;167;252m' _cat3=$'\e[38;2;255;174;193m' _cat4=$'\e[38;2;255;226;2m' _green=$'\e[38;2;173;255;184m' _purple=$'\e[38;2;243;159;249m'

return 0 2> /dev/null

app::set_lang
app::set_paths
app::set_resource_service github.com

app::loop_menu '(root
      m  mc  u       ; Mirrors & updates.
      (f             ; Fonts
        f ff b f1 f2)
      (t             ; Color themes
        t tt b t1 t2)
      (k             ; Keymaps
        k kk b k1)
      fish           ; Install fish shell.
      (ffff          ; Fisher plugins
        f  a  b)
      (sh            ; Shell extras (eza/zoxide/atuin)
        eza  zox  atu)
      s  l  i        ; Switch server / Lang / Install
      cl  is  gh     ; Clear cache / Issues / Repo
      q              ; Exit
)'
