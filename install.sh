#!/bin/bash

set -euxo pipefail
shopt -s nullglob

##
# Global constants.
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
BUILD_DIR="${SCRIPT_DIR}/build"
mkdir -p "${BUILD_DIR}"

##
# Determine all configuration that is OS- or architecture-dependent.
if [[ $OSTYPE == 'darwin'* ]]; then
	if ! which brew >/dev/null 2>&1; then
		/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
	fi
	brew install bash kitty wget jq gh git tmux htop rsync perl
	fonts_install_dir="${HOME}/Library/Fonts"

	# Setup deps for neovim source build.
	brew install ninja cmake gettext curl
elif [[ -f "/etc/debian_version" ]]; then
	sudo apt update && sudo apt upgrade -y
	sudo apt install git rsync tmux htop bash wget perl
	fonts_install_dir="${HOME}/.local/share/fonts"

	# Setup deps for neovim source build.
	sudo apt install ninja-build gettext cmake unzip curl build-essential
fi

##
# Python via `uv`
if ! which uv >/dev/null 2>&1; then
	curl -LsSf https://astral.sh/uv/install.sh | sh
fi

##
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

##
# Install a nice shell prompt.
if ! which starship >/dev/null 2>&1; then
	curl -sS https://starship.rs/install.sh | sudo sh
fi

##
# Vendor a pinned GNU Stow.
#
# Distro-packaged stow versions vary wildly, and any version < 2.4.0 has broken
# `--dotfiles` handling that bites depending on which machine you run on:
#
#   1. On a directory-level dotfile (e.g. `dot-config`) whose target already
#      exists, it crashes with
#      `stow: ERROR: stow_contents() called with non-directory path: .../.config`
#      because it applies the `dot-` -> `.` translation to the package-side path.
#   2. With `--adopt` over a pre-existing regular file, it dumps the adopted
#      file under the translated name (e.g. a stray, untracked `dotfiles/.bashrc`)
#      instead of overwriting the tracked `dot-bashrc`, which then trips the
#      "installation not complete" check below.
#
# 2.4.1 fixes both while letting us keep the readable `dot-` naming convention.
# Stow is pure Perl, so "building" is just substituting three `.in` templates --
# no autotools or Module::Build required.
STOW_VERSION=2.4.1
STOW_DIR="${BUILD_DIR}/stow-${STOW_VERSION}"
STOW="${STOW_DIR}/bin/stow"
if [[ ! -x "${STOW}" ]]; then
	STOW_TARBALL="${BUILD_DIR}/stow-${STOW_VERSION}.tar.gz"
	wget -q "https://github.com/aspiers/stow/archive/refs/tags/v${STOW_VERSION}.tar.gz" -O "${STOW_TARBALL}"
	rm -rf "${STOW_DIR}"
	mkdir -p "${STOW_DIR}"
	tar xzf "${STOW_TARBALL}" -C "${STOW_DIR}" --strip-components=1
	stow_perl="$(command -v perl)"
	stow_render() {
		sed -e "s|@PERL@|${stow_perl}|g" \
			-e "s|@VERSION@|${STOW_VERSION}|g" \
			-e "s|@USE_LIB_PMDIR@|use lib \"${STOW_DIR}/lib\";|g" \
			"$1" >"$2"
	}
	stow_render "${STOW_DIR}/bin/stow.in" "${STOW_DIR}/bin/stow"
	stow_render "${STOW_DIR}/lib/Stow.pm.in" "${STOW_DIR}/lib/Stow.pm"
	stow_render "${STOW_DIR}/lib/Stow/Util.pm.in" "${STOW_DIR}/lib/Stow/Util.pm"
	chmod +x "${STOW_DIR}/bin/stow"
fi

##
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

##
# Render the current build path into a file for use in `.set_path`.
echo "${BUILD_DIR}" >"${SCRIPT_DIR}/dotfiles/dot-dotfiles-build-path"

##
# Manually "adopt" all folder-level config.
#
# Otherwise we get an error like
# ```
# stow: ERROR: stow_contents() called with non-directory path: developer/bruno-dotfiles/dotfiles/.vim
# ```
#
# https://github.com/aspiers/stow/issues/19
for folder in dotfiles/*; do
	[[ -d "${folder}" ]] || continue
	real_folder_path="$(realpath --relative-to="${HOME}" "${folder}")"
	eventual_link_location="${HOME}/.${folder#dotfiles/dot-}"
	if [[ -L "${eventual_link_location}" ]]; then
		rm "${eventual_link_location}"
		continue
	fi
	if [[ -d "${eventual_link_location}" ]]; then
		cp -r "${eventual_link_location}" "${eventual_link_location}.bak"
		rm -rf "${folder}"
		cp -r "${eventual_link_location}.bak" "${folder}"
		rm -rf "${eventual_link_location}"
		ln -s "${real_folder_path}" "${eventual_link_location}"
	fi
done

##
# Actually install all "dotfiles".
"${STOW}" --dir "${SCRIPT_DIR}" --target="${HOME}" --adopt --dotfiles dotfiles

##
# Validate install was clean
#
# If our dotfiles adoption led to any diff, we print an error message.
{
	cd "${SCRIPT_DIR}"
	# First add to the tree to prevent new files from not showing up as a diff.
	git add .
	# Now update the index, to prevent "touch"ed files from showing as a diff
	# even if there is no "real" diff.
	git update-index --refresh
	# With the above setup, this command will succeed only if there are no
	# changes to our non-.gitignore'd files.
	if ! git diff-index --quiet HEAD --; then
		echo "WARNING: -- Dotfiles installation not complete! --"
		echo "WARNING: "
		echo "WARNING: Some of your pre-existing files seem to have conflicted"
		echo "WARNING: with this repo. Please check if this was intended. If not,"
		echo "WARNING: a simple $(git checkout) should complete the install!"
	fi
}

### Post-install

##
# Download TPM at install time to avoid having to maintain a Git submodule for
# it.
export TMUX_PLUGIN_MANAGER_PATH="${HOME}/.tmux/plugins/"
if [ ! -d "${TMUX_PLUGIN_MANAGER_PATH}/tpm" ]; then
	git clone https://github.com/tmux-plugins/tpm "${TMUX_PLUGIN_MANAGER_PATH}/tpm"
fi
"${TMUX_PLUGIN_MANAGER_PATH}/tpm/bin/install_plugins"

##
# Build and install our fonts directory.
FONTS_DIR="${BUILD_DIR}/fonts"
mkdir -p "${FONTS_DIR}"
mkdir -p "${fonts_install_dir}"
if [[ ! -f "${FONTS_DIR}/UbuntuMonoNerdFont-Regular.ttf" ]]; then
	wget https://github.com/ryanoasis/nerd-fonts/releases/download/v3.3.0/UbuntuMono.zip -O "${BUILD_DIR}/UbuntuMono.zip"
	unzip "${BUILD_DIR}/UbuntuMono.zip" -d "${FONTS_DIR}"
fi
"${STOW}" --target="${fonts_install_dir}" --dir "${BUILD_DIR}" fonts
# Validate fonts installation worked...it is very flaky/annoying on OS X.
if ! fc-list | grep UbuntuMono >/dev/null 2>&1; then
	echo "WARNING: Fonts placed into correct directory but fc-list not seeing them, if you are on a Mac you need to manually click on each of the corresponding font files!"
fi
