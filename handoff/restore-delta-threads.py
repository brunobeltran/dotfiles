#!/usr/bin/env python3
"""Points an old machine's Claude Code sessions back at the Delta threads they recorded into.

Changes nothing unless given --apply. Run with --help for what is written, what
Delta is asked, and examples.
"""

import argparse
import functools
import json
import os
import pathlib
import re
import shutil
import subprocess
import sys
import threading
import time

DESCRIPTION = """\
The Delta plugin keeps one entry per Claude Code session, naming the Delta
thread the session records into, in ~/.claude/plugins/store/delta_*.json. A
session resumed without its entry starts a new thread. This rebuilds the
entries of an old machine's store so that `claude --resume` carries each
session on in its original thread. With no flag it reports what --apply would
write, and still asks Delta the questions below.

An old entry cannot be copied as it is, so for each old session this asks
Delta, without changing anything there:

  delta thread status LINK --source claude-code --external-id SESSION
      the number this machine's Delta gives the session's next record, and
      the thread's worktrees
  delta worktree list --thread LINK
      the thread's worktrees again, when status ran out of time inspecting them
  delta thread watch LINK
      the items already in the thread
  delta worktree list
      what Delta already tracks in the session's checkout

and writes an entry holding

  - the thread, its link, and the audience and upload state Delta reports;
  - Delta's number for the next record. The old machine's count lived in its
    Delta app and did not travel, and the plugin refuses an entry that is
    ahead of Delta;
  - the session's checkout and transcript under this home directory. When the
    session resumes, the plugin itself adopts that checkout into the thread's
    worktree (`delta worktree mount REFERENCE DIR --existing-checkout`);
  - every item already in the thread, marked as seen, so the resumed session
    is not handed its own history as news.

Not carried: subagents' entries, so a subagent continued after the move
records into a new child thread; and records the old machine had queued but
not yet delivered.

A session is skipped, with the reason, when its transcript or checkout is not
on this machine, when Delta does not answer for its thread or the thread does
not list the session's worktree, or when it is already attached to that thread
here. Every other entry in this machine's store is left alone. An old session that was resumed here into a new thread is
pointed back at its old one.

The store is kept as <name>.pre-handoff before its first change. --apply also
saves the old machine's store under ~/LAPTOP_HANDOFF/delta-plugin-store/,
which later runs read once the extracted handoff under DIR is deleted. --apply
refuses while a Claude Code session is open, since an open one rewrites the
store.

The plugin forgets an entry 30 days after its session last ended, and here
that clock starts at the move. Running this again restores a forgotten entry.

Examples:
  ./restore-delta-threads.py
  ./restore-delta-threads.py --session ff650e5d
  ./restore-delta-threads.py --session ff650e5d --apply
  ./restore-delta-threads.py --apply
  ./restore-delta-threads.py --old-store /mnt/usb/delta-store.json --old-home /Users/bruno
"""

KEPT_SUFFIX = ".pre-handoff"
SAVED_OLD_STORE_DIR = "LAPTOP_HANDOFF/delta-plugin-store"
WATCH_SECONDS = 120

# What the plugin records for a thread item it will never show Claude.
NEVER_SHOWN = "omitted"

CWD_FIELD = re.compile(r'"cwd":\s*"((?:[^"\\]|\\.)*)"')


class DeltaRefused(Exception):
    pass


class Skipped(Exception):
    pass


def moved_path(path, old_home, new_home):
    if path == old_home or path.startswith(old_home + "/"):
        return new_home + path[len(old_home):]
    return path


def project_slug(path):
    """The name of the folder Claude Code files transcripts under for a session run in `path`."""
    return "".join(ch if ch.isascii() and ch.isalnum() else "-" for ch in path)


def worktree_id(reference):
    """A worktree reference is `<uuid>#t=<timeline>`; the timeline moves on, the uuid does not."""
    return reference.split("#", 1)[0]


