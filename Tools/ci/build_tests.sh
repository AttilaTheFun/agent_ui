#!/bin/bash
# AgentUI's tests (the package's two test targets, Swift 6 mode, warnings as
# errors), built as macos_unit_test bundles (MODULE.bazel, BUILD.bazel) for
# one of GitHub's own Macs to run (Tools/ci/hosted_tests.sh, the test job).
# CI builds them at release verification alone (the build-tests job), on
# one of GitHub's `xcode-27` Macs with the Mac's own Xcode (27.2 where the
# image has it), nothing of Shireworks'. On Linux they build as before,
# with rules_applecross and Xcode 27.2's SDK archive from Shireworks' files
# (`--config=apple_on_linux`), for an agent's container.
#
#   Tools/ci/build_tests.sh <out>
#
# Out come each bundle's .zip, named for its target, and gui.txt: the
# targets tagged `gui` (AgentUIPackageTests: it draws its views in windows),
# one a line.
#
#   DEVELOPER_DIR  a Mac's Xcode (default: Xcode 27.2 where the image has it)
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
me="$(basename "$0")"
out="${1:?usage: Tools/ci/build_tests.sh <out>}"
mkdir -p "$out"
out="$(cd "$out" && pwd)"
# Xcode 27.2's SDK archive (Linux alone), in Shireworks' files by its SHA-256.
SDK_SHA256="b1583e60f9fd35881b5a948ce71627079877f1ced7ea231e14d3c342dd389668"

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

if [ "$(uname -s)" = Darwin ]; then
    # A Mac builds with its own Xcode.
    if [ -z "${DEVELOPER_DIR:-}" ] && [ -d /Applications/Xcode_27.2.app ]; then
        export DEVELOPER_DIR=/Applications/Xcode_27.2.app/Contents/Developer
    fi
    xcodebuild -version | head -1
    flags=""
    echo "This Mac: $(sysctl -n hw.ncpu) CPUs, $(($(sysctl -n hw.memsize) / 1073741824)) GB memory"
else
    # The SDK archive from Shireworks' files, at the address its API gives
    # (Tools/ci/shireworks.sh, copied from AttilaTheFun/shireworks).
    url="$(sh "$ROOT/Tools/ci/shireworks.sh" files-url "$SDK_SHA256")" \
        || { echo "$me: Shireworks didn't say where its files are (SHIREWORKS_GRANT or SHIREWORKS_SERVERS)" >&2; exit 1; }
    echo "rewrite apple-sdks\.invalid/.* $url" > "$work/downloader.cfg"
    flags="--config=apple_on_linux --downloader_config=$work/downloader.cfg"
    echo "This container: $(nproc) CPUs, $(awk '/MemTotal/ { printf "%.1f GB", $2 / 1048576 }' /proc/meminfo 2> /dev/null) memory"
fi

cd "$ROOT"
targets="$(bazel query 'kind(macos_unit_test, //...)' 2> /dev/null)"
bazel query 'attr(tags, "\bgui\b", kind(macos_unit_test, //...))' 2> /dev/null | sed 's/.*://' > "$out/gui.txt"
# And how much memory the build took (Tools/ci/memory_watch.sh), said
# whether it worked or not: a build the container's memory cut short is
# what the figure is for.
. "$ROOT/Tools/ci/memory_watch.sh"
memory_watch_start
built=0
# shellcheck disable=SC2086 # one target a word
bazel build $flags --curses=no $targets || built=$?
memory_watch_report "the tests' build"
[ "$built" -eq 0 ] || exit "$built"
root="$(bazel info $flags execution_root 2> /dev/null)"
for target in $targets; do
    # shellcheck disable=SC2086
    bundle="$(bazel cquery $flags --output=files "$target" 2> /dev/null | grep '\.zip$')"
    cp "$root/$bundle" "$out/${target##*:}.zip"
done
ls -l "$out"
