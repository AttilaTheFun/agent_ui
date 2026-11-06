#!/bin/bash
# AgentUI's proof, on one of GitHub's own Macs (`xcode-27`: Xcode 27.2 and
# its iOS simulators), which a public repository has for free, leaving OS
# Server's macOS VMs to the agents (Logan, 5 Nov 2026): the four demo apps
# built and pictured by Tools/proof.sh, and each picture compared with the
# one kept for it at the base (CI: the previous release, else the commit
# before; else this commit).
#
#   Tools/ci/hosted_proof.sh --proof <dir> [--kind quick|full] [--base <revision>]
#
# The proof, in <dir>, as Reviews reads it from the run's `proof` artifact:
#   screens/<name>.png  each demo app's first screen at this commit
#   before/<name>.png   each that differs, as kept at the base (none for a
#                       screen the base hasn't got)
#   diffs/<name>.png    each that differs from its picture kept at the base (Tests/Proof),
#                       its changed pixels red (Tools/ci/snapshot_diff.swift,
#                       CoreGraphics)
#   proof.json          {"commit", "ref", "kind", "run", "base": {"commit"},
#                        "screens": [{"name", "changed", "changedPixels"}]}
# The script fails as Tools/proof.sh does, or when no picture comes back.
#
#   PROOF_REF      the ref the proof is of (default: GITHUB_REF, else the branch)
#   DEVELOPER_DIR  the Xcode (default: Xcode 27.2 where the image has it)
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
me="$(basename "$0")"
XCODEGEN_URL="https://github.com/yonaskolb/XcodeGen/releases/download/2.46.0/xcodegen.zip"
XCODEGEN_SHA256="4d9e34b62172d645eed6457cac13fc222569974098ef4ee9c3368bedf0196806"

usage() { echo "usage: Tools/ci/hosted_proof.sh --proof <dir> [--kind quick|full] [--base <revision>]" >&2; exit 2; }
proof=""
kind="quick"
base="HEAD"
while [ $# -gt 0 ]; do
    case "$1" in
        --proof) proof="${2:?--proof takes a folder}"; shift 2 ;;
        --kind) kind="${2:?--kind takes quick or full}"; shift 2 ;;
        --base) base="${2:?--base takes a revision}"; shift 2 ;;
        *) usage ;;
    esac
done
[ -n "$proof" ] || usage
case "$kind" in quick | full) ;; *) usage ;; esac
if [ -z "${DEVELOPER_DIR:-}" ] && [ -d /Applications/Xcode_27.2.app ]; then
    export DEVELOPER_DIR=/Applications/Xcode_27.2.app/Contents/Developer
fi

commit="$(git -C "$ROOT" rev-parse HEAD)"
base_commit="$(git -C "$ROOT" rev-parse --verify "$base^{commit}")" || { echo "$me: no revision $base to compare with" >&2; exit 1; }
ref="${PROOF_REF:-${GITHUB_REF:-refs/heads/$(git -C "$ROOT" branch --show-current)}}"

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

echo "::group::Xcode, XcodeGen and the diff tool"
xcodebuild -version | head -1
xcrun simctl list runtimes | grep -i '^ios' || true
# XcodeGen's release, checked against the sum above.
curl -fsSL -o "$work/xcodegen.zip" "$XCODEGEN_URL"
echo "$XCODEGEN_SHA256  $work/xcodegen.zip" | shasum -a 256 -c - > /dev/null
(cd "$work" && unzip -q -o xcodegen.zip && chmod +x xcodegen/bin/xcodegen)
export PATH="$work/xcodegen/bin:$PATH"
# The diff tool before the apps: a broken one fails before they're built.
xcrun swiftc -O -o "$work/snapshot_diff" "$ROOT/Tools/ci/snapshot_diff.swift"
# The pictures kept at the base, what the screens are compared with.
mkdir -p "$work/base"
git -C "$ROOT" archive "$base_commit" Tests/Proof | tar -x -C "$work/base"
echo "::endgroup::"

echo "::group::Tools/proof.sh: the demo apps, built and pictured"
status=0
(cd "$ROOT" && PROOF_DIR="$work/out" Tools/proof.sh ci) || status=$?
echo "::endgroup::"

# The proof, from the screens and how each compared with the base.
json() { printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'; }
mkdir -p "$proof/screens" "$proof/diffs" "$proof/before"
screens=""
summary=""
for picture in "$work/out/review-ios"/*.png; do
    [ -e "$picture" ] || continue
    name="$(basename "$picture" .png)"
    kept="$work/base/Tests/Proof/$name.png"
    cp "$picture" "$proof/screens/$name.png"
    if ! pixels="$("$work/snapshot_diff" "$kept" "$picture" "$work/diff.png")"; then
        echo "$me: $name was not compared" >&2
        [ "$status" -ne 0 ] || status=1
        continue
    fi
    changed=false
    if [ "$pixels" -ne 0 ]; then
        changed=true
        [ ! -f "$work/diff.png" ] || mv "$work/diff.png" "$proof/diffs/$name.png"
        [ ! -f "$kept" ] || cp "$kept" "$proof/before/$name.png"
    fi
    rm -f "$work/diff.png"
    screens="$screens${screens:+,}
    {\"name\": \"$(json "$name")\", \"changed\": $changed, \"changedPixels\": $pixels}"
    summary="$summary| $name | $([ "$changed" = true ] && echo "$pixels pixels changed" || echo unchanged) |
"
done
cp "$work/out/review-ios/manifest.json" "$proof/" 2> /dev/null || true
cp "$work/out"/build-*.log "$proof/" 2> /dev/null || true
cat > "$proof/proof.json" << EOF
{
  "commit": "$commit",
  "ref": "$(json "$ref")",
  "kind": "$kind",
  "run": ${GITHUB_RUN_ID:-null},
  "base": {"commit": "$base_commit"},
  "screens": [$screens
  ]
}
EOF
cat "$proof/proof.json"
if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
    printf '### Proof (%s) of %s\n\n| Screen | Against its picture kept at %s |\n| --- | --- |\n%s' "$kind" "${commit:0:7}" "${base_commit:0:7}" "$summary" >> "$GITHUB_STEP_SUMMARY"
fi

if [ -z "$screens" ]; then
    echo "$me: no pictures came back" >&2
    [ "$status" -ne 0 ] || status=1
fi
finished=1
exit "$status"
