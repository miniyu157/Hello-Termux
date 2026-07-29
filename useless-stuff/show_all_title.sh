#!/usr/bin/env bash
SCRIPT_DIR="${BASH_SOURCE[0]%/*}"
[[ $SCRIPT_DIR == "${BASH_SOURCE[0]}" ]] && SCRIPT_DIR="."
(
    source "$SCRIPT_DIR/../hi.sh" 2> /dev/null

    names=()
    max=0
    while IFS=' ' read -r _ _ name; do
        [[ $name == *::title || $name =~ ^menu::[^:]+$ ]] || continue
        names+=("$name")
        ((${#name} > max)) && max=${#name}
    done < <(declare -F)

    n=0
    for name in "${names[@]}"; do
        title=''
        "$name" title 2> /dev/null || true
        printf "%4d  %-*s  %s\n" "$((++n))" "$max" "$name" "$title"
    done
)
