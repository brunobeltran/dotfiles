#!/usr/bin/env bash
#
# Captures the state of this machine that is not already a file (unpushed git
# work, the live tmux session, a system inventory) into a staging directory.
# Changes nothing unless given --apply. See usage() for options and examples.
set -uo pipefail

STAGING="${HANDOFF_STAGING:-${HOME}/handoff}"
MODE=dry-run
LOG=""

# find(1) predicates for directories to prune: their checkouts are not ours
# (plugin managers, build trees, caches), so nothing in them needs saving.
VENDORED_DIRECTORIES=(
    -name Library -o -name .Trash -o -name node_modules -o -name .cache
    -o -name .codex -o -name .claude -o -name .local -o -name plugged
    -o -path "*/dotfiles/build" -o -path "*/dot-tmux/plugins"
)

REPO_SEARCH_DEPTH=6

usage() {
    cat <<'EOF'
handoff-collect.sh [--apply | --survey] [--staging DIR]

Captures state that is not already a file into DIR (default: $HANDOFF_STAGING,
else ~/handoff). With no flag it reports what --apply would do.

  --apply        write the staging directory
  --survey       print the worktree table to stdout and exit; writes nothing
  --staging DIR  where to stage

Examples:
  handoff-collect.sh
  handoff-collect.sh --survey | column -t -s $'\t'
  handoff-collect.sh --apply --staging ~/LAPTOP_HANDOFF

Staged under DIR:
  git/<repo>.bundle            branches with commits on no remote, and every
                               branch checked out in a worktree. Carries all
                               of their commits that are not on the remote's
                               default branch, or the whole history when the
                               repo has no remote.
  git/worktrees.tsv            one row per worktree: where it was and on what
  git/dirty_<path>.patch       uncommitted changes to tracked files
  git/untracked_<path>.tar.gz  untracked files that are not ignored
  git/stash_<repo>_<n>.patch   each stash entry, indexed by git/stashes.tsv
  tmux/                        newest tmux-resurrect snapshot, a readable
                               session-plan.tsv, and every pane's scrollback
  system/                      Brewfile, applications, defaults, versions,
                               known_hosts, ssh key inventory (no private keys)
  manifest.tsv                 the handoff-manifest.sh tally (takes minutes)
  handoff-restore.sh           replays git/ on the next machine
  RUNBOOK.md

Reads repositories and writes only under DIR. Pushes nothing, deletes nothing,
creates no refs, copies no secrets.
EOF
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
        --apply) MODE=apply ;;
        --survey) MODE=survey ;;
        --staging)
            if [[ $# -lt 2 ]]; then
                echo "--staging needs a directory" >&2
                exit 1
            fi
            STAGING="$2"
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

log_line() {
    echo "$1"
    if [[ -n "${LOG}" ]]; then
        echo "$1" >>"${LOG}"
    fi
}

heading() { log_line "== $*"; }

report() {
    if applying; then
        log_line "  $*"
    else
        log_line "  would $*"
    fi
}

prepare_staging() {
    case "${STAGING}" in
    /*) ;;
    *) STAGING="${PWD}/${STAGING}" ;;
    esac
    applying || return 0
    mkdir -p "${STAGING}/git" "${STAGING}/tmux" "${STAGING}/system"
    LOG="${STAGING}/collect.log"
    : >"${LOG}"
}

# Usage: stage_output system/versions.txt describe_versions
stage_output() {
    local staged_path="$1"
    shift
    report "write ${staged_path}"
    applying || return 0
    "$@" >"${STAGING}/${staged_path}" 2>>"${LOG}"
}

stage_copy() {
    local staged_dir="$1" source="$2"
    [[ -e "${source}" ]] || return 0
    report "copy ${staged_dir}/$(basename "${source}")"
    applying || return 0
    cp "${source}" "${STAGING}/${staged_dir}/"
}

# Paths are staged relative to ~ so they can be replayed under another home.
home_relative() {
    case "$1" in
    "${HOME}") echo "~" ;;
    "${HOME}"/*) echo "~${1#"${HOME}"}" ;;
    *) echo "$1" ;;
    esac
}

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

# Prints each repository's common git dir once, however many worktrees it has.
discover_repos() {
    find "${HOME}" -maxdepth "${REPO_SEARCH_DEPTH}" \
        \( "${VENDORED_DIRECTORIES[@]}" \) -prune -o -name .git -print 2>/dev/null |
        while read -r git_entry; do
            git -C "$(dirname "${git_entry}")" rev-parse --path-format=absolute --git-common-dir 2>/dev/null
        done | sort -u
}

# hgcreate (dot-bash_aliases) lays a repo out as a bare <name>/<name>.git with
# one worktree per branch beside it.
layout_of() {
    local common_dir="$1" root
    root="$(dirname "${common_dir}")"
    if [[ "$(basename "${common_dir}")" == .git ]]; then
        echo plain
    elif [[ "${common_dir}" == "${root}/$(basename "${root}").git" ]]; then
        echo hgcreate
    else
        echo bare
    fi
}

worktrees_of() {
    git --git-dir="$1" worktree list --porcelain | awk '
        /^worktree / { path = substr($0, 10) }
        /^bare$/ || /^prunable/ { path = "" }
        /^$/ { if (path != "") print path; path = "" }
        END { if (path != "") print path }'
}

detached_heads_of() {
    git --git-dir="$1" worktree list --porcelain | awk '
        /^HEAD / { head = $2 }
        /^detached$/ { print head }'
}

REPO_COMMON_DIRS=""
WORKTREE_TABLE=""

survey_worktree() {
    local common_dir="$1" checkout="$2"
    local branch head upstream remote_url ahead=0 behind=0 modified untracked
    branch="$(git -C "${checkout}" rev-parse --abbrev-ref HEAD 2>/dev/null)" || branch=HEAD
    head="$(git -C "${checkout}" rev-parse --verify --quiet HEAD)" || head=-
    upstream="$(git -C "${checkout}" rev-parse --abbrev-ref --symbolic-full-name '@{upstream}' 2>/dev/null)" || upstream=-
    remote_url="$(git -C "${checkout}" remote get-url origin 2>/dev/null)" || remote_url=NO-REMOTE
    if [[ "${upstream}" != - ]]; then
        ahead="$(git -C "${checkout}" rev-list --count "${upstream}..HEAD")"
        behind="$(git -C "${checkout}" rev-list --count "HEAD..${upstream}")"
    fi
    modified="$(git -C "${checkout}" status --porcelain --untracked-files=no | wc -l | tr -d ' ')"
    untracked="$(git -C "${checkout}" ls-files --others --exclude-standard | wc -l | tr -d ' ')"
    WORKTREE_TABLE+="$(printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s' \
        "$(home_relative "$(dirname "${common_dir}")")" "$(layout_of "${common_dir}")" \
        "$(home_relative "${checkout}")" "${branch}" "${head}" "${upstream}" \
        "${ahead}" "${behind}" "${modified}" "${untracked}" "${remote_url}")"$'\n'
}

survey_worktrees() {
    local common_dir checkout
    REPO_COMMON_DIRS="$(discover_repos)"
    while read -r common_dir; do
        [[ -n "${common_dir}" ]] || continue
        while read -r checkout; do
            [[ -d "${checkout}" ]] || continue
            survey_worktree "${common_dir}" "${checkout}"
        done < <(worktrees_of "${common_dir}")
    done <<<"${REPO_COMMON_DIRS}"
}

print_worktrees_tsv() {
    printf 'repo_root\tlayout\tworktree\tbranch\thead\tupstream\tahead\tbehind\tmodified\tuntracked\tremote_url\n'
    printf '%s' "${WORKTREE_TABLE}"
}

archive_untracked_files() {
    git -C "$1" ls-files --others --exclude-standard -z | tar -C "$1" -czf - --null -T -
}

stage_uncommitted_work() {
    heading "git: worktrees and uncommitted work"
    stage_output git/worktrees.tsv print_worktrees_tsv
    local repo_root layout worktree branch head upstream ahead behind modified untracked remote_url
    local checkout slug
    # shellcheck disable=SC2034
    while IFS=$'\t' read -r repo_root layout worktree branch head upstream ahead behind modified untracked remote_url; do
        [[ -n "${worktree}" ]] || continue
        checkout="$(expand_home "${worktree}")"
        slug="$(slug_of "${worktree}")"
        if [[ "${modified}" != 0 ]]; then
            stage_output "git/dirty_${slug}.patch" git -C "${checkout}" diff --binary HEAD
        fi
        if [[ "${untracked}" != 0 ]]; then
            stage_output "git/untracked_${slug}.tar.gz" archive_untracked_files "${checkout}"
        fi
    done <<<"${WORKTREE_TABLE}"
}

# The remote's default branch: the one remote ref that is never rewritten or
# deleted, so commits on it are certain to exist in any future clone.
durable_remote_ref() {
    local common_dir="$1" candidate
    for candidate in refs/remotes/origin/HEAD refs/remotes/origin/main refs/remotes/origin/master; do
        if git --git-dir="${common_dir}" rev-parse --verify --quiet "${candidate}" >/dev/null; then
            echo "${candidate}"
            return 0
        fi
    done
}

# Refs holding commits no remote has, plus every checked-out branch, so a
# worktree's commit stays restorable even if its remote branch is rewritten.
refs_to_bundle() {
    local common_dir="$1" ref
    {
        git --git-dir="${common_dir}" for-each-ref --format='%(refname)' refs/heads refs/tags |
            while read -r ref; do
                if [[ -n "$(git --git-dir="${common_dir}" rev-list -1 "${ref}" --not --remotes)" ]]; then
                    echo "${ref}"
                fi
            done
        git --git-dir="${common_dir}" worktree list --porcelain | sed -n 's/^branch //p'
    } | sort -u
}

# Usage: warn_about_unrestorable_detached_heads "${common_dir}" arbor origin/HEAD refs/heads/x ...
warn_about_unrestorable_detached_heads() {
    local common_dir="$1" repo_name="$2" commit
    shift 2
    while read -r commit; do
        if [[ -n "$(git --git-dir="${common_dir}" rev-list -1 "${commit}" --not "$@")" ]]; then
            log_line "  WARNING ${repo_name}: detached HEAD ${commit:0:12} is on no bundled branch and will NOT be carried. Put a branch on it and re-run."
        fi
    done < <(detached_heads_of "${common_dir}")
}

bundle_repo() {
    local common_dir="$1" repo_name="$2"
    local ref durable_ref commit_count scope="whole history"
    local refs=() restorable=()
    while read -r ref; do
        [[ -n "${ref}" ]] || continue
        refs+=("${ref}")
        restorable+=("${ref}")
    done < <(refs_to_bundle "${common_dir}")
    durable_ref="$(durable_remote_ref "${common_dir}")"
    if [[ -n "${durable_ref}" ]]; then
        restorable+=("${durable_ref}")
        scope="not on ${durable_ref#refs/remotes/}"
    fi
    if [[ ${#restorable[@]} -gt 0 ]]; then
        warn_about_unrestorable_detached_heads "${common_dir}" "${repo_name}" "${restorable[@]}"
    fi
    if [[ ${#refs[@]} -eq 0 ]]; then
        report "skip ${repo_name}: no branches to bundle"
        return 0
    fi

    local revisions=("${refs[@]}")
    if [[ -n "${durable_ref}" ]]; then
        revisions+=(--not "${durable_ref}")
    fi
    commit_count="$(git --git-dir="${common_dir}" rev-list --count "${revisions[@]}")"
    if [[ "${commit_count}" == 0 ]]; then
        report "skip ${repo_name}: every commit is on ${durable_ref#refs/remotes/}"
        return 0
    fi
    report "write git/${repo_name}.bundle (${commit_count} commits, ${scope})"
    applying || return 0
    git --git-dir="${common_dir}" bundle create "${STAGING}/git/${repo_name}.bundle" "${revisions[@]}" 2>>"${LOG}" ||
        log_line "  FAILED to bundle ${repo_name}; see collect.log"
}

STASH_TABLE=""

# A stash is a commit whose first parent is the commit it was made on and whose
# third parent, when present, holds the files that were untracked.
render_stash_patch() {
    local common_dir="$1" stash="$2"
    git --git-dir="${common_dir}" diff --binary "${stash}^1" "${stash}"
    if git --git-dir="${common_dir}" rev-parse --verify --quiet "${stash}^3" >/dev/null; then
        git --git-dir="${common_dir}" show --binary --format= "${stash}^3"
    fi
}

stage_stashes() {
    local common_dir="$1" repo_name="$2" stash patch index=0
    while read -r stash; do
        patch="git/stash_${repo_name}_${index}.patch"
        stage_output "${patch}" render_stash_patch "${common_dir}" "${stash}"
        STASH_TABLE+="$(printf '%s\t%s\t%s\t%s' "${patch}" \
            "$(home_relative "$(dirname "${common_dir}")")" \
            "$(git --git-dir="${common_dir}" rev-parse "${stash}^1")" \
            "$(git --git-dir="${common_dir}" log -1 --format=%s "${stash}")")"$'\n'
        index=$((index + 1))
    done < <(git --git-dir="${common_dir}" log --walk-reflogs --format=%H refs/stash 2>/dev/null)
}

print_stashes_tsv() {
    printf 'patch\trepo_root\tbase_commit\tsubject\n'
    printf '%s' "${STASH_TABLE}"
}

stage_unpushed_commits() {
    heading "git: commits and stashes that exist nowhere else"
    local common_dir repo_name
    while read -r common_dir; do
        [[ -n "${common_dir}" ]] || continue
        repo_name="$(basename "$(dirname "${common_dir}")")"
        bundle_repo "${common_dir}" "${repo_name}"
        stage_stashes "${common_dir}" "${repo_name}"
    done <<<"${REPO_COMMON_DIRS}"
    stage_output git/stashes.tsv print_stashes_tsv
}

# tmux-resurrect omits the pane-title field (the 7th) when the title is empty,
# shifting every later field; the cwd is found by its ":/" prefix instead.
render_tmux_session_plan() {
    local snapshot="$1"
    printf 'window\twindow_name\tpane\tcwd\tcommand\n'
    awk -F'\t' '
        NR == FNR {
            if ($1 == "window") { name = $4; sub(/^:/, "", name); window_name[$3] = name }
            next
        }
        $1 == "pane" {
            cwd_field = 0
            for (i = 1; i <= NF; i++) if ($i ~ /^:\//) { cwd_field = i; break }
            if (cwd_field == 0) next
            window = $3
            pane = $6
            cwd = $cwd_field; sub(/^:/, "", cwd)
            full_command = $NF; sub(/^:/, "", full_command)
            process_name = $(cwd_field + 2)
            printf "%s\t%s\t%s\t%s\t%s\n", window, window_name[window], pane, cwd,
                (full_command != "" ? full_command : process_name)
        }' "${snapshot}" "${snapshot}" | sort -t$'\t' -k1,1n -k3,3n
}

snapshot_tmux() {
    heading "tmux"
    if ! tmux has-session 2>/dev/null; then
        report "skip: no tmux server is running"
        return 0
    fi

    local resurrect_dir="${HOME}/.local/share/tmux/resurrect"
    local save_now="${HOME}/.tmux/plugins/tmux-resurrect/scripts/save.sh"
    if [[ -x "${save_now}" ]]; then
        report "force a fresh tmux-resurrect save"
        if applying; then
            "${save_now}" >>"${LOG}" 2>&1
        fi
    fi

    local newest_snapshot
    newest_snapshot="$(ls -t "${resurrect_dir}"/tmux_resurrect_*.txt 2>/dev/null | head -1)"
    if [[ -n "${newest_snapshot}" ]]; then
        stage_copy tmux "${newest_snapshot}"
        stage_output tmux/session-plan.tsv render_tmux_session_plan "${newest_snapshot}"
    fi
    stage_copy tmux "${resurrect_dir}/pane_contents.tar.gz"
}

describe_versions() {
    echo "host: $(hostname)"
    echo "os: $(uname -srm)"
    echo "date: $(date '+%Y-%m-%d %H:%M %Z')"
    echo
    local tool version
    for tool in bash git tmux nvim claude codex gh brew uv node python3 bazelisk starship rsync; do
        version="$({ "${tool}" --version || "${tool}" -V; } 2>/dev/null | head -1)"
        printf '%-10s %s\n' "${tool}" "${version:-(not installed)}"
    done
}

list_ssh_keys() {
    printf 'fingerprint\tcomment\tprivate_key\tpassphrase\n'
    local public_key private_key passphrase fingerprint comment
    for public_key in "${HOME}"/.ssh/*.pub; do
        [[ -e "${public_key}" ]] || continue
        private_key="${public_key%.pub}"
        if [[ ! -f "${private_key}" ]]; then
            passphrase="(private key not on this machine)"
        elif ssh-keygen -y -P "" -f "${private_key}" >/dev/null 2>&1; then
            passphrase=NONE
        else
            passphrase=yes
        fi
        read -r _ fingerprint comment _ < <(ssh-keygen -l -f "${public_key}" 2>/dev/null)
        printf '%s\t%s\t%s\t%s\n' "${fingerprint}" "${comment}" "$(home_relative "${private_key}")" "${passphrase}"
    done
}

list_applications() {
    printf 'app\tsource\n'
    local app source
    for app in /Applications/*.app "${HOME}"/Applications/*.app; do
        [[ -e "${app}" ]] || continue
        source="manual-or-brew"
        if [[ "$(mdls -name kMDItemAppStoreHasReceipt -raw "${app}" 2>/dev/null)" == 1 ]]; then
            source="app-store"
        fi
        printf '%s\t%s\n' "$(basename "${app}")" "${source}"
    done
}

read_macos_defaults() {
    local domain
    for domain in NSGlobalDomain com.apple.dock com.apple.finder com.apple.screencapture \
        com.apple.Safari com.apple.menuextra.clock com.apple.universalaccess; do
        echo "### ${domain}"
        defaults read "${domain}" 2>/dev/null || echo "(unreadable)"
        echo
    done
}

inventory_system() {
    heading "system"
    stage_output system/versions.txt describe_versions
    stage_output system/ssh-keys.tsv list_ssh_keys
    stage_copy system "${HOME}/.ssh/known_hosts"

    local tailscale=/Applications/Tailscale.app/Contents/MacOS/Tailscale
    if [[ -x "${tailscale}" ]]; then
        stage_output system/tailnet.txt "${tailscale}" status
    fi
    if [[ "${OSTYPE}" == darwin* ]]; then
        stage_output system/Brewfile brew bundle dump --file=-
        stage_output system/applications.tsv list_applications
        stage_output system/defaults-snapshot.txt read_macos_defaults
    fi
}

stage_restore_tooling() {
    heading "tally and restore tooling"
    local here
    here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    stage_copy . "${here}/handoff-restore.sh"
    stage_copy . "${here}/RUNBOOK.md"
    stage_output manifest.tsv env HANDOFF_STAGING="${STAGING}" "${here}/handoff-manifest.sh"
}

summarise() {
    echo
    if applying; then
        log_line "staged in ${STAGING}"
        du -sh "${STAGING}"/* | tee -a "${LOG}"
    else
        echo "Dry run: nothing was written. Re-run with --apply to stage into ${STAGING}."
    fi
}

main() {
    parse_args "$@"
    survey_worktrees
    if [[ "${MODE}" == survey ]]; then
        print_worktrees_tsv
        return 0
    fi
    prepare_staging
    stage_uncommitted_work
    stage_unpushed_commits
    snapshot_tmux
    inventory_system
    stage_restore_tooling
    summarise
}

main "$@"
