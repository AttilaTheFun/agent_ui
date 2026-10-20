# Tools

`xcodegen generate --spec Examples/project.yml` regenerates the examples project
(XcodeGen: `brew install xcodegen`).

`Tools/released_pins.sh` fails while a dependency is pinned to a revision or
a branch rather than a released version: CI runs it on main's commits, and a
release waits for it.
