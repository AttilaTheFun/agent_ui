# Tools

`xcodegen generate --spec Examples/project.yml` regenerates the examples project
(XcodeGen: `brew install xcodegen`).

`Tools/released_pins.sh` fails while a dependency is pinned to a revision or
a branch rather than a released version: CI runs it in a release's run (the
`pins` job), and the release waits for it.

`Tools/check_rules.py` checks the rules of AGENTS.md that must hold (CI's
`container` job, on every pull request): run it before pushing.
