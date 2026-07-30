#!/usr/bin/env python3
"""Generate keymap_list.tsv from local keymaps/ directory.

Output: TSV format (DisplayName<TAB>FileName.properties)
"""

import sys
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parent.parent
KEYMAPS_DIR = PROJECT_ROOT / "keymaps"
OUTPUT = PROJECT_ROOT / "res_lists" / "keymap_list.tsv"


def atomic_write(path: Path, lines: list[str]) -> None:
    tmp = path.with_suffix(path.suffix + ".tmp")
    path.parent.mkdir(parents=True, exist_ok=True)
    with open(tmp, "w", encoding="utf-8") as f:
        for line in lines:
            f.write(line + "\n")
        f.flush()
        import os

        os.fsync(f.fileno())
    tmp.rename(path)


def validate_tsv(path: Path, min_lines: int, name: str) -> int:
    with open(path, encoding="utf-8") as f:
        lines = [line.rstrip("\n") for line in f]
    count = len(lines)
    if count < min_lines:
        raise ValueError(f"{name} output has only {count} lines, expected at least {min_lines}")
    seen: set[str] = set()
    dups = 0
    for i, line in enumerate(lines, 1):
        parts = line.split("\t")
        if len(parts) != 2 or not parts[0].strip() or not parts[1].strip():
            raise ValueError(f"{name} line {i}: invalid TSV: {line!r}")
        if line in seen:
            dups += 1
        seen.add(line)
    if dups:
        print(f"Warning: {name} has {dups} duplicate lines", file=sys.stderr)
    return count


def main() -> int:
    files = sorted(KEYMAPS_DIR.glob("*.properties"))
    if not files:
        print("ERROR: No .properties files found in keymaps/", file=sys.stderr)
        return 1

    lines = [f"{f.stem}\t{f.name}" for f in files]
    atomic_write(OUTPUT, lines)

    count = validate_tsv(OUTPUT, min_lines=1, name="keymaps")
    print(f"keymap_list.tsv: {count} entries", file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main())
