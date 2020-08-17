#!/bin/bash

newfiles=`git ls-tree --full-tree -r HEAD | cut -d\  -f3 | cut -d. -f2-`

for file in $newfiles; do
    if [[ -a "${HOME}/.${file}" ]]; then
        cp -r "${HOME}/.${file}" "${file}"
    fi
done
