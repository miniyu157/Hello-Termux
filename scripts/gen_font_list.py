#!/usr/bin/env python3
"""Generate font_list.tsv from ryanoasis/nerd-fonts.

Traverses the patched-fonts/ directory tree via GitHub Contents API,
using BFS with pagination, auth, retry, and per-directory error
resilience.

Output: TSV format (DisplayName<TAB>Family/path/Font.ttf)
"""

import concurrent.futures
import json
import os
import random
import subprocess
import sys
import time
import urllib.error
import urllib.request
from collections import deque
from pathlib import Path

# ---------------------------------------------------------------------------
# Config
# ---------------------------------------------------------------------------

REPO = "ryanoasis/nerd-fonts"
API_PATH = "patched-fonts"
API_BASE = f"https://api.github.com/repos/{REPO}/contents/{API_PATH}"

PROJECT_ROOT = Path(__file__).resolve().parent.parent
OUTPUT = PROJECT_ROOT / "res_lists" / "font_list.tsv"

WORKERS = 5
TIMEOUT = 30
MAX_RETRIES = 3
RETRY_BASE = 1.0
MIN_FONTS = 1000
EXPECTED_FONTS = 1500


# ---------------------------------------------------------------------------
# Helpers (self-contained — duplicated per-script intentionally)
# ---------------------------------------------------------------------------


def get_token() -> str | None:
    try:
        r = subprocess.run(
            ["gh", "auth", "token"], capture_output=True, text=True, timeout=5
        )
        return r.stdout.strip() or None
    except Exception:
        return None


def build_opener(token: str | None) -> urllib.request.OpenerDirector:
    opener = urllib.request.build_opener()
    opener.addheaders = [
        ("Accept", "application/vnd.github.v3+json"),
        ("User-Agent", "hello-termux/2.0"),
    ]
    if token:
        opener.addheaders.append(("Authorization", f"Bearer {token}"))
    return opener


def parse_retry_after(headers: dict) -> float:
    from email.utils import parsedate_to_datetime

    val = headers.get("Retry-After", "")
    if not val:
        return 60.0
    if val.isdigit():
        return min(float(val), 120.0)
    try:
        dt = parsedate_to_datetime(val)
        return max((dt.timestamp() - time.time()), 1.0)
    except Exception:
        return 60.0


def api_get(
    opener: urllib.request.OpenerDirector, url: str
) -> tuple[dict | list, dict]:
    """GET *url*, return (json_body, headers_dict)."""
    req = urllib.request.Request(url)
    last_err: Exception | None = None
    for n in range(MAX_RETRIES):
        try:
            with opener.open(req, timeout=TIMEOUT) as resp:
                body = resp.read()
                headers = dict(resp.headers)
                return (json.loads(body), headers)
        except urllib.error.HTTPError as e:
            last_err = e
            status = e.code
            if status == 429:
                rh = {k.lower(): v for k, v in e.headers.items()}  # type: ignore[union-attr]
                delay = parse_retry_after(rh)
                print(f"    Rate limited, waiting {delay:.0f}s ...", file=sys.stderr)
                time.sleep(delay)
                continue
            if 400 <= status < 500:
                raise
        except (urllib.error.URLError, TimeoutError, json.JSONDecodeError) as e:
            last_err = e
        if n < MAX_RETRIES - 1:
            delay = RETRY_BASE * (2**n) + random.uniform(0, 1)
            time.sleep(delay)
    raise last_err  # type: ignore[misc]


def paginate_entries(
    opener: urllib.request.OpenerDirector, url: str
) -> list[dict]:
    """Fetch all entries from a paginated GitHub Contents API endpoint."""
    all_entries: list[dict] = []
    next_url: str | None = url
    seen: set[str] = set()
    page_num = 0

    while next_url:
        if next_url in seen:
            break
        seen.add(next_url)
        page_num += 1
        body, headers = api_get(opener, next_url)

        if isinstance(body, list):
            all_entries.extend(body)
        elif isinstance(body, dict):
            if "items" in body:
                all_entries.extend(body["items"])
            elif isinstance(body, list):
                all_entries.extend(body)

        next_url = None
        for part in headers.get("Link", "").split(","):
            if 'rel="next"' in part:
                s, e = part.find("<"), part.find(">")
                if s != -1 and e != -1:
                    next_url = part[s + 1:e]
                break

    return all_entries


def is_font(name: str) -> bool:
    return name.endswith((".ttf", ".otf"))


# ---------------------------------------------------------------------------
# BFS traversal
# ---------------------------------------------------------------------------


def discover_family(
    family: str,
    token: str | None,
) -> tuple[list[str], list[tuple[str, str]]]:
    """BFS a font family directory tree. Collects all .ttf/.otf files.

    Returns (font_paths, errors) where font_paths are "Family/.../file.ttf"
    and errors are (directory, reason) for directories that failed.
    """
    opener = build_opener(token)
    queue: deque[str] = deque([family])
    results: list[str] = []
    errors: list[tuple[str, str]] = []

    while queue:
        current = queue.popleft()
        try:
            entries = paginate_entries(opener, f"{API_BASE}/{current}")
        except Exception as e:
            errors.append((current, str(e)[:120]))
            continue

        for e in entries:
            if e.get("type") == "file" and is_font(e.get("name", "")):
                results.append(f"{current}/{e['name']}")
            elif e.get("type") == "dir":
                queue.append(f"{current}/{e['name']}")

    return results, errors


