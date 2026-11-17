#!/usr/bin/env bash
#
# Copies the plain files of an extracted machine handoff (agent rules, Codex
# state, ssh, credentials, shell and editor history, loose files) back into
# this home directory. Changes nothing unless given --apply. See usage() for
# what goes where, and examples.
set -uo pipefail
shopt -s nullglob dotglob

DUMP="${HOME}/Downloads"
OLD_HOME=/Users/bruno
MODE=dry-run

VIM_TEMP_DIRS=developer/dotfiles/dotfiles/dot-vim/temp_dirs

usage() {
    cat <<'EOF'
restore-home-files.sh [--apply] [--dump DIR] [--old-home PATH]

Copies files from DIR, where the handoff zip was extracted (default:
~/Downloads), to where they lived under the old home (default: /Users/bruno).
With no flag it prints what --apply would do.

Nothing already on this machine is overwritten, with three exceptions that
keep the previous file beside the new one as <name>.pre-handoff:
~/.claude/settings.json, ~/.viminfo and nvim's main.shada.

  1. ~/.claude/CLAUDE.md and settings.json
  2. ~/.codex, with the old home rewritten in config.toml
  3. the shared ssh key, and the known_hosts entries this machine lacks
  4. gcloud, gh and op configuration under ~/.config
  5. shell history (the old machine's first), vim and nvim state and undo
     history, IPython, Jupyter, the ansible log
  6. Desktop and Downloads
  7. LAPTOP_HANDOFF to ~/LAPTOP_HANDOFF, and the old machine's agent
     scratchpads to ~/LAPTOP_HANDOFF/scratchpads

The old machine's personal ssh key (id_ed25519) is deliberately not installed.
Run this before restore-claude-state.py: settings.json carries the retention
setting that keeps old transcripts from being cleaned up.

Examples:
  ./restore-home-files.sh
  ./restore-home-files.sh --apply
  ./restore-home-files.sh --dump /mnt/usb/extracted --apply
EOF
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
        --apply) MODE=apply ;;
        --dump | --old-home)
            if [[ $# -lt 2 ]]; then
                echo "$1 needs a value" >&2
                exit 1
            fi
            if [[ "$1" == --dump ]]; then
                DUMP="$(cd "$2" && pwd)" || exit 1
            else
                OLD_HOME="${2%/}"
            fi
            shift
            ;;
        -h | --help)
            usage
            exit 0
            ;;
        *)
            echo "unknown argument: $1" >&2
            usage >&2
            exit 1
            ;;
        esac
        shift
    done
}

applying() { [[ "${MODE}" == apply ]]; }

heading() {
    echo
    echo "== $*"
}

note() { echo "  $*"; }

run() {
    if applying; then
        echo "  + $(printf '%q ' "$@")"
        "$@"
    else
        echo "  would run: $(printf '%q ' "$@")"
    fi
}

place_file() {
    local source="$1" destination="$2"
    if [[ ! -e "${source}" ]]; then
        note "not in the dump: ${source}"
    elif [[ -e "${destination}" ]]; then
        note "exists, left alone: ${destination}"
    else
        run mkdir -p "$(dirname "${destination}")"
        run cp -p "${source}" "${destination}"
    fi
}