def delta_json(*arguments):
    done = subprocess.run(["delta", "--json", *arguments], capture_output=True, text=True, check=False)
    try:
        answer = json.loads(done.stdout)
    except ValueError:
        answer = None
    error = answer.get("error") if isinstance(answer, dict) else None
    if isinstance(error, dict):
        raise DeltaRefused(error.get("message") or error.get("code") or json.dumps(error))
    if done.returncode != 0 or not isinstance(answer, dict):
        said = (done.stderr or done.stdout).strip().splitlines()
        raise DeltaRefused(said[-1] if said else f"delta exited with status {done.returncode}")
    return answer


@functools.cache
def thread_status(locator, producer):
    return delta_json("thread", "status", locator, "--source", "claude-code", "--external-id", producer)


@functools.cache
def references_attached_to(locator):
    return [tree["reference"] for tree in delta_json("worktree", "list", "--thread", locator).get("worktrees", [])]


@functools.cache
def thread_item_keys(locator):
    """The plugin's names for everything now in a thread: an item's id, or
    `comment:<id>`. None when the listing did not finish.

    `delta thread watch` prints the thread's items, then `live`, then stays
    connected, so it is stopped at `live`."""
    keys, finished = [], False
    with subprocess.Popen(
        ["delta", "--json", "thread", "watch", locator],
        stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True,
    ) as watch:
        deadline = threading.Timer(WATCH_SECONDS, watch.kill)
        deadline.start()
        try:
            for line in watch.stdout:
                if not line.strip():
                    continue
                event = json.loads(line)
                if event.get("error"):
                    break
                if event.get("type") == "item":
                    keys.append(event["item"]["id"])
                elif event.get("type") == "comment":
                    keys.append("comment:" + event["comment"]["id"])
                elif event.get("type") == "live":
                    finished = True
                    break
        except (ValueError, KeyError, TypeError, AttributeError):
            finished = False
        finally:
            deadline.cancel()
            watch.kill()
    return keys if finished else None


def references_by_checkout():
    tracked = {}
    for worktree in delta_json("worktree", "list").get("worktrees", []):
        for entry in worktree.get("directories", []):
            tracked.setdefault(os.path.realpath(entry["directory"]), []).append(worktree["reference"])
    return tracked


def resume_directory(transcript, relocate):
    """`claude --resume` finds a session only from the directory its transcript
    is filed under, which the transcript's own rows name."""
    with transcript.open(encoding="utf-8", errors="replace") as rows:
        for row in rows:
            for quoted in CWD_FIELD.findall(row):
                directory = relocate(json.loads(f'"{quoted}"'))
                if project_slug(directory) == transcript.parent.name:
                    return directory
    return None


def seen_ledger(thread, item_keys, old_ledger):
    """Marks everything now in the thread as never to be shown, except that what
    the old machine recorded having shown Claude is kept, so an item that is
    edited later is still corrected."""
    items = dict.fromkeys(item_keys, NEVER_SHOWN)
    if old_ledger and old_ledger.get("thread") == thread:
        items.update({key: shown for key, shown in old_ledger.get("items", {}).items() if key in items})
    return {"thread": thread, "items": items}


def thread_reference(locator, worktrees, old_reference):
    if worktrees.get("status") == "available":
        listed = [tree["reference"] for tree in worktrees.get("items", [])]
    else:
        try:
            listed = references_attached_to(locator)
        except DeltaRefused as refusal:
            raise Skipped(f"Delta could not list the thread's worktrees: {refusal}") from refusal
    if old_reference in listed:
        return old_reference
    same_worktree = [reference for reference in listed if worktree_id(reference) == worktree_id(old_reference)]
    if len(same_worktree) == 1:
        return same_worktree[0]
    raise Skipped(
        f"the thread lists {len(same_worktree)} timelines of the worktree this session worked in "
        f"({old_reference}); it lists: {', '.join(listed) or 'no worktrees'}"
    )


