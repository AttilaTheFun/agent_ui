#!/bin/bash
# AgentUI's proof, in a macOS VM leased from OS Server (xcode_27_2: Xcode
# 27.2 and its iOS simulator): the four demo apps built and pictured by
# Tools/proof.sh there, and each picture compared with the one kept for it
# at the base (CI: the commit before, so a change that takes new pictures
# shows as a change; else this commit).
#
#   Tools/ci/mac_vm_proof.sh --proof <dir> [--kind quick|full] [--base <revision>]
#
# The proof, in <dir>, as Reviews reads it from the run's `proof` artifact:
#   screens/<name>.png  each demo app's first screen at this commit
#   diffs/<name>.png    each that differs from its picture kept at the base (Tests/Proof),
#                       its changed pixels red (Tools/ci/snapshot_diff.swift,
#                       built here)
#   proof.json          {"commit", "ref", "kind", "run", "base": {"commit"},
#                        "screens": [{"name", "changed", "changedPixels"}]}
# The script fails as Tools/proof.sh does, or when no picture comes back.
#
#   PROOF_REF  the ref the proof is of (default: GITHUB_REF, else the branch)
#
# The VM is the script's alone: leased for an hour, renewed while it runs,
# released however it ends (a kill nothing can trap leaves it an hour at
# most). The committed tree goes in (git archive HEAD), with XcodeGen, which
# the image may not have: its release, checked against the sum below.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
XCODEGEN_URL="https://github.com/yonaskolb/XcodeGen/releases/download/2.46.0/xcodegen.zip"
XCODEGEN_SHA256="4d9e34b62172d645eed6457cac13fc222569974098ef4ee9c3368bedf0196806"

usage() { echo "usage: Tools/ci/mac_vm_proof.sh --proof <dir> [--kind quick|full] [--base <revision>]" >&2; exit 2; }
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

commit="$(git -C "$ROOT" rev-parse HEAD)"
base_commit="$(git -C "$ROOT" rev-parse --verify "$base^{commit}")" || { echo "mac_vm_proof.sh: no revision $base to compare with" >&2; exit 1; }
ref="${PROOF_REF:-${GITHUB_REF:-refs/heads/$(git -C "$ROOT" branch --show-current)}}"
OSS="/Applications/OS Server.app/Contents/Helpers/oss"
[ -x "$OSS" ] || OSS="$(command -v oss)"

work="$(mktemp -d)"
chmod 700 "$work"
lease=""
renewer=""
child=""

