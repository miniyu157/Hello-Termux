#!/usr/bin/env bash

# shellcheck disable=SC2155,SC2317,SC1130

app::set_resource_service() {
    local service="$1"
    case "$service" in
        cdn.jsdelivr.net)
            APP_RESOURCE_SERVICE="cdn.jsdelivr.net"
            URL_exe="https://cdn.jsdelivr.net/gh/miniyu157/hello-termux@main/hi.sh"

            URL_config_cells_prefix="https://cdn.jsdelivr.net/gh/miniyu157/hello-termux@main/config_cells/"
            URL_res_lists_prefix="https://cdn.jsdelivr.net/gh/miniyu157/hello-termux@main/res_lists/"

            URL_font_prefix="https://cdn.jsdelivr.net/gh/ryanoasis/nerd-fonts@master/patched-fonts"
            URL_keymap_prefix="https://cdn.jsdelivr.net/gh/miniyu157/hello-termux@main/keymaps"
            URL_theme_prefix="https://cdn.jsdelivr.net/gh/mbadolato/iTerm2-Color-Schemes@master/termux"
            ;;
        github.com)
            APP_RESOURCE_SERVICE="github.com"
            URL_exe="https://github.com/miniyu157/hello-termux/raw/main/hi.sh"

            URL_config_cells_prefix="https://github.com/miniyu157/hello-termux/raw/main/config_cells/"
            URL_res_lists_prefix="https://github.com/miniyu157/hello-termux/raw/main/res_lists/"

            URL_font_prefix="https://raw.githubusercontent.com/ryanoasis/nerd-fonts/master/patched-fonts"
            URL_keymap_prefix="https://github.com/miniyu157/hello-termux/raw/main/keymaps"
            URL_theme_prefix="https://raw.githubusercontent.com/mbadolato/iTerm2-Color-Schemes/master/termux"
            ;;
        cdn.statically.io)
            APP_RESOURCE_SERVICE="cdn.statically.io"
            URL_exe="https://cdn.statically.io/gh/miniyu157/hello-termux/main/hi.sh"

            URL_config_cells_prefix="https://cdn.statically.io/gh/miniyu157/hello-termux/main/config_cells/"
            URL_res_lists_prefix="https://cdn.statically.io/gh/miniyu157/hello-termux/main/res_lists/"

            URL_font_prefix="https://cdn.statically.io/gh/ryanoasis/nerd-fonts/master/patched-fonts"
            URL_keymap_prefix="https://cdn.statically.io/gh/miniyu157/hello-termux/main/keymaps"
            URL_theme_prefix="https://cdn.statically.io/gh/mbadolato/iTerm2-Color-Schemes/master/termux"
            ;;
    esac
}

app::set_paths() {
    path_termux_mirrors_dir="$PREFIX/etc/termux/mirrors"
    path_termux_mirror_link="$PREFIX/etc/termux/chosen_mirrors"
    path_termux_tmp="$PREFIX/tmp"

    path_termux_key_properties="$HOME/.termux/termux.properties"
    path_termux_colors_properties="$HOME/.termux/colors.properties"
    path_termux_font_ttf="$HOME/.termux/font.ttf"

    path_cache_dir="$HOME/.cache/hello-termux"
    path_cache_res_lists_dir="$path_cache_dir/res_lists"
    path_cache_config_cells_dir="$path_cache_dir/config_cells"

    path_termux_res_cache_dir="$HOME/.termux/cache"

    path_exe_install_bin="$PREFIX/bin/hi"
    path_exe_uninstall_bin="$PREFIX/bin/hi-uninstall"

    mkdir -p "$path_cache_dir"
}