# Usage: place_tree "${DUMP}/.config/gcloud" "${HOME}/.config/gcloud" --exclude logs
# Copies what the destination lacks. rsync is handed the source's entries
# rather than the directory itself, so that an existing destination does not
# take on the dump's permissions and timestamp.
place_tree() {
    local source="$1" destination="$2"
    shift 2
    local entries=("${source}"/*)
    if [[ ${#entries[@]} -eq 0 ]]; then
        note "not in the dump: ${source}"
        return 0
    fi
    run mkdir -p "${destination}"
    run rsync -a --ignore-existing "$@" "${entries[@]}" "${destination}/"
}

replace_keeping_original() {
    local source="$1" destination="$2"
    if [[ ! -e "${source}" ]]; then
        note "not in the dump: ${source}"
    elif [[ ! -e "${destination}" ]]; then
        place_file "${source}" "${destination}"
    elif cmp -s "${source}" "${destination}"; then
        note "already in place: ${destination}"
    elif [[ -e "${destination}.pre-handoff" ]]; then
        note "replaced on an earlier run, left alone: ${destination}"
    else
        run mv "${destination}" "${destination}.pre-handoff"
        run cp -p "${source}" "${destination}"
    fi
}

restore_agent_rules() {
    heading "Claude Code rules and settings"
    place_file "${DUMP}/.claude/CLAUDE.md" "${HOME}/.claude/CLAUDE.md"
    replace_keeping_original "${DUMP}/.claude/settings.json" "${HOME}/.claude/settings.json"
}

restore_codex() {
    heading "Codex"
    place_tree "${DUMP}/.codex" "${HOME}/.codex" --exclude config.toml
    local saved="${DUMP}/.codex/config.toml" config="${HOME}/.codex/config.toml"
    if [[ -e "${config}" ]]; then
        note "exists, left alone: ${config}"
    elif [[ -e "${saved}" ]]; then
        note "write ${config}, with ${OLD_HOME} rewritten to ${HOME}"
        if applying; then
            sed "s|${OLD_HOME}|${HOME}|g" "${saved}" >"${config}"
            chmod 600 "${config}"
        fi
    fi
}

add_missing_known_hosts() {
    local theirs="${DUMP}/.ssh/known_hosts" ours="${HOME}/.ssh/known_hosts" missing
    if [[ ! -e "${theirs}" || ! -e "${ours}" ]]; then
        place_file "${theirs}" "${ours}"
        return 0
    fi
    missing="$(grep -vxFf "${ours}" "${theirs}")"
    if [[ -z "${missing}" ]]; then
        note "already has every entry: ${ours}"
        return 0
    fi
    note "append $(grep -c . <<<"${missing}") entries to ${ours}"
    applying || return 0
    printf '%s\n' "${missing}" >>"${ours}"
}

restore_ssh() {
    heading "ssh"
    place_file "${DUMP}/.ssh/shared_forest_ed25519" "${HOME}/.ssh/shared_forest_ed25519"
    place_file "${DUMP}/.ssh/shared_forest_ed25519.pub" "${HOME}/.ssh/shared_forest_ed25519.pub"
    add_missing_known_hosts
}

# The 1Password CLI refuses a configuration directory that anyone but its
# owner can enter.
restore_op_config() {
    place_tree "${DUMP}/.config/op" "${HOME}/.config/op"
    if [[ -d "${DUMP}/.config/op" ]]; then
        run chmod 700 "${HOME}/.config/op"
    fi
}

restore_credentials() {
    heading "gcloud, gh and op configuration"
    place_tree "${DUMP}/.config/gcloud" "${HOME}/.config/gcloud" --exclude logs
    place_tree "${DUMP}/.config/gh" "${HOME}/.config/gh"
    restore_op_config
}

prepend_shell_history() {
    local theirs="${DUMP}/.bash_history" ours="${HOME}/.bash_history"
    if [[ ! -e "${theirs}" || ! -e "${ours}" ]]; then
        place_file "${theirs}" "${ours}"
    elif [[ -e "${ours}.pre-handoff" ]]; then
        note "merged on an earlier run, left alone: ${ours}"
    else
        note "put the old machine's $(wc -l <"${theirs}") history lines ahead of the $(wc -l <"${ours}") in ${ours}"
        applying || return 0
        cp -p "${ours}" "${ours}.pre-handoff"
        cat "${theirs}" "${ours}.pre-handoff" >"${ours}"
    fi
}

# vim and nvim name an undo file after the absolute path of the file it
# belongs to, with every / written as %, so the old home is part of the name.
restore_undo_history() {
    local old_prefix="${OLD_HOME//\//%}%" new_prefix="${HOME//\//%}%"
    local kind file name destination placed
    for kind in undodir nvim-undodir; do
        placed=0
        for file in "${DUMP}/${VIM_TEMP_DIRS}/${kind}"/*; do
            name="$(basename "${file}")"
            if [[ "${name}" == "${old_prefix}"* ]]; then
                name="${new_prefix}${name#"${old_prefix}"}"
            fi
            destination="${HOME}/.vim/temp_dirs/${kind}/${name}"
            [[ -e "${destination}" ]] && continue
            placed=$((placed + 1))
            if applying; then
                mkdir -p "$(dirname "${destination}")"
                cp -p "${file}" "${destination}"
            fi
        done
        note "${kind}: ${placed} undo files to place, renamed from ${old_prefix} to ${new_prefix}"
    done
}

restore_shell_and_editors() {
    heading "shell and editor state"
    prepend_shell_history
    replace_keeping_original "${DUMP}/.viminfo" "${HOME}/.viminfo"
    replace_keeping_original "${DUMP}/.local/state/nvim/shada/main.shada" "${HOME}/.local/state/nvim/shada/main.shada"
    restore_undo_history
    place_tree "${DUMP}/${VIM_TEMP_DIRS}/backups" "${HOME}/.vim/temp_dirs/backups"
    place_tree "${DUMP}/${VIM_TEMP_DIRS}/nvim-backups" "${HOME}/.vim/temp_dirs/nvim-backups"
    place_tree "${DUMP}/.ipython" "${HOME}/.ipython"
    place_tree "${DUMP}/.jupyter" "${HOME}/.jupyter"
    place_tree "${DUMP}/.ansible" "${HOME}/.ansible"
}

restore_loose_files() {
    heading "Desktop and Downloads"
    place_tree "${DUMP}/Desktop" "${HOME}/Desktop" --exclude .localized
    place_tree "${DUMP}/Downloads" "${HOME}/Downloads"
}

archive_handoff() {
    heading "staging directory and agent scratchpads, kept under ~/LAPTOP_HANDOFF"
    place_tree "${DUMP}/LAPTOP_HANDOFF" "${HOME}/LAPTOP_HANDOFF"
    place_tree "${DUMP}/private/tmp" "${HOME}/LAPTOP_HANDOFF/scratchpads"
}

main() {
    parse_args "$@"
    if [[ ! -d "${DUMP}/LAPTOP_HANDOFF" ]]; then
        echo "no LAPTOP_HANDOFF under ${DUMP}; pass --dump DIR" >&2
        exit 1
    fi
    restore_agent_rules
    restore_codex
    restore_ssh
    restore_credentials
    restore_shell_and_editors
    restore_loose_files
    archive_handoff
    echo
    applying || echo "Dry run: nothing was changed. Re-run with --apply."
}

main "$@"
