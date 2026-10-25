#!/bin/bash
# The proof of a commit, for a release's review: the demo apps
# (Examples/: AgentExample, SplitExample, StackExample, TabbedExample), each
# built for the iPhone simulator, launched and pictured, as a run the review
# server files by commit (Reviews shows it with the release's draft).
#
#   Tools/proof.sh [version]          -> .proof/review-ios (or $PROOF_DIR)
#   then, from a reviews checkout:
#   bazel run //reviews/harnesses:publish_proof -- runs <agent_ui>/.proof --commit <sha>
#
# The version is the release's under review (the newest tag's otherwise).
# Runs on any Mac with Xcode and XcodeGen; the simulator is one of its own
# ("AgentUI proof", an iPhone 17), erased first, its clock at 9:41.
set -uo pipefail
cd "$(dirname "$0")/.."
OUT="${PROOF_DIR:-$PWD/.proof}"
VERSION="${1:-$(git describe --tags --abbrev=0 2>/dev/null | sed 's/^v//')}"
APPS=(AgentExample SplitExample StackExample TabbedExample)
rm -rf "$OUT" && mkdir -p "$OUT/review-ios"
xcodegen generate --spec Examples/project.yml >/dev/null || exit 1
status=0
for app in "${APPS[@]}"; do
  xcodebuild build -project Examples/AgentUIExamples.xcodeproj -scheme "${app}_iOS" -sdk iphonesimulator \
    -destination 'generic/platform=iOS Simulator' -derivedDataPath DerivedData/proof CODE_SIGNING_ALLOWED=NO \
    > "$OUT/build-$app.log" 2>&1 || { echo "$app: build failed (see $OUT/build-$app.log)"; status=1; }
done
runtime="$(xcrun simctl list runtimes | grep -o 'com.apple.CoreSimulator.SimRuntime.iOS-[0-9-]*' | tail -1)"
sim="$(xcrun simctl list devices | grep -F 'AgentUI proof (' | grep -o '[0-9A-F-]\{36\}' | head -1)"
[ -n "$sim" ] || sim="$(xcrun simctl create "AgentUI proof" "iPhone 17" "$runtime")"
xcrun simctl shutdown "$sim" 2>/dev/null || true
xcrun simctl erase "$sim"
xcrun simctl boot "$sim"
xcrun simctl bootstatus "$sim" >/dev/null
xcrun simctl status_bar "$sim" override --time 9:41 --batteryState charged --batteryLevel 100 --cellularBars 4 --wifiBars 3
items=()
for app in "${APPS[@]}"; do
  bundle="$(ls -d DerivedData/proof/Build/Products/Debug-iphonesimulator/${app}.app 2>/dev/null)"
  [ -n "$bundle" ] || { items+=("{\"name\":\"$app\",\"status\":\"failed\",\"notes\":\"not built\"}"); status=1; continue; }
  id="$(defaults read "$PWD/$bundle/Info" CFBundleIdentifier)"
  xcrun simctl install "$sim" "$bundle" && xcrun simctl launch "$sim" "$id" >/dev/null
  sleep 5
  if xcrun simctl io "$sim" screenshot "$OUT/review-ios/$app.png" >/dev/null 2>&1; then
    items+=("{\"name\":\"$app\",\"status\":\"new\",\"capture\":\"$app.png\"}")
  else
    items+=("{\"name\":\"$app\",\"status\":\"failed\",\"notes\":\"no picture\"}"); status=1
  fi
  xcrun simctl terminate "$sim" "$id" >/dev/null 2>&1 || true
done
xcrun simctl shutdown "$sim" 2>/dev/null || true
joined="$(IFS=,; echo "${items[*]}")"
cat > "$OUT/review-ios/manifest.json" <<JSON
{"schema":1,"app":"AgentUI","version":"$VERSION","release":"${VERSION%.*}","commit":"$(git rev-parse HEAD)",
 "kind":"snapshots","target":"ios","device":"iPhone 17","orientation":"portrait",
 "started":"$(date -u +%Y-%m-%dT%H:%M:%SZ)","notes":"Tools/proof.sh: the demo apps' first screens",
 "items":[$joined]}
JSON
echo "proof of $(git rev-parse --short HEAD) ($VERSION): $OUT"
exit $status
