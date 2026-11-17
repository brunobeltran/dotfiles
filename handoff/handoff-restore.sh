#!/usr/bin/env bash
#
# Replays the git state that handoff-collect.sh staged (repos, bundled commits,
# branches, worktrees) onto this machine. Changes nothing unless given --apply.
# See usage() for the steps, their order, and examples.
set -uo pipefail

STAGING="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODE=dry-run

# Newline-terminated lists (see is_listed) of repo paths; PLACED_BRANCHES holds
# "<repo> <branch>" instead.
PREPARED_REPOS=""
UNAVAILABLE_REPOS=""
CREATED_REPOS=""
PLACED_BRANCHES=""

usage() {
    cat <<'EOF'
handoff-restore.sh [--apply] [--staging DIR]

Rebuilds repos, branches and worktrees from DIR/git, where DIR was staged by
handoff-collect.sh (default: the directory this script is in). With no flag it
prints the git commands --apply would run.

Run it after source-for-work.sh, which makes the hgcreate clones.

  1. A plain repo that is missing is cloned, or initialised if it had no
     remote. A missing hgcreate repo is reported: run hgcreate, then re-run.
  2. The commits in <repo>.bundle are fetched. No refs are created by this.
  3. Each recorded worktree is added, with its branch put at the recorded
     commit. A checkout that already exists is left alone.
  4. Bundled branches with no local branch of that name are created. A local
     branch that already exists is never moved; differences are reported.
  5. Patches, untracked-file archives and stashes are listed, not applied.

Paths recorded as ~/... are recreated under this machine's $HOME. Worktrees
that lived outside the old home directory are skipped.

Examples:
  ~/LAPTOP_HANDOFF/handoff-restore.sh
  ~/LAPTOP_HANDOFF/handoff-restore.sh --apply
  ./handoff-restore.sh --staging /mnt/usb/LAPTOP_HANDOFF --apply
EOF
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
        --apply) MODE=apply ;;
        --staging)
            if [[ $# -lt 2 ]]; then
                echo "--staging needs a directory" >&2
                exit 1
            fi
            STAGING="$(cd "$2" && pwd)" || exit 1
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

# Usage: is_listed "${repo}" "${CREATED_REPOS}"
is_listed() { [[ $'\n'"$2" == *$'\n'"$1"$'\n'* ]]; }

was_under_old_home() { [[ "$1" == \~ || "$1" == \~/* ]]; }

expand_home() {
    case "$1" in
    \~) echo "${HOME}" ;;
    \~/*) echo "${HOME}${1#\~}" ;;
    *) echo "$1" ;;
    esac
}

# Usage: slug_of "~/mergelabs/bruno/temp"   ->   mergelabs_bruno_temp
slug_of() {
    local relative="${1#\~/}"
    echo "${relative//\//_}"
}

worktree_rows() { tail -n +2 "${STAGING}/git/worktrees.tsv"; }

bundle_of() { echo "${STAGING}/git/$(basename "$1").bundle"; }

bundled_refs() { git bundle list-heads "$1" | cut -d' ' -f2; }

make_repo_available() {
    local repo="$1" layout="$2" remote_url="$3"
    [[ -e "${repo}/.git" ]] && return 0
    case "${layout}" in
    hgcreate)
        note "MISSING ${repo}: run 'hgcreate ${remote_url}', then re-run this script"
        return 1
        ;;
    plain)
        if [[ "${remote_url}" == NO-REMOTE ]]; then
            run git init "${repo}"
        else
            run git clone "${remote_url}" "${repo}"
        fi
        CREATED_REPOS+="${repo}"$'\n'
        ;;
    *)
        note "SKIPPED ${repo}: do not know how to recreate a '${layout}' layout"
        return 1
        ;;
    esac
}

# Fetches by explicit ref name with no destination, which stores the commits
# without creating or moving any ref; tags are the exception and are created.
fetch_bundled_commits() {
    local repo="$1" bundle ref
    bundle="$(bundle_of "${repo}")"
    [[ -f "${bundle}" ]] || return 0
    local refspecs=()
    while read -r ref; do
        case "${ref}" in
        refs/tags/*) refspecs+=("${ref}:${ref}") ;;
        *) refspecs+=("${ref}") ;;
        esac
    done < <(bundled_refs "${bundle}")
    run git -C "${repo}" fetch --quiet "${bundle}" "${refspecs[@]}"
}

prepare_repo() {
    local repo="$1" layout="$2" remote_url="$3"
    is_listed "${repo}" "${PREPARED_REPOS}" && return 0
    is_listed "${repo}" "${UNAVAILABLE_REPOS}" && return 1
    echo "${repo}"
    if ! make_repo_available "${repo}" "${layout}" "${remote_url}"; then
        UNAVAILABLE_REPOS+="${repo}"$'\n'
        return 1
    fi
    fetch_bundled_commits "${repo}"
    PREPARED_REPOS+="${repo}"$'\n'
}

restore_checkout() {
    local repo="$1" checkout="$2" branch="$3" commit="$4" upstream="$5"
    if [[ "${commit}" == - ]]; then
        note "nothing to restore for ${checkout}: it had no commits"
        return 0
    fi

    if [[ "${checkout}" == "${repo}" ]]; then
        if ! is_listed "${repo}" "${CREATED_REPOS}"; then
            note "exists, left alone: ${checkout}"
            return 0
        fi
        if [[ "${branch}" == HEAD ]]; then
            run git -C "${repo}" checkout --detach "${commit}"
            return 0
        fi
        run git -C "${repo}" checkout -B "${branch}" "${commit}" || return 0
    else
        if [[ -e "${checkout}" ]]; then
            note "exists, left alone: ${checkout}"
            return 0
        fi
        if [[ "${branch}" == HEAD ]]; then
            run git -C "${repo}" worktree add --detach "${checkout}" "${commit}"
            return 0
        fi
        run git -C "${repo}" worktree add -B "${branch}" "${checkout}" "${commit}" || return 0
    fi

    PLACED_BRANCHES+="${repo} ${branch}"$'\n'
    if [[ "${upstream}" != - ]]; then
        run git -C "${repo}" branch --set-upstream-to="${upstream}" "${branch}"
    fi
}

# Rows are read on fd 3: git and ssh inherit stdin and would swallow the rest.
restore_worktrees() {
    local repo_root layout worktree branch head upstream ahead behind modified untracked remote_url
    local repo
    # shellcheck disable=SC2034
    while IFS=$'\t' read -r -u 3 repo_root layout worktree branch head upstream ahead behind modified untracked remote_url; do
        if ! was_under_old_home "${worktree}"; then
            note "SKIPPED ${worktree}: outside the old home directory (${branch} at ${head:0:12})"
            continue
        fi
        repo="$(expand_home "${repo_root}")"
        prepare_repo "${repo}" "${layout}" "${remote_url}" || continue
        restore_checkout "${repo}" "$(expand_home "${worktree}")" "${branch}" "${head}" "${upstream}"
    done 3< <(worktree_rows)
}

# Skips PLACED_BRANCHES because in a dry run they do not exist yet and would be
# planned twice.
create_branches_missing_locally() {
    local repo="$1" bundle commit ref branch
    bundle="$(bundle_of "${repo}")"
    [[ -f "${bundle}" ]] || return 0
    while read -r -u 3 commit ref; do
        [[ "${ref}" == refs/heads/* ]] || continue
        branch="${ref#refs/heads/}"
        is_listed "${repo} ${branch}" "${PLACED_BRANCHES}" && continue
        if ! git -C "${repo}" show-ref --verify --quiet "${ref}" 2>/dev/null; then
            run git -C "${repo}" branch --no-track "${branch}" "${commit}"
        elif ! git -C "${repo}" merge-base --is-ancestor "${commit}" "${ref}" 2>/dev/null; then
            note "differs: ${branch} here lacks ${commit:0:12}, its tip on the old machine"
        fi
    done 3< <(git bundle list-heads "${bundle}")
}

restore_remaining_branches() {
    local repo
    echo
    echo "Branches that had no worktree:"
    while read -r repo; do
        [[ -n "${repo}" ]] || continue
        echo "${repo}"
        create_branches_missing_locally "${repo}"
    done <<<"${PREPARED_REPOS}"
}

list_manual_steps() {
    local repo_root layout worktree branch head upstream ahead behind modified untracked remote_url
    local slug target patch archive
    echo
    echo "Left to do by hand:"
    # shellcheck disable=SC2034
    while IFS=$'\t' read -r repo_root layout worktree branch head upstream ahead behind modified untracked remote_url; do
        slug="$(slug_of "${worktree}")"
        target="$(expand_home "${worktree}")"
        patch="${STAGING}/git/dirty_${slug}.patch"
        archive="${STAGING}/git/untracked_${slug}.tar.gz"
        if ! was_under_old_home "${worktree}"; then
            target="<a checkout of ${branch} at ${head:0:12}>"
        fi
        [[ -f "${patch}" ]] && note "git -C ${target} apply ${patch}"
        [[ -f "${archive}" ]] && note "tar -xzf ${archive} -C ${target}"
    done < <(worktree_rows)

    local stash_patch stash_repo base_commit subject
    if [[ -f "${STAGING}/git/stashes.tsv" ]]; then
        while IFS=$'\t' read -r stash_patch stash_repo base_commit subject; do
            note "stash from ${stash_repo} (${subject}), made on ${base_commit:0:12}: ${STAGING}/${stash_patch}"
        done < <(tail -n +2 "${STAGING}/git/stashes.tsv")
    fi
}

main() {
    parse_args "$@"
    if [[ ! -f "${STAGING}/git/worktrees.tsv" ]]; then
        echo "no git/worktrees.tsv under ${STAGING}; pass --staging DIR" >&2
        exit 1
    fi
    restore_worktrees
    restore_remaining_branches
    list_manual_steps
    echo
    applying || echo "Dry run: nothing was changed. Re-run with --apply."
}

main "$@"
