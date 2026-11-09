# Working in this repo

Personal dotfiles plus a single bootstrap script, `install.sh`, that must take a
fresh Mac or Debian box (possibly without `sudo`) to a fully working setup in
one run. `mac_setup.sh` is only for macOS `defaults`-style system settings; it
never installs software.

The header comment of `install.sh` lists the mechanical rules (build dir, full
path idempotency checks, `${HOME}`, user-mode installs). Read it before editing.
The rules below are the decision rules that the header does not spell out.

## Adding something to install.sh

Follow these in order. The first rule that applies decides; do not present the
later ones as alternatives.

1. **One script.** Everything installable goes in `install.sh`, in the
   OS-specific branch if it is OS-specific. Never propose a new script, a
   "privileged" script, or a README-only instruction instead.
2. **Use upstream's recommended install method, verbatim.** If the vendor
   documents a one-liner (`curl ... | sh`), use that exact line. Do not
   re-implement what it does (apt repo setup, keyrings, distro detection), do
   not vendor a tarball when a package exists, and do not pick a less-blessed
   variant for "purity" reasons. Check the vendor docs for what is currently
   recommended rather than guessing.
3. **macOS GUI apps are Homebrew casks**, added directly to the `brew install`
   lines in the darwin branch. Prefer the cask that wraps the vendor's own
   standalone `.pkg` over App Store or CLI-only variants.
4. **User mode is preferred, not required.** When a tool fundamentally needs
   root (a VPN daemon, a kernel/system extension), install it the blessed way
   with `sudo` anyway. Do not search for a rootless workaround, do not
   downgrade functionality to avoid `sudo`, and do not skip the tool.
5. **Non-essential steps must never abort the script.** Wrap anything that
   touches the network as root, needs interactive approval, or could plausibly
   fail on a locked-down machine in a subshell with
   `( ... ) || _warn_loudly "..." "Retry by hand: ..."`. `_warn_loudly` prints
   a very visible warning and sleeps `${LONG_ENOUGH_TO_READ}` seconds. Core
   steps (package manager bootstrap, stow, neovim) stay fatal.
6. **Idempotency via full paths.** Gate each step on the exact file the install
   is expected to produce (`/usr/bin/foo`, `${HOME}/.local/bin/foo`,
   `/Applications/Foo.app`), never `command -v`.
7. **Environment setup runs unconditionally; only the install it enables is
   gated.** Anything a later step depends on (`export PATH=...` to pick up
   brew or GNU coreutils, `source`-ing an env file, setting a variable) must
   execute on every run, outside any idempotency `if`. Only the install that
   produces the gated file goes inside the `if`. A guard around the setup
   means a rerun on an already-bootstrapped machine silently runs with the
   wrong tools.
8. **Never assume GNU tools on macOS.** `/usr/bin` has BSD `realpath`, `sed`,
   `stat`, etc. with different flags. Any step that needs GNU flags must run
   after the gnubin `PATH` export in the darwin branch, and a flag that only
   GNU supports is a hint to check which binary will actually be found.
9. **The repo is the source of truth; `install.sh` never deletes or overwrites
   anything under `dotfiles/`.** Adopting a pre-existing live directory means
   moving it aside and pulling *missing* entries into the repo folder, never
   `rm -rf` of the repo folder or copying the live tree over it. Remember the
   live tree is usually full of symlinks back into the repo from an earlier
   run; copying those over the real files destroys the tracked content.

Steps that can only ever be done by a human (browser logins, `tailscale up`,
`twingate setup`, approving a macOS system extension) are left out of the
script entirely; mention them in the commit message or a comment, not as a
script step.

## When asked "what are the options"

Apply the rules above and recommend the single result they produce. List an
alternative only if the rules genuinely do not decide between two methods, and
say which rule is undecided. Verify the current upstream-recommended method
(vendor docs, `brew info`) before answering; do not list methods from memory.
