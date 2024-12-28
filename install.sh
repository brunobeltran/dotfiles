#!/bin/bash

set -euxo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
BUILD_DIR="${SCRIPT_DIR}/build"

if [[ $OSTYPE == 'darwin'* ]]; then
	if ! which brew >/dev/null 2>&1; then
		/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
	fi
	brew install bash stow kitty wget
	miniconda_download_link=https://repo.anaconda.com/miniconda/Miniconda3-latest-MacOSX-x86_64.sh

	# Setup deps for neovim source build.
	brew install ninja cmake gettext curl
elif [[ -f "/etc/debian_version" ]]; then
	sudo apt update && sudo apt upgrade -y
	sudo apt install git rsync tmux htop bash wget stow
	if [[ $(uname -m) == "aarch64" ]]; then
		miniconda_download_link=https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-aarch64.sh
	else
		miniconda_download_link=https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh
	fi

	# Setup deps for neovim source build.
	sudo apt install ninja-build gettext cmake unzip curl build-essential
fi

# Setup miniconda.
if ! which conda >/dev/null 2>&1; then
	wget -O miniconda.sh "${BUILD_DIR}/${miniconda_download_link}"
	bash "${BUILD_DIR}/miniconda.sh"
	rm "${BUILD_DIR}/miniconda.sh"
fi

# Many distros come with ancient fzf, install from source.
if [[ ! -d "${BUILD_DIR}/fzf" ]]; then
	git clone --depth 1 https://github.com/junegunn/fzf.git "${BUILD_DIR}/fzf"
fi
if ! which fzf >/dev/null 2>&1; then
	"${BUILD_DIR}/fzf/install"
fi

# Install a nice shell prompt.
if ! which starship >/dev/null 2>&1; then
	curl -sS https://starship.rs/install.sh | sudo sh
fi

# Build NeoVim from source.
if [[ ! -d "${BUILD_DIR}/neovim" ]]; then
	git clone https://github.com/neovim/neovim.git "${BUILD_DIR}/neovim"
fi
if ! which nvim >/dev/null 2>&1; then
	cd ./neovim
	sudo mkdir -p /opt/nvim
	sudo chown "${USER}" /opt/nvim
	make CMAKE_BUILD_TYPE=Release CMAKE_INSTALL_PREFIX=/opt/nvim
	make CMAKE_BUILD_TYPE=Release CMAKE_INSTALL_PREFIX=/opt/nvim install
	cd ..
fi

stow --dir "${SCRIPT_DIR}" --target="${HOME}" --adopt --dotfiles dotfiles
