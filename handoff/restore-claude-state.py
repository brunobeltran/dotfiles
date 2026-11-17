#!/usr/bin/env python3
"""Merges the Claude Code state of an extracted machine handoff into ~/.claude.

Changes nothing unless given --apply. Run with --help for what is merged, how
collisions are handled, and examples.
"""

import argparse
import json
import os
import pathlib
import shutil
import subprocess
import sys

DESCRIPTION = """\
Merges Claude Code state from DIR/.claude and DIR/.claude.json, where DIR is
where the handoff zip was extracted, into this machine's ~/.claude. With no
flag it reports what --apply would do.

  projects/       each directory is copied under the name Claude Code derives
                  from the same path beneath this home, joining any directory
                  already there. Existing files are kept; a MEMORY.md present
                  on both sides gains the index lines it lacks.
  file-history/   copied; existing files are kept
  jobs/           copied; existing files are kept
  history.jsonl   rows from both machines in time order, with project paths
                  under the old home rewritten
  ~/.claude.json  the per-project entries this machine lacks, re-keyed

Transcripts are copied as they are: paths inside them still name the old home.
history.jsonl and ~/.claude.json are kept beside the new ones as
<name>.pre-handoff. Re-running is safe: it adds only what is still missing.

--apply refuses to run until restore-home-files.sh has installed
settings.json, whose cleanupPeriodDays keeps old transcripts from being
deleted. Close every Claude Code session first: an open one can rewrite
~/.claude.json and drop the entries added here.

Examples:
  ./restore-claude-state.py
  ./restore-claude-state.py --apply
  ./restore-claude-state.py --dump /mnt/usb/extracted --old-home /Users/bruno
"""

KEPT_SUFFIX = ".pre-handoff"


def project_slug(path):
    """Claude Code keeps a project's sessions in a directory named after its
    working directory, with every character but ASCII letters and digits
    replaced by '-': /home/bruno/arbor.git becomes -home-bruno-arbor-git."""
    return "".join(ch if ch.isascii() and ch.isalnum() else "-" for ch in path)


def moved_path(path, old_home, new_home):
    if path == old_home or path.startswith(old_home + "/"):
        return new_home + path[len(old_home):]
    return path


def moved_project_name(name, old_home, new_home):
    old_slug, new_slug = project_slug(old_home), project_slug(new_home)
    if name == old_slug or name.startswith(old_slug + "-"):
        return new_slug + name[len(old_slug):]
    return name


def add_missing_lines(source, destination, apply):
    """Meant for MEMORY.md, an index of one line per memory."""
    have = destination.read_text(encoding="utf-8")
    known = set(have.splitlines())
    missing = [
        line
        for line in source.read_text(encoding="utf-8").splitlines()
        if line.strip() and line not in known
    ]
    if missing and apply:
        separator = "" if not have or have.endswith("\n") else "\n"
        with destination.open("a", encoding="utf-8") as handle:
            handle.write(separator + "\n".join(missing) + "\n")
    return len(missing)


def merge_tree(source, destination, apply):
    copied = kept = index_lines = 0
    for folder, subfolders, files in os.walk(source):
        target = destination / os.path.relpath(folder, source)
        links = [name for name in subfolders if os.path.islink(os.path.join(folder, name))]
        for name in files + links:
            origin, copy = pathlib.Path(folder, name), target / name
            if not os.path.lexists(copy):
                copied += 1
                if apply:
                    target.mkdir(parents=True, exist_ok=True)
                    shutil.copy2(origin, copy, follow_symlinks=False)
            elif name == "MEMORY.md":
                index_lines += add_missing_lines(origin, copy, apply)
            else:
                kept += 1
    return copied, kept, index_lines


