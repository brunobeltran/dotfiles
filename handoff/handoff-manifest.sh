#!/usr/bin/env bash
#
# Read-only tally of what on this machine is worth moving to the next one.
# See usage() for the output formats and columns.
set -uo pipefail

STAGING="${HANDOFF_STAGING:-${HOME}/handoff}"
FORMAT=tsv
ONLY_P0=0

usage() {
    cat <<'EOF'
handoff-manifest.sh [--tsv|--json|--summary] [--p0]

Tallies everything on this machine worth moving to the next one. Reads only;
writes nothing, moves nothing.

  --tsv      header plus one row per item (default)
  --json     the same rows as a JSON array
  --summary  item count and total bytes per priority
  --p0       restrict to the irreplaceable rows

Columns:
  priority     P0 irreplaceable, P1 painful to lose, P2 convenience,
               P3 deliberately skipped and listed so the tally is complete
  category     secrets | git | ai-state | tmux | config | app-data |
               user-files | cache
  replaceable  no | partial | yes
  bytes        0 when the path does not exist
  exists       yes | no
  path         absolute path, or a short label when the item is not a file
  note         why it is listed and what to do about it

Examples:
  handoff-manifest.sh --summary
  handoff-manifest.sh --p0 | column -t -s $'\t'
  handoff-manifest.sh --json > tally.json

Sizing the larger directories takes a few minutes.
EOF
}

parse_args() {
    local arg
    for arg in "$@"; do
        case "${arg}" in
        --json) FORMAT=json ;;
        --summary) FORMAT=summary ;;
        --tsv) FORMAT=tsv ;;
        --p0) ONLY_P0=1 ;;
        -h | --help)
            usage
            exit 0
            ;;
        *)
            echo "unknown argument: ${arg}" >&2
            usage >&2
            exit 1
            ;;
        esac
    done
}

bytes_used_by() {
    [[ -e "$1" ]] || {
        echo 0
        return
    }
    local kilobytes
    kilobytes="$(du -sk "$1" 2>/dev/null | awk '{print $1; exit}')" || kilobytes=0
    echo $((${kilobytes:-0} * 1024))
}

ROWS=()

# Usage: emit P1 config partial "${HOME}/.viminfo" "vim jumplist and registers."
emit() {
    local priority="$1" category="$2" replaceable="$3" path="$4"
    shift 4
    [[ ${ONLY_P0} -eq 1 && ${priority} != P0 ]] && return 0
    local exists=no
    [[ -e "${path}" ]] && exists=yes
    ROWS+=("$(printf '%s\t%s\t%s\t%s\t%s\t%s\t%s' \
        "${priority}" "${category}" "${replaceable}" "$(bytes_used_by "${path}")" \
        "${exists}" "${path}" "$*")")
}

collect_secrets() {
    emit P0 secrets no "${HOME}/.ssh/id_ed25519" \
        "GitHub key, comment 'bruno@temp-macbook-personal'. HAS NO PASSPHRASE. Since you must add a key to GitHub on the new box anyway, prefer generating a fresh one there and deleting this from github.com/settings/keys, so this never has to travel."
    emit P0 secrets no "${HOME}/.ssh/shared_forest_ed25519" \
        "Shared forest key (bruno+shared@forestneurotech.org), passphrase-protected. A shared credential, so it must be carried rather than regenerated."
    emit P0 secrets no "${HOME}/.ssh/known_hosts" \
        "61 hosts including the tailnet. Not secret; saves re-verifying every fingerprint."
    emit P0 secrets no "${HOME}/.config/gcloud" \
        "gcloud ADC and account db. Physically inside the dotfiles repo and gitignored, so cloning dotfiles on the new box brings none of it. Alternative: re-run 'gcloud auth login' and 'gcloud auth application-default login'."
    emit P0 secrets no "${HOME}/.codex/auth.json" \
        "Codex CLI credentials. Alternative: re-run 'codex login'."
    emit P0 secrets partial "${HOME}/.config/gh" \
        "gh config.yml and hosts.yml. The token itself is in the macOS Keychain, not here, so plan on 'gh auth login' regardless."
    emit P0 secrets no "${HOME}/Library/Keychains" \
        "login.keychain-db holds the gh token, Wi-Fi passwords and app credentials. Not transferable by file copy, and Migration Assistant will not help going to Debian: budget for re-authenticating every app."
}

