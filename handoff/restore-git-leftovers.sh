#!/usr/bin/env bash
#
# Finishes what handoff-restore.sh lists under "Left to do by hand": applies
# the staged patches, unpacks untracked files and recreates stashes. Changes
# nothing unless given --apply. See usage() for the steps and examples.
set -uo pipefail

DUMP="${HOME}/Downloads"
STAGING=""
MODE=dry-run

usage() {
    cat <<'EOF'
restore-git-leftovers.sh [--apply] [--dump DIR]

Run after "handoff-restore.sh --apply". Works from DIR/LAPTOP_HANDOFF/git,
where DIR is where the handoff zip was extracted (default: ~/Downloads). With
no flag it prints what --apply would do.

  1. Each dirty_<path>.patch is applied to its worktree and each
     untracked_<path>.tar.gz unpacked into it, never over an existing file.
     A worktree that is not at the commit the old machine recorded is left
     alone, as is a patch that is already applied or does not apply cleanly.
  2. A worktree that lived outside the old home is recreated, detached, at
     <repo>/handoff-scratch/<name>, and its patch applied there.
  3. Each stash is recreated as a stash entry with its original message,
     oldest first so the order matches. One that is already there is skipped.

Examples:
  ./restore-git-leftovers.sh
  ./restore-git-leftovers.sh --apply
  ./restore-git-leftovers.sh --dump /mnt/usb/extracted --apply
EOF
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
        --apply) MODE=apply ;;
        --dump)
            if [[ $# -lt 2 ]]; then
                echo "--dump needs a directory" >&2
                exit 1
            fi
            DUMP="$(cd "$2" && pwd)" || exit 1
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

note() { echo "  $*"; }

run() {
    if applying; then
        echo "  + $(printf '%q ' "$@")"
        "$@"
    else
        echo "  would run: $(printf '%q ' "$@")"
    fi
}

was_under_old_home() { [[ "$1" == \~ || "$1" == \~/* ]]; }

expand_home() {
    case "$1" in
    \~) echo "${HOME}" ;;
    \~/*) echo "${HOME}${1#\~}" ;;
    *) echo "$1" ;;
    esac
}

# Usage: slug_of "~/mergelabs/bruno/temp"   ->   mergelabs_bruno_temp
# The same naming handoff-collect.sh gave each worktree's patch and archive.
slug_of() {
    local relative="${1#\~/}"
    echo "${relative//\//_}"
}

checkout_is_at() {
    [[ "$(git -C "$1" rev-parse --verify --quiet HEAD 2>/dev/null)" == "$2" ]]
}

apply_patch() {
    local checkout="$1" patch="$2"
    if git -C "${checkout}" apply --reverse --check "${patch}" 2>/dev/null; then
        note "already applied: $(basename "${patch}")"
    elif git -C "${checkout}" apply --check "${patch}" 2>/dev/null; then
        run git -C "${checkout}" apply "${patch}"
    else
        note "SKIPPED $(basename "${patch}"): does not apply cleanly to ${checkout}"
    fi
}

# macOS tar stores a file's extended attributes as a sibling member named
# ._<file>; those members are not files the worktree ever held.
unpack_untracked_files() {
    local checkout="$1" archive="$2"
    run tar --extract --gzip --file "${archive}" --directory "${checkout}" \
        --exclude '._*' --skip-old-files --warning=no-unknown-keyword
}

recreate_scratch_worktree() {
    local repo="$1" checkout="$2" commit="$3"
    if [[ -e "${checkout}" ]]; then
        note "exists, left alone"
    elif [[ ! -e "${repo}/.git" ]]; then
        note "MISSING ${repo}: run handoff-restore.sh --apply first"
    else
        run git -C "${repo}" worktree add --detach "${checkout}" "${commit}"
    fi
}

# Rows are read on fd 3 so that nothing run in the loop can swallow the rest
# through stdin.
restore_uncommitted_work() {
    local repo_root layout worktree branch head upstream ahead behind modified untracked remote_url
    local slug patch archive repo checkout
    echo "Uncommitted work:"
    # shellcheck disable=SC2034
    while IFS=$'\t' read -r -u 3 repo_root layout worktree branch head upstream ahead behind modified untracked remote_url; do
        slug="$(slug_of "${worktree}")"
        patch="${STAGING}/git/dirty_${slug}.patch"
        archive="${STAGING}/git/untracked_${slug}.tar.gz"
        [[ -f "${patch}" || -f "${archive}" ]] || continue
        repo="$(expand_home "${repo_root}")"
        if was_under_old_home "${worktree}"; then
            checkout="$(expand_home "${worktree}")"
            echo "${checkout}"
        else
            checkout="${repo}/handoff-scratch/$(basename "${worktree}")"
            echo "${checkout}  (was ${worktree})"
            recreate_scratch_worktree "${repo}" "${checkout}" "${head}"
        fi
        if [[ ! -d "${checkout}" ]]; then
            note "no checkout there yet, so nothing was checked or applied"
            continue
        fi
        if ! checkout_is_at "${checkout}" "${head}"; then
            note "left alone: it is not at ${head:0:12}, the commit the old machine recorded"
            continue
        fi
        if [[ -f "${patch}" ]]; then
            apply_patch "${checkout}" "${patch}"
        fi
        if [[ -f "${archive}" ]]; then
            unpack_untracked_files "${checkout}" "${archive}"
        fi
    done 3< <(tail -n +2 "${STAGING}/git/worktrees.tsv")
}

stash_exists() {
    git -C "$1" log --walk-reflogs --format=%gs refs/stash 2>/dev/null | grep -qxF -- "$2"
}

# Usage: stash_patch_onto ~/arbor /path/stash_arbor_0.patch fe1f6771e07e "WIP on main: ..."
# Applies the patch in a throwaway worktree at the commit the stash was made
# on, then stores the result, so no existing checkout is disturbed. Stashes
# belong to the repository, not to the worktree they were made in.
stash_patch_onto() {
    local repo="$1" patch="$2" base_commit="$3" subject="$4"
    local scratch stash_commit="" stored=1
    scratch="$(mktemp -d)"
    if git -C "${repo}" worktree add --detach "${scratch}/base" "${base_commit}" >/dev/null 2>&1; then
        if git -C "${scratch}/base" apply --index "${patch}"; then
            stash_commit="$(git -C "${scratch}/base" stash create)"
        fi
        if [[ -n "${stash_commit}" ]]; then
            git -C "${scratch}/base" stash store --message "${subject}" "${stash_commit}"
            stored=$?
        fi
        git -C "${repo}" worktree remove --force "${scratch}/base"
    fi
    rmdir "${scratch}"
    return "${stored}"
}

recreate_stash() {
    local repo="$1" patch="$2" base_commit="$3" subject="$4"
    if [[ ! -e "${repo}/.git" ]]; then
        note "MISSING ${repo}: run handoff-restore.sh --apply first"
    elif stash_exists "${repo}" "${subject}"; then
        note "already stashed in ${repo}: ${subject}"
    elif ! git -C "${repo}" cat-file -e "${base_commit}^{commit}" 2>/dev/null; then
        note "SKIPPED $(basename "${patch}"): ${repo} lacks ${base_commit:0:12}, the commit it was made on"
    elif ! applying; then
        note "would stash in ${repo}: ${subject}"
    elif stash_patch_onto "${repo}" "${patch}" "${base_commit}" "${subject}"; then
        note "stashed in ${repo}: ${subject}"
    else
        note "FAILED to stash $(basename "${patch}") in ${repo}"
    fi
}

# stashes.tsv lists each repository's stashes newest first; replaying the file
# backwards rebuilds every stack in its original order.
recreate_stashes() {
    local stash_patch stash_repo base_commit subject
    echo
    echo "Stashes:"
    [[ -f "${STAGING}/git/stashes.tsv" ]] || return 0
    while IFS=$'\t' read -r -u 3 stash_patch stash_repo base_commit subject; do
        recreate_stash "$(expand_home "${stash_repo}")" "${STAGING}/${stash_patch}" "${base_commit}" "${subject}"
    done 3< <(tail -n +2 "${STAGING}/git/stashes.tsv" | tac)
}

main() {
    parse_args "$@"
    STAGING="${DUMP}/LAPTOP_HANDOFF"
    if [[ ! -f "${STAGING}/git/worktrees.tsv" ]]; then
        echo "no LAPTOP_HANDOFF/git/worktrees.tsv under ${DUMP}; pass --dump DIR" >&2
        exit 1
    fi
    restore_uncommitted_work
    recreate_stashes
    echo
    applying || echo "Dry run: nothing was changed. Re-run with --apply."
}

main "$@"
