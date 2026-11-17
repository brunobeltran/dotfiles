#!/usr/bin/env python3
"""Rebuilds the old machine's tmux session from its tmux-resurrect snapshot.

Changes nothing unless given --apply. Run with --help for how the snapshot is
adapted to this machine, what does not come back, and examples.
"""

import argparse
import json
import os
import pathlib
import socket
import subprocess
import sys
import tarfile
import time

DESCRIPTION = """\
Restores the tmux session saved in DIR/LAPTOP_HANDOFF/tmux, where DIR is where
the handoff zip was extracted, as a new session beside the ones already
running. With no flag it lists the windows, panes and working directories it
would create.

tmux-resurrect does the restoring. This script first makes the snapshot
restorable on this machine:
  - paths under the old home are rewritten to this one
  - the session is renamed, so no existing session or pane is touched
  - panes saved without a title are given one
  - window layouts are converted to the notation this tmux understands
It then puts the snapshot and its scrollback where resurrect looks for them
and runs resurrect's restore script.

Panes come back as shells in their old directory, with their scrollback.
Editors are relaunched by resurrect; anything else that was running is listed
so you can start it again. Run this from inside tmux, after the worktrees
exist.

Examples:
  ./restore-tmux.py
  ./restore-tmux.py --apply
  ./restore-tmux.py --apply --session work
"""

LINE_KINDS = ("pane", "window", "state", "grouped_session")
SHELLS = ("bash", "zsh", "sh", "fish")
RESTORE_SCRIPT = pathlib.Path.home() / ".tmux/plugins/tmux-resurrect/scripts/restore.sh"


def tmux(*arguments):
    done = subprocess.run(["tmux", *arguments], capture_output=True, text=True, check=False)
    return done.stdout.strip()


def read_snapshot(path):
    """A line that does not open with a known kind continues a multi-line
    command, the last field of the line before it."""
    lines = []
    for raw in path.read_text(encoding="utf-8").splitlines():
        fields = raw.split("\t")
        if fields[0] in LINE_KINDS:
            lines.append(fields)
        elif lines and raw.strip():
            lines[-1][-1] += "\n" + raw
    return lines


def layout_checksum(layout):
    """The 16-bit rotate-and-add checksum tmux requires in front of a layout."""
    checksum = 0
    for byte in layout.encode():
        checksum = ((checksum >> 1) + ((checksum & 1) << 15) + byte) & 0xFFFF
    return checksum


def layout_cells(node):
    size = "{w}x{h},{x},{y}".format(**node)
    if node["t"] == "p":
        return f"{size},{node['i']}"
    opening, closing = "[]" if node["t"] == "v" else "{}"
    return size + opening + ",".join(layout_cells(child) for child in node["c"]) + closing


def classic_layout(saved):
    """tmux 3.8 saves a window layout as JSON, which older tmux cannot apply.
    Converts it to the "<checksum>,WxH,X,Y[...]" notation, where [] stacks the
    cells of a "v" node and {} puts the cells of an "h" node side by side.

    classic_layout('{"V":2,"L":{"t":"p","w":295,"h":95,"x":0,"y":0,"i":0}}')
    returns 'cd5d,295x95,0,0,0'.
    """
    cells = layout_cells(json.loads(saved)["L"])
    return f"{layout_checksum(cells):04x},{cells}"


def adapted(lines, session, old_home, new_home):
    """Returns the snapshot as resurrect on this machine can restore it.

    resurrect splits fields on tabs treated as whitespace, so an empty pane
    title swallows a field: such panes were saved with their directory in the
    title's place and a stray pid before the command. They get this host's
    name as title, tmux's own default, which lines the fields up again.
    """
    title = socket.gethostname()
    result = []
    for fields in lines:
        kind = fields[0]
        if kind == "grouped_session":
            continue
        fields = [field.replace(old_home, new_home) for field in fields]
        if kind == "state":
            fields = ["state", session, ""]
        else:
            fields[1] = session
        if kind == "pane" and fields[6].startswith(":/"):
            fields = fields[:6] + [title] + fields[6:9] + [fields[-1]]
        if kind == "window" and fields[6].startswith("{"):
            fields[6] = classic_layout(fields[6])
        result.append(fields)
    return result


def snapshot_text(lines):
    return "".join("\t".join(field.split("\n")[0] for field in fields) + "\n" for fields in lines)


def describe(lines):
    names = {fields[2]: fields[3][1:] for fields in lines if fields[0] == "window"}
    for fields in lines:
        if fields[0] != "pane":
            continue
        window, pane, directory = fields[2], fields[5], fields[7][1:]
        process, command = fields[9], fields[10][1:]
        absent = "" if os.path.isdir(directory) else "   (no such directory yet)"
        print(f"  {window}.{pane}  {names.get(window, ''):<30} {directory}{absent}")
        if process not in SHELLS:
            for line in (command or process).split("\n"):
                print(f"        was running: {line}")