def entry_for(old, status, reference, checkout, transcript, now):
    entry = {
        "session": old["session"],
        "thread": status["thread_id"],
        "snapshot": old.get("snapshot", True),
        "next": status["producer"]["next_sequence"],
        "pending": [],
        "checkout": checkout,
        "checkoutReference": reference,
        "transcript": str(transcript),
        "endedAt": now,
    }
    for field in ("url", "visibility", "upload"):
        if status.get(field) is not None:
            entry[field] = status[field]
    registered = entry.get("url") and (status.get("upload") or {}).get("state") == "uploaded"
    if registered or old.get("uploaded"):
        entry["uploaded"] = True
    for field in ("title", "organization", "autoUpload", "producer", "continuedIn"):
        if field in old:
            entry[field] = old[field]
    return entry


def plan(old, old_ledger, here, tracked, relocate, now):
    """Returns the entry and seen-items ledger to store for one old session, and the
    lines that report them, or raises Skipped with the reason. The ledger is None
    when the thread's items could not be listed.

    `here` is this machine's entry for the session, if it has one; `tracked` is
    what `references_by_checkout()` returned."""
    session = old["session"]
    if here and here.get("thread") == old["thread"]:
        raise Skipped("already attached to this thread here; left alone")
    transcripts = sorted((pathlib.Path.home() / ".claude" / "projects").glob(f"*/{session}.jsonl"))
    if not transcripts:
        raise Skipped("its transcript is not on this machine")
    checkout = relocate(old.get("checkout") or "")
    if not os.path.isdir(checkout):
        raise Skipped(f"its checkout is not on this machine: {checkout or 'none was recorded'}")

    locator = old.get("url") or old["thread"]
    producer = old.get("producer", session)
    try:
        status = thread_status(locator, producer)
    except DeltaRefused as refusal:
        raise Skipped(f"Delta did not answer for {locator}: {refusal}") from refusal
    if status.get("thread_id") != old["thread"]:
        raise Skipped(f"{locator} now leads to a different thread")
    if (status.get("access") or {}).get("state") != "granted":
        raise Skipped("this Delta account has no access to the thread")
    numbering = status.get("producer") or {}
    if numbering.get("source") != "claude-code" or numbering.get("external_id") != producer:
        raise Skipped("Delta did not report this session's record numbering")
    reference = thread_reference(locator, status.get("worktrees") or {}, old.get("checkoutReference") or "")

    item_keys = thread_item_keys(locator)
    resume_from = resume_directory(transcripts[0], relocate)
    report = [
        f"thread   {status.get('url') or locator}",
        f"resume   cd {resume_from} && claude --resume {session}"
        if resume_from
        else f"resume   claude --resume {session}, from the directory it ran in",
        f"entry    next record {numbering['next_sequence']} ({old.get('next')} on the old machine), checkout {checkout}",
        f"seen     {len(item_keys)} items already in the thread"
        if item_keys is not None
        else "seen     NOT MARKED: Delta did not list the thread, so the session will be shown its newest items once",
    ]
    others = sorted(
        {worktree_id(r) for r in tracked.get(os.path.realpath(checkout), [])} - {worktree_id(reference)}
    )
    if others:
        report.append(
            f"caution  Delta already tracks {checkout} as worktree {', '.join(others)}, from a thread "
            "started on this machine; the resumed session may say it could not restore the checkout"
        )
    if here:
        report.append(f"replaces this machine's entry, which records into {here.get('url') or here.get('thread')}")
    entry = entry_for(old, status, reference, checkout, transcripts[0], now)
    ledger = None if item_keys is None else seen_ledger(status["thread_id"], item_keys, old_ledger)
    return entry, ledger, report


def only_store_in(directory):
    found = sorted(directory.glob("delta_*.json")) if directory.is_dir() else []
    return found[0] if len(found) == 1 else None


