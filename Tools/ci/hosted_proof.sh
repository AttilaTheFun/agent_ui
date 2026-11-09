#!/bin/bash
# AgentUI's proof, on one of GitHub's own Macs (`xcode-27`: Xcode 27.2 and
# its iOS simulators), which a public repository has for free, leaving OS
# Server's macOS VMs to the agents (Logan, 5 Nov 2026): the four demo apps
# built and pictured by Tools/proof.sh, in AttilaTheFun/reviews' proof format
# 2 (docs/PROOF_FORMAT.md). Nothing is compared here: Reviews compares a
# release's proof with the prior release's, item by item, by id (Logan, 8 Nov
# 2026).
#
#   Tools/ci/hosted_proof.sh --proof <dir> [--tests <test logs>] [--version <version>]
#
# The proof, in <dir>, kept flat as the run's `proof` artifact (GitHub zips
# it, so its download is proof.zip as a release keeps it):
#   proof.json                 format 2: each demo app's first screen an item,
#                              ios/phone/<demo> (agent-example, tabbed-example)
#                              or ios/pad/<demo> (split-example, stack-example,
#                              pictured on an iPad), with its sha256
#                              and size; and, with --tests (hosted_tests.sh's
#                              --logs), tests/macos, the bundles' counts from
#                              XCTest's last "Executed N tests, with M failures"
#   screens/ios/{phone,pad}/<demo>.png
#   logs/macos.txt             the bundles' logs, with --tests
# --version is what it is a proof of (a release's proposal gives it), else the
# newest v* tag's. The script fails as Tools/proof.sh does, or when no picture
# comes back.
#
#   DEVELOPER_DIR  the Xcode (default: Xcode 27.2 where the image has it)
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
me="$(basename "$0")"
XCODEGEN_URL="https://github.com/yonaskolb/XcodeGen/releases/download/2.46.0/xcodegen.zip"
XCODEGEN_SHA256="4d9e34b62172d645eed6457cac13fc222569974098ef4ee9c3368bedf0196806"

usage() { echo "usage: Tools/ci/hosted_proof.sh --proof <dir> [--tests <test logs>] [--version <version>]" >&2; exit 2; }
proof=""
tests=""
version=""
while [ $# -gt 0 ]; do
    case "$1" in
        --proof) proof="${2:?--proof takes a folder}"; shift 2 ;;
        --tests) tests="${2:?--tests takes the folder of hosted_tests.sh logs}"; shift 2 ;;
        --version) version="${2:?--version takes a version}"; shift 2 ;;
        *) usage ;;
    esac
done
[ -n "$proof" ] || usage
if [ -z "${DEVELOPER_DIR:-}" ] && [ -d /Applications/Xcode_27.2.app ]; then
    export DEVELOPER_DIR=/Applications/Xcode_27.2.app/Contents/Developer
fi

commit="$(git -C "$ROOT" rev-parse HEAD)"
[ -n "$version" ] || version="$(git -C "$ROOT" describe --tags --abbrev=0 --match 'v[0-9]*' 2> /dev/null | sed 's/^v//')"

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

echo "::group::Xcode and XcodeGen"
xcodebuild -version | head -1
xcrun simctl list runtimes | grep -i '^ios' || true
# XcodeGen's release, checked against the sum above.
curl -fsSL -o "$work/xcodegen.zip" "$XCODEGEN_URL"
echo "$XCODEGEN_SHA256  $work/xcodegen.zip" | shasum -a 256 -c - > /dev/null
(cd "$work" && unzip -q -o xcodegen.zip && chmod +x xcodegen/bin/xcodegen)
export PATH="$work/xcodegen/bin:$PATH"
echo "::endgroup::"

echo "::group::Tools/proof.sh: the demo apps, built and pictured"
status=0
(cd "$ROOT" && PROOF_DIR="$work/out" Tools/proof.sh ci) || status=$?
echo "::endgroup::"

# The proof (format 2): the screens, then the tests.
mkdir -p "$proof"
cp "$work/out"/build-*.log "$proof/" 2> /dev/null || true
python3 -I - "$work/out/review-ios" "$proof" "$version" "$commit" "${GITHUB_REPOSITORY:-AttilaTheFun/agent_ui}" "${GITHUB_RUN_ID:-}" "$tests" << 'PY' || status=1
import datetime, glob, hashlib, json, os, re, shutil, struct, sys
pictures, proof, version, commit, repository, run, tests = sys.argv[1:8]
items = []
for path in sorted(glob.glob(os.path.join(pictures, "*.png"))):
    stem = os.path.basename(path)[:-4]
    # AgentExample -> agent-example: stable from release to release.
    name = re.sub(r"(?<=[a-z0-9])(?=[A-Z])", "-", stem).lower()
    if not re.fullmatch(r"[a-z0-9][a-z0-9.-]*", name):
        sys.exit(f"hosted_proof: {stem}.png makes no id")
    # The device Tools/proof.sh's device_for pictured it on: an iPad for
    # the two whose sidebars show there, an iPhone for the others.
    device, on = ("pad", "an iPad") if stem in ("SplitExample", "StackExample") else ("phone", "an iPhone")
    file = f"screens/ios/{device}/{name}.png"
    os.makedirs(os.path.dirname(os.path.join(proof, file)), exist_ok=True)
    shutil.copyfile(path, os.path.join(proof, file))
    data = open(path, "rb").read()
    width, height = struct.unpack(">II", data[16:24])
    title = re.sub(r"(?<=[a-z])(?=[A-Z])", " ", stem)
    items.append({"id": f"ios/{device}/{name}", "kind": "screen", "title": f"{title} on {on}", "file": file,
                  "sha256": hashlib.sha256(data).hexdigest(), "width": width, "height": height})
if not items:
    sys.exit("hosted_proof: no pictures came back")
if tests:
    count = failures = 0
    logs = sorted(glob.glob(os.path.join(tests, "*", "test.log")))
    os.makedirs(os.path.join(proof, "logs"), exist_ok=True)
    with open(os.path.join(proof, "logs", "macos.txt"), "w") as out:
        for log in logs:
            text = open(log, errors="replace").read()
            out.write(f"== {os.path.basename(os.path.dirname(log))}\n{text}\n")
            executed = re.findall(r"Executed (\d+) tests?, with (\d+) failures?", text)
            if executed:
                count += int(executed[-1][0]); failures += int(executed[-1][1])
    items.append({"id": "tests/macos", "kind": "tests", "title": "macOS", "result": "passed" if logs and failures == 0 else "failed",
                  "tests": count, "failures": failures, "log": "logs/macos.txt"})
document = {"format": 2, "app": "AgentUI", "version": version, "repository": repository, "commit": commit,
            "run": int(run) if run else None, "made": datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
            "items": items}
with open(os.path.join(proof, "proof.json"), "w") as f:
    json.dump(document, f, indent=2); f.write("\n")
print(json.dumps(document, indent=2))
summary = os.environ.get("GITHUB_STEP_SUMMARY")
if summary:
    lines = [f"### Proof of {commit[:7]} ({version}), format 2", "", "Reviews compares it with the prior release's, item by item.", "",
             "| Item | |", "| --- | --- |"]
    lines += [f"| {i['id']} | " + (f"{i['width']}×{i['height']}" if i["kind"] == "screen" else f"{i['result']}: {i['tests']} tests, {i['failures']} failures") + " |" for i in items]
    open(summary, "a").write("\n".join(lines) + "\n")
PY
finished=1
exit "$status"
