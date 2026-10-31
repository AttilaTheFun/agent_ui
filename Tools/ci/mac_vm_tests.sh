#!/bin/bash
# AgentUI's tests, in a macOS VM leased from OS Server (xcode-27.0: Xcode
# 27.0): `swift test`, the code held to the Swift 6 mode with warnings as
# errors (the manifest keeps the Swift 5 language mode: other SwiftUIs build
# these sources and are not ready for 6).
#
#   Tools/ci/mac_vm_tests.sh
#
# The VM (Tools/ci/mac_vm.sh) is the script's alone, released however it
# ends.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
. "$ROOT/Tools/ci/mac_vm.sh"
mac_vm_start agent_ui-ci

mac_vm_steps << 'STEPS'
    test)
        cd agent_ui && swift test -Xswiftc -swift-version -Xswiftc 6 -Xswiftc -warnings-as-errors
        ;;
STEPS

echo "::group::A macOS VM (xcode-27.0)"
mac_vm_lease
mac_vm_copy_tree
echo "::endgroup::"

status=0
run in_vm test || status=$?
[ "$status" -eq 0 ] || echo "::error::swift test failed ($status)"
mac_vm_release
finished=1
exit "$status"
