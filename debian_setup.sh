#!/bin/bash

set -euxo pipefail
shopt -s nullglob

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)

# Usage: _warn <app> <retry command>
# None of the apps here are essential, so a failure warns and carries on.
_warn() {
    echo "WARNING: $1 did not install. Retry by hand: $2" >&2
}

##
# Applications that need root: each vendor's own Debian/Ubuntu install, which
# also registers the vendor's apt repo so `apt upgrade` keeps them current.
# The 1Password and Chrome `.deb`s configure their apt repo and signing key
# themselves, so we install those rather than re-doing that setup by hand.
# Flathub/Snap builds are skipped: they are not vendor-maintained (1Password
# says so explicitly, and its sandboxed builds lose browser integration).

if [[ ! -f /usr/bin/google-chrome-stable ]]; then
    (
        cd "$(mktemp -d)"
        wget -q https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
        sudo apt install -y ./google-chrome-stable_current_amd64.deb
    ) || _warn "Google Chrome" "sudo apt install ./google-chrome-stable_current_amd64.deb (from google.com/chrome)"
fi

if [[ ! -f /usr/bin/1password ]]; then
    (
        cd "$(mktemp -d)"
        wget -q https://downloads.1password.com/linux/debian/amd64/stable/1password-latest.deb
        sudo apt install -y ./1password-latest.deb
    ) || _warn "1Password" "see https://support.1password.com/install-linux/"
fi

# Signal only documents the apt-repo route; these are its commands verbatim
# (run in a scratch dir, since they write files to the current directory).
if [[ ! -f /usr/bin/signal-desktop ]]; then
    (
        cd "$(mktemp -d)"
        curl https://updates.signal.org/desktop/apt/keys.asc | gpg --dearmor >signal-desktop-keyring.gpg
        cat signal-desktop-keyring.gpg | sudo tee /usr/share/keyrings/signal-desktop-keyring.gpg >/dev/null
        curl -o signal-desktop.sources https://updates.signal.org/static/desktop/apt/signal-desktop.sources
        cat signal-desktop.sources | sudo tee /etc/apt/sources.list.d/signal-desktop.sources >/dev/null
        sudo apt update && sudo apt install -y signal-desktop
    ) || _warn "Signal" "see https://signal.org/download/linux/"
fi

##
# Delta, via its documented installer (user mode, into `~/.local/delta.app`).
# The installer does its own desktop integration and rewrites it on every
# install. `--non-interactive` skips both its confirmation prompt and its offer
# to append a PATH line to `~/.bashrc`, which is tracked in this repo.
if [[ ! -f "${HOME}/.local/delta.app/bin/delta" ]]; then
    (
        cd "$(mktemp -d)"
        curl -fsSL https://delta.dev/install.sh -o delta-install.sh
        sh delta-install.sh --non-interactive
    ) || _warn "Delta" "curl -fsSL https://delta.dev/install.sh -o delta-install.sh && sh delta-install.sh"
fi