do::set_deps() {
    local missing=()
    for dep in "$@"; do
        if [[ $dep == *:* ]]; then
            command -v "${dep%%:*}" > /dev/null 2>&1 || missing+=("${dep##*:}")
        else
            command -v "$dep" > /dev/null 2>&1 || missing+=("$dep")
        fi
    done
    ((${#missing[@]})) || return 0
    if [[ -n ${PREFIX:-} ]]; then
        i18n::printf "正在安装缺少的依赖: %s\n" "Installing missing dependencies: %s\n" "${missing[*]}"
        pkg install -y "${missing[@]}" || {
            i18n::printf "依赖安装未完成。\n" "Dependency installation did not complete.\n"
            return 1
        }
    else
        i18n::printf "失败了，尚未安装这些：%s\n" \
            "Failed — not yet installed: %s\n" \
            "${missing[*]}"
        return 1
    fi
}

out::fetch_cached() {
    local -n _ref_out="$1"
    local cache="$2" url="$3" ttl="${4:-30}"

    if [[ -s $cache ]] && [[ -z $(find "$cache" -mtime "+$ttl" 2> /dev/null) ]]; then
        _ref_out=$(< "$cache")
    else
        _ref_out=$(curl -#L "$url") || {
            i18n::printf "拉取失败: %s\n" "Failed to fetch: %s\n" "$url" >&2
            return 1
        }
        mkdir -p "$(dirname "$cache")"
        printf '%s\n' "$_ref_out" > "$cache"
    fi
}

do::cache_resource() {
    local cache_dir="$1" name="$2" url="$3"
    local dest="${cache_dir}/${name}"
    mkdir -p "$cache_dir"
    [[ -f $dest ]] && return 0
    mkdir -p "$(dirname "$dest")"
    curl -#L "$url" -o "${dest}.tmp" && mv "${dest}.tmp" "$dest"
}

# 列出目录下文件（不含 .tmp），空则返回 1
out::list_dir_files() {
    local dir="$1" output
    output=$(cd "$dir" 2> /dev/null && find . -type f ! -name '*.tmp' | sed 's|^\./||' | sort)
    [[ -n $output ]] || return 1
    printf '%s\n' "$output"
}

# Swap two files
do::swap_file() {
    local a="$1" b="$2" tmp=$(mktemp "$path_termux_tmp/ht_XXXXX")
    mv "$a" "$tmp" && mv "$b" "$a" && mv "$tmp" "$b"
}

# 扫描目标路径，如已有工具痕迹则显示提示，始终放行
# $1: 扫描目标（文件或目录路径）
# $2: grep -E 模式
void::warn_existing_config() {
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
do::write_user_config() {
    do::set_deps gum || return 1

    local config="$1" content="$2"
    [[ -f $config ]] && [[ "$(< "$config")" == *"$content"* ]] && {
        local _range=$(_content="$content" awk '
            { h = h $0 "\n" }
            END {
                n = ENVIRON["_content"]
                if (p = index(h, n)) {
                    b = substr(h, 1, p - 1); s = gsub(/\n/, "&", b) + 1
                    print s, s + gsub(/\n/, "&", n)
                }
            }
        ' "$config")
        i18n::printf "${_cat4}已有完全相同的配置 (L%s-L%s): %s。\n未修改。${_off}\n" "${_cat4}Already configured (L%s-L%s): %s.\nNo changes.${_off}\n" "${_range%% *}" "${_range##* }" "$config"
        return 1
    }

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
        do::swap_file "$tmp" "$config" && i18n::printf "修改前的配置位于 %s\n" "Previous config saved at %s\n" "$tmp"
    else
        mv "$tmp" "$config" && i18n::printf "已新建文件: %s\n" "Created new file: %s\n" "$config"
    fi
}

# 从 config_cells/vim/ 拉取 Neovim 配置文件并写入
# $1: 远端文件名（含后缀）
# $2: 配置文件完整路径
# $3: grep -E 模式
do::neovim_apply_config_cell() {
    local name="$1" config_path="$2" pattern="$3" _content
    out::fetch_cached _content "$path_cache_config_cells_dir/vim/${name}" "${URL_config_cells_prefix}vim/${name}" || return 1
    void::warn_existing_config ~/.config/nvim/ "$pattern"
    do::write_user_config "$config_path" "$_content" && i18n_msg::nvim_config_changed
}

# 应用 Termux 资源。下载缓存 → 复制到目标 → 刷新 Termux 设置
# $1  远端相对路径（用于拼接 URL 和本地缓存）
# $2  缓存子目录名
# $3  URL 前缀值
# $4  本地目标文件路径
do::termux_apply_resource() {
    local remote_path="$1" subdir="$2" url_prefix="$3" target="$4"
    do::cache_resource "$path_termux_res_cache_dir/$subdir" "$remote_path" "${url_prefix}/${remote_path// /%20}" &&
        cp -f "$path_termux_res_cache_dir/$subdir/$remote_path" "$target" &&
        termux-reload-settings &&
        i18n::printf "已应用 %s → %s\n" "Applied %s → %s\n" "$remote_path" "$target"
}

# 从远程 TSV 列表 fzf 选择，stdout 输出选中的值（TSV 第二列）
# $1: TSV 文件名    $2: fzf prompt 中文    $3: fzf prompt 英文
out::fzf_tsv_pick() {
    do::set_deps fzf >&2 || return 1
    local _list
    out::fetch_cached _list "$path_cache_res_lists_dir/$1" "$URL_res_lists_prefix/$1" || return 1
    local _chosen=$(printf '%s\n' "$_list" | fzf --prompt="$(i18n::printf "$2" "$3")" --with-nth=1 --delimiter='\t' | cut -f2)
    [[ -n $_chosen ]] || return 1
    printf '%s\n' "$_chosen"
}

# 从本地目录 fzf 选择，stdout 输出选中的文件名
# $1: 缓存目录路径    $2: fzf prompt 中文    $3: fzf prompt 英文
out::fzf_dir_pick() {
    do::set_deps fzf >&2 || return 1
    local _list
    _list=$(out::list_dir_files "$1") || {
        i18n::printf "没有已缓存的资源: %s\n" "No cached resources: %s\n" "$1" >&2
        return 1
    }
    local _chosen=$(printf '%s\n' "$_list" | fzf --prompt="$(i18n::printf "$2" "$3")")
    [[ -n $_chosen ]] || return 1
    printf '%s\n' "$_chosen"
}

# gum choose 交互式选择 shell，取消则设 MENU_QUICK=1 并返回 1
# $1: 工具名（用于 i18n 提示）  $2+: shell 候选列表
out::choose_shell() {
    do::set_deps gum >&2 || return 1
    local tool="$1" chosen
    shift
    chosen=$(gum choose --header="$(i18n::printf "需要为哪个 shell 设置 %s？" "Which shell to configure for %s?" "$tool")" "$@")
    [[ -n $chosen ]] || {
        MENU_QUICK=1
        return 1
    }
    printf '%s\n' "$chosen"
}

void::open_url() {
    xdg-open "$1" || {
        i18n::printf "拉起 xdg-open 失败: %s\n" "Failed to open URL: %s\n" "$1"
        return 1
    }
}

# 获取 fisher 插件安装状态的 i18n 文本
# $1  插件名
out::fisher_plugin_status() {
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
out::command_status() {
    local _v="${2:-}"
    if command -v "$1" > /dev/null 2>&1; then
        i18n::printf ${_v:+-v "$_v"} "已安装" "installed"
    else
        i18n::printf ${_v:+-v "$_v"} "未安装" "not installed"
    fi
}

# 通过文件是否存在获取 i18n 状态文本
out::command_status_by_file() {
    local _v="${2:-}"
    if [[ -f $1 ]]; then
        i18n::printf ${_v:+-v "$_v"} "已安装" "installed"
    else
        i18n::printf ${_v:+-v "$_v"} "未安装" "not installed"
    fi
}

# 将 chosen_mirrors 指向指定镜像文件或镜像组目录
# $1  镜像文件或镜像组目录路径
do::set_mirror_link() {
    [[ -L $path_termux_mirror_link ]] && unlink "$path_termux_mirror_link"
    ln -s "$1" "$path_termux_mirror_link"
}

# 读取镜像文件的描述（第 2 行首个空格之后）
# $1  镜像文件路径
# $2  输出变量名，省略则输出到 stdout
out::mirror_desc() {
    local _v="${2:-}" _omd_desc=''
    {
        IFS= read -r _
        IFS=' ' read -r _ _omd_desc
    } < "$1"
    if [[ -n $_v ]]; then
        printf -v "$_v" '%s' "$_omd_desc"
    else
        printf '%s' "$_omd_desc"
    fi
}

do::need_termux_prefix() {
    [[ -n ${PREFIX:-} ]] || {
        i18n::printf "此功能仅在 Termux 环境下可用。\n" "This feature is only available in Termux.\n" >&2
        return 1
    }
}
# ==== 业务菜单函数开始 ====
menu::root() { printf -v "$1" '%b\n%b' "Hello Termux${_off}" "${_faint}https://github.com/miniyu157/Hello-Termux${_off}"; }

menu::root::m() {
    do::need_termux_prefix || return 1
    do::set_deps gum || return 1

    local _mg_label="$(i18n::printf "镜像组（在多个镜像间轮换，推荐）" "Mirror group (rotate between mirrors, recommended)")"
    local _ms_label="$(i18n::printf "单一镜像" "Single mirror")"

    # Step 1: Mirror group or single mirror
    local mode
    mode=$(gum choose --header="$(i18n::printf "选择镜像模式：" "Select mirror mode:")" \
        "$_mg_label" "$_ms_label") || {
        MENU_QUICK=1
        return 1
    }

    {
        if [[ $mode == "$_ms_label" ]]; then
            # ---- Single mirror ----
            local _opts=() _desc=''

            # Default mirror first
            local _def_path="$path_termux_mirrors_dir/default"
            [[ -f $_def_path ]] && {
                out::mirror_desc "$_def_path" _desc
                _opts+=("${_def_path##*/} — $_desc")
            }

            # packages.termux.dev second (special-cased in original)
            local _ptd_path="$path_termux_mirrors_dir/europe/packages.termux.dev"
            [[ -f $_ptd_path ]] && {
                out::mirror_desc "$_ptd_path" _desc
                _opts+=("packages.termux.dev — $_desc")
            }

            # All remaining mirrors, skip packages.termux.dev (already added)
            while IFS= read -r -d '' f; do
                local _u="${f##*/}"
                [[ $_u == "packages.termux.dev" ]] && continue
                out::mirror_desc "$f" _desc
                _opts+=("$_u — $_desc")
            done < <(find "$path_termux_mirrors_dir"/{asia,chinese_mainland,europe,north_america,oceania,russia}/ \
                -type f ! -name "*\.dpkg-old" ! -name "*\.dpkg-new" ! -name "*~" -print0 2> /dev/null | sort -z)

            local chosen
            chosen=$(gum filter --header="$(i18n::printf "选择单一镜像（可输入筛选）：" "Select a single mirror (type to filter):")" \
                --placeholder="$(i18n::printf "输入关键词筛选..." "Type to filter...")" \
                "${_opts[@]}") || {
                MENU_QUICK=1
                return 1
            }

            local chosen_url="${chosen%% — *}"
            local mirror_path
            mirror_path=$(find "$path_termux_mirrors_dir" -name "$chosen_url" -type f 2> /dev/null | head -1)
            [[ -z $mirror_path ]] && {
                i18n::printf "未找到镜像: %s\n" "Mirror not found: %s\n" "$chosen_url" >&2
                return 1
            }
            do::set_mirror_link "$mirror_path"
        else
            # ---- Mirror group ----
            local _g_all="$(i18n::printf "所有镜像" "All mirrors")"
            local _g_asia="$(i18n::printf "亚洲（不含中国大陆和俄罗斯）" "Asia (excl. Chinese Mainland & Russia)")"
            local _g_cn="$(i18n::printf "中国大陆" "Chinese Mainland")"
            local _g_eu="$(i18n::printf "欧洲" "Europe")"
            local _g_na="$(i18n::printf "北美" "North America")"
            local _g_oc="$(i18n::printf "大洋洲" "Oceania")"
            local _g_ru="$(i18n::printf "俄罗斯" "Russia")"

            local group
            group=$(gum choose --header="$(i18n::printf "选择镜像组：" "Choose mirror group:")" \
                "$_g_all" "$_g_asia" "$_g_cn" "$_g_eu" "$_g_na" "$_g_oc" "$_g_ru") || {
                MENU_QUICK=1
                return 1
            }

            case "$group" in
                "$_g_all") do::set_mirror_link "$path_termux_mirrors_dir/all" ;;
                "$_g_asia") do::set_mirror_link "$path_termux_mirrors_dir/asia" ;;
                "$_g_cn") do::set_mirror_link "$path_termux_mirrors_dir/chinese_mainland" ;;
                "$_g_eu") do::set_mirror_link "$path_termux_mirrors_dir/europe" ;;
                "$_g_na") do::set_mirror_link "$path_termux_mirrors_dir/north_america" ;;
                "$_g_oc") do::set_mirror_link "$path_termux_mirrors_dir/oceania" ;;
                "$_g_ru") do::set_mirror_link "$path_termux_mirrors_dir/russia" ;;
            esac
        fi
    } && i18n::printf "设置完成，建议运行一次 '${_hl}pkg update${_off}' 以更新数据库。\n" "Done. Run '${_hl}pkg update${_off}' to refresh the package database.\n"
}
menu::root::m::title() {
    local link=$(readlink "$path_termux_mirror_link" 2> /dev/null)
    link="${link##*/}"
    i18n::printf -v "$1" "${_cat1}${_memu_hl} 更换软件包源${_faint}（镜像: %s）${_off}" "${_cat1}${_memu_hl} Change package mirror${_faint} (mirror: %s)${_off}" "${link:-$(i18n::printf "未设置" "none")}"
}
menu::root::m::hint() { i18n::printf -v "$1" "使用 gum 实现的高速 termux-change-repo 替代。\n仅 Termux 环境可用。" "A fast gum-based replacement for termux-change-repo.\nTermux environment only."; }
menu::root::u() {
    do::need_termux_prefix || return 1
    pkg update -y && apt upgrade -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold"
}
menu::root::u::title() { i18n::printf -v "$1" "${_cat1}󰏕 更新和升级软件包${_off}" "${_cat1}󰏕 Update and upgrade packages${_off}"; }
menu::root::u::hint() { i18n::printf -v "$1" "更新软件包索引并升级全部已安装包。\n仅 Termux 环境可用。" "Update package index and upgrade all installed packages.\nTermux environment only."; }

