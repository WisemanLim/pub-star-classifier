#!/usr/bin/env bash
set -euo pipefail

APP_NAME="pub-star-classifier"
BIN_DIR="${HOME}/.local/bin"
BIN_PATH="${BIN_DIR}/${APP_NAME}"
CFG_DIR="${HOME}/.pub-star-classifier"

need() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "오류: '$1'이(가) 필요합니다." >&2
    exit 1
  }
}

need python3

mkdir -p "${BIN_DIR}"
mkdir -p "${CFG_DIR}"

if [[ -f "${BIN_PATH}" ]]; then
  echo "기존 설치가 감지되었습니다: ${BIN_PATH}"
fi

cat > "${BIN_PATH}" <<'PY'
#!/usr/bin/env python3
import argparse
import json
import os
import re
import shutil
import subprocess
import sys
import textwrap
import urllib.error
import urllib.parse
import urllib.request
from dataclasses import dataclass, asdict
from datetime import datetime
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple

APP_NAME = "pub-star-classifier"
CONFIG_DIR = Path.home() / ".pub-star-classifier"
CONFIG_JSON = CONFIG_DIR / "config.json"
DEFAULT_OUT_DIR = CONFIG_DIR / "output"
CRON_MARKER = f"# {APP_NAME}"

CATEGORIES: Dict[str, List[str]] = {
    "시스템 인프라": ["kernel", "container", "containerd", "runc", "qemu", "kvm", "proxmox", "firecracker"],
    "웹 프레임워크": ["django", "flask", "fastapi", "express", "nestjs", "spring", "gin", "echo", "rails"],
    "데이터베이스": ["postgres", "postgresql", "mysql", "mariadb", "redis", "mongodb", "cockroach", "tidb"],
    "머신러닝/AI": ["llm", "transformer", "transformers", "pytorch", "tensorflow", "sklearn", "llama", "vllm", "ollama"],
    "DevOps/클라우드": ["kubernetes", "k8s", "helm", "terraform", "ansible", "argocd", "flux", "keda", "packer"],
    "프론트엔드 UI": ["react", "vue", "svelte", "next", "nuxt", "tailwind", "shadcn", "vite"],
    "네트워킹/보안": ["nginx", "caddy", "traefik", "envoy", "openssl", "wireguard", "falco", "oauth"],
    "빅데이터 처리": ["spark", "hadoop", "kafka", "flink", "ray", "dask", "airflow", "dbt"],
    "모바일 개발": ["flutter", "react native", "react-native", "android", "kotlin", "swift", "tauri"],
    "유틸리티/도구": ["awesome-", "cli", "tool", "sdk", "dotfiles", "git", "makefile"],
}


@dataclass
class Repo:
    full_name: str
    html_url: str
    description: str
    language: str
    stargazers_count: int
    license: str


def eprint(msg: str) -> None:
    print(msg, file=sys.stderr)


def load_dotenv_file(path: Path) -> Dict[str, str]:
    if not path.exists():
        return {}
    env: Dict[str, str] = {}
    for raw in path.read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        if "=" not in line:
            continue
        k, v = line.split("=", 1)
        k = k.strip()
        v = v.strip().strip("'").strip('"')
        if k:
            env[k] = v
    return env


def load_config() -> Dict[str, Any]:
    CONFIG_DIR.mkdir(parents=True, exist_ok=True)
    if not CONFIG_JSON.exists():
        return {}
    try:
        return json.loads(CONFIG_JSON.read_text(encoding="utf-8"))
    except Exception:
        return {}