# ---------------------------------------------------------------------------
# Output
# ---------------------------------------------------------------------------


def atomic_write(path: Path, lines: list[str]) -> None:
    tmp = path.with_suffix(path.suffix + ".tmp")
    path.parent.mkdir(parents=True, exist_ok=True)
    with open(tmp, "w", encoding="utf-8") as f:
        for line in lines:
            f.write(line + "\n")
        f.flush()
        os.fsync(f.fileno())
    tmp.rename(path)


def validate_tsv(path: Path, min_lines: int, name: str, soft_max: int = 0) -> int:
    with open(path, encoding="utf-8") as f:
        lines = [line.rstrip("\n") for line in f]
    count = len(lines)
    if count < min_lines:
        raise ValueError(
            f"{name} output has only {count} lines, expected at least {min_lines}"
        )
    if soft_max and count < soft_max * 0.8:
        print(
            f"Warning: {name} has {count} entries (expected ~{soft_max}).  "
            f"This may indicate API truncation.",
            file=sys.stderr,
        )
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


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------


def main() -> int:
    token = get_token()
    if not token:
        print("Warning: No gh auth token (60 req/hr limit)", file=sys.stderr)
    else:
        print(f"Using token ({token[:8]}...)", file=sys.stderr)

    opener = build_opener(token)

    # ---- Phase 1: Fetch family list ----------------------------------------
    print("Phase 1: Fetching font family list ...", file=sys.stderr, end=" ", flush=True)
    t0 = time.monotonic()
    entries = paginate_entries(opener, API_BASE)
    families = sorted(
        e["name"] for e in entries if e.get("type") == "dir"
    )
    n_families = len(families)
    print(f"{n_families} families ({time.monotonic() - t0:.1f}s)", file=sys.stderr)

    if n_families == 0:
        print("ERROR: No font families found", file=sys.stderr)
        return 1

    # ---- Phase 2: Concurrent BFS -------------------------------------------
    print(f"Phase 2: Traversing families (workers={WORKERS}) ...",
          file=sys.stderr, flush=True)
    t0 = time.monotonic()

    all_fonts: list[str] = []
    failed_families: list[tuple[str, str]] = []       # family -> error reason
    partial_families: dict[str, list[tuple[str, str]]] = {}  # family -> per-dir errors
    done = 0

    with concurrent.futures.ThreadPoolExecutor(max_workers=WORKERS) as ex:
        future_map = {
            ex.submit(discover_family, f, token): f
            for f in families
        }
        for fut in concurrent.futures.as_completed(future_map):
            family = future_map[fut]
            done += 1
            try:
                fonts, dir_errors = fut.result()
                all_fonts.extend(fonts)
                if dir_errors:
                    partial_families[family] = dir_errors
            except Exception as e:
                failed_families.append((family, str(e)[:120]))

            pct = done * 100 // n_families
            print(
                f"\r  {done}/{n_families} ({pct}%)",
                file=sys.stderr, end="", flush=True,
            )

    elapsed = time.monotonic() - t0
    print(f"  done ({elapsed:.1f}s)", file=sys.stderr)

    # ---- Phase 3: TSV output -----------------------------------------------
    print("Phase 3: Generating TSV output ...", file=sys.stderr, end=" ", flush=True)

    def make_display(path: str) -> str:
        filename = path.rsplit("/", 1)[-1]
        for ext in (".ttf", ".otf"):
            if filename.endswith(ext):
                return filename[:-len(ext)]
        return filename

    lines = sorted(f"{make_display(p)}\t{p}" for p in all_fonts)
    atomic_write(OUTPUT, lines)

    try:
        count = validate_tsv(OUTPUT, min_lines=MIN_FONTS, name="fonts", soft_max=EXPECTED_FONTS)
    except ValueError as e:
        print(f"\nERROR: {e}", file=sys.stderr)
        return 1

    print(f"{count} fonts", file=sys.stderr)

    # ---- Summary -----------------------------------------------------------
    n_success = n_families - len(failed_families)
    n_partial = len(partial_families)

    print(f"\nSummary:", file=sys.stderr)
    print(f"  Families fully traversed: {n_success - n_partial}/{n_families}", file=sys.stderr)
    if n_partial:
        print(f"  Families with partial results: {n_partial}", file=sys.stderr)
        for fam, errs in sorted(partial_families.items()):
            for dirpath, reason in errs[:3]:
                print(f"    {dirpath}: {reason}", file=sys.stderr)
    if failed_families:
        print(f"  Failed families: {len(failed_families)}", file=sys.stderr)
        for fam, reason in failed_families:
            print(f"    {fam}: {reason}", file=sys.stderr)
    print(f"  Total fonts: {len(all_fonts)}", file=sys.stderr)

    return 1 if failed_families else 0


if __name__ == "__main__":
    sys.exit(main())