collect_git() {
    emit P0 git no "${STAGING}" \
        "Everything handoff-collect.sh --apply staged; move this directory whole. git/ holds bundles of unpushed branches and of every worktree's branch, patches of uncommitted changes and stashes, and worktrees.tsv. handoff-restore.sh replays it; RUNBOOK.md says in what order."
    emit P0 git no "${HOME}/developer/dbSDK" \
        "NO GIT REMOTE AT ALL. Its bundle in the staging directory is the only copy. LEGAL HOLD: this must never be pushed to any remote, ever. Move the bundle as a file only."
    emit P0 git partial "/private/tmp/claude-501" \
        "Claude scratchpad worktrees and loose scripts. Their commits and patches are staged, but the worktrees themselves are not restored, and macOS purges /private/tmp."
}

collect_ai_state() {
    emit P0 ai-state no "${HOME}/.claude/CLAUDE.md" \
        "Machine-wide instructions every Claude session loads (comment and docstring policy, never run, stage, commit or push unasked, network rules). It is a plain file: it reaches the next machine only if copied to ~/.claude/CLAUDE.md there."
    emit P0 ai-state no "${HOME}/.claude/settings.json" \
        "Model, effort levels, theme, empty attribution, enabled plugins."
    emit P0 ai-state no "${HOME}/.claude/projects" \
        "Transcripts and the per-project memory/ dirs. Keyed by a slug of the working directory, so every dir here says -Users-bruno-*. On /home/bruno those slugs will not match and six of them collide with -home-bruno-* dirs left by the previous Linux box. Copy wholesale now; merge by hand once everything is across."
    emit P1 ai-state no "${HOME}/.claude.json" \
        "Per-project history, onboarding flags, oauth account, MCP and plugin state. Its 'projects' keys are absolute paths and will need the same rename."
    emit P1 ai-state no "${HOME}/.claude/history.jsonl" \
        "Global prompt history. Each row carries an absolute 'project' path."
    emit P1 ai-state partial "${HOME}/.claude/plugins" \
        "installed_plugins.json and known_marketplaces.json are what matter (delta@zed-industries). The directory cache re-downloads."
    emit P1 ai-state no "${HOME}/.claude/skills" "Synced skills."
    emit P1 ai-state no "${HOME}/.claude/jobs" \
        "Background job state.json and timeline.jsonl. See the P3 row before copying the whole tree."
    emit P1 ai-state partial "${HOME}/.claude/file-history" \
        "Undo history for Claude's edits. Only meaningful against the same checkouts."
    emit P1 ai-state no "${HOME}/.codex/config.toml" "Codex config."
    emit P1 ai-state no "${HOME}/.codex/history.jsonl" "Codex prompt history."
    emit P1 ai-state no "${HOME}/.codex/sessions" "Codex session transcripts."
    emit P1 ai-state no "${HOME}/.codex/memories_1.sqlite" "Codex memories."
    emit P1 ai-state no "${HOME}/.codex/thread_history_1.sqlite" "Codex thread history."
    emit P1 ai-state no "${HOME}/.codex/state_5.sqlite" "Codex UI and session state."
    emit P1 ai-state no "${HOME}/.codex/skills" "Codex skills."
    emit P2 ai-state yes "${HOME}/.claude/backups" "Settings backups."
    emit P2 ai-state yes "${HOME}/.claude/paste-cache" "Pasted-content cache."
    emit P2 ai-state yes "${HOME}/.claude/uploads" "Uploaded files cache."
    emit P3 ai-state yes "${HOME}/.claude/jobs/dbd21e4e/tmp" \
        "EXCLUDE. Hugo and Sphinx build output from one job, and the single largest thing in ~/.claude. Regenerable."
    emit P3 ai-state yes "${HOME}/.codex/packages" "Re-downloadable."
    emit P3 ai-state yes "${HOME}/.codex/cache" "Re-downloadable."
    emit P3 ai-state yes "${HOME}/.claude/telemetry" "Local telemetry spool."
    emit P3 ai-state yes "${HOME}/.claude/cache" "Regenerable."
    emit P3 ai-state yes "${HOME}/.claude/shell-snapshots" "Per-session, stale on another machine."
    emit P3 ai-state yes "${HOME}/.claude/session-env" "Per-session, stale on another machine."
}

