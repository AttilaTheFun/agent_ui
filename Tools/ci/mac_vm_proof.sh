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
#                       built and run in the VM: CoreGraphics)
#   proof.json          {"commit", "ref", "kind", "run", "base": {"commit"},
#                        "screens": [{"name", "changed", "changedPixels"}]}
# The script fails as Tools/proof.sh does, or when no picture comes back.
#
#   PROOF_REF  the ref the proof is of (default: GITHUB_REF, else the branch)
#
# The VM is the script's alone: leased for an hour, renewed while it runs,
# released however it ends (a kill nothing can trap leaves it an hour at
# most). The committed tree goes in (git archive HEAD), with XcodeGen, which
# the image may not have (its release, checked against the sum below), and
# the pictures kept at the base; the screens, their diffs and how many
# pixels each changed come back. The runner needs nothing of a Mac's
# (CI's: agent_ui-jit, a Linux container).
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

# SHA-256 as the runner has it: coreutils' on Linux, Perl's on a Mac.
sum256() { if command -v sha256sum > /dev/null; then sha256sum "$@"; else shasum -a 256 "$@"; fi; }

# XcodeGen first: nothing leased if it can't be had. And the pictures kept
# at the base, what the screens are compared with, in the VM.
mkdir -p "$work/vm/base"
git -C "$ROOT" archive "$base_commit" Tests/Proof | tar -x -C "$work/vm/base"
curl -fsSL -o "$work/vm/xcodegen.zip" "$XCODEGEN_URL"
echo "$XCODEGEN_SHA256  $work/vm/xcodegen.zip" | sum256 -c - > /dev/null

echo "::group::A macOS VM (xcode_27_2)"
# A key of the run's own for the VM's SSH, gone with the run.
ssh-keygen -q -t ed25519 -N '' -C agent_ui-ci -f "$work/key"
run "$OSS" machine lease macos --config=xcode_27_2 --minutes=60 --wait --key="$work/key.pub" --exports > "$work/lease"
lease="$(. "$work/lease"; printf '%s' "$OSS_ID")"
echo "Leased $lease"
# Renewed every ten minutes; told to stop, it stops its sleep too.
(
    trap 'kill $! 2> /dev/null; exit 0' TERM
    # While the script lives: a cancel that kills it (SIGKILL, no trap)
    # leaves no renewer holding the lease for good. $$ is the script's,
    # in this subshell too.
    while kill -0 "$$" 2> /dev/null; do
        sleep 600 &
        wait $!
        kill -0 "$$" 2> /dev/null || break
        "$OSS" machine renew "$lease" --minutes=60 > /dev/null || true
    done
) &
renewer=$!
for _ in $(seq 1 30); do vm true 2> /dev/null && break; sleep 5; done

# The tree as committed, XcodeGen, the kept pictures, and what the VM runs,
# into ~/ci there.
git -C "$ROOT" archive --format=tar.gz -o "$work/vm/tree.tar.gz" HEAD
cat > "$work/vm/in_vm.sh" << 'EOF'
#!/bin/bash
# In the VM, in ~/ci: the tree in src/, XcodeGen in xcodegen/, the pictures
# kept at the base in base/Tests/Proof.
set -uo pipefail
cd ~/ci
export PATH="$HOME/ci/xcodegen/bin:/usr/bin:/bin:/usr/sbin:/sbin"
case "$1" in
    unpack)
        mkdir -p src && tar -xzf tree.tar.gz -C src || exit
        unzip -q -o xcodegen.zip && chmod +x xcodegen/bin/xcodegen || exit
        xcodebuild -version | head -1
        xcrun simctl list runtimes | grep -i '^ios'
        ;;
    tools)
        # The diff tool, with the VM's Xcode (CoreGraphics, ImageIO).
        xcrun swiftc -O -o ~/ci/snapshot_diff src/Tools/ci/snapshot_diff.swift
        ;;
    proof)
        # Not a git checkout: the version is the run's business, not the tag's.
        rm -rf ~/ci/out && cd src && PROOF_DIR="$HOME/ci/out" Tools/proof.sh ci
        ls ~/ci/out/review-ios/*.png
        ;;
    compare)
        # Each screen against its picture kept at the base: a line of its
        # name and changed pixels, and its diff where any changed.
        rm -rf ~/ci/diffs && mkdir -p ~/ci/diffs && : > ~/ci/compared.tsv || exit
        for picture in ~/ci/out/review-ios/*.png; do
            [ -e "$picture" ] || continue
            name="$(basename "$picture" .png)"
            pixels="$(~/ci/snapshot_diff "base/Tests/Proof/$name.png" "$picture" "diffs/$name.png")" || exit
            printf '%s\t%s\n' "$name" "$pixels" >> compared.tsv
        done
        ;;
esac
EOF
run "$OSS" machine upload "$lease" --identity="$work/key" "$work/vm" ci
run vm bash ci/in_vm.sh unpack
# The diff tool before the apps: a broken one fails before they're built.
run vm bash ci/in_vm.sh tools
echo "::endgroup::"

echo "::group::Tools/proof.sh: the demo apps, built and pictured"
status=0
run vm bash ci/in_vm.sh proof || status=$?
echo "::endgroup::"
echo "::group::The screens against their pictures kept at the base"
# Whatever came of the apps: a broken screen is what the proof is for.
run vm bash ci/in_vm.sh compare || { echo "mac_vm_proof.sh: the screens were not compared" >&2; [ "$status" -ne 0 ] || status=1; }
# scp makes each folder (one already here would get it inside).
run "$OSS" machine download "$lease" --identity="$work/key" ci/out/review-ios "$work/recorded" || mkdir -p "$work/recorded"
run "$OSS" machine download "$lease" --identity="$work/key" ci/diffs "$work/diffs" || mkdir -p "$work/diffs"
run "$OSS" machine download "$lease" --identity="$work/key" ci/compared.tsv "$work/compared.tsv" || : > "$work/compared.tsv"
echo "::endgroup::"
release

# The proof, from the screens and how each compared with the base.
json() { printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'; }
mkdir -p "$proof/screens" "$proof/diffs"
screens=""
summary=""
for picture in "$work/recorded"/*.png; do
    [ -e "$picture" ] || continue
    name="$(basename "$picture" .png)"
    cp "$picture" "$proof/screens/$name.png"
    [ ! -f "$work/diffs/$name.png" ] || cp "$work/diffs/$name.png" "$proof/diffs/$name.png"
    pixels="$(awk -F'\t' -v name="$name" '$1 == name { print $2; exit }' "$work/compared.tsv")"
    case "$pixels" in
        '' | *[!0-9]*)
            echo "mac_vm_proof.sh: $name was not compared" >&2
            [ "$status" -ne 0 ] || status=1
            continue ;;
    esac
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