# ---- 字体菜单 ----
menu::f() { i18n::printf -v "$1" "${_cat2}${_memu_hl} 浏览/探索/更改字体${_off}" "${_cat2}${_memu_hl} Browse / discover / change fonts${_off}"; }
menu::f::b() { void::open_url "https://www.programmingfonts.org/#oxproto"; }
menu::f::b::title() { i18n::printf -v "$1" "${_cat2}󰆋 在浏览器预览字体效果${_faint}（programmingfonts.org）${_off}" "${_cat2}󰆋 Preview fonts in browser${_faint} (programmingfonts.org)${_off}"; }
menu::f::1() { do::termux_apply_resource "IosevkaTerm/IosevkaTermNerdFont-Regular.ttf" fonts "$URL_font_prefix" "$path_termux_font_ttf"; }
menu::f::1::title() { i18n::printf -v "$1" "${_cat2} 快捷安装 IosevkaTerm Nerd Font${_off}" "${_cat2} Quick-install IosevkaTerm Nerd Font${_off}"; }
menu::f::2() { do::termux_apply_resource "IosevkaTerm/IosevkaTermNerdFont-BoldItalic.ttf" fonts "$URL_font_prefix" "$path_termux_font_ttf"; }
menu::f::2::title() { i18n::printf -v "$1" "${_cat2} 快捷安装 IosevkaTerm Nerd Font Bold Italic${_off}" "${_cat2} Quick-install IosevkaTerm Nerd Font Bold Italic${_off}"; }
menu::f::f() {
    local chosen
    chosen=$(out::fzf_tsv_pick font_list.tsv "搜索字体 > " "Search fonts > ") || {
        MENU_QUICK=1
        return 1
    }
    do::termux_apply_resource "$chosen" fonts "$URL_font_prefix" "$path_termux_font_ttf"
}
menu::f::f::title() { i18n::printf -v "$1" "${_cat2}${_memu_hl} 探索 Nerd Font 字体${_faint}（ryanoasis/nerd-fonts）${_off}" "${_cat2}${_memu_hl} Discover Nerd Fonts${_faint} (ryanoasis/nerd-fonts)${_off}"; }
menu::f::ff() {
    local chosen
    chosen=$(out::fzf_dir_pick "$path_termux_res_cache_dir/fonts" "搜索已缓存字体 > " "Search cached fonts > ") || {
        MENU_QUICK=1
        return 1
    }
    do::termux_apply_resource "$chosen" fonts "$URL_font_prefix" "$path_termux_font_ttf"
}
menu::f::ff::title() { i18n::printf -v "$1" "${_cat2} 浏览已缓存的字体${_faint}（~/.termux/cache）${_off}" "${_cat2} Browse cached fonts${_faint} (~/.termux/cache)${_off}"; }

# ----颜色主题菜单 ----
menu::t() { i18n::printf -v "$1" "${_cat3}${_memu_hl} 浏览/探索/更改颜色主题${_off}" "${_cat3}${_memu_hl} Browse / discover / change color themes${_off}"; }
menu::t::b() { void::open_url "https://github.com/mbadolato/iTerm2-Color-Schemes"; }
menu::t::b::title() { i18n::printf -v "$1" "${_cat3}󰆋 在浏览器预览颜色主题${_faint}（mbadolato/iTerm2-Color-Schemes）${_off}" "${_cat3}󰆋 Preview color themes in browser${_faint} (mbadolato/iTerm2-Color-Schemes)${_off}"; }
menu::t::1() { do::termux_apply_resource "Dracula+.properties" themes "$URL_theme_prefix" "$path_termux_colors_properties"; }
menu::t::1::title() { i18n::printf -v "$1" "${_cat3} 快捷应用 Dracula+ 主题${_off}" "${_cat3} Quick-apply Dracula+${_off}"; }
menu::t::2() { do::termux_apply_resource "Gruvbox Dark.properties" themes "$URL_theme_prefix" "$path_termux_colors_properties"; }
menu::t::2::title() { i18n::printf -v "$1" "${_cat3} 快捷应用 Gruvbox Dark 主题${_off}" "${_cat3} Quick-apply Gruvbox Dark${_off}"; }
menu::t::t() {
    local chosen
    chosen=$(out::fzf_tsv_pick theme_list.tsv "搜索主题 > " "Search themes > ") || {
        MENU_QUICK=1
        return 1
    }
    do::termux_apply_resource "$chosen" themes "$URL_theme_prefix" "$path_termux_colors_properties"
}
menu::t::t::title() { i18n::printf -v "$1" "${_cat3}${_memu_hl} 探索颜色主题${_faint}（mbadolato/iTerm2-Color-Schemes）${_off}" "${_cat3}${_memu_hl} Discover color themes${_faint} (mbadolato/iTerm2-Color-Schemes)${_off}"; }
menu::t::tt() {
    local chosen
    chosen=$(out::fzf_dir_pick "$path_termux_res_cache_dir/themes" "搜索已缓存主题 > " "Search cached themes > ") || {
        MENU_QUICK=1
        return 1
    }
    do::termux_apply_resource "$chosen" themes "$URL_theme_prefix" "$path_termux_colors_properties"
}
menu::t::tt::title() { i18n::printf -v "$1" "${_cat3} 浏览已缓存的主题${_faint}（~/.termux/cache）${_off}" "${_cat3} Browse cached themes${_faint} (~/.termux/cache)${_off}"; }

