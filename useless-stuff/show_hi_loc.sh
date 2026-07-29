#!/usr/bin/env bash
SCRIPT_DIR="${BASH_SOURCE[0]%/*}"
[[ $SCRIPT_DIR == "${BASH_SOURCE[0]}" ]] && SCRIPT_DIR="."
rg -v '^\s*(#|$)' "$SCRIPT_DIR/../hi.sh" | nl -ba
