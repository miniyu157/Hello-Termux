#!/usr/bin/env python3
"""从 ryanoasis/nerd-fonts 仓库生成扁平字体索引 font_list.txt。

并发拉取 + Token 鉴权 + 自动重试 + BFS 递归遍历任意深度目录树。
输出格式: FamilyName/FileName.ttf
"""

import concurrent.futures
import json
import subprocess
import sys
import time
import urllib.request
from collections import deque

REPO = "ryanoasis/nerd-fonts"
API = f"https://api.github.com/repos/{REPO}/contents/patched-fonts"
WORKERS = 15
RETRIES = 3
RETRY_BASE = 1.0
TIMEOUT = 30


def get_token() -> str | None:
    try:
        r = subprocess.run(
            ["gh", "auth", "token"], capture_output=True, text=True, timeout=5
        )
        return r.stdout.strip() or None
    except Exception:
        return None


def build_request(url: str, token: str | None) -> urllib.request.Request:
    req = urllib.request.Request(url)
    req.add_header("Accept", "application/vnd.github.v3+json")
    req.add_header("User-Agent", "hello-termux-gen-font-list/1.0")
    if token:
        req.add_header("Authorization", f"Bearer {token}")
    return req


def api_get(url: str, token: str | None) -> list[dict]:
    """带指数退避重试的 API GET，返回解析后的 JSON list。"""
    req = build_request(url, token)
    last_err = None
    for n in range(RETRIES):
        try:
            with urllib.request.urlopen(req, timeout=TIMEOUT) as resp:
                return json.loads(resp.read())
        except Exception as e:
            last_err = e
            if n < RETRIES - 1:
                time.sleep(RETRY_BASE * (2 ** n))
    raise last_err  # type: ignore[misc]


def is_font(name: str) -> bool:
    return name.endswith((".ttf", ".otf"))


# ---------------------------------------------------------------------------
# 递归 BFS 遍历单个家族目录树，收集所有 .ttf 文件
# ---------------------------------------------------------------------------

def discover_family(family: str, token: str | None) -> list[str]:
    """
    从家族根目录开始 BFS 遍历，找到所有 .ttf 文件。
    返回 ["FamilyName/.../file.ttf", ...] 格式（保留完整相对路径）。
    支持任意深度的嵌套（扁平、2层 Variant、3层 Variant/Weight...）
    """
    queue = deque([family])
    results: list[str] = []

    while queue:
        current = queue.popleft()
        entries = api_get(f"{API}/{current}", token)

        font_files = [e["name"] for e in entries if e["type"] == "file" and is_font(e["name"])]
        if font_files:
            for font in font_files:
                results.append(f"{current}/{font}")
        else:
            for e in entries:
                if e["type"] == "dir":
                    queue.append(f"{current}/{e['name']}")

    return results


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main() -> int:
    token = get_token()
    if not token:
        print("⚠ 未获取到 gh auth token，将使用未认证请求（60次/小时限制）", file=sys.stderr)
    else:
        print(f"✓ 已获取 GitHub token（{token[:8]}...）", file=sys.stderr)

    # Phase 1 — 拉取家族列表
    print("▸ 拉取字体家族列表 ...", file=sys.stderr, end=" ", flush=True)
    t0 = time.monotonic()
    entries = api_get(API, token)
    families = sorted(e["name"] for e in entries if e["type"] == "dir")
    n_families = len(families)
    print(f"{n_families} 个家族 ({time.monotonic() - t0:.1f}s)", file=sys.stderr)

    # Phase 2 — 并发 BFS 遍历每个家族
    print(f"▸ 并发遍历家族目录树 (workers={WORKERS}) ...",
          file=sys.stderr, end=" ", flush=True)
    t0 = time.monotonic()

    all_results: list[str] = []
    failed: list[str] = []
    api_calls = n_families  # at minimum, one call per family
    done = 0

    with concurrent.futures.ThreadPoolExecutor(max_workers=WORKERS) as ex:
        future_map = {ex.submit(discover_family, f, token): f for f in families}
        for fut in concurrent.futures.as_completed(future_map):
            family = future_map[fut]
            done += 1
            try:
                ttf_list = fut.result()
                all_results.extend(ttf_list)
            except Exception:
                failed.append(family)
            pct = done * 100 // n_families
            print(f"\r▸ 并发遍历家族目录树 (workers={WORKERS}) ... {done}/{n_families}",
                  file=sys.stderr, end="", flush=True)

    elapsed = time.monotonic() - t0
    print(f" 完成 ({elapsed:.1f}s)", file=sys.stderr)
    if failed:
        print(f"  失败家族: {', '.join(sorted(failed))}", file=sys.stderr)

    # 输出
    all_results.sort()
    for line in all_results:
        print(line)

    ok_families = n_families - len(failed)
    print(f"\n✓ {ok_families}/{n_families} 个家族, {len(all_results)} 条记录", file=sys.stderr)
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
