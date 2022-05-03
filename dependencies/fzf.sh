#!/bin/bash

# post-install instructions in apt-cache
git clone --depth 1 https://github.com/junegunn/fzf.git "${HOME}/.fzf"
"${HOME}/.fzf/install"