# ---- 按键布局菜单 ----
menu::k() { i18n::printf -v "$1" "${_cat4}${_memu_hl}󰌓 浏览/探索/更改按键布局${_off}" "${_cat4}${_memu_hl}󰌓 Browse / discover / change keymaps${_off}"; }
menu::k::b() { void::open_url "https://github.com/miniyu157/hello-termux"; }
menu::k::b::title() { i18n::printf -v "$1" "${_cat4}󰆋 在浏览器预览按键布局${_faint}（miniyu157/Hello-Termux）${_off}" "${_cat4}󰆋 Preview keymaps in browser${_faint} (miniyu157/Hello-Termux)${_off}"; }
menu::k::1() { do::termux_apply_resource "Enhanced.properties" keymaps "$URL_keymap_prefix" "$path_termux_key_properties"; }
menu::k::1::title() { i18n::printf -v "$1" "${_cat4} 快捷应用实用按键布局${_off}" "${_cat4} Quick-apply enhanced key bindings${_off}"; }
menu::k::k() {
    local chosen
    chosen=$(out::fzf_tsv_pick keymap_list.tsv "搜索按键布局 > " "Search keymaps > ") || {
        MENU_QUICK=1
        return 1
    }
    do::termux_apply_resource "$chosen" keymaps "$URL_keymap_prefix" "$path_termux_key_properties"
}
menu::k::k::title() { i18n::printf -v "$1" "${_cat4}${_memu_hl}󰌓 探索按键布局${_faint}（miniyu157/Hello-Termux）${_off}" "${_cat4}${_memu_hl}󰌓 Discover keymaps${_faint} (miniyu157/Hello-Termux)${_off}"; }
menu::k::kk() {
    local chosen
    chosen=$(out::fzf_dir_pick "$path_termux_res_cache_dir/keymaps" "搜索已缓存按键布局 > " "Search cached keymaps > ") || {
        MENU_QUICK=1
        return 1
    }
    do::termux_apply_resource "$chosen" keymaps "$URL_keymap_prefix" "$path_termux_key_properties"
}
menu::k::kk::title() { i18n::printf -v "$1" "${_cat4} 浏览已缓存的按键布局${_faint}（~/.termux/cache）${_off}" "${_cat4} Browse cached keymaps${_faint} (~/.termux/cache)${_off}"; }

# ---- fish 安装 ----

menu::fi::i() { do::set_deps fish && chsh -s fish && i18n_msg::shell_changed fish; }
menu::fi::i::title() {
    local _status=''
    out::command_status fish _status
    i18n::printf -v "$1" "${_green}${_memu_hl} 安装友好交互的 Shell - fish${_faint}（%s）${_off}" "${_green}${_memu_hl} Install the friendly interactive shell — fish${_faint} (%s)${_off}" "$_status"
}

# ---- fish 插件 ----

menu::fi() { i18n::printf -v "$1" "${_green}${_memu_hl} 了解友好交互的 fish + fisher${_off}" "${_green}${_memu_hl} About the friendly interactive fish + fisher${_off}"; }
menu::fi::ii() {
    local fisher_func="$HOME/.config/fish/functions/fisher.fish"
    if [[ ! -f $fisher_func ]]; then
        fish -c "curl -sL https://raw.githubusercontent.com/jorgebucaran/fisher/main/functions/fisher.fish | source && fisher install jorgebucaran/fisher" || return 1
    fi
    i18n::printf "已安装 fisher，可以使用 '${_hl}fisher${_off}' 命令管理 fish 插件，也可以用于卸载自身。\n" "fisher is installed. Use '${_hl}fisher${_off}' to manage fish plugins, or to uninstall itself.\n"
}
menu::fi::ii::title() { i18n::printf -v "$1" "${_green}${_memu_hl}󰻳 安装 fisher 插件管理器${_faint}（%s）${_off}" "${_green}${_memu_hl}󰻳 Install fisher plugin manager${_faint} (%s)${_off}" "$(out::fisher_plugin_status "jorgebucaran/fisher")"; }
menu::fi::1() { fish -c "fisher install gazorby/fifc"; }
menu::fi::1::title() { i18n::printf -v "$1" "${_green}gazorby/fifc — 智能补全${_faint}（%s）${_off}" "${_green}gazorby/fifc — smart completions${_faint} (%s)${_off}" "$(out::fisher_plugin_status "gazorby/fifc")"; }
menu::fi::2() { fish -i -c "fisher install IlanCosman/tide@v6" < /dev/tty; }
menu::fi::2::title() { i18n::printf -v "$1" "${_green}IlanCosman/tide@v6 — 优秀主题${_faint}（%s）${_off}" "${_green}IlanCosman/tide@v6 — a beautiful prompt${_faint} (%s)${_off}" "$(out::fisher_plugin_status "IlanCosman/tide")"; }

# ---- Shell 辅助套件 ----