##
# User-mode app bundles managed with Stow.
#
# Reuse the Stow that `install.sh` vendors rather than pinning a second copy of
# its version here.
stow_candidates=("${SCRIPT_DIR}"/build/stow-*/bin/stow)
if ((${#stow_candidates[@]} == 0)); then
    echo "No vendored stow under ${SCRIPT_DIR}/build; run install.sh first." >&2
    exit 1
fi
STOW="${stow_candidates[-1]}"

# Self-contained app bundles (each `<name>.app` holding its own bin/, lib/,
# share/) live here and are stowed into `~/.local`, so that their `bin/`,
# `share/applications/` and `share/icons/` show up in the standard XDG
# locations as symlinks into the bundle. Nothing is copied or edited, so the
# desktop integration always matches whatever version is installed, and
# `--restow` on every run picks up files added or dropped by an update.
APP_STOW_DIR="${HOME}/.local/stow"
mkdir -p "${APP_STOW_DIR}"

# kitty, via upstream's binary installer. Its docs recommend exactly this
# layout for stow users (install with `dest=~/.local/stow`, then
# `stow kitty.app`). `launch=n` stops it from opening a kitty window
# mid-script. To update kitty, delete the bundle and rerun this script.
if [[ ! -f "${APP_STOW_DIR}/kitty.app/bin/kitty" ]]; then
    curl -L https://sw.kovidgoyal.net/kitty/installer.sh |
        sh /dev/stdin dest="${APP_STOW_DIR}" launch=n
fi
# Expose only what integration needs (`bin/kitty`, `bin/kitten`, both
# `.desktop` files, icons, man pages):
# - `lib/` is kitty's private copies of libcrypto, libpython, etc. Its binaries
#   find them via their real path, and linking them into `~/.local/lib` would
#   collide with the next bundle that ships its own libcrypto.
# - `bin/slangc` is an internal shader compiler, not something for `PATH`.
# `kitty-open.desktop` *is* included: on Mint it makes kitty the handler for
# `ssh://` and `kitty://` links and for shell scripts (`.sh` and friends; kitty
# asks before running them), and adds "Open with kitty" for folders. The
# `text/*` and `image/*` wildcards it also declares are ignored by GLib, so
# text and image files keep their current apps.
# `--no-folding` makes stow create real directories and link only files.
# Without it, stow may turn e.g. `~/.local/share/doc` into a symlink into the
# bundle, so other tools writing there would write inside kitty.app, which the
# installer `rm -rf`s on reinstall.
"${STOW}" --dir="${APP_STOW_DIR}" --target="${HOME}/.local" --restow --no-folding \
    --ignore='^lib' --ignore='^bin/slangc' \
    kitty.app

##
# Rebuild the indexes desktops read, from whatever is installed right now
# (both regenerate from scratch, so they cannot drift):
# - GLib (Nemo, Cinnamon, Firefox) only learns which file types an app handles
#   from `mimeinfo.cache`, so without this `kitty-open.desktop` does nothing.
# - Once `~/.local/share/icons/hicolor` has an `icon-theme.cache` (Delta's
#   installer creates one), GTK ignores icons that are not in it.
mkdir -p "${HOME}/.local/share/applications" "${HOME}/.local/share/icons/hicolor"
update-desktop-database "${HOME}/.local/share/applications"
gtk-update-icon-cache -f -t "${HOME}/.local/share/icons/hicolor"

# kitty as the default terminal for xdg-terminal-exec (used by some desktops
# and apps to open "a terminal"). Cinnamon itself uses the gsetting below.
if [[ "$(cat "${HOME}/.config/xdg-terminals.list" 2>/dev/null)" != kitty.desktop ]]; then
    mkdir -p "${HOME}/.config"
    echo 'kitty.desktop' >"${HOME}/.config/xdg-terminals.list"
fi

##
# Cinnamon settings. These keys are Cinnamon's, not freedesktop standards, so
# they may need updating across Mint releases. Only write keys whose value
# differs, so re-runs are no-ops.
if [[ "${XDG_CURRENT_DESKTOP:-}" == *Cinnamon* ]]; then
    # Usage: _gsetting <schema> <key> <value as GVariant text>
    _gsetting() {
        if [[ "$(gsettings get "$1" "$2")" != "$3" ]]; then
            gsettings set "$1" "$2" "$3"
        fi
    }

    # Default terminal (Nemo's "Open in Terminal", Ctrl-Alt-T, etc.).
    _gsetting org.cinnamon.desktop.default-applications.terminal exec "'kitty'"

    # Non-"natural" touchpad scrolling.
    _gsetting org.cinnamon.desktop.peripherals.touchpad natural-scroll false

    # Caps Lock -> Control, keeping any other XKB options already set.
    xkb_options="$(gsettings get org.cinnamon.desktop.input-sources xkb-options)"
    if [[ ${xkb_options} != *"'ctrl:nocaps'"* ]]; then
        if [[ ${xkb_options} == *"[]" ]]; then
            xkb_options="['ctrl:nocaps']"
        else
            xkb_options="${xkb_options%]}, 'ctrl:nocaps']"
        fi
        gsettings set org.cinnamon.desktop.input-sources xkb-options "${xkb_options}"
    fi

    # (Ctrl-Space needs no freeing here: Mint's input-source switching, in both
    # Cinnamon and IBus, is Super-Space.)

    # Panel pins: file manager, Firefox, kitty, and nothing else. They live in
    # the grouped-window-list applet's per-instance JSON file; the instance id
    # varies per machine, so read it from the enabled-applets list. Cinnamon
    # does not watch that file, and the applet only reads `pinned-apps` when it
    # starts (its change callback is null), so after writing the file, restart
    # just that applet over D-Bus. If Cinnamon isn't running, the file alone
    # takes effect at next login.
    pinned_apps='["nemo.desktop", "firefox.desktop", "kitty.desktop"]'
    gwl_uuid=grouped-window-list@cinnamon.org
    gwl_instance="$(gsettings get org.cinnamon enabled-applets |
        grep -o "${gwl_uuid}:[0-9]*" | head -n1 | cut -d: -f2)" || true
    gwl_file="${HOME}/.config/cinnamon/spices/${gwl_uuid}/${gwl_instance}.json"
    if [[ -n ${gwl_instance} && -f ${gwl_file} ]]; then
        if /usr/bin/python3 -I - "${gwl_file}" "${pinned_apps}" <<'EOF'
import json, sys
path, wanted = sys.argv[1], json.loads(sys.argv[2])
with open(path) as f:
    settings = json.load(f)
if settings["pinned-apps"]["value"] == wanted:
    sys.exit(1)  # already set: nothing to tell Cinnamon
settings["pinned-apps"]["value"] = wanted
with open(path, "w") as f:
    json.dump(settings, f, indent=4)
EOF
        then
            gdbus call --session --dest org.Cinnamon --object-path /org/Cinnamon \
                --method org.Cinnamon.ReloadXlet "${gwl_uuid}" APPLET >/dev/null ||
                echo "WARNING: pins saved, but the panel did not reload; they apply at next login." >&2
        fi
    else
        echo "WARNING: no ${gwl_uuid} panel applet found; pin apps by hand." >&2
    fi
fi
