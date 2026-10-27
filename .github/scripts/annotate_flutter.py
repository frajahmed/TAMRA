"""Turn a `flutter test` or `flutter analyze` log into short GitHub annotations.

GitHub cuts an annotation after about 4 KB, so one long log hides every error but the first.
This script sends one annotation per failing test (the exception block) and one per analyzer
issue, so all results can be read through the public API without logging in.
Usage: python annotate_flutter.py <log file> <title>
"""

import os
import re
import sys
from pathlib import Path

MAX_ANNOTATIONS = 20
MAX_CHARS = 3500
WORKSPACE = os.environ.get("GITHUB_WORKSPACE", "/nonexistent") + "/"


def escape(text: str) -> str:
    """Escape a message for the ::error:: workflow command."""
    return text.replace("%", "%25").replace("\r", "%0D").replace("\n", "%0A")


def test_failures(log: str) -> list[str]:
    """One text per failing test: the exception block from the test framework."""
    blocks = re.findall(r"══╡ EXCEPTION CAUGHT.*?\n(.*?)\n═{20,}", log, flags=re.S)
    return [block.strip() for block in blocks]


def analyzer_issues(log: str) -> list[str]:
    """One text per analyzer line (`info • message • file:line:col • rule`)."""
    return [line.strip() for line in log.splitlines() if " • " in line]


def main() -> int:
    """Print the annotations; the summary line comes last."""
    path, title = Path(sys.argv[1]), sys.argv[2]
    if not path.exists():
        return 0
    log = path.read_text(encoding="utf-8", errors="replace").replace(WORKSPACE, "")
    items = test_failures(log) + analyzer_issues(log)
    for index, item in enumerate(items[:MAX_ANNOTATIONS], start=1):
        print(f"::error title={title} {index}/{len(items)}::{escape(item[:MAX_CHARS])}")
    summary = [line for line in log.splitlines() if line.strip()][-3:]
    print(f"::error title={title} summary::{escape(chr(10).join(summary))}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