menu::sh() { i18n::printf -v "$1" \
    "${_purple}${_memu_hl} 更多 Shell 辅助套件${_off}
${_faint}将显示 diff 更改供审阅，自动备份旧配置${_off}" \
    "${_purple}${_memu_hl} More Shell utilities${_off}
${_faint}Shows diff before applying, auto-backs up old config${_off}"; }
menu::sh::1() {
    do::set_deps eza || return 1

    local shell content config scan_target
    shell=$(out::choose_shell eza bash fish) || return 1
    out::fetch_cached content "${path_cache_config_cells_dir}/shell/eza_alias.${shell}" "${URL_config_cells_prefix}shell/eza_alias.${shell}" || return 1
    case "$shell" in
        bash) config="$HOME/.bashrc" scan_target="$HOME/.bashrc" ;;
        fish) config="$HOME/.config/fish/conf.d/eza_alias.fish" scan_target="$HOME/.config/fish/" ;;
    esac

    void::warn_existing_config "$scan_target" 'alias.*eza'
    do::write_user_config "$config" "$content" && i18n_msg::shell_changed "$shell"
}
menu::sh::1::title() { i18n::printf -v "$1" "${_purple}安装 eza，并为 bash/fish 配置实用别名${_off}" "${_purple}Install eza and configure aliases for bash/fish${_off}"; }
menu::sh::2() {
    do::set_deps zoxide || return 1

    local shell content config scan_target
    shell=$(out::choose_shell zoxide bash fish) || return 1
    out::fetch_cached content "${path_cache_config_cells_dir}/shell/zoxide_init.${shell}" "${URL_config_cells_prefix}shell/zoxide_init.${shell}" || return 1
    case "$shell" in
        bash) config="$HOME/.bashrc" scan_target="$HOME/.bashrc" ;;
        fish) config="$HOME/.config/fish/conf.d/zoxide_init.fish" scan_target="$HOME/.config/fish/" ;;
    esac

    void::warn_existing_config "$scan_target" 'zoxide init'
    do::write_user_config "$config" "$content" && i18n_msg::shell_changed "$shell"
}
menu::sh::2::title() { i18n::printf -v "$1" "${_purple}安装 zoxide，并为 bash/fish 配置 hook${_off}" "${_purple}Install zoxide and configure hook for bash/fish${_off}"; }
menu::sh::3() {
    do::set_deps atuin || return 1

    local shell content config scan_target
    shell=$(out::choose_shell atuin bash fish) || return 1
    out::fetch_cached content "${path_cache_config_cells_dir}/shell/atuin_init.${shell}" "${URL_config_cells_prefix}shell/atuin_init.${shell}" || return 1
    case "$shell" in
        bash) config="$HOME/.bashrc" scan_target="$HOME/.bashrc" ;;
        fish) config="$HOME/.config/fish/conf.d/atuin_init.fish" scan_target="$HOME/.config/fish/" ;;
    esac

    void::warn_existing_config "$scan_target" 'atuin init'
    do::write_user_config "$config" "$content" && i18n_msg::shell_changed "$shell"
}
menu::sh::3::title() { i18n::printf -v "$1" "${_purple}安装 atuin，并为 bash/fish 配置 hook${_off}" "${_purple}Install atuin and configure hook for bash/fish${_off}"; }
menu::sh::4() {
    do::set_deps bat || return 1

    local shell content config scan_target
    shell=$(out::choose_shell bat bash fish) || return 1
    out::fetch_cached content "${path_cache_config_cells_dir}/shell/bat_alias.${shell}" "${URL_config_cells_prefix}shell/bat_alias.${shell}" || return 1
    case "$shell" in
        bash) config="$HOME/.bashrc" scan_target="$HOME/.bashrc" ;;
        fish) config="$HOME/.config/fish/conf.d/bat_alias.fish" scan_target="$HOME/.config/fish/" ;;
    esac

    void::warn_existing_config "$scan_target" 'alias.*cat.*bat'
    do::write_user_config "$config" "$content" && i18n_msg::shell_changed "$shell"
}
menu::sh::4::title() { i18n::printf -v "$1" "${_purple}安装 bat，并为 bash/fish 配置实用别名${_off}" "${_purple}Install bat and configure aliases for bash/fish${_off}"; }
menu::sh::5() { do::set_deps rg:ripgrep; }
menu::sh::5::title() {
    local _s=''
    out::command_status rg _s
    i18n::printf -v "$1" "${_purple}安装更好的 grep — ripgrep${_faint}（%s）${_off}" "${_purple}Install a better grep — ripgrep${_faint} (%s)${_off}" "$_s"
}
menu::sh::6() { do::set_deps fd; }
menu::sh::6::title() {
    local _s=''
    out::command_status fd _s
    i18n::printf -v "$1" "${_purple}安装更好的 find — fd${_faint}（%s）${_off}" "${_purple}Install a better find — fd${_faint} (%s)${_off}" "$_s"
}

# ---- Neovim + Lazyvim ----