def repack_scrollback(source, destination, old_session, new_session):
    """Rewrites resurrect's scrollback archive for the renamed session: its
    members are named pane-<session>:<window>.<pane>. The ._* members macOS tar
    adds for extended attributes are dropped."""
    with tarfile.open(source) as old, tarfile.open(destination, "w:gz") as new:
        for member in old:
            name = os.path.basename(member.name)
            if not member.isfile() or name.startswith("._"):
                continue
            renamed = name.replace(f"pane-{old_session}:", f"pane-{new_session}:", 1)
            member.name = f"./pane_contents/{renamed}"
            member.pax_headers = {}
            new.addfile(member, old.extractfile(member))


def resurrect_dir():
    legacy =pathlib.Path.home() / ".tmux/resurrect"
    if legacy.is_dir():
        return legacy
    data_home = os.environ.get("XDG_DATA_HOME") or pathlib.Path.home() / ".local/share"
    return pathlib.Path(data_home) / "tmux/resurrect"


def restore(lines, source, old_session, session):
    """Installs the adapted snapshot as resurrect's latest and runs its restore.

    Resetting tmux-continuum's last-save time holds off its autosave, which
    would repoint `last` at a half-restored session. @resurrect-never-overwrite
    stops resurrect from replacing the existing pane when the server has only
    one.
    """
    directory = resurrect_dir()
    directory.mkdir(parents=True, exist_ok=True)
    snapshot = directory / source.name
    snapshot.write_text(snapshot_text(lines), encoding="utf-8")
    scrollback = source.with_name("pane_contents.tar.gz")
    if scrollback.is_file():
        repack_scrollback(scrollback, directory / "pane_contents.tar.gz", old_session, session)
    last = directory / "last"
    last.unlink(missing_ok=True)
    last.symlink_to(snapshot.name)

    tmux("set-option", "-g", "@continuum-save-last-timestamp", str(int(time.time())))
    earlier = tmux("show-option", "-gqv", "@resurrect-never-overwrite")
    tmux("set-option", "-g", "@resurrect-never-overwrite", "on")
    try:
        subprocess.run([str(RESTORE_SCRIPT)], check=False)
    finally:
        if earlier:
            tmux("set-option", "-g", "@resurrect-never-overwrite", earlier)
        else:
            tmux("set-option", "-gu", "@resurrect-never-overwrite")


def main():
    parser = argparse.ArgumentParser(
        description=DESCRIPTION, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    parser.add_argument("--apply", action="store_true", help="restore the session")
    parser.add_argument("--dump", default="~/Downloads", help="where the handoff zip was extracted")
    parser.add_argument("--old-home", default="/Users/bruno", help="home directory on the old machine")
    parser.add_argument("--session", default="mac", help="name for the restored session")
    args = parser.parse_args()

    staged = pathlib.Path(args.dump).expanduser().resolve() / "LAPTOP_HANDOFF/tmux"
    snapshots = sorted(staged.glob("tmux_resurrect_*.txt"))
    if not snapshots:
        sys.exit(f"no tmux_resurrect_*.txt under {staged}; pass --dump DIR")
    source = snapshots[-1]
    lines = read_snapshot(source)
    sessions = {fields[1] for fields in lines if fields[0] in ("pane", "window")}
    if len(sessions) != 1:
        sys.exit(f"{source} holds {len(sessions)} sessions; this restores exactly one")
    old_session = sessions.pop()
    lines = adapted(lines, args.session, args.old_home.rstrip("/"), str(pathlib.Path.home()))

    print(f"Session '{old_session}' from {source.name}, restored as '{args.session}':")
    describe(lines)
    if not args.apply:
        print("\nDry run: nothing was changed. Re-run with --apply from inside tmux.")
        return
    if not os.environ.get("TMUX"):
        sys.exit("run this from inside tmux")
    if not RESTORE_SCRIPT.is_file():
        sys.exit(f"tmux-resurrect is not installed at {RESTORE_SCRIPT}")
    exists = subprocess.run(["tmux", "has-session", "-t", f"={args.session}"], capture_output=True, check=False)
    if exists.returncode == 0:
        sys.exit(f"a session named '{args.session}' already exists; pass --session NAME")
    restore(lines, source, old_session, args.session)
    print(f"\nRestored as '{args.session}'. The session you ran this from is untouched.")


if __name__ == "__main__":
    main()
