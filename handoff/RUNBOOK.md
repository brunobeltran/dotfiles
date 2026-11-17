# Machine handoff runbook

Written for the move from a Mac (`/Users/bruno`) to a Debian box
(`/home/bruno`). `handoff-collect.sh` copies this file into the staging
directory, so on the new machine it doubles as the brief for whoever, or
whichever agent, does the restore.

| script | runs on | does |
|---|---|---|
| `handoff-collect.sh` | old machine | stages unpushed git work, the tmux session and a system inventory |
| `handoff-manifest.sh` | old machine | read-only tally of everything else worth moving |
| `handoff-restore.sh` | new machine | replays the staged git state |
| `restore-home-files.sh` | new machine | copies the carried home files back into place |
| `restore-git-leftovers.sh` | new machine | applies the staged patches, untracked files and stashes |
| `restore-claude-state.py` | new machine | merges Claude Code sessions, memory and history |
| `restore-delta-threads.py` | new machine | points those sessions back at their Delta threads |
| `restore-tmux.py` | new machine | rebuilds the tmux session |
| `restore-cleanup.sh` | new machine | deletes the extracted copy once it is restored |

All of them change nothing without `--apply` (the manifest never does), and
each documents itself under `--help`.

## On the old machine

1. Stop background agents. They commit while the snapshot is being taken.
2. `./handoff-collect.sh --apply --staging ~/LAPTOP_HANDOFF`
3. Move `~/LAPTOP_HANDOFF` whole, plus the P0 and P1 rows of its
   `manifest.tsv`. Leave out `~/.claude/jobs/*/tmp` and `~/.codex/packages`:
   both are large and regenerable.
4. Before erasing the machine, check from another device that the copy is
   readable. Nothing here is backed up anywhere else.

`~/developer/dbSDK` is under legal hold: it has no git remote and must never
be given one or pushed anywhere. Its bundle is a plain file. Move it as one.

## What the staging directory holds

```
git/<repo>.bundle            branches with commits on no remote, plus every
                             worktree's branch; whole history for dbSDK
git/worktrees.tsv            one row per worktree: path, branch, commit, upstream
git/dirty_<path>.patch       uncommitted changes to tracked files
git/untracked_<path>.tar.gz  untracked, non-ignored files
git/stash_<repo>_<n>.patch   each stash, indexed by git/stashes.tsv
tmux/session-plan.tsv        window, pane, cwd and command of the live session
tmux/pane_contents.tar.gz    scrollback of every pane
system/                      Brewfile, applications, versions, tailnet, ssh key inventory
manifest.tsv                 the tally, as measured on the old machine
*.unifi, *.unf               UniFi backups, if they were dropped in here
```

Each bundle depends only on commits that are on the remote's default branch, so
it stays usable even if other remote branches are rebased or deleted before the
restore. Paths in the tables are written relative to `~`.

## On the new machine

Extract what was moved into one directory, `DIR`, so that every file sits at
its old path relative to `~`: `DIR/LAPTOP_HANDOFF`, `DIR/.claude`,
`DIR/.codex` and so on, with the agent scratchpads from `/private/tmp` at
`DIR/private/tmp`. The `restore-*` scripts are in `handoff/` of the dotfiles
checkout and read from `--dump DIR` (default `~/Downloads`). Run each one bare
to read its plan, then again with `--apply`. They copy and never move, so `DIR`
stays whole until the last step, and re-running one adds only what is missing.

1. Sign in to 1Password and Bitwarden. Make an SSH key and add it to GitHub.
2. Clone dotfiles and run `./install.sh`. (`mac_setup.sh` is macOS-only.)
3. `restore-home-files.sh`. Puts back `~/.claude/CLAUDE.md`, the machine-wide
   agent rules, and `~/.claude/settings.json`; `~/.codex`; the shared SSH key
   and the old `known_hosts` entries; the `gcloud`, `gh` and `op`
   configuration; shell history, vim and nvim state and undo history, IPython,
   Jupyter; Desktop and Downloads. It also copies the staging directory and the
   scratchpads to `~/LAPTOP_HANDOFF`, their permanent home.
   - It goes first because `settings.json` carries `cleanupPeriodDays`. Without
     it Claude Code deletes transcripts older than 30 days the next time it
     starts, restored ones included.
   - The old machine's personal SSH key is not installed. Delete it from
     github.com/settings/keys once no host still depends on it.
   - `~/.config` is a real directory here, not a symlink into the dotfiles repo
     as on the Mac, so the configuration goes to `~/.config` itself. `htop`,
     `uv`, `fzf` and `fish` are left to this machine's installers.
4. Run `source-for-work.sh`, then
   `hgcreate git@github.com:arbor-neuroscience/arbor-fouragnan.git`, which it
   does not cover.
5. `DIR/LAPTOP_HANDOFF/handoff-restore.sh`. It only ever adds: existing
   checkouts and branches are left alone. Expect a failed `--set-upstream-to`
   for any branch that has since been deleted on the remote.