menu::vi() { i18n::printf -v "$1" \
    "${_vimcolor}${_memu_hl} 配置 Neovim + Lazyvim${_off}
${_faint}包含 Lazyvim 的实用配置，其中 1-6 菜单为配置文件写入${_off}" \
    "${_vimcolor}${_memu_hl} Configure Neovim + Lazyvim${_off}
${_faint}Practical configs for Lazyvim, items 1-6 write config files${_off}"; }

menu::vi::i() { do::set_deps nvim:neovim; }
menu::vi::i::title() {
    local _status=''
    out::command_status nvim _status
    i18n::printf -v "$1" "${_vimcolor}${_memu_hl} 安装 Neovim${_faint}（%s）${_off}" "${_vimcolor}${_memu_hl} Install Neovim${_faint} (%s)${_off}" "$_status"
}

menu::vi::ii() { do::set_deps git && git clone https://github.com/LazyVim/starter ~/.config/nvim && i18n_msg::nvim_config_changed; }
menu::vi::ii::title() {
    local _status=''
    out::command_status_by_file ~/.local/share/nvim/lazy/LazyVim/init.lua _status
    i18n::printf -v "$1" "${_vimcolor}${_memu_hl} 安装 Lazyvim${_faint}（%s）${_off}" "${_vimcolor}${_memu_hl} Install Lazyvim${_faint} (%s)${_off}" "$_status"
}

menu::vi::1() { do::neovim_apply_config_cell keymaps.lua ~/.config/nvim/lua/config/keymaps.lua 'nvim_create_user_command'; }
menu::vi::1::title() { i18n::printf -v "$1" "${_vimcolor}使 :w :wq :q :qa 忽略大小写${_off}" "${_vimcolor}Make :w :wq :q :qa case-insensitive${_off}"; }
menu::vi::2() { do::neovim_apply_config_cell blink.lua ~/.config/nvim/lua/plugins/blink.lua 'select_and_accept'; }
menu::vi::2::title() { i18n::printf -v "$1" "${_vimcolor}补全键换为 Tab${_off}" "${_vimcolor}Use Tab for completion${_off}"; }
menu::vi::3() { do::neovim_apply_config_cell suda.lua ~/.config/nvim/lua/plugins/suda.lua 'suda_smart_edit'; }
menu::vi::3::title() { i18n::printf -v "$1" "${_vimcolor}安装 suda 插件，使鉴权在编辑器内完成${_off}" "${_vimcolor}Install suda.vim to keep auth within the editor${_off}"; }
menu::vi::4() { do::neovim_apply_config_cell autocmds.lua ~/.config/nvim/lua/config/autocmds.lua 'lazyvim_wrap_spell'; }
menu::vi::4::title() { i18n::printf -v "$1" "${_vimcolor}编辑 markdown/gitcommit 时禁用拼写检查并自动换行${_off}" "${_vimcolor}Disable spell check & enable wrap when editing markdown/gitcommit${_off}"; }
menu::vi::5() { do::neovim_apply_config_cell options_listchars.lua ~/.config/nvim/lua/config/options.lua listchars; }
menu::vi::5::title() { i18n::printf -v "$1" "${_vimcolor}空格显示为点号以高亮${_off}" "${_vimcolor}Highlight spaces as dots${_off}"; }
menu::vi::6() { do::neovim_apply_config_cell options_clipboard.lua ~/.config/nvim/lua/config/options.lua 'termux-clipboard-set'; }
menu::vi::6::title() { i18n::printf -v "$1" "${_vimcolor}写入 termux-api 的剪贴板配置${_off}" "${_vimcolor}Write termux-api clipboard config${_off}"; }

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
    curl -#L "$URL_exe" -o "$path_exe_install_bin" || {
        i18n::printf "拉取失败: %s\n" "Failed to fetch: %s\n" "$URL_exe"
        return 1
    }
    chmod +x "$path_exe_install_bin" && {
        cat > "$path_exe_uninstall_bin" << EOF
#!/usr/bin/env bash
rm -f "$path_exe_install_bin" "$path_exe_uninstall_bin"
printf 'hi has been uninstalled.\n'
EOF
    } && chmod +x "$path_exe_uninstall_bin" && i18n::printf "安装完成。使用 hi 启动。\n使用 hi-uninstall 卸载。\n" "Done. Run 'hi' to start.\nRun 'hi-uninstall' to uninstall.\n"
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

menu::root::cl() { rm -rf "$path_cache_dir" && mkdir -p "$path_cache_dir" && i18n::printf "清理: %s\n" "Cleared: %s\n" "$path_cache_dir"; }
menu::root::cl::title() { i18n::printf -v "$1" " 清除缓存目录${_faint}（~/.cache/hello-termux）${_off}" " Clear cache directory${_faint} (~/.cache/hello-termux)${_off}"; }

menu::root::is() { void::open_url "https://github.com/miniyu157/hello-termux/issues"; }
menu::root::is::title() { i18n::printf -v "$1" "󰭻 前往 Issues 页面" "󰭻 Go to Issues page"; }

menu::root::gh() { void::open_url "https://github.com/miniyu157/hello-termux"; }
menu::root::gh::title() { i18n::printf -v "$1" "󰊤 前往源代码仓库" "󰊤 Go to source repository"; }

menu::root::q() { exit 0; }
menu::root::q::title() { i18n::printf -v "$1" "󰩈 退出程序" "󰩈 Exit"; }

# ---- i18n ----

app::set_lang() {
    [[ -n ${APP_LANG} ]] && return

    local locale
    locale=$(getprop persist.sys.locale 2> /dev/null)
    [[ -n $locale ]] || locale=$(getprop ro.product.locale 2> /dev/null)
    if [[ $locale == zh-* ]] || [[ ${LANG:-} == zh_* ]]; then
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

i18n_msg::nvim_config_changed() { i18n::printf "${_ok}>${_off} 已更改 Neovim 配置，建议运行一次 '${_hl}nvim${_off}' 以初始化配置。\n" "${_ok}>${_off} Neovim configuration changed. Run '${_hl}nvim${_off}' once to initialize the config.\n"; }

# -- loop menu --

# 剥离 S-表达式最外层括号：(a b c) → a b c
out::strip_parens() {
    local s="${1#(}" _v="${2:-}"
    if [[ -n $_v ]]; then
        printf -v "$_v" '%s' "${s%)}"
    else
        printf '%s\n' "${s%)}"
    fi
}

# 按括号深度将扁平常量解析为逐行子节点
# "a (g1 b (g2 c)) f" → a \n (g1 b (g2 c)) \n f
out::parse_children() {
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
out::split_args() {
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

# 词左边界：跳过光标前空白，再跳过一个词，返回起始下标
# $1 输入串  $2 光标位置  $3 输出变量名
out::word_left_pos() {
    local s="$1" i="$2"
    while ((i > 0)) && [[ ${s:i-1:1} == [[:space:]] ]]; do ((i--)); done
    while ((i > 0)) && [[ ${s:i-1:1} != [[:space:]] ]]; do ((i--)); done
    printf -v "$3" '%s' "$i"
}

# 词右边界：跳过光标处空白，再跳过一个词，返回结束下标
# $1 输入串  $2 光标位置  $3 输出变量名
out::word_right_pos() {
    local s="$1" i="$2" n="${#1}"
    while ((i < n)) && [[ ${s:i:1} == [[:space:]] ]]; do ((i++)); done
    while ((i < n)) && [[ ${s:i:1} != [[:space:]] ]]; do ((i++)); done
    printf -v "$3" '%s' "$i"
}

# 显示列宽：非 ASCII 一律计 2 列。中英混排的正文按此计算与终端实际一致；
# Nerd Font 图标属 Ambiguous 宽度，其列数由终端决定，不适用此估算
# $1 输入串  $2 输出变量名
out::display_width() {
    local ascii="${1//[![:ascii:]]/}"
    printf -v "$2" '%s' "$((${#ascii} + 2 * (${#1} - ${#ascii})))"
}

# 按显示列宽截断，超长时末尾换成省略号。要求输入为纯文本：
# 串内若含转义序列，列宽会被算错且可能被截断在序列中间
# $1 输入串  $2 最大列宽  $3 输出变量名
out::fit_width() {
    local s="$1" max="$2" w=0
    out::display_width "$s" w
    ((w <= max)) && {
        printf -v "$3" '%s' "$s"
        return
    }
    # 省略号 … 属 Ambiguous 宽度，保守预留 2 列
    local budget=$((max - 2)) acc=0 i=0 n="${#s}" c cw out=''
    ((budget <= 0)) && {
        printf -v "$3" '%s' ''
        return
    }
    while ((i < n)); do
        c="${s:i:1}"
        [[ $c == [[:ascii:]] ]] && cw=1 || cw=2
        ((acc + cw > budget)) && break
        out+="$c"
        ((acc += cw))
        ((i++))
    done
    printf -v "$3" '%s…' "$out"
}

# 按显示列宽软折行。输入中的换行为硬换行（末尾的换行不计，否则会多出空行）；
# 单行超宽时优先断在空格处，无空格（如 CJK）则任意位置断开。不限制行数
# $1 输入串  $2 最大列宽  $3 输出数组变量名（nameref）
out::wrap_width() {
    local s="$1" max="$2"
    # shellcheck disable=SC2178
    local -n _wo="$3"
    _wo=()
    ((max < 2)) && max=2
    while [[ $s == *$'\n' ]]; do s="${s%$'\n'}"; done
    local rest="$s" line cur ch cw i n w sp
    while true; do
        line="${rest%%$'\n'*}"
        cur='' w=0 i=0 n="${#line}" sp=-1
        while ((i < n)); do
            ch="${line:i:1}"
            [[ $ch == [[:ascii:]] ]] && cw=1 || cw=2
            if ((w + cw > max)); then
                if ((sp >= 0)); then
                    _wo+=("${cur:0:sp}")
                    cur="${cur:sp+1}"
                else
                    _wo+=("$cur")
                    cur=''
                fi
                out::display_width "$cur" w
                sp=-1
            fi
            cur+="$ch"
            ((w += cw))
            [[ $ch == ' ' ]] && sp=$((${#cur} - 1))
            ((i++))
        done
        _wo+=("$cur")
        [[ $rest == *$'\n'* ]] || break
        rest="${rest#*$'\n'}"
    done
}

# 单行视口：取光标附近宽度不超过 max 的窗口，溢出侧以 … 标记。输入行必须恒占一行，
# 一旦触发终端自动折行，\r\e[K 就只清得到最后一行，下方 hint 区随即错位
# 分两段回传，调用方在两段之间存光标（\e[s），由终端自行确定列，
# 从而不受 … 属 Ambiguous 宽度、实际列数由终端决定的影响
# $1 输入串  $2 光标字符下标  $3 最大列宽  $4 光标前输出变量名  $5 光标后输出变量名
out::viewport() {
    local s="$1" cur="$2" max="$3" w=0
    out::display_width "$s" w
    ((w <= max)) && {
        printf -v "$4" '%s' "${s:0:cur}"
        printf -v "$5" '%s' "${s:cur}"
        return
    }
    # 右锚定在光标：向左收集到预算用尽为止。… 保守按 2 列预留
    local budget=$((max - 2)) acc=0 i="$cur" ch cw
    while ((i > 0)); do
        ch="${s:i-1:1}"
        [[ $ch == [[:ascii:]] ]] && cw=1 || cw=2
        ((acc + cw > budget)) && break
        ((acc += cw))
        ((i--))
    done
    if ((i > 0)); then
        printf -v "$4" '…%s' "${s:i:cur-i}"
        ((acc += 2))
    else
        printf -v "$4" '%s' "${s:0:cur}"
    fi
    out::fit_width "${s:cur}" "$((max - acc))" "$5"
}

# 抹去输入行及其下方的 hint 区，光标停在输入行首。整块区域归输入引擎自有，
# 故 \e[J 到屏幕末尾是安全的
app::clear_input_region() { printf '\r\e[J'; }

# 逐字输入 + hint 渲染。输入恒占一行（超长走视口），hint 渲染在其下方
# $1 = parent 名
# $2 = children 数组名 (nameref)
# $3 = 输出变量名 (nameref)
# $4 = 历史数组名 (nameref)，由调用层持有，↑↓ 在其中浏览
# $5 = 菜单帧变量名 (nameref)，hint 缩行时用它重刷整帧
# 返回 0 且输出非空 = 用户选择；0 且空 = Escape 返回上层；1 = EOF（输入流关闭）
app::read_input_with_hint() {
    local parent="$1"
    local -n _ariwh_children="$2" _ariwh_out="$3" _ariwh_hist="$4" _ariwh_frame="$5"
    local buffer='' byte='' hint='' cursor_pos=0
    local vp_head='' vp_tail=''
    local -a parts=() hint_rows=()
    local key='' child hint_func
    # 已向下方预留的行数。扩容靠 \n，缩行靠重刷整帧后归零重撑
    local reserved=0
    # 上次求过 hint 的首词。hint 只依赖首词，故逐键击键无须重复查找与折行
    local hint_key=''
    # 历史游标：等于历史长度表示"停在当前行"，此时 stash 无意义
    local hist_idx="${#_ariwh_hist[@]}" hist_stash=''
    local cols=${COLUMNS:-80}
    [[ $cols =~ ^[0-9]+$ ]] && ((cols > 20)) || cols=80

    while true; do
        IFS= read -rsn1 byte || { # 输入流关闭 → 上抛，避免空串被当成"返回上层"
            app::clear_input_region
            return 1
        }
        case "$byte" in
            '') # Enter — 引擎接管屏幕刷新
                app::clear_input_region
                _ariwh_out="$buffer"
                return 0
                ;;
            $'\x7f' | $'\x08') # Backspace / Ctrl+H — 删除光标前字符
                if ((cursor_pos > 0)); then
                    buffer="${buffer:0:cursor_pos-1}${buffer:cursor_pos}"
                    ((cursor_pos--))
                fi
                ;;
            $'\x04') # Ctrl+D — 空行时视为 EOF，否则删除光标处字符
                if [[ -z $buffer ]]; then
                    app::clear_input_region
                    return 1
                elif ((cursor_pos < ${#buffer})); then
                    buffer="${buffer:0:cursor_pos}${buffer:cursor_pos+1}"
                fi
                ;;
            $'\x15') buffer="${buffer:cursor_pos}" cursor_pos=0 ;; # Ctrl+U — 删至行首
            $'\x17')                                               # Ctrl+W — 删至词首
                local _wl=0
                out::word_left_pos "$buffer" "$cursor_pos" _wl
                buffer="${buffer:0:_wl}${buffer:cursor_pos}"
                cursor_pos=$_wl
                ;;
            $'\e') # Escape — 按序列语法逐字节读取，不贪婪抽干（否则会吞掉紧随的按键）
                local esc='' final='' params='' mod=''
                if ! IFS= read -rsn1 -t "$ESC_DELAY" byte; then
                    # 超时且无后继字节 → 裸 Escape，返回上层
                    app::clear_input_region
                    _ariwh_out=''
                    return 0
                fi
                case "$byte" in
                    '[') # CSI: 读参数字节（数字/分号）直到终结字节
                        while IFS= read -rsn1 -t 0.2 byte; do
                            esc+="$byte"
                            [[ $byte == [[:digit:]] || $byte == ';' ]] || break
                        done
                        final="${esc: -1}" params="${esc%?}"
                        ;;
                    'O') # SS3: 固定再读一个终结字节
                        IFS= read -rsn1 -t 0.2 final || final=''
                        ;;
                    *) continue ;; # Alt+键 等，忽略
                esac

                # 修饰位：CSI 1;<mod><final>，5=Ctrl 2=Shift 3=Alt
                [[ $params == *';'* ]] && mod="${params##*;}"

                case "$final" in
                    D) # ← / Ctrl+← / Shift+←
                        if [[ $mod == 5 ]]; then
                            out::word_left_pos "$buffer" "$cursor_pos" cursor_pos
                        else
                            ((cursor_pos > 0)) && ((cursor_pos--))
                        fi
                        ;;
                    C) # → / Ctrl+→ / Shift+→
                        if [[ $mod == 5 ]]; then
                            out::word_right_pos "$buffer" "$cursor_pos" cursor_pos
                        else
                            ((cursor_pos < ${#buffer})) && ((cursor_pos++))
                        fi
                        ;;
                    A) # ↑ — 取更早的历史；首次离开当前行时先暂存已输入内容
                        if ((hist_idx > 0)); then
                            ((hist_idx == ${#_ariwh_hist[@]})) && hist_stash="$buffer"
                            ((hist_idx--))
                            buffer="${_ariwh_hist[hist_idx]}"
                            cursor_pos=${#buffer}
                        fi
                        ;;
                    B) # ↓ — 取更晚的历史；越过最新一条则恢复暂存内容
                        if ((hist_idx < ${#_ariwh_hist[@]})); then
                            ((hist_idx++))
                            if ((hist_idx == ${#_ariwh_hist[@]})); then
                                buffer="$hist_stash"
                            else
                                buffer="${_ariwh_hist[hist_idx]}"
                            fi
                            cursor_pos=${#buffer}
                        fi
                        ;;
                    H) cursor_pos=0 ;;          # Home（CSI \e[H / SS3 \eOH）
                    F) cursor_pos=${#buffer} ;; # End（CSI \e[F / SS3 \eOF）
                    '~')
                        case "${params%%;*}" in
                            1 | 7) cursor_pos=0 ;;          # Home
                            4 | 8) cursor_pos=${#buffer} ;; # End
                            3)                              # Delete — 删除光标处字符
                                ((cursor_pos < ${#buffer})) &&
                                    buffer="${buffer:0:cursor_pos}${buffer:cursor_pos+1}"
                                ;;
                        esac
                        ;;
                    *) ;; # 其他序列忽略（不泄漏到 buffer）
                esac
                ;;
            *) # 可打印字符 — 在光标处插入，控制字符忽略
                [[ $byte == [[:cntrl:]] ]] && continue
                buffer="${buffer:0:cursor_pos}${byte}${buffer:cursor_pos}"
                ((cursor_pos++))
                ;;
        esac

        # 求 hint：以 buffer 首词为 key 查找。首词未变则沿用上次的折行结果
        out::split_args "$buffer" parts
        key="${parts[0]:-}"
        if [[ $key != "$hint_key" ]]; then
            hint_key="$key" hint='' hint_rows=()
            if [[ -n $key ]]; then
                for child in "${_ariwh_children[@]}"; do
                    if [[ $child != '('*')' && $child == "$key" ]]; then
                        hint_func="menu::${parent}::${key}::hint"
                        declare -F "$hint_func" > /dev/null 2>&1 || hint_func="menu::_::${key}::hint"
                        # 丢弃 stdout：hint 应经 nameref 写回，误写标准输出者不得污染屏幕
                        "$hint_func" hint > /dev/null 2>&1 || true
                        break
                    fi
                done
            fi
            # 缩进 2 列，末列留空以避开终端的延迟折行
            [[ -n $hint ]] && out::wrap_width "$hint" "$((cols - 3))" hint_rows
        fi

        # hint 缩行时重刷整帧：扩容用的 \n 可能已滚屏，局部删行无法把菜单拉回屏内。
        # 重刷后光标回到输入行行首，预留归零，下面的扩容分支据此重新撑开
        local want="${#hint_rows[@]}" i
        if ((want < reserved)); then
            printf '%s' "${_refresh}${_ariwh_frame}"
            reserved=0
        fi

        # 扩容必须早于 \e[s：触底时 \n 会滚屏，而 DECSC 存的是绝对位置
        if ((want > reserved)); then
            printf '\r'
            for ((i = reserved; i < want; i++)); do printf '\n'; done
            printf '\e[%sA' "$((want - reserved))"
            reserved=$want
        fi

        out::viewport "$buffer" "$cursor_pos" "$((cols - 1))" vp_head vp_tail
        printf '\r\e[K%s' "$vp_head"
        printf '\e[s'
        printf '%s' "$vp_tail"
        # 只用相对移动，绝不输出 \n：hint 区因此永远不可能长出预留之外
        for ((i = 0; i < reserved; i++)); do
            printf '\e[B\r\e[K'
            ((i < want)) && printf '  %s%s%s' "${_faint}" "${hint_rows[i]}" "${_off}"
        done
        printf '\e[u'
    done
} < /dev/tty

# 递归菜单渲染器
# $1  S-表达式，如 "(root m mc u (ffff f a b) q)"
# $2  根名称（首层自动从 $1 提取，递归时透传）
app::loop_menu() {
    local raw_expr="$1" root_name="${2:-}"

    # 规范化 S-表达式
    local flat="$(out::strip_parens "$(printf '%s' "$raw_expr" | sed 's/;.*//' | tr '\n' ' ' | sed 's/[[:space:]]\{1,\}/ /g; s/^ //; s/ $//')")"
    local parent="${flat%% *}" children_flat="${flat#* }"
    [[ $children_flat == "$parent" ]] && children_flat=''
    [[ -z $root_name ]] && root_name="$parent"

    local -a children_arr=()
    out::parse_children "$children_flat" children_arr

    # 本层历史。递归时每层各持一份，互不干扰
    local -a hist=()

    while true; do
        # 准备 buf
        local buf=$'\n' _line='' _key_indent=3

        # 调用 menu::<parent> 渲染标题，第一行作为主标题（✦ 包裹的加粗），剩余行作为副标题（4空格缩进）
        local header_text='' first_line rest_lines
        "menu::${parent}" header_text 2> /dev/null || true
        [[ -z $header_text ]] && first_line="$parent" || first_line="${header_text%%$'\n'*}"
        [[ $header_text == *$'\n'* ]] && rest_lines="${header_text#*$'\n'}"

        local _cols=${COLUMNS:-80} _sep
        [[ $_cols =~ ^[0-9]+$ ]] && ((_cols > 20)) || _cols=80
        printf -v _sep '%*s' "$_cols" ''
        _sep="${_sep// /─}"

        buf+="${_b}  ✦ ${first_line} ✦ ${_off}"$'\n'
        [[ -n ${rest_lines:-} ]] && buf+='    '${rest_lines//$'\n'/$'\n'    }$'\n'
        buf+="$_sep"$'\n'

        # 渲染子节点
        local child _in='' _gt='' _lt=''
        for child in "${children_arr[@]}"; do
            if [[ $child == '('*')' ]]; then
                out::strip_parens "$child" _in
                local gname="${_in%% *}" _gt=''
                "menu::${gname}" _gt 2> /dev/null
                _gt="${_gt%%$'\n'*}"
                printf -v _line "${_faint}${_italic}%${_key_indent}s${_off} %s\n" "$gname" "$_gt"
            else
                local title_func="menu::${parent}::${child}::title" _lt=''
                declare -F "menu::${parent}::${child}" > /dev/null 2>&1 ||
                    title_func="menu::_::${child}::title"
                "$title_func" _lt 2> /dev/null
                printf -v _line "${_faint}${_italic}%${_key_indent}s${_off} %s\n" "$child" "$_lt"
            fi
            buf+="$_line"
        done

        # Footer
        buf+="${_faint}${_sep}${_off}"$'\n'
        if [[ $parent == "$root_name" ]]; then
            i18n::printf -v _line "${_uline}键入需要的工具回车运行:${_off}\n" "${_uline}Type a key and press Enter to run:${_off}\n"
        else
            i18n::printf -v _line "${_uline}键入选项或留空返回:${_off}\n" "${_uline}Type a choice or leave empty to go back:${_off}\n"
        fi
        buf+="$_line"

        printf '%s' "${_refresh}${buf}"

        local choice=''
        app::read_input_with_hint "$parent" children_arr choice hist buf || {
            printf '\n'
            return
        }
        [[ -z $choice ]] && { [[ $parent == "$root_name" ]] && continue || return; }

        # 拆分用户输入：第一项为 key，剩余为业务参数
        local key='' parts=()
        out::split_args "$choice" parts
        key="${parts[0]:-}"
        set -- "${parts[@]:1}"

        # 匹配用户输入；未匹配 → 继续循环（重新渲染）
        local matched=0
        for child in "${children_arr[@]}"; do
            if [[ $child == '('*')' ]]; then
                local inner
                out::strip_parens "$child" inner
                [[ ${inner%% *} == "$key" ]] && {
                    matched=1
                    app::loop_menu "$child" "$root_name"
                    break
                }
            elif [[ $child == "$key" ]]; then
                local action_func="menu::${parent}::${key}"
                declare -F "$action_func" > /dev/null 2>&1 || action_func="menu::_::${key}"
                declare -F "$action_func" > /dev/null 2>&1 || break
                matched=1
                MENU_QUICK=0
                "$action_func" "$@"
                local _rc=$?
                ((MENU_QUICK)) || {
                    local _p="$_ok>"
                    ((_rc)) && _p="${_cat1}×"
                    i18n::printf "${_p}${_off} 工具运行结束，退出码: %s\n" "${_p}${_off} Tool finished, exit code: %s\n" "$_rc"
                    i18n::printf "  按回车键继续..." "  Press Enter to continue..."
                    read -rs _ < /dev/tty
                }
                break
            fi
        done

        # 仅记录真正派发过的输入：误击不入历史。连续重复只留一条
        ((matched)) && { ((${#hist[@]})) && [[ ${hist[-1]} == "$choice" ]] || hist+=("$choice"); }
    done
}

# 裸 Escape 与 Escape 序列首字节的区分窗口。太小会把慢速终端（Android/ssh）的
# 方向键误判为裸 Escape，残余字节继而作为字面量落入 buffer。vim/fzf 量级为 25–50ms。
declare -g ESC_DELAY=0.03

declare -g _refresh=$'\e[H\e[J' _b=$'\e[1m' _faint=$'\e[2m' _italic=$'\e[3m' _memu_hl=$'\e[1m' _uline=$'\e[4m' _off=$'\e[0m' _ok=$'\e[38;2;137;230;137m' _hl=$'\e[38;2;255;174;193m' _cat1=$'\e[38;2;230;137;137m' _cat2=$'\e[38;2;137;184;230m' _cat3=$'\e[38;2;230;137;184m' _cat4=$'\e[38;2;230;211;137m' _green=$'\e[38;2;112;235;153m' _purple=$'\e[38;2;193;177;241m' _vimcolor=$'\e[38;2;78;199;96m'

return 0 2> /dev/null

app::set_lang
app::set_paths
app::set_resource_service github.com

app::loop_menu '(root
      m  u           ; Mirrors & updates.
      (f             ; Fonts
        f ff b 1 2)
      (t             ; Color themes
        t tt b 1 2)
      (k             ; Keymaps
        k kk b 1)
      (fi            ; Fish shell & fisher plugins
        i  ii  1  2)
      (vi            ; Neovim + Lazyvim
        i  ii  1  2  3  4  5  6)
      (sh            ; Shell extras (eza/zoxide/atuin)
        1  2  3  4  5  6)
      s  l  i        ; Switch server / Lang / Install
      cl  is  gh     ; Clear cache / Issues / Repo
      q              ; Exit
)'