def write_private(path, text):
    path.parent.mkdir(parents=True, exist_ok=True)
    scratch = path.with_name(path.name + ".handoff-tmp")
    private = os.open(scratch, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    with open(private, "w", encoding="utf-8") as handle:
        handle.write(text)
    os.replace(scratch, path)


def running_sessions():
    found = subprocess.run(["pgrep", "-a", "-x", "claude"], capture_output=True, text=True, check=False)
    return found.stdout.splitlines()


def chosen(sessions, prefixes):
    if not prefixes:
        return sessions
    for prefix in prefixes:
        if not any(old["session"].startswith(prefix) for old in sessions):
            sys.exit(f"no old session starts with {prefix}")
    return [old for old in sessions if old["session"].startswith(tuple(prefixes))]


def main():
    parser = argparse.ArgumentParser(
        description=DESCRIPTION, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    parser.add_argument("--apply", action="store_true", help="write the entries")
    parser.add_argument(
        "--session", action="append", metavar="ID", help="only this old session, by id or its start; repeatable"
    )
    parser.add_argument("--dump", default="~/Downloads", metavar="DIR", help="where the handoff zip was extracted")
    parser.add_argument("--old-store", metavar="FILE", help="the old machine's store, when it is not under DIR")
    parser.add_argument("--old-home", default="/Users/bruno", help="home directory on the old machine")
    args = parser.parse_args()

    home = pathlib.Path.home()
    saved_dir = home / SAVED_OLD_STORE_DIR
    source = (
        pathlib.Path(args.old_store).expanduser()
        if args.old_store
        else only_store_in(pathlib.Path(args.dump).expanduser() / ".claude" / "plugins" / "store")
        or only_store_in(saved_dir)
    )
    if source is None or not source.is_file():
        sys.exit(f"no old store under {args.dump}/.claude/plugins/store or {saved_dir}; pass --old-store FILE")
    store_path = only_store_in(home / ".claude" / "plugins" / "store")
    if store_path is None:
        sys.exit("the Delta plugin has no store on this machine yet; start Claude Code with the plugin once first")
    if not shutil.which("delta"):
        sys.exit("the delta command is not on PATH; install Delta and sign in first")

    open_sessions = running_sessions()
    if open_sessions and args.apply:
        sys.exit(
            f"{len(open_sessions)} Claude Code sessions are open and would rewrite {store_path}. "
            "Close them all, then run this from a plain shell:\n  " + "\n  ".join(open_sessions)
        )
    if open_sessions:
        print(f"NOTE: {len(open_sessions)} Claude Code sessions are open; --apply refuses until they are closed.\n")

    old_store = json.loads(source.read_text(encoding="utf-8"))
    store = json.loads(store_path.read_text(encoding="utf-8"))
    sessions = chosen(
        [old for key, old in old_store.items() if key.startswith("session:") and old.get("thread")],
        args.session,
    )
    try:
        tracked = references_by_checkout()
    except DeltaRefused as refusal:
        sys.exit(f"Delta is not answering: {refusal}")
    relocate = functools.partial(moved_path, old_home=args.old_home.rstrip("/"), new_home=str(home))
    now = int(time.time() * 1000)

    planned = 0
    for old in sorted(sessions, key=lambda old: (old.get("checkout") or "", old.get("title") or "")):
        session = old["session"]
        print(f"{session[:8]}  {old.get('title') or '(untitled)'}")
        try:
            entry, ledger, report = plan(
                old, old_store.get(f"appended:{session}"), store.get(f"session:{session}"), tracked, relocate, now
            )
        except Skipped as reason:
            print(f"    skipped: {reason}\n")
            continue
        planned += 1
        print("".join(f"    {line}\n" for line in report))
        for key in [key for key in store if key.startswith((f"drawn:{session}:", f"child:{session}:"))]:
            del store[key]
        store[f"session:{session}"] = entry
        store.pop(f"appended:{session}", None)
        if ledger is not None:
            store[f"appended:{session}"] = ledger

    print(f"{planned} of {len(sessions)} old sessions {'written' if args.apply else 'to write'} in {store_path}")
    if not args.apply:
        print("Dry run: nothing was changed. Re-run with --apply.")
        return
    if saved_dir.parent.is_dir() and not (saved_dir / store_path.name).exists():
        write_private(saved_dir / store_path.name, source.read_text(encoding="utf-8"))
    if planned:
        kept = store_path.with_name(store_path.name + KEPT_SUFFIX)
        if not kept.exists():
            shutil.copy2(store_path, kept)
        write_private(store_path, json.dumps(store, indent=2, ensure_ascii=False) + "\n")


if __name__ == "__main__":
    main()
