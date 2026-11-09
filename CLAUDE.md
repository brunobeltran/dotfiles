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

Steps that can only ever be done by a human (browser logins, `tailscale up`,
`twingate setup`, approving a macOS system extension) are left out of the
script entirely; mention them in the commit message or a comment, not as a
script step.

## When asked "what are the options"

Apply the rules above and recommend the single result they produce. List an
alternative only if the rules genuinely do not decide between two methods, and
say which rule is undecided. Verify the current upstream-recommended method
(vendor docs, `brew info`) before answering; do not list methods from memory.