# The VM given back now, not left to its hour.
release() {
    if [ -n "$renewer" ]; then
        kill "$renewer" 2> /dev/null || true
        wait "$renewer" 2> /dev/null || true
        renewer=""
    fi
    # A lease asked for as the script was stopped: its id, if it came.
    [ -n "$lease" ] || lease="$(. "$work/lease" 2> /dev/null; printf '%s' "${OSS_ID:-}")"
    if [ -n "$lease" ]; then
        "$OSS" machine release "$lease" || echo "mac_vm_proof.sh: lease $lease was not released: oss machine release $lease" >&2
        lease=""
        rm -f "$work/lease"
    fi
}
# macOS's bash (3.2) runs this with $? 0 when an unset variable stops the
# script (set -eu): an end before the last line is a failure, whatever it says.
finished=""
cleanup() {
    local status=$?
    [ -n "$finished" ] || [ "$status" -ne 0 ] || status=1
    [ -z "$child" ] || kill "$child" 2> /dev/null || true
    release
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
vm() { "$OSS" machine ssh "$lease" --identity="$work/key" -- "$@"; }

# The diff tool and XcodeGen first: nothing leased if either fails. And the
# pictures kept at the base, what the screens are compared with.
xcrun swiftc -O -o "$work/snapshot_diff" "$ROOT/Tools/ci/snapshot_diff.swift"
mkdir "$work/base"
git -C "$ROOT" archive "$base_commit" Tests/Proof | tar -x -C "$work/base"
mkdir "$work/vm"
curl -fsSL -o "$work/xcodegen.zip" "$XCODEGEN_URL"
echo "$XCODEGEN_SHA256  $work/xcodegen.zip" | shasum -a 256 -c - > /dev/null
unzip -q -d "$work/vm" "$work/xcodegen.zip"

echo "::group::A macOS VM (xcode_27_2)"
# A key of the run's own for the VM's SSH, gone with the run.
ssh-keygen -q -t ed25519 -N '' -C agent_ui-ci -f "$work/key"
run "$OSS" machine lease macos --config=xcode_27_2 --minutes=60 --wait --key="$work/key.pub" --exports > "$work/lease"
lease="$(. "$work/lease"; printf '%s' "$OSS_ID")"
echo "Leased $lease"
# Renewed every ten minutes; told to stop, it stops its sleep too.
(
    trap 'kill $! 2> /dev/null; exit 0' TERM
    while :; do
        sleep 600 &
        wait $!
        "$OSS" machine renew "$lease" --minutes=60 > /dev/null || true
    done
) &
renewer=$!
for _ in $(seq 1 30); do vm true 2> /dev/null && break; sleep 5; done

# The tree as committed, XcodeGen, and what the VM runs, into ~/ci there.
git -C "$ROOT" archive --format=tar.gz -o "$work/vm/tree.tar.gz" HEAD
cat > "$work/vm/in_vm.sh" << 'EOF'
#!/bin/bash
# In the VM, in ~/ci: the tree in src/, XcodeGen in xcodegen/.
set -uo pipefail
cd ~/ci
export PATH="$HOME/ci/xcodegen/bin:/usr/bin:/bin:/usr/sbin:/sbin"
case "$1" in
    unpack)
        mkdir -p src && tar -xzf tree.tar.gz -C src && chmod +x xcodegen/bin/xcodegen || exit
        xcodebuild -version | head -1
        xcrun simctl list runtimes | grep -i '^ios'
        ;;
    proof)
        # Not a git checkout: the version is the run's business, not the tag's.
        rm -rf ~/ci/out && cd src && PROOF_DIR="$HOME/ci/out" Tools/proof.sh ci
        ls ~/ci/out/review-ios/*.png
        ;;
esac
EOF
run "$OSS" machine upload "$lease" --identity="$work/key" "$work/vm" ci
run vm bash ci/in_vm.sh unpack
echo "::endgroup::"

echo "::group::Tools/proof.sh: the demo apps, built and pictured"
status=0
run vm bash ci/in_vm.sh proof || status=$?
# scp makes the folder (one already here would get it inside).
run "$OSS" machine download "$lease" --identity="$work/key" ci/out/review-ios "$work/recorded" || mkdir -p "$work/recorded"
echo "::endgroup::"
release

# The proof, from the pictures and the ones kept at the base.
json() { printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'; }
mkdir -p "$proof/screens" "$proof/diffs"
screens=""
summary=""
for picture in "$work/recorded"/*.png; do
    [ -e "$picture" ] || continue
    name="$(basename "$picture" .png)"
    cp "$picture" "$proof/screens/$name.png"
    pixels="$("$work/snapshot_diff" "$work/base/Tests/Proof/$name.png" "$picture" "$proof/diffs/$name.png")"
    changed=false
    [ "$pixels" -eq 0 ] || changed=true
    screens="$screens${screens:+,}
    {\"name\": \"$(json "$name")\", \"changed\": $changed, \"changedPixels\": $pixels}"
    summary="$summary| $name | $([ "$changed" = true ] && echo "$pixels pixels changed" || echo unchanged) |
"
done
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
    echo "mac_vm_proof.sh: no pictures came back" >&2
    [ "$status" -ne 0 ] || status=1
fi
finished=1
exit "$status"
