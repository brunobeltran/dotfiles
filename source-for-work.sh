#!/usr/bin/env bash
#
# Stuff I only need at work.

_interactive_ssh_key_for_github() {
    local want_password
    local key_comment_name
    local key_algo="${1:-ed25519}"
    local key_file_name="${2:-id_${key_algo}}"

    read -r -p "Need to make an SSH key, do you want a password? (Y/n) " want_password
    read -r -p "Correct key name? (defaults to $(hostname)) " key_comment_name
    key_comment_name="${key_comment_name:-$(hostname)}"

    local keygen_args=(-t "${key_algo}" -C "${key_comment_name}" -f "${HOME}/.ssh/${key_file_name}")
    # Without -N, ssh-keygen prompts for the passphrase itself (hidden input,
    # with confirmation). An explicit empty -N skips the prompt entirely.
    if [[ "${want_password}" =~ ^[Nn] ]]; then
        keygen_args+=(-N "")
    fi

    mkdir -p "${HOME}/.ssh" && chmod 700 "${HOME}/.ssh"
    ssh-keygen "${keygen_args[@]}"

    cat "${HOME}/.ssh/${key_file_name}.pub" | pbcopy
    read -r -p "Public key copied to clipboard. Hit [enter] to open https://github.com/settings/ssh/new"
    open https://github.com/settings/ssh/new
    read -r -p "Press [enter] when done to continue. "
}

# Claude Code
curl -fsSL https://claude.ai/install.sh | bash

# Codex CLI
curl -fsSL https://chatgpt.com/codex/install.sh | sh

if [[ ! -f "${HOME}/.ssh/id_ed25519.pub" ]]; then
    _interactive_ssh_key_for_github ed25519
fi

cd
hgcreate git@github.com:forest-neurotech/forest.git
hgcreate git@github.com:merge-io/mergelabs.git
hgcreate git@github.com:arbor-neuroscience/arbor.git
cd ~/mergelabs/main
ln -s ../../forest/main/butterfly butterfly
