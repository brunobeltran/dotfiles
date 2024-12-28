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
FZF_DIR="${BUILD_DIR}/fzf"
if [[ ! -d "${FZF_DIR}" ]]; then
	git clone --depth 1 https://github.com/junegunn/fzf.git "${FZF_DIR}"
fi
# FZF comes with a very noisy install script that dumps stuff all over the
# place, but one thing we can always be sure of is that once it is run, it will
# download or build an FZF binary to this path.
if [[ ! -f "${FZF_DIR}/bin/fzf" ]]; then
	"${FZF_DIR}/install" --no-update-rc --key-bindings --completion --xdg
fi

# Install a nice shell prompt.
if ! which starship >/dev/null 2>&1; then
	curl -sS https://starship.rs/install.sh | sudo sh
fi

# Build NeoVim from source.
NEOVIM_SOURCE_DIR="${BUILD_DIR}/neovim-src"
NEOVIM_BUILD_DIR="${BUILD_DIR}/neovim-build"
if [[ ! -d "${NEOVIM_SOURCE_DIR}" ]]; then
	git clone https://github.com/neovim/neovim.git "${NEOVIM_SOURCE_DIR}"
fi
if [[ ! -f "${NEOVIM_BUILD_DIR}/bin/nvim" ]]; then
	{
		cd "${NEOVIM_SOURCE_DIR}"
		mkdir -p "${NEOVIM_BUILD_DIR}"
		make CMAKE_BUILD_TYPE=Release CMAKE_INSTALL_PREFIX="${NEOVIM_BUILD_DIR}"
		make CMAKE_BUILD_TYPE=Release CMAKE_INSTALL_PREFIX="${NEOVIM_BUILD_DIR}" install
	}
fi

# Render the current build path into a file for use in `.set_path`.
echo "${BUILD_DIR}" >"${SCRIPT_DIR}/dotfiles/dot-dotfiles-build-path"

stow --dir "${SCRIPT_DIR}" --target="${HOME}" --adopt --dotfiles dotfiles