def replace_text(path, text):
    """Swaps in new contents atomically with the old file's permissions,
    keeping the first version ever replaced as <name>.pre-handoff."""
    scratch = path.with_name(path.name + ".handoff-tmp")
    private = os.open(scratch, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    with open(private, "w", encoding="utf-8") as handle:
        handle.write(text)
    if path.exists():
        kept = path.with_name(path.name + KEPT_SUFFIX)
        if not kept.exists():
            shutil.copy2(path, kept)
        shutil.copymode(path, scratch)
    os.replace(scratch, path)


def merge_projects(dump_claude, live_claude, old_home, new_home, apply):
    print("\n== projects")
    verb = "copied" if apply else "to copy"
    for source in sorted(entry for entry in (dump_claude / "projects").iterdir() if entry.is_dir()):
        name = moved_project_name(source.name, old_home, new_home)
        copied, kept, index_lines = merge_tree(source, live_claude / "projects" / name, apply)
        renamed = "" if name == source.name else f" -> {name}"
        merged = f", {index_lines} MEMORY.md lines added" if index_lines else ""
        print(f"  {source.name}{renamed}: {copied} {verb}, {kept} already there{merged}")


def merge_session_keyed_tree(name, dump_claude, live_claude, apply):
    print(f"\n== {name}")
    source = dump_claude / name
    if not source.is_dir():
        print(f"  not in the dump: {source}")
        return
    copied, kept, _ = merge_tree(source, live_claude / name, apply)
    print(f"  {copied} {'copied' if apply else 'to copy'}, {kept} already there")


def history_rows(path, old_home, new_home):
    rows = []
    if not path.is_file():
        return rows
    for line in path.read_text(encoding="utf-8").splitlines():
        if not line.strip():
            continue
        try:
            row = json.loads(line)
        except json.JSONDecodeError:
            row = None
        if not isinstance(row, dict):
            rows.append((0, line))
            continue
        project = row.get("project")
        if isinstance(project, str) and moved_path(project, old_home, new_home) != project:
            row["project"] = moved_path(project, old_home, new_home)
            line = json.dumps(row, ensure_ascii=False, separators=(",", ":"))
        timestamp = row.get("timestamp")
        rows.append((timestamp if isinstance(timestamp, (int, float)) else 0, line))
    return rows


def merge_history(dump_claude, live_claude, old_home, new_home, apply):
    print("\n== history.jsonl")
    live = live_claude / "history.jsonl"
    ours = set(history_rows(live, old_home, new_home))
    theirs = set(history_rows(dump_claude / "history.jsonl", old_home, new_home))
    merged = sorted(ours | theirs)
    gained = len(merged) - len(ours)
    print(f"  {gained} rows {'added' if apply else 'to add'} to the {len(ours)} already there")
    if apply and gained:
        replace_text(live, "".join(line + "\n" for _, line in merged))


def merge_project_entries(dump, old_home, new_home, apply):
    print("\n== ~/.claude.json")
    live = pathlib.Path.home() / ".claude.json"
    saved = dump / ".claude.json"
    if not saved.is_file() or not live.is_file():
        print(f"  needs both {saved} and {live}; skipped")
        return
    theirs = json.loads(saved.read_text(encoding="utf-8")).get("projects", {})
    config = json.loads(live.read_text(encoding="utf-8"))
    ours = config.setdefault("projects", {})
    added = 0
    for key, entry in theirs.items():
        moved = moved_path(key, old_home, new_home)
        if moved in ours:
            print(f"  kept this machine's entry: {moved}")
        else:
            ours[moved] = entry
            added += 1
            print(f"  {'added' if apply else 'to add'}: {moved}")
    if apply and added:
        replace_text(live, json.dumps(config, indent=2, ensure_ascii=False) + "\n")


def keeps_old_transcripts(live_claude):
    """Claude Code deletes transcripts older than cleanupPeriodDays when it
    starts, and uses 30 days when the setting is absent."""
    try:
        settings = json.loads((live_claude / "settings.json").read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return False
    return isinstance(settings, dict) and "cleanupPeriodDays" in settings


def running_sessions():
    found = subprocess.run(["pgrep", "-a", "-x", "claude"], capture_output=True, text=True, check=False)
    return found.stdout.splitlines()


def main():
    parser = argparse.ArgumentParser(
        description=DESCRIPTION, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    parser.add_argument("--apply", action="store_true", help="make the changes")
    parser.add_argument("--dump", default="~/Downloads", help="where the handoff zip was extracted")
    parser.add_argument("--old-home", default="/Users/bruno", help="home directory on the old machine")
    args = parser.parse_args()

    dump = pathlib.Path(args.dump).expanduser().resolve()
    dump_claude, live_claude = dump / ".claude", pathlib.Path.home() / ".claude"
    old_home, new_home = args.old_home.rstrip("/"), str(pathlib.Path.home())

    if not (dump_claude / "projects").is_dir():
        sys.exit(f"no .claude/projects under {dump}; pass --dump DIR")
    if args.apply and not keeps_old_transcripts(live_claude):
        sys.exit(
            f"{live_claude}/settings.json sets no cleanupPeriodDays, so Claude Code would delete "
            "the older transcripts copied here. Run restore-home-files.sh --apply first."
        )
    sessions = running_sessions()
    if sessions:
        print(
            f"WARNING: {len(sessions)} Claude Code processes are running. One of them can rewrite "
            "~/.claude.json and drop the entries added here; close them, or re-run this afterwards."
        )

    merge_projects(dump_claude, live_claude, old_home, new_home, args.apply)
    merge_session_keyed_tree("file-history", dump_claude, live_claude, args.apply)
    merge_session_keyed_tree("jobs", dump_claude, live_claude, args.apply)
    merge_history(dump_claude, live_claude, old_home, new_home, args.apply)
    merge_project_entries(dump, old_home, new_home, args.apply)

    if not args.apply:
        print("\nDry run: nothing was changed. Re-run with --apply.")


if __name__ == "__main__":
    main()
