#!/usr/bin/env bash
#
# Deletes the extracted copy of a machine handoff once it has been restored,
# keeping the zip it came from. Changes nothing unless given --apply. See
# usage() for the checks it makes first, and examples.
set -uo pipefail

DUMP="${HOME}/Downloads"
ZIP=""
MODE=dry-run

EXTRACTED_PATHS=(
    .ansible .bash_history .claude .claude.json .codex .config .ipython .jupyter
    .local .ssh .viminfo Desktop Downloads LAPTOP_HANDOFF developer private
)

usage() {
    cat <<'EOF'
restore-cleanup.sh [--apply] [--dump DIR] [--zip FILE]

Removes what the handoff zip unpacked into DIR (default: ~/Downloads): a
skeleton of the old home directory, which holds an ssh private key and cloud
credentials in the clear. The zip itself (default: DIR/bruno-handoff.zip) and
~/LAPTOP_HANDOFF are kept. With no flag it lists what --apply would delete.

--apply deletes nothing unless
  - DIR is not this home directory,
  - the zip passes an integrity test, which takes a minute, and
  - ~/LAPTOP_HANDOFF/git matches DIR/LAPTOP_HANDOFF/git, the copy that
    restore-home-files.sh makes.

Run it last, once every other restore script has been applied and checked.

Examples:
  ./restore-cleanup.sh
  ./restore-cleanup.sh --apply
  ./restore-cleanup.sh --dump /mnt/usb/extracted --zip /mnt/usb/bruno-handoff.zip
EOF
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
        --apply) MODE=apply ;;
        --dump | --zip)
            if [[ $# -lt 2 ]]; then
                echo "$1 needs a value" >&2
                exit 1
            fi
            if [[ "$1" == --dump ]]; then
                DUMP="$(cd "$2" && pwd)" || exit 1
            else
                ZIP="$2"
            fi
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

refuse() {
    echo "refusing: $*" >&2
    exit 1
}

check_nothing_is_lost() {
    echo "Testing ${ZIP} ..."
    unzip -tq "${ZIP}" || refuse "${ZIP} is missing or damaged"
    diff -rq "${DUMP}/LAPTOP_HANDOFF/git" "${HOME}/LAPTOP_HANDOFF/git" ||
        refuse "${HOME}/LAPTOP_HANDOFF/git is not a full copy; run restore-home-files.sh --apply first"
}

main() {
    parse_args "$@"
    ZIP="${ZIP:-${DUMP}/bruno-handoff.zip}"
    if [[ "${DUMP}" -ef "${HOME}" ]]; then
        refuse "${DUMP} is the home directory"
    fi
    if [[ ! -f "${DUMP}/LAPTOP_HANDOFF/manifest.tsv" ]]; then
        refuse "no extracted handoff under ${DUMP}; pass --dump DIR"
    fi
    if applying; then
        check_nothing_is_lost
    fi

    local path
    for path in "${EXTRACTED_PATHS[@]}"; do
        [[ -e "${DUMP}/${path}" ]] || continue
        note "$(du -sh "${DUMP}/${path}" | cut -f1)  ${DUMP}/${path}"
        run rm -rf -- "${DUMP:?}/${path}"
    done
    echo
    applying || echo "Dry run: nothing was deleted. Re-run with --apply."
}

main "$@"