collect_tmux() {
    emit P2 tmux partial "${HOME}/.local/share/tmux/resurrect" \
        "Every tmux-resurrect snapshot. The newest one, a readable session plan and all pane scrollback are already in the staging directory; this is only the older history."
}

collect_config() {
    emit P1 config partial "${HOME}/.config/op" "1Password CLI config. Inside the dotfiles repo, gitignored."
    emit P1 config yes "${HOME}/.config/htop" "htop layout. Inside the dotfiles repo, gitignored."
    emit P1 config yes "${HOME}/.config/uv" "uv config. Inside the dotfiles repo, gitignored."
    emit P1 config yes "${HOME}/.config/fzf" "Written by the fzf installer; install.sh recreates it."
    emit P1 config yes "${HOME}/.config/fish" "Written by the fzf installer; install.sh recreates it."
    emit P1 config no "${HOME}/.bash_history" \
        "The single best aid for reconstructing what you were in the middle of."
    emit P1 config no "${HOME}/.viminfo" "vim jumplist, registers, recent files."
    emit P1 config no "${HOME}/.local/state/nvim" "nvim shada: marks, registers, recent files."
    emit P1 config no "${HOME}/developer/dotfiles/dotfiles/dot-vim/temp_dirs" \
        "vim and nvim undo history. Inside the repo, gitignored."
    emit P1 config no "${HOME}/.ipython" "IPython history db."
    emit P1 config yes "${HOME}/.jupyter" "Jupyter config."
    emit P1 config no "${HOME}/.ansible/logs_forest.log" "Ansible run log against forest hosts."
    emit P2 config yes "${HOME}/.config.bak" \
        "Left over from the Linux to Mac migration on 2026-11-09. Check for anything never re-linked, then drop."
    emit P2 config yes "${HOME}/.m2" "Maven cache."
    emit P2 config yes "${HOME}/.android" "Android SDK state."
}

