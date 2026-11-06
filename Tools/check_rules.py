#!/usr/bin/env python3
"""The rules of AGENTS.md that must hold, checked: CI's `rules` job, on
every pull request and every commit on main. AGENTS.md says why each holds;
this says where one doesn't, with the file and line.

    Tools/check_rules.py

- No `@unchecked Sendable` and no `nonisolated(unsafe)`, anywhere.
- No third-party dependencies: Package.swift declares no `.package(…)`.
- In Sources/, which build against Apple's SwiftUI and against a
  reimplementation of it elsewhere:
  - no Combine and no CoreGraphics (CGFloat comes through SwiftUI);
  - none of the Foundation the other SwiftUIs' hosts lack (DateFormatter,
    JSONDecoder, JSONEncoder, FileManager, URLSession, NotificationCenter,
    Data) outside an Apple platform's `#if` (canImport(UIKit) or
    canImport(AppKit), or os(iOS), os(macOS), …);
  - one public or internal type per file, named after it (`Type.swift`, or
    `Type+Topic.swift` for an extension's file).

Exits 1 when anything breaks a rule, saying what. Standard library only.
"""

import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

FOUNDATION = re.compile(r"\b(DateFormatter|JSONDecoder|JSONEncoder|FileManager|URLSession|NotificationCenter|Data)\b")
APPLE = re.compile(r"canImport\((UIKit|AppKit)\)|os\((iOS|macOS|tvOS|watchOS|visionOS)\)")
DECLARATION = re.compile(r"^(?:@\w+(?:\([^)]*\))?\s+)*(?:(public|internal|package|open|private|fileprivate)\s+)?"
                         r"(?:(?:final|indirect|nonisolated)\s+)*(class|struct|enum|protocol|actor)\s+(\w+)", re.M)

problems = []


def problem(where, what):
    problems.append(f"{where}: {what}")


def tracked():
    files = subprocess.run(["git", "-C", str(ROOT), "ls-files", "-z"], capture_output=True, check=True).stdout
    return [name for name in files.decode().split("\0") if name]


def code(text):
    """The text with comments and string literals blanked, line for line."""
    text = re.sub(r"/\*.*?\*/", lambda m: re.sub(r"[^\n]", " ", m.group(0)), text, flags=re.S)
    text = re.sub(r'"""(?:.|\n)*?"""', lambda m: re.sub(r"[^\n]", " ", m.group(0)), text)
    text = re.sub(r'"(?:\\.|[^"\\\n])*"', '""', text)
    return re.sub(r"//[^\n]*", "", text)


def apple_lines(body):
    """For each line, whether it is inside an Apple platform's #if."""
    inside = []
    stack = []  # each open #if: whether its branch here is an Apple platform's
    for line in body.splitlines():
        directive = re.match(r"\s*#(if|elseif|else|endif)\b(.*)", line)
        if directive:
            kind, condition = directive.group(1), directive.group(2)
            positive = bool(APPLE.search(condition)) and "!" not in condition
            if kind == "if":
                stack.append(positive)
            elif kind == "elseif" and stack:
                stack[-1] = positive
            elif kind == "else" and stack:
                stack[-1] = False
            elif kind == "endif" and stack:
                stack.pop()
        inside.append(any(stack))
    return inside


def check_swift(name, text):
    body = code(text)
    lines = body.splitlines()
    for number, line in enumerate(lines, 1):
        if re.search(r"@unchecked\s+Sendable", line):
            problem(f"{name}:{number}", "no `@unchecked Sendable`")
        if re.search(r"nonisolated\s*\(\s*unsafe\s*\)", line):
            problem(f"{name}:{number}", "no `nonisolated(unsafe)`")
    if not name.startswith("Sources/"):
        return
    apple = apple_lines(body)
    for number, line in enumerate(lines, 1):
        imported = re.match(r"\s*(?:@_?\w+\s+)*import\s+(?:\w+\s+)?(Combine|CoreGraphics)\b", line)
        if imported:
            problem(f"{name}:{number}", f"no {imported.group(1)}: every target imports SwiftUI (CGFloat comes through it)")
        for found in FOUNDATION.finditer(line):
            if not apple[number - 1]:
                problem(f"{name}:{number}",
                        f"{found.group(1)} only under an Apple platform's #if: the other SwiftUIs' Foundation hasn't it")
    shared = [m.group(3) for m in DECLARATION.finditer(body) if (m.group(1) or "internal") not in ("private", "fileprivate")]
    stem = Path(name).stem
    if len(shared) > 1:
        problem(name, f"one public or internal type per file: {', '.join(shared)}")
    elif shared and shared[0] != stem.split("+")[0]:
        problem(name, f"a file is named after its type: {shared[0]}.swift")


def main():
    for name in tracked():
        path = ROOT / name
        if not path.is_file():
            continue
        if name == "Package.swift":
            body = code(path.read_text())
            for number, line in enumerate(body.splitlines(), 1):
                if ".package(" in line:
                    problem(f"{name}:{number}", "no third-party dependencies: consumers take this package alone")
        elif name.endswith(".swift"):
            check_swift(name, path.read_text())
    for line in problems:
        print(line)
    if problems:
        print(f"{len(problems)} broken: AGENTS.md says why each holds", file=sys.stderr)
        sys.exit(1)
    print("Every rule holds.")


if __name__ == "__main__":
    main()
