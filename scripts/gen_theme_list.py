#!/usr/bin/env python3
"""Generate theme_list.tsv from mbadolato/iTerm2-Color-Schemes.

Fetches the termux/ directory via GitHub Contents API with auth, retry,
and pagination.  Falls back to the Git Trees API if the response is
truncated (>1000 entries).

Output: TSV format (ThemeName<TAB>ThemeName.properties)
"""

import json
import os
import random
import subprocess
import sys
import time
import urllib.request
from email.utils import parsedate_to_datetime
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parent.parent
OUTPUT = PROJECT_ROOT / "res_lists" / "theme_list.tsv"

REPO = "mbadolato/iTerm2-Color-Schemes"
DIR_PATH = "termux"
API_BASE = f"https://api.github.com/repos/{REPO}"
MIN_THEMES = 300
EXPECTED_THEMES = 580
TIMEOUT = 30
MAX_RETRIES = 3
RETRY_BASE = 1.0

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
) -> tuple[list[dict], dict]:
    """GET *url*, return (json_list, headers_dict)."""
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
                # HTTPError exposes headers via .headers (no getheader needed)
                rh = {k.lower(): v for k, v in e.headers.items()}  # type: ignore[union-attr]
                delay = parse_retry_after(rh)
                print(f"  Rate limited, waiting {delay:.0f}s ...", file=sys.stderr)
                time.sleep(delay)
                continue
            if 400 <= status < 500:
                raise
            # 5xx: retry with backoff
        except (urllib.error.URLError, TimeoutError, json.JSONDecodeError) as e:
            last_err = e
        if n < MAX_RETRIES - 1:
            delay = RETRY_BASE * (2**n) + random.uniform(0, 1)
            print(f"  Retry {n+1}/{MAX_RETRIES} after {delay:.1f}s: {last_err}", file=sys.stderr)
            time.sleep(delay)
    raise last_err  # type: ignore[misc]


def paginate(
    opener: urllib.request.OpenerDirector, url: str
) -> list[tuple[list[dict], bool]]:
    """Fetch all pages from a GitHub Contents API endpoint.

    Returns a list of (entries_list, truncated_bool) — one per page.
    Follows Link rel=next headers.
    """
    pages: list[tuple[list[dict], bool]] = []
    next_url: str | None = url
    seen: set[str] = set()

    while next_url:
        if next_url in seen:
            break
        seen.add(next_url)
        entries, headers = api_get(opener, next_url)
        truncated = bool(entries.get("truncated", False)) if isinstance(entries, dict) else False
        items = entries if isinstance(entries, list) else entries.get("items", entries if isinstance(entries, list) else [])
        pages.append((items, truncated))
        # Parse Link header for next page
        link = headers.get("Link", "")
        next_url = None
        for part in link.split(","):
            if 'rel="next"' in part:
                start = part.find("<")
                end = part.find(">")
                if start != -1 and end != -1:
                    next_url = part[start + 1:end]
                break
    return pages


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
        raise ValueError(f"{name} output has only {count} lines, expected at least {min_lines}")
    if soft_max and count < soft_max * 0.8:
        print(f"Warning: {name} has {count} entries (expected ~{soft_max}).  "
              f"This may indicate API truncation.", file=sys.stderr)
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
# Fetch strategies
# ---------------------------------------------------------------------------


def fetch_via_contents(opener: urllib.request.OpenerDirector) -> tuple[list[str], bool]:
    """Fetch .properties filenames via Contents API.  Returns (tsv_lines, truncated)."""
    url = f"{API_BASE}/contents/{DIR_PATH}"
    pages = paginate(opener, url)
    lines: list[str] = []
    any_truncated = False
    for entries, truncated in pages:
        if truncated:
            any_truncated = True
        for entry in entries:
            if isinstance(entry, dict) and entry.get("type") == "file":
                name = entry.get("name", "")
                if name.endswith(".properties"):
                    display = name[:-len(".properties")]
                    lines.append(f"{display}\t{name}")
    return lines, any_truncated


def fetch_via_git_trees(opener: urllib.request.OpenerDirector) -> list[str]:
    """Fallback: fetch full file listing via Git Trees API (recursive).

    Not limited to 1000 entries like the Contents API.
    """
    # Get default branch
    repo_info, _ = api_get(opener, API_BASE)
    default_branch = repo_info.get("default_branch", "master")

    # Get branch info for tree SHA
    branch_url = f"{API_BASE}/branches/{default_branch}"
    branch_info, _ = api_get(opener, branch_url)
    tree_sha = branch_info["commit"]["commit"]["tree"]["sha"]

    # Get recursive tree
    tree_url = f"{API_BASE}/git/trees/{tree_sha}?recursive=1"
    tree_data, _ = api_get(opener, tree_url)

    lines: list[str] = []
    prefix = f"{DIR_PATH}/"
    for entry in tree_data.get("tree", []):
        path = entry.get("path", "")
        if path.startswith(prefix) and path.endswith(".properties") and entry.get("type") == "blob":
            filename = path[len(prefix):]
            display = filename[:-len(".properties")]
            lines.append(f"{display}\t{filename}")
    return lines


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

    print("Fetching theme list via Contents API ...", file=sys.stderr, end=" ", flush=True)
    t0 = time.monotonic()
    lines, truncated = fetch_via_contents(opener)
    elapsed = time.monotonic() - t0
    print(f"{len(lines)} entries ({elapsed:.1f}s)", file=sys.stderr)

    if truncated and len(lines) >= 1000:
        print("Contents API response was truncated. Falling back to Git Trees API ...",
              file=sys.stderr)
        lines = fetch_via_git_trees(opener)
        print(f"  Trees API: {len(lines)} entries", file=sys.stderr)

    if not lines:
        print(f"ERROR: No .properties files found in {REPO}/{DIR_PATH}", file=sys.stderr)
        return 1

    lines.sort()
    atomic_write(OUTPUT, lines)

    try:
        count = validate_tsv(OUTPUT, min_lines=MIN_THEMES, name="themes", soft_max=EXPECTED_THEMES)
    except ValueError as e:
        print(f"ERROR: {e}", file=sys.stderr)
        return 1

    print(f"theme_list.tsv: {count} entries", file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main())