collect_app_data() {
    emit P0 app-data no "1Password Secret Key and Emergency Kit" \
        "NOT A FILE. 1Password > Settings > Accounts, or 1password.com > My Profile > Get Emergency Kit. Without the Secret Key you cannot sign in on the new box."
    local unifi_backup
    for unifi_backup in "${STAGING}"/*.unifi "${STAGING}"/*.unf "${HOME}"/Downloads/*.unifi "${HOME}"/Downloads/*.unf; do
        [[ -e "${unifi_backup}" ]] || continue
        emit P0 app-data no "${unifi_backup}" \
            "UniFi backup. A .unifi file is the console's System Backup and restores everything, device adoption included. A network_site_*.unf is a site export: configuration only."
    done
    emit P2 app-data yes "${HOME}/Library/Application Support/Signal" \
        "Message history lives on the phone and a newly linked device syncs from it, so nothing here is load-bearing. Just link the new box to your phone."
    emit P2 app-data yes "${HOME}/Library/Application Support/Claude" "Claude desktop app state; re-logs-in."
    emit P2 app-data partial "${HOME}/Library/Application Support/Delta" "Delta app state; mostly re-downloadable."
    emit P2 app-data yes "${HOME}/Library/Group Containers/2BUA8C4S2C.com.1password" \
        "Local vault cache. Re-syncs once you sign in with the Secret Key."
    emit P2 app-data yes "${HOME}/Library/Application Support/Google/Chrome" \
        "Both profiles (brunobeltran0@gmail.com, bruno@forestneurotech.org) are signed in, so Chrome Sync carries bookmarks, passwords and extensions. Verify sync is on before wiping."
    emit P3 app-data yes "${HOME}/Library/Application Support/UniFi OS Server" \
        "EXCLUDE. Almost entirely the podman VM disk image. The backups are the artifact, not this directory, and the autobackups live inside the image rather than on the host filesystem."
}

collect_user_files() {
    emit P1 user-files no "${HOME}/Desktop" "Screenshots."
    emit P1 user-files partial "${HOME}/Downloads" \
        "Mostly two copies of one large .dmg. The keepers are jic.md / jic2.md / jic3.md, aria-fusi-conversation.md, the Arbor RFC pdf, the floor plan png and the truenas tar."
    emit P1 user-files no "${HOME}/Pictures/Photos Library.photoslibrary" \
        "Photos library. Check whether iCloud Photos is on before assuming it is safe."
    emit P2 user-files no "${HOME}/Music" "Small."
    emit P2 user-files no "${HOME}/Movies" "Small."
    emit P2 user-files yes "${HOME}/id_ed25519.pub" \
        "A PUBLIC key belonging to zach@bonobo, not yours. Not secret; safe to drop."
}

collect_skipped() {
    emit P3 cache yes "${HOME}/.cache" "Almost entirely the mergelabs Bazel cache. Rebuilds."
    emit P3 cache yes "${HOME}/developer/dotfiles/build" "install.sh build dirs. install.sh rebuilds them."
    emit P3 cache yes "${HOME}/.local/share/nvim" "lazy and mason. Reinstall on first launch."
    emit P3 cache yes "${HOME}/developer/dotfiles/dotfiles/dot-vim/plugged" "vim plugins. Reinstall."
    emit P3 cache yes "${HOME}/developer/dotfiles/dotfiles/dot-tmux/plugins" "tpm plugins. install.sh reinstalls."
    emit P3 cache yes "${HOME}/mergelabs" "Re-cloneable from origin plus the bundles."
    emit P3 cache yes "${HOME}/arbor" "Re-cloneable from origin plus the bundles."
    emit P3 cache yes "${HOME}/forest" "Re-cloneable from origin plus the bundles."
    emit P3 cache yes "${HOME}/arbor-fouragnan" "Re-cloneable from origin plus the bundles."
    emit P3 cache yes "${HOME}/developer/bruno-fitness" "Re-cloneable from origin."
    emit P3 cache yes "${HOME}/developer/forest1-functional-testing" "Re-cloneable from origin."
    emit P3 cache yes "${HOME}/.npm" "npm cache."
}

print_tsv() {
    printf 'priority\tcategory\treplaceable\tbytes\texists\tpath\tnote\n'
    printf '%s\n' "${ROWS[@]}" | sort -t$'\t' -k1,1 -k2,2 -k4,4nr
}

print_json() {
    printf '%s\n' "${ROWS[@]}" | python3 -I -c '
import csv, json, sys
columns = ["priority", "category", "replaceable", "bytes", "exists", "path", "note"]
rows = []
for raw in csv.reader(sys.stdin, delimiter="\t"):
    if not raw:
        continue
    row = dict(zip(columns, raw))
    row["bytes"] = int(row["bytes"])
    rows.append(row)
rows.sort(key=lambda r: (r["priority"], r["category"], -r["bytes"]))
json.dump(rows, sys.stdout, indent=2)
sys.stdout.write("\n")
'
}

print_summary() {
    printf '%s\n' "${ROWS[@]}" | awk -F'\t' '
        function human(b,   units, i) {
            split("B KiB MiB GiB TiB", units, " ")
            i = 1
            while (b >= 1024 && i < 5) { b /= 1024; i++ }
            return sprintf("%.1f%s", b, units[i])
        }
        { bytes[$1] += $4; count[$1]++; total += $4 }
        END {
            printf "%-5s %7s  %s\n", "PRIO", "ITEMS", "BYTES"
            split("P0 P1 P2 P3", order, " ")
            for (i = 1; i <= 4; i++) {
                p = order[i]
                if (p in count) printf "%-5s %7d  %s\n", p, count[p], human(bytes[p])
            }
            printf "%-5s %7s  %s\n", "ALL", "", human(total)
        }'
}

main() {
    parse_args "$@"
    collect_secrets
    collect_git
    collect_ai_state
    collect_tmux
    collect_config
    collect_app_data
    collect_user_files
    collect_skipped
    case "${FORMAT}" in
    tsv) print_tsv ;;
    json) print_json ;;
    summary) print_summary ;;
    esac
}

main "$@"
