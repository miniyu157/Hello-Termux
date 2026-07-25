#!/usr/bin/env bash
# 从 keymaps/ 目录生成 keymap_list.txt
# 格式: 每行一个完整文件名（含 .properties 后缀）

cd "${0%/*}/.." || exit 1

for f in keymaps/*.properties; do
    [[ -f "$f" ]] || continue
    filename="${f##*/}"
    printf '%s\n' "$filename"
done
