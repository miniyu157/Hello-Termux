#!/usr/bin/env bash

SCRIPT_DIR="${BASH_SOURCE[0]%/*}"
[[ $SCRIPT_DIR == "${BASH_SOURCE[0]}" ]] && SCRIPT_DIR="."
source "$SCRIPT_DIR/../hi.sh"

# render — 渲染测试
menu::root::render() { pure::render_test '(root _b _b _b _b _b _b _b _b _b _b (_g) (_g _b _b _b) _b _b _b _b _b _b _b)' 1200; }
menu::root::render::title() { i18n::printf -v "$1" "󰡳 渲染测试${_faint}（渲染耗时）${_off}" "󱦁 Render Test${_faint} (render cost)${_off}"; }

# args — 参数透传测试
menu::root::args() {
    i18n::printf "── 参数透传测试 ──\n" "── Arg Forward Test ──\n"
    i18n::printf "  参数数量: %d\n" "  Arg count: %d\n" "$#"
    local _i=1
    for _a in "$@"; do
        i18n::printf "  [%d] %s\n" "  [%d] %s\n" "$_i" "$_a"
        ((_i++))
    done
}
menu::root::args::title() { i18n::printf -v "$1" "󰘥 参数透传测试${_faint}（\$@ 回显）${_off}" "󰘥 Arg Forward Test${_faint} (\$@ echo)${_off}"; }

# -- 渲染测试桩 --

menu::_g() { i18n::printf -v "$1" "${_purple}󰻳 测试分组${_off}" "${_purple}󰻳 Test Group${_off}"; }
menu::root::_b::title() { i18n::printf -v "$1" "${_cat1}󱦁 测试叶${_faint}（ANSI）${_off}" "${_cat1}󱦁 Test Leaf${_faint} (ANSI)${_off}"; }
menu::_g::_b::title() { i18n::printf -v "$1" "${_green}󰐱 测试子叶${_faint}（ANSI）${_off}" "${_green}󰐱 Test Sub${_faint} (ANSI)${_off}"; }
menu::root::_b() { :; }
menu::_g::_b() { :; }

# 测量菜单渲染耗时，完全复刻 app::loop_menu 一帧的渲染路径
# $1  S-表达式（必需）
# $2  迭代次数（必需）
pure::render_test() {
    local expr="$1" iterations="$2"
    local flat parent children_flat child inner gname title_func i t0 t1 t2 timings=''
    local header_text='' first_line rest_lines _in='' _gt='' _lt='' buf='' _line=''

    flat=$(pure::strip_parens "$(printf '%s' "$expr" | sed 's/;.*//' | tr '\n' ' ' | sed 's/[[:space:]]\{1,\}/ /g; s/^ //; s/ $//')")
    parent="${flat%% *}"
    children_flat="${flat#* }"
    [[ $children_flat == "$parent" ]] && children_flat=''

    for ((i = 0; i < iterations; i++)); do
        # -- 解析 --
        t0=$EPOCHREALTIME
        local -a children_arr=()
        pure::parse_children "$children_flat" children_arr
        t1=$EPOCHREALTIME

        # -- 渲染（复刻 app::loop_menu 一帧完整输出：buf 拼装 + 末尾一次性打印，stdout → /dev/null） --
        {
            buf=''
            "menu::${parent}" header_text 2> /dev/null || true
            [[ -z $header_text ]] && first_line="$parent" || first_line="${header_text%%$'\n'*}"
            [[ $header_text == *$'\n'* ]] && rest_lines="${header_text#*$'\n'}"
            buf+="${_b}  ✦ ${first_line} ✦ ${_off}"$'\n'
            [[ -n ${rest_lines:-} ]] && buf+='    '${rest_lines//$'\n'/$'\n'    }$'\n'
            buf+="─────────────────────────────────────────────────"$'\n'

            for child in "${children_arr[@]}"; do
                if [[ $child == '('*')' ]]; then
                    pure::strip_parens "$child" _in
                    gname="${_in%% *}"
                    _gt=''
                    "menu::${gname}" _gt 2> /dev/null
                    _gt="${_gt%%$'\n'*}"
                    printf -v _line "${_faint}${_italic}%4s${_off} %s\n" "$gname" "$_gt"
                else
                    title_func="menu::${parent}::${child}::title"
                    _lt=''
                    declare -F "menu::${parent}::${child}" >/dev/null 2>&1 ||
                        title_func="menu::_::${child}::title"
                    "$title_func" _lt 2> /dev/null
                    printf -v _line "${_faint}${_italic}%4s${_off} %s\n" "$child" "$_lt"
                fi
                buf+="$_line"
            done

            buf+="${_faint}─────────────────────────────────────────────────${_off}"$'\n'
            i18n::printf -v _line "${_uline}键入需要的工具回车运行:${_off}\n" "${_uline}Type a key and press Enter to run:${_off}\n"
            buf+="$_line"

            printf '%s' "${_refresh}${buf}"
        } > /dev/null
        t2=$EPOCHREALTIME
        timings+="$t0 $t1 $t2"$'\n'
    done

    awk -v n="$iterations" '
    BEGIN { min_p = 999; min_r = 999 }
    {
        p = $2 - $1;  r = $3 - $2
        sum_p += p;   sum_r += r
        if (p < min_p) min_p = p
        if (p > max_p) max_p = p
        if (r < min_r) min_r = r
        if (r > max_r) max_r = r
    }
    END {
        printf "Iterations: %d\n", n
        printf "Parse:   %8.3f ms avg  (%.3f min / %.3f max)\n", (sum_p/n)*1000, min_p*1000, max_p*1000
        printf "Render:  %8.3f ms avg  (%.3f min / %.3f max)\n", (sum_r/n)*1000, min_r*1000, max_r*1000
        printf "Total:   %8.3f ms avg  (%.3f min / %.3f max)\n", ((sum_p+sum_r)/n)*1000, (min_p+min_r)*1000, (max_p+max_r)*1000
    }' <<< "$timings"
}

# -- 启动测试菜单 --
if [[ ${BASH_SOURCE[0]} == "$0" ]]; then
    app::set_lang
    app::set_paths
    app::set_resource_service github.com

    app::loop_menu '(root render args q)'
fi
