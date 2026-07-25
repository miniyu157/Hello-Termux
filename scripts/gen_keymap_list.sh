#!/usr/bin/env bash
# 从 keymaps/ 目录生成 keymap_list.txt
# 格式: TSV (Display Name\tfilename.properties)
# 每个 .properties 文件首行可用 # @name 指定显示名，否则回退到文件名

cd "${0%/*}/.." || exit 1

for f in keymaps/*.properties; do
    [[ -f "$f" ]] || continue
    filename="${f##*/}"
    display=$(head -1 "$f" | sed -n 's/^# *@name  *//p')
    [[ -n $display ]] || display="${filename%.properties}"
    printf '%s\t%s\n' "$display" "$filename"
done