def save_config(cfg: Dict[str, Any]) -> None:
    CONFIG_DIR.mkdir(parents=True, exist_ok=True)
    CONFIG_JSON.write_text(json.dumps(cfg, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def classify_repo(repo: Repo) -> str:
    hay = f"{repo.full_name} {repo.description or ''}".lower()
    for cat, keywords in CATEGORIES.items():
        if any(kw in hay for kw in keywords):
            return cat
    lang = (repo.language or "").lower()
    if lang in {"go", "rust"}:
        return "시스템 인프라"
    if lang in {"python"} and any(x in hay for x in ["ml", "ai", "llm", "torch", "tensor"]):
        return "머신러닝/AI"
    if lang in {"typescript", "javascript"} and any(x in hay for x in ["react", "vue", "svelte", "ui", "frontend"]):
        return "프론트엔드 UI"
    return "유틸리티/도구"


def github_get_json(url: str, token: Optional[str]) -> Tuple[Any, Dict[str, str]]:
    req = urllib.request.Request(url, method="GET")
    req.add_header("Accept", "application/vnd.github+json")
    req.add_header("User-Agent", APP_NAME)
    if token:
        req.add_header("Authorization", f"Bearer {token}")
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            body = resp.read().decode("utf-8")
            headers = {k.lower(): v for k, v in resp.headers.items()}
            return json.loads(body), headers
    except urllib.error.HTTPError as e:
        try:
            details = e.read().decode("utf-8", errors="replace")
        except Exception:
            details = ""
        raise RuntimeError(f"GitHub API 오류: HTTP {e.code} {e.reason}\n{details}".strip())
    except urllib.error.URLError as e:
        raise RuntimeError(f"네트워크 오류: {e}")


_LINK_RE = re.compile(r'<([^>]+)>;\s*rel="([^"]+)"')


def parse_next_link(link_header: str) -> Optional[str]:
    links = dict(_LINK_RE.findall(link_header or ""))
    return links.get("next")


def fetch_starred(user_id: str, token: Optional[str]) -> List[Repo]:
    per_page = 100
    url = f"https://api.github.com/users/{urllib.parse.quote(user_id)}/starred?per_page={per_page}"
    repos: List[Repo] = []
    while url:
        data, headers = github_get_json(url, token)
        if not isinstance(data, list):
            raise RuntimeError("예상치 못한 GitHub 응답 형식입니다.")
        for item in data:
            lic = (item.get("license") or {}).get("spdx_id") or ""
            repos.append(
                Repo(
                    full_name=item.get("full_name") or "",
                    html_url=item.get("html_url") or "",
                    description=item.get("description") or "",
                    language=item.get("language") or "",
                    stargazers_count=int(item.get("stargazers_count") or 0),
                    license=lic,
                )
            )
        url = parse_next_link(headers.get("link", ""))
    return repos


def markdown_table_top(repos: List[Repo], top_n: int) -> str:
    categorized: Dict[str, List[Repo]] = {k: [] for k in CATEGORIES.keys()}
    for r in repos:
        categorized.setdefault(classify_repo(r), []).append(r)

    lines = []
    lines.append("| 카테고리 | 프로젝트 | 언어 | Stars |")
    lines.append("|---|---|---:|---:|")
    for cat in CATEGORIES.keys():
        items = sorted(categorized.get(cat, []), key=lambda x: x.stargazers_count, reverse=True)[:top_n]
        if not items:
            lines.append(f"| **{cat}** | - | - | - |")
            continue
        for i, r in enumerate(items):
            cat_cell = f"**{cat}**" if i == 0 else ""
            proj = f"[{r.full_name}]({r.html_url})"
            lang = r.language or "-"
            lines.append(f"| {cat_cell} | {proj} | {lang} | {r.stargazers_count} |")
    return "\n".join(lines) + "\n"


def ensure_out_dir(path: Path) -> None:
    path.mkdir(parents=True, exist_ok=True)


def write_outputs(out_dir: Path, user_id: str, repos: List[Repo], top_n: int, fmt: str) -> Dict[str, Path]:
    ensure_out_dir(out_dir)
    ts = datetime.now().strftime("%Y%m%d-%H%M%S")
    paths: Dict[str, Path] = {}

    if fmt in {"md", "both"}:
        md_path = out_dir / f"{user_id}-stars-{ts}.md"
        md_path.write_text(markdown_table_top(repos, top_n), encoding="utf-8")
        paths["md"] = md_path

    if fmt in {"json", "both"}:
        json_path = out_dir / f"{user_id}-stars-{ts}.json"
        json_path.write_text(
            json.dumps([asdict(r) for r in repos], ensure_ascii=False, indent=2) + "\n",
            encoding="utf-8",
        )
        paths["json"] = json_path

    return paths


def prompt_select(prompt: str, options):
    eprint(prompt)
    for idx, (_, label) in enumerate(options, start=1):
        eprint(f"  {idx}. {label}")
    while True:
        choice = input("> ").strip()
        if not choice:
            continue
        if choice.isdigit() and 1 <= int(choice) <= len(options):
            return options[int(choice) - 1][0]
        eprint("번호를 다시 입력해 주세요.")


def crontab_read() -> str:
    proc = subprocess.run(["crontab", "-l"], capture_output=True, text=True)
    if proc.returncode != 0:
        return ""
    return proc.stdout


def crontab_write(content: str) -> None:
    proc = subprocess.run(["crontab", "-"], input=content, text=True)
    if proc.returncode != 0:
        raise RuntimeError("crontab 갱신에 실패했습니다.")


def install_cron(expr: str, command: str) -> None:
    current = crontab_read().splitlines()
    filtered = [ln for ln in current if CRON_MARKER not in ln]
    filtered.append(f"{expr} {command} {CRON_MARKER}")
    crontab_write("\n".join(filtered).rstrip() + "\n")


def remove_cron() -> bool:
    current = crontab_read().splitlines()
    filtered = [ln for ln in current if CRON_MARKER not in ln]
    if len(filtered) == len(current):
        return False
    crontab_write("\n".join(filtered).rstrip() + "\n")
    return True


def which(cmd: str) -> Optional[str]:
    path = os.getenv("PATH", "")
    for p in path.split(os.pathsep):
        cand = Path(p) / cmd
        if cand.exists() and os.access(cand, os.X_OK):
            return str(cand)
    return None


def main() -> int:
    parser = argparse.ArgumentParser(
        prog=APP_NAME,
        formatter_class=argparse.RawDescriptionHelpFormatter,
        description=textwrap.dedent(
            """\
            GitHub Stars를 카테고리로 분류하여 Markdown/JSON으로 내보냅니다.

            설정 우선순위: --user-id > .env(PSC_USER_ID) > 저장된 설정 > 프롬프트
            """
        ),
    )
    parser.add_argument("--user-id", dest="user_id", help="이번 실행에만 GitHub username 지정")
    parser.add_argument("--set-user-id", dest="set_user_id", help="GitHub username 저장")
    parser.add_argument("--out", dest="out_dir", help="출력 디렉토리 (기본: ~/.pub-star-classifier/output)")
    parser.add_argument("--format", dest="fmt", default="md", choices=["md", "json", "both"], help="출력 형식")
    parser.add_argument("--top", dest="top_n", type=int, default=3, help="카테고리별 Top N (기본 3)")
    parser.add_argument("--install-cron", action="store_true", help="crontab 등록 플로우 실행")
    parser.add_argument("--cron", dest="cron_expr", help="cron 표현식 직접 지정 (예: '0 9 * * *')")
    parser.add_argument("--remove-cron", action="store_true", help="등록된 crontab 항목 제거")
    parser.add_argument("--non-interactive", action="store_true", help="프롬프트 없이 실행")
    args = parser.parse_args()

    dotenv = {}
    dotenv.update(load_dotenv_file(Path.cwd() / ".env"))
    dotenv.update(load_dotenv_file(CONFIG_DIR / ".env"))
    cfg = load_config()

    if args.set_user_id:
        cfg["user_id"] = args.set_user_id.strip()
        save_config(cfg)
        print(f"저장 완료: user_id={cfg['user_id']}")
        return 0

    if args.remove_cron:
        removed = remove_cron()
        print("crontab 항목 제거됨" if removed else "제거할 crontab 항목이 없습니다.")
        return 0

    user_id = (
        (args.user_id or "").strip()
        or (dotenv.get("PSC_USER_ID") or "").strip()
        or (os.getenv("PSC_USER_ID") or "").strip()
        or (cfg.get("user_id") or "").strip()
    )

    if not user_id and not args.non_interactive and sys.stdin.isatty():
        user_id = input("GitHub username(필수)를 입력하세요: ").strip()
        if user_id:
            cfg["user_id"] = user_id
            save_config(cfg)

    if not user_id:
        eprint("오류: user_id가 필요합니다. --user-id 또는 .env(PSC_USER_ID) 또는 --set-user-id를 사용하세요.")
        return 2

    token = (
        (dotenv.get("PSC_GITHUB_TOKEN") or "").strip()
        or (os.getenv("PSC_GITHUB_TOKEN") or "").strip()
        or (dotenv.get("GITHUB_TOKEN") or "").strip()
        or (os.getenv("GITHUB_TOKEN") or "").strip()
    ) or None

    out_dir = Path(args.out_dir or (dotenv.get("PSC_OUT_DIR") or "") or str(DEFAULT_OUT_DIR)).expanduser()

    if args.install_cron:
        if args.cron_expr:
            expr = args.cron_expr.strip()
        elif args.non_interactive:
            expr = "0 9 * * *"
        else:
            expr = prompt_select(
                "crontab 스케줄을 선택하세요.",
                [
                    ("0 9 * * *", "매일 09:00"),
                    ("0 * * * *", "매시간 (정각)"),
                    ("0 9 * * 1", "매주 월요일 09:00"),
                    ("*/15 * * * *", "15분마다"),
                    ("custom", "직접 입력"),
                ],
            )
            if expr == "custom":
                expr = input("cron 표현식을 입력하세요 (예: 0 9 * * *): ").strip()

        exe = which(APP_NAME) or str(Path(__file__).resolve())
        cmd = f'{exe} --non-interactive --format {args.fmt} --top {args.top_n} --out "{out_dir}"'
        install_cron(expr, cmd)
        print(f"crontab 등록 완료: {expr}")
        return 0

    repos = fetch_starred(user_id, token)
    paths = write_outputs(out_dir, user_id, repos, args.top_n, args.fmt)
    print(f"분석 완료: {len(repos)}개 레포")
    for k, p in paths.items():
        print(f"- {k}: {p}")
    if not paths:
        print(markdown_table_top(repos, args.top_n))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
PY

chmod +x "${BIN_PATH}"

if [[ ! -f "${CFG_DIR}/.env" ]]; then
  cat > "${CFG_DIR}/.env" <<'ENV'
# pub-star-classifier local env (예시)
# PSC_USER_ID=
# PSC_GITHUB_TOKEN=
# PSC_OUT_DIR=
ENV
  echo "생성됨: ${CFG_DIR}/.env (필요 시 값 입력)"
else
  echo "유지됨: ${CFG_DIR}/.env (이미 존재)"
fi

echo "설치 완료: ${BIN_PATH}"
echo ""
echo "PATH에 ${BIN_DIR}가 없다면 다음을 추가하세요:"
echo "  export PATH=\"${BIN_DIR}:\$PATH\""
echo ""
echo "빠른 시작:"
echo "  ${APP_NAME} --set-user-id <github-username>"
echo "  ${APP_NAME} --format md --top 3"

