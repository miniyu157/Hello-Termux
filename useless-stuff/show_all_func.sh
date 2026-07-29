#!/usr/bin/env bash
SCRIPT_DIR="${BASH_SOURCE[0]%/*}"
[[ $SCRIPT_DIR == "${BASH_SOURCE[0]}" ]] && SCRIPT_DIR="."
(
    source "$SCRIPT_DIR/../hi.sh" 2> /dev/null
    declare -F | awk '{printf "%4d  %s\n", NR, $3}'
)
