#!/bin/bash
# AgentUI's tests, built on Linux (Tools/ci/build_tests.sh, the build-tests
# job), run on one of GitHub's own Macs (`xcode-27`, the test job), which a
# public repository has for free, leaving OS Server's slots to CI and the
# agents (Logan, 5 Nov 2026). Each bundle runs in the runner's desktop
# session, where AgentUIPackageTests' windows draw, by Xcode's `xctest`
# (`xcrun xctest`, as for any macOS logic test), with Xcode 27.2, the SDK
# they are built with, where the image has it.
#
#   Tools/ci/hosted_tests.sh <bundles> [--logs <dir>]
#
# <bundles> holds build_tests.sh's out: each bundle's .zip. --logs gets each
# bundle's test.log. Fails when a bundle does, after every bundle.
set -euo pipefail
me="$(basename "$0")"
usage() { echo "usage: Tools/ci/hosted_tests.sh <bundles> [--logs <dir>]" >&2; exit 2; }
[ $# -ge 1 ] || usage
bundles="$(cd "$1" && pwd)"
shift
logs=""
while [ $# -gt 0 ]; do
    case "$1" in
        --logs) logs="${2:?--logs takes a folder}"; shift 2 ;;
        *) usage ;;
    esac
done
if [ -z "${DEVELOPER_DIR:-}" ] && [ -d /Applications/Xcode_27.2.app ]; then
    export DEVELOPER_DIR=/Applications/Xcode_27.2.app/Contents/Developer
fi
xcodebuild -version | head -1

work="$(mktemp -d)"
finished=""
# macOS's bash (3.2) runs this with $? 0 when an unset variable stops the
# script (set -eu): an end before the last line is a failure, whatever it says.
cleanup() {
    local status=$?
    [ -n "$finished" ] || [ "$status" -ne 0 ] || status=1
    rm -rf "$work"
    exit "$status"
}
trap cleanup EXIT

status=0
count=0
for zip in "$bundles"/*.zip; do
    [ -f "$zip" ] || continue
    count=$((count + 1))
    name="$(basename "$zip" .zip)"
    mkdir -p "$work/$name" "$work/logs/$name"
    ditto -x -k "$zip" "$work/$name"
    bundle="$(find "$work/$name" -maxdepth 1 -name '*.xctest' | head -1)"
    [ -n "$bundle" ] || { echo "::error::$name: no .xctest in its zip"; status=1; continue; }
    echo "::group::$name"
    started=$SECONDS
    result=0
    xcrun xctest "$bundle" > "$work/logs/$name/test.log" 2>&1 || result=$?
    # A run that never started has no count: grep finds nothing, and without
    # `|| true` set -e would end the script here, before its log is shown.
    executed="$(grep -E 'Executed [0-9]+ tests?' "$work/logs/$name/test.log" | tail -1 | sed 's/^[[:space:]]*//' || true)"
    grep -E "error:|failed \(" "$work/logs/$name/test.log" | head -40 || true
    echo "::endgroup::"
    if [ "$result" -eq 0 ]; then
        echo "$name PASSED in $((SECONDS - started))s: ${executed:-no count}"
    else
        echo "$name FAILED ($result) in $((SECONDS - started))s: ${executed:-no count}"
        tail -40 "$work/logs/$name/test.log"
        status=1
    fi
done
[ "$count" -gt 0 ] || { echo "$me: no bundles in $bundles" >&2; status=1; }
if [ -n "$logs" ]; then
    mkdir -p "$logs"
    cp -R "$work/logs/." "$logs/"
fi
[ "$status" -eq 0 ] || echo "::error::Test failed"
finished=1
exit "$status"
