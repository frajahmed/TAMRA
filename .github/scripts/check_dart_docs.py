"""Check that every public top-level declaration in app/lib has a /// doc comment.

Covers classes, enums, extensions, typedefs, top-level functions, top-level
providers/constants and public methods/getters of classes (2-space indent).
Skipped: private names ("_"), overrides (@override), constructors, fields, generated files
and translation getters in app_strings.dart (`=> text('key')`: the key names the text).
Usage: python .github/scripts/check_dart_docs.py app/lib
"""

import re
import sys
from pathlib import Path

DECLARATION = re.compile(
    r"^(?:abstract\s+|final\s+|sealed\s+|base\s+|interface\s+)*"
    r"(?:class|enum|mixin|extension|typedef)\s+([A-Za-z]\w*)"
    r"|^(?:final|const)\s+(?:[\w<>?,\s]+\s+)?([a-zA-Z]\w*)\s*="
    r"|^(?!return\b|import\b|export\b|part\b|library\b)[\w<>?,\s]+?\s+([a-zA-Z]\w*)\s*\("
)


METHOD = re.compile(
    r"^  (?:static\s+)?(?!return\b|final\b|const\b|late\b|var\b)"
    r"[\w<>?,\[\]\s]+?\s+(?:get\s+)?([a-zA-Z]\w*)\s*(?:\(|=>|\{|async)"
)


def _class_names(lines: list[str]) -> set[str]:
    """Class names of the file (their constructors look like methods)."""
    names = set()
    for line in lines:
        match = re.match(r"^(?:abstract\s+|final\s+|sealed\s+|interface\s+)*class\s+(\w+)", line)
        if match:
            names.add(match.group(1))
    return names


def undocumented(path: Path) -> list[str]:
    """Names of public top-level declarations in one file that have no doc comment."""
    missing = []
    lines = path.read_text(encoding="utf-8").splitlines()
    classes = _class_names(lines)
    for index, line in enumerate(lines):
        if line.startswith("  ") and not line.startswith("   "):
            method = METHOD.match(line)
            if not method or method.group(1) in classes or method.group(1).startswith("_"):
                continue
            if "=> text('" in line or "=> _fill('" in line:
                continue
            previous = index - 1
            while previous >= 0 and lines[previous].lstrip().startswith("@"):
                if lines[previous].strip() == "@override":
                    break
                previous -= 1
            if previous >= 0 and lines[previous].strip() == "@override":
                continue
            if previous < 0 or not lines[previous].lstrip().startswith("///"):
                missing.append(f"{path}:{index + 1}: {method.group(1)}")
            continue
        if not line or line[0].isspace() or line.startswith(("//", "@", "}", ")")):
            continue
        match = DECLARATION.match(line)
        if not match:
            continue
        name = next(group for group in match.groups() if group)
        if name.startswith("_") or name == "main":
            continue
        previous = index - 1
        while previous >= 0 and lines[previous].lstrip().startswith("@"):
            previous -= 1
        if previous < 0 or not lines[previous].lstrip().startswith("///"):
            missing.append(f"{path}:{index + 1}: {name}")
    return missing


def main() -> int:
    """Print every missing doc comment; exit 1 when there is at least one."""
    root = Path(sys.argv[1] if len(sys.argv) > 1 else "app/lib")
    missing = [
        item
        for path in sorted(root.rglob("*.dart"))
        if not path.name.endswith((".g.dart", ".freezed.dart"))
        for item in undocumented(path)
    ]
    for item in missing:
        print(f"Missing /// doc comment: {item}")
    print(f"{len(missing)} public declarations without a doc comment.")
    return 1 if missing else 0


if __name__ == "__main__":
    sys.exit(main())