6. `restore-git-leftovers.sh`. Does what `handoff-restore.sh` lists under
   "Left to do by hand": applies each patch, unpacks each archive of untracked
   files, and recreates each stash with its original message. A worktree that
   lived outside the old home comes back detached at
   `<repo>/handoff-scratch/<name>`. A worktree that is not at the commit the
   old machine recorded is left alone. The dotfiles checkout is the usual
   case: it is already in use on some other branch by now, so switch it to the
   branch `worktrees.tsv` records before running this, or its uncommitted work
   is skipped.
7. Close every Claude Code session, then `restore-claude-state.py`.
   `~/.claude/projects` is keyed by a slug of the working directory, so each
   `-Users-bruno-*` directory is copied under this machine's
   `-home-bruno-*` name and merged into any directory already there (seven
   were, left by an earlier Linux machine and by sessions started here).
   `history.jsonl` and the `projects` entries of `~/.claude.json` carry
   absolute paths and get the same rewrite. `file-history` and `jobs` are
   copied as they are. Transcripts are not edited: paths inside them still
   name the old home.
8. With every Claude Code session still closed, and Delta installed and signed
   in, `restore-delta-threads.py`. The Delta plugin keeps which thread each
   session records into in `~/.claude/plugins/store/delta_*.json`, and a
   session resumed without its entry starts a new thread.
   - The old entries cannot be copied across. Delta numbers a session's
     records per machine, and the plugin refuses an entry that is ahead of
     Delta, so the script asks this machine's Delta about each thread and
     writes entries that fit its answers.
   - Run it before starting new sessions in the restored checkouts. A thread
     started here gives its checkout a second Delta worktree, and the script
     flags the old sessions that share that checkout.
   - Do one session first: `--session ID --apply`, then `claude --resume` it
     with the command the script prints, and check that Delta shows the old
     thread and takes a prompt. Then run it for the rest.
9. `restore-tmux.py`, from inside tmux and after step 5 so the directories
   exist. It restores the snapshot through tmux-resurrect as a second session,
   `mac`, leaving the running one alone. Windows, layouts, working directories
   and scrollback come back; editors are relaunched; everything else that was
   running (`claude --resume ...`, `ssh ...`) is listed for you to start again.
10. `gh auth login`, `gcloud auth login`, `tailscale up`, `twingate setup`.
11. `restore-cleanup.sh`, last. `DIR` holds an SSH private key and cloud
    credentials in the clear; this deletes the extracted files and keeps the
    archive they came from. It refuses unless the archive tests intact and
    `~/LAPTOP_HANDOFF` holds the bundles. An encrypted archive asks for its
    password during that test, so run it from a terminal.

## What nothing here carries

- **Keychain.** The `gh` token and app logins live there and do not transfer.
- **UniFi.** `unifi_os_backup_*.unifi` is the console's System Backup and
  restores everything, device adoption included. `network_site_*.unf` is a site
  export: configuration only, and it needs Network 10.6.109 or newer.
- **Signal.** Nothing to carry: link the new device and it syncs from the phone.
- **The Delta app's own data.** It was never on the manifest, and it held each
  session's record numbering and each checkout's worktree identity. Threads
  live in the account and come back on sign-in. `restore-delta-threads.py`
  rebuilds the plugin's side from Delta's answers; subagents' entries, and
  records the old machine had queued but not delivered, stay behind.
- **Gitignored files inside worktrees.** The patches and archives hold changes
  to tracked files and untracked files that are not ignored. A `.env` or a
  local settings file that git ignores is not staged.
- **A stash made on a commit that is no longer on any branch.** The bundles
  carry branches, not the commits stashes were made on. If that commit has
  since been amended or rebased away, the stash cannot be recreated and stays a
  patch under `~/LAPTOP_HANDOFF/git/`.

## How far this has been tested

`handoff-collect.sh` and `handoff-manifest.sh` have run for real on the old
machine. The restore side has run for real once, on 2026-11-18, from that Mac
onto Linux Mint 22.3 with tmux 3.4:

- `handoff-restore.sh` rebuilt four repos and twenty worktrees.
- `restore-home-files.sh` and `restore-claude-state.py` put everything in
  place: thirty project directories merged into twenty-four, none left under
  an old-home name.
- `restore-git-leftovers.sh` applied every patch and archive and recreated
  three of five stashes. The other two (`stash_arbor_0.patch`,
  `stash_arbor-fouragnan_0.patch`) were made on commits no branch holds any
  more, and remain patches.
- `restore-tmux.py` restored all ten windows and twenty-six panes with their
  layouts.

`claude --resume` has since found restored sessions from their renamed project
directories (`ff650e5d`, `debf6ef4`).

`restore-delta-threads.py` ran for real the same day and attached all 28 old
sessions to their original threads. Two were then resumed (`ff650e5d`,
`dbd21e4e`), and Delta holds what they have recorded since in those threads,
with their real checkouts attached. `delta thread status` can run out of time
inspecting a thread's worktrees, as it did for the `hugo-docs` threads in dry
runs; the script then asks `delta worktree list --thread`.

Not yet exercised: resuming a session whose checkout Delta also tracks as a
second worktree (the script's `caution` lines), continuing a subagent after
the move, and `restore-cleanup.sh --apply`.
