#!/bin/bash
# AgentUI's tests on macOS (the package's two test targets, Swift 6 mode,
# warnings as errors), built on Linux in the job's own container
# (agent_ui-jit: OS Server's cache in its ~/.bazelrc, the read token in its
# ~/.netrc) as macos_unit_test bundles (MODULE.bazel, BUILD.bazel), then run
# on a slot of OS Server's primary Mac (`oss machine lease mac`: a macOS user
# of its own on a VM that stays up, ready in seconds), not in a macOS VM
# leased for the job: the macOS VMs are left to the agents that need one
# (Logan, 3 Nov 2026). A bundle tagged `gui` (AgentUIPackageTests: it draws
# its views in windows) runs in the primary's GUI session (`--gui`).
#
#   Tools/ci/mac_vm_tests.sh [--logs <dir>]
#
# --logs gets each bundle's test.log and test.xml. The slot is the script's
# alone, released however it ends.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
OSS="/Applications/OS Server.app/Contents/Helpers/oss"
[ -x "$OSS" ] || OSS="$(command -v oss)"
me="$(basename "$0")"
# Xcode 27.2's SDK archive, in OS Server's files by its SHA-256.
SDK_SHA256="b1583e60f9fd35881b5a948ce71627079877f1ced7ea231e14d3c342dd389668"

logs=""
while [ $# -gt 0 ]; do
    case "$1" in
        --logs) logs="${2:?--logs takes a folder}"; shift 2 ;;
        *) echo "usage: Tools/ci/mac_vm_tests.sh [--logs <dir>]" >&2; exit 2 ;;
    esac
done

work="$(mktemp -d)"
slot=""
child=""
finished=""
cleanup() {
    local status=$?
    [ -n "$finished" ] || [ "$status" -ne 0 ] || status=1
    [ -z "$child" ] || kill "$child" 2> /dev/null || true
    [ -n "$slot" ] || slot="$(. "$work/lease" 2> /dev/null; printf '%s' "${OSS_ID:-}")"
    if [ -n "$slot" ]; then
        "$OSS" machine release "$slot" || echo "$me: slot $slot was not released: oss machine release $slot" >&2
    fi
    rm -rf "$work"
    exit "$status"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

# Long commands run in the background and are waited for, so a signal (the
# runner cancelling the job) reaches the trap at once, not when they end.
run() {
    "$@" &
    child=$!
    local status=0
    wait "$child" || status=$?
    child=""
    return "$status"
}

# The SDK archive from OS Server's files, its host the first of OSS_SERVERS
# (OSS_FILES_HOST names another).
host="${OSS_FILES_HOST:-}"
if [ -z "$host" ]; then
    host="${OSS_SERVERS:-}"
    host="${host%%[ ,]*}"
    host="${host#*://}"
    host="${host%%[:/]*}"
fi
[ -n "$host" ] || { echo "$me: no host for OS Server's files (OSS_SERVERS): set OSS_FILES_HOST" >&2; exit 1; }
echo "rewrite apple-sdks\.invalid/.* http://$host:7490/files/sha256/$SDK_SHA256" > "$work/downloader.cfg"
flags="--config=apple_on_linux --downloader_config=$work/downloader.cfg"

echo "::group::The tests, built on Linux"
cd "$ROOT"
targets="$(bazel query 'kind(macos_unit_test, //...)' 2> /dev/null)"
gui="$(bazel query 'attr(tags, "\bgui\b", kind(macos_unit_test, //...))' 2> /dev/null)"
# shellcheck disable=SC2086 # one target a word
run bazel build $flags --curses=no $targets
root="$(bazel info $flags execution_root 2> /dev/null)"
echo "::endgroup::"

echo "::group::A slot on the primary Mac"
started=$SECONDS
run "$OSS" machine lease mac --wait --minutes=30 --exports > "$work/lease"
slot="$(. "$work/lease"; printf '%s' "$OSS_ID")"
echo "Slot $slot, in $((SECONDS - started))s"
echo "::endgroup::"

echo "::group::The tests"
status=0
for target in $targets; do
    name="${target##*:}"
    # shellcheck disable=SC2086
    bundle="$root/$(bazel cquery $flags --output=files "$target" 2> /dev/null | grep '\.zip$')"
    out="$work/testlogs/$name"
    mkdir -p "$out"
    mode=""
    case " $(echo $gui) " in *" $target "*) mode="--gui" ;; esac
    started=$SECONDS
    result=0
    run timeout 900 "$OSS" machine xctest "$slot" --tests="$bundle" $mode --junit="$out/test.xml" > "$out/test.log" 2>&1 || result=$?
    [ "$result" -ne 124 ] || echo "stopped after 15 minutes" >> "$out/test.log"
    # A run that never started (stopped waiting for the slot's GUI session,
    # say) has no count: grep finds nothing, and without `|| true` set -e
    # would end the script here, before the failure and its log are shown.
    executed="$(grep -E 'Executed [0-9]+ tests?' "$out/test.log" | tail -1 | sed 's/^[[:space:]]*//' || true)"
    if [ "$result" -eq 0 ]; then
        echo "$name${mode:+ ($mode)} PASSED in $((SECONDS - started))s: ${executed:-no count}"
    else
        echo "$name${mode:+ ($mode)} FAILED ($result) in $((SECONDS - started))s: ${executed:-no count}"
        tail -40 "$out/test.log"
        status=1
    fi
done
echo "::endgroup::"
if [ -n "$logs" ]; then
    mkdir -p "$logs"
    cp -R "$work/testlogs/." "$logs/"
fi
[ "$status" -eq 0 ] || echo "::error::Test failed"
finished=1
exit "$status"
