#!/bin/bash
# The demo apps' first screens (Examples/: AgentExample, SplitExample,
# StackExample, TabbedExample), each built for the simulator, launched and
# pictured. CI runs it in a leased macOS VM (Tools/ci/mac_vm_proof.sh) and
# compares the pictures with Tests/Proof; run here, it is a look before
# pushing.
#
#   Tools/proof.sh [version]          -> .proof/review-ios (or $PROOF_DIR)
#
# Split and Stack on an iPad, where their sidebars show; the others on an
# iPhone. Each device a simulator of its own ("AgentUI proof", an iPhone 17;
# "AgentUI proof iPad", an iPad Pro 13-inch (M5)), erased first, its status
# bar held still, one at a time. Needs Xcode and XcodeGen.
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
# The newest iOS runtime, major and minor only: a device's own runtime
# (iOS-27-2-iPhone19-4) would otherwise end the match at a dash.
runtime="$(xcrun simctl list runtimes | grep -oE 'com\.apple\.CoreSimulator\.SimRuntime\.iOS-[0-9]+-[0-9]+' | tail -1)"
# Each example on the device it is about: an iPad for the two that differ
# only where there is room for a sidebar beside the content (on an iPhone
# both are a list alone, and look the same), an iPhone for the rest.
at="$(date -u -r "$(date -j -f '%Y-%m-%dT%H:%M:%S' 2007-01-09T09:41:00 +%s)" '+%Y-%m-%dT%H:%M:%S.000Z')"
device_for() { case "$1" in SplitExample | StackExample) echo "iPad Pro 13-inch (M5)" ;; *) echo "iPhone 17" ;; esac; }
items=()
for device in "iPhone 17" "iPad Pro 13-inch (M5)"; do
  apps=()
  for app in "${APPS[@]}"; do [ "$(device_for "$app")" = "$device" ] && apps+=("$app"); done
  [ ${#apps[@]} -gt 0 ] || continue
  # A simulator of its own for each device, erased first; one at a time.
  name="AgentUI proof"
  [ "$device" = "iPhone 17" ] || name="AgentUI proof iPad"
  sim="$(xcrun simctl list devices | grep -F "$name (" | grep -o '[0-9A-F-]\{36\}' | head -1)"
  [ -n "$sim" ] || sim="$(xcrun simctl create "$name" "$device" "$runtime")"
  xcrun simctl shutdown "$sim" 2>/dev/null || true
  xcrun simctl erase "$sim"
  xcrun simctl boot "$sim"
  xcrun simctl bootstatus "$sim" >/dev/null
  # The status bar held still (~/Developer/AGENTS.md, "hold them still"): the
  # clock, the battery, Wi-Fi and cellular bars, and no carrier name or network
  # type, which otherwise drift from run to run. A whole date, for an iPad's
  # status bar shows the day too: 9:41 on 9 January 2007 where the simulator
  # is, in the one form simctl takes (UTC, with milliseconds).
  if ! xcrun simctl status_bar "$sim" override --time "$at" --dataNetwork wifi --wifiMode active --wifiBars 3 \
    --cellularMode active --cellularBars 4 --operatorName "" --batteryState charged --batteryLevel 100; then
    echo "$device: the status bar was not held still"; status=1
  fi
  for app in "${apps[@]}"; do
    bundle="$(ls -d DerivedData/proof/Build/Products/Debug-iphonesimulator/${app}.app 2>/dev/null)"
    [ -n "$bundle" ] || { items+=("{\"name\":\"$app\",\"status\":\"failed\",\"notes\":\"not built\"}"); status=1; continue; }
    id="$(defaults read "$PWD/$bundle/Info" CFBundleIdentifier)"
    xcrun simctl install "$sim" "$bundle" && xcrun simctl launch "$sim" "$id" >/dev/null
    sleep 5
    # Masked: a fresh simulator draws the Dynamic Island and another doesn't.
    if xcrun simctl io "$sim" screenshot --mask=black "$OUT/review-ios/$app.png" >/dev/null 2>&1; then
      items+=("{\"name\":\"$app\",\"status\":\"new\",\"capture\":\"$app.png\",\"device\":\"$device\"}")
    else
      items+=("{\"name\":\"$app\",\"status\":\"failed\",\"notes\":\"no picture\"}"); status=1
    fi
    xcrun simctl terminate "$sim" "$id" >/dev/null 2>&1 || true
  done
  xcrun simctl shutdown "$sim" 2>/dev/null || true
done
joined="$(IFS=,; echo "${items[*]}")"
cat > "$OUT/review-ios/manifest.json" <<JSON
{"schema":1,"app":"AgentUI","version":"$VERSION","release":"${VERSION%.*}","commit":"$(git rev-parse HEAD)",
 "kind":"snapshots","target":"ios","device":"iPhone 17 and iPad Pro 13-inch (M5)","orientation":"portrait",
 "started":"$(date -u +%Y-%m-%dT%H:%M:%SZ)","notes":"Tools/proof.sh: the demo apps' first screens",
 "items":[$joined]}
JSON
echo "proof of $(git rev-parse --short HEAD) ($VERSION): $OUT"
exit $status
