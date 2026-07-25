#!/usr/bin/env bash

curl -s https://api.github.com/repos/mbadolato/iTerm2-Color-Schemes/contents/termux | grep '"name":' | cut -d'"' -f4
