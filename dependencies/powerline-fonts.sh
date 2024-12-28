#!/bin/bash

font_dir="${HOME}/.local/share/fonts/"
font_conf="${HOME}/.config/fontconfig/conf.d/"
mkdir -p "${font_dir}"
mkdir -p "${font_conf}"

if ! wget \
    -P "${font_dir}" \
    https://github.com/powerline/powerline/raw/develop/font/PowerlineSymbols.otf &&
    wget \
        -P "${font_conf}" \
        https://github.com/powerline/powerline/raw/develop/font/10-powerline-symbols.conf; then

    echo "Unable to download powerline fonts, is there a network connection?"
    exit 3
fi

fc-cache -vf "${font_dir}"

printf "Powerline fonts installed, you may need to restart X.\n"
