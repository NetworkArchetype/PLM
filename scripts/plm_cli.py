#!/usr/bin/env python3
"""Operator console for PLM (CLI + optional curses UI).

Features mirror the Admin GUI:
- Environment detection (git/python/winget/wsl/docker/nvidia/cuda)
- Run smoke test (test_installation.py)
- Run full pytest suite
- Probe CUDA/GPU (nvidia-smi, nvcc)
- Toggle CUDA via Configure-CUDA.ps1
- Launch Admin GUI
- Open debug console (optionally with venv activated)
- Export debug report

Usage examples:
  python scripts/plm_cli.py --env
  python scripts/plm_cli.py --smoke
  python scripts/plm_cli.py --pytest
  python scripts/plm_cli.py --probe-cuda
  python scripts/plm_cli.py --enable-cuda
  python scripts/plm_cli.py --disable-cuda
  python scripts/plm_cli.py --launch-gui
  python scripts/plm_cli.py --menu      # interactive menu (default)
  python scripts/plm_cli.py --curses    # try curses menu (requires windows-curses on Windows)

Note: On Windows, install optional curses support with:
  pip install windows-curses
"""
from __future__ import annotations

import argparse
import datetime
import json
import os
import shutil
import subprocess
import sys
import tempfile
import uuid
from pathlib import Path
from typing import Dict, List, Optional, Tuple

try:
    import plm_store  # type: ignore
except Exception:  # noqa: BLE001
    plm_store = None

REPO_ROOT = Path(__file__).resolve().parents[1]
DEFAULT_PY = Path(sys.executable)
VENV_PY = REPO_ROOT / "venv" / "Scripts" / "python.exe"
CONFIG_CUDA_PS1 = REPO_ROOT / "Configure-CUDA.ps1"
ADMIN_GUI_PS1 = REPO_ROOT / "Deploy" / "PLM-Environment-AdminGUI.fixed.ps1"
CONTEXT_PATH = REPO_ROOT / ".plm_session.ndjson"
SESSION_ID = str(uuid.uuid4())
USERNAME = os.environ.get("USERNAME") or os.environ.get("USER") or "unknown"


def which(cmd: str) -> Optional[str]:
    path = shutil.which(cmd)
    return path


def run(cmd: List[str], capture: bool = True, check: bool = False) -> Tuple[int, str, str]:
    try:
        proc = subprocess.run(cmd, capture_output=capture, text=True, check=check)
        return proc.returncode, proc.stdout.strip(), proc.stderr.strip()
    except FileNotFoundError as exc:
        return 127, "", str(exc)
    except subprocess.CalledProcessError as exc:
        return exc.returncode, exc.stdout or "", exc.stderr or ""


def get_python() -> Path:
    if VENV_PY.exists():
        return VENV_PY
    return DEFAULT_PY


def detect_environment() -> Dict[str, bool]:
    def docker_ready() -> bool:
        if not which("docker"):
            return False
        code, out, _ = run(["docker", "version", "--format", "{{.Server.Version}}"], capture=True)
        if code == 0 and out:
            return True
        code, out, _ = run(["docker", "info", "--format", "{{.ID}}"], capture=True)
        return code == 0 and bool(out)

    def wsl_ready() -> bool:
        if not which("wsl"):
            return False
        code, out, _ = run(["wsl", "-l", "-q"], capture=True)
        if code != 0 or not out.strip():
            return False
        status_code, _, _ = run(["wsl", "--status"], capture=True)
        return status_code == 0

    env = {
        "git": bool(which("git")),
        "python": bool(which("python")),
        "winget": bool(which("winget")),
        "wsl": wsl_ready(),
        "docker": docker_ready(),
        "wt": bool(which("wt")),
        "code": bool(which("code")),
        "nvidia_smi": bool(which("nvidia-smi")),
        "nvcc": bool(which("nvcc")),
    }
    return env


def _utc_iso() -> str:
    return datetime.datetime.now(datetime.timezone.utc).isoformat()


def append_context(msg: str) -> None:
    entry = {
        "ts": _utc_iso(),
        "session": SESSION_ID,
        "source": "cli",
        "user": USERNAME,
        "msg": msg,
    }
    try:
        CONTEXT_PATH.parent.mkdir(parents=True, exist_ok=True)
        with CONTEXT_PATH.open("a", encoding="utf-8") as f:
            f.write(json.dumps(entry, separators=(",", ":")) + "\n")
    except OSError:
        pass
    _log_store_event("context", msg, None)


def _log_store_event(kind: str, msg: str, payload: Optional[Dict] = None) -> None:
    if not plm_store:
        return
    try:
        plm_store.log_event(
            source="cli",
            kind=kind,
            msg=msg,
            session=SESSION_ID,
            user=USERNAME,
            payload=payload,
            engine="auto",
        )
    except Exception:
        # Logging must never break CLI
        pass


def context_tail(count: int = 200) -> List[Dict]:
    if not CONTEXT_PATH.exists():
        return []
    try:
        lines = CONTEXT_PATH.read_text(encoding="utf-8").splitlines()
    except OSError:
        return []
    tail = lines[-count:]
    out: List[Dict] = []
    for ln in tail:
        try:
            out.append(json.loads(ln))
        except json.JSONDecodeError:
            continue
    return out


def _parse_ts(ts_str: str) -> Optional[datetime.datetime]:
    try:
        dt = datetime.datetime.fromisoformat(ts_str)
        if dt.tzinfo is None:
            dt = dt.replace(tzinfo=datetime.timezone.utc)
        return dt
    except Exception:
        return None


def check_collision(minutes: int = 30) -> None:
    cutoff = datetime.datetime.now(datetime.timezone.utc) - datetime.timedelta(minutes=minutes)
    me = os.environ.get("USERNAME") or os.environ.get("USER")
    hits = [
        e
        for e in context_tail()
        if e.get("ts")
        and (
            (e.get("user") and e.get("user") != me)
            or (e.get("session") and e.get("session") != SESSION_ID)
        )
    ]
    recent = []
    for e in hits:
        try:
            ts = _parse_ts(e["ts"])
            if ts and ts >= cutoff:
                recent.append((ts, e))
        except ValueError:
            continue
    if recent:
        ts, entry = sorted(recent)[-1]
        user = entry.get("user", "unknown")
        print(f"Heads-up: another session ({user}) was active at {ts.isoformat()}. Be cautious with shared resources.")


def open_docs() -> None:
    doc_path = REPO_ROOT / "docs" / "Admin-GUI-and-CLI-Guide.md"
    if not doc_path.exists():
        print("Operator guide not found.")
        return
    print(f"Opening operator guide: {doc_path}")
    append_context("cli:open-docs")
    if os.name == "nt":
        os.startfile(doc_path)  # type: ignore[attr-defined]
    else:
        subprocess.Popen(["xdg-open", str(doc_path)])


def print_environment(env: Dict[str, bool]) -> None:
    print("Environment detection:")
    for k, v in env.items():
        status = "OK" if v else "Missing"
        print(f"- {k}: {status}")
    append_context("cli:env")
    _log_store_event("env", "cli:env", {"env": env})


def run_smoke(full: bool = False) -> int:
    py = get_python()
    cmd = [str(py)]
    if full:
        cmd += ["-m", "pytest"]
        label = "Full pytest suite"
    else:
        cmd += ["test_installation.py"]
        label = "Smoke test"
    append_context(f"cli:{label}")
    print(f"Running {label} with {py} ...")
    code, out, err = run(cmd, capture=True)
    if out:
        print(out)
    if err:
        print(err)
    print(f"Exit code: {code}")
    append_context(f"cli:{label}:exit={code}")
    _log_store_event("diagnostic", label, {"exit_code": code, "full": full})
    return code


def probe_cuda() -> None:
    print("CUDA/GPU probe...")
    append_context("cli:probe-cuda")
    _log_store_event("probe", "cli:probe-cuda", None)
    code, out, err = run(["nvidia-smi"])
    if code == 0:
        print("- nvidia-smi OK")
        if out:
            print(out)
    else:
        print(f"- nvidia-smi not available ({err or code})")
    _log_store_event("probe", "cli:nvidia-smi", {"exit_code": code, "stdout": out, "stderr": err})
    code, out, err = run(["nvcc", "--version"])
    if code == 0:
        print("- nvcc detected")
        if out:
            print(out)
    else:
        print(f"- nvcc not available ({err or code})")
    _log_store_event("probe", "cli:nvcc", {"exit_code": code, "stdout": out, "stderr": err})


def toggle_cuda(enable: bool) -> int:
    if not CONFIG_CUDA_PS1.exists():
        print("Configure-CUDA.ps1 not found; cannot toggle CUDA.")
        return 1
    append_context("cli:enable-cuda" if enable else "cli:disable-cuda")
    cmd = [
        "powershell",
        "-ExecutionPolicy",
        "Bypass",
        "-File",
        str(CONFIG_CUDA_PS1),
        "-Enable" if enable else "-Disable",
    ]
    print(("Enabling" if enable else "Disabling") + " CUDA via Configure-CUDA.ps1 ...")
    code, out, err = run(cmd)
    if out:
        print(out)
    if err:
        print(err)
    _log_store_event("action", "cli:toggle-cuda", {"enable": enable, "exit_code": code, "stdout": out, "stderr": err})
    return code


def winget_batch(ids: List[str], upgrade: bool = False) -> int:
    if not which("winget"):
        print("winget not found; install App Installer from Microsoft Store.")
        return 1
    verb = "upgrade" if upgrade else "install"
    rc = 0
    for pkg in ids:
        cmd = ["winget", verb, "--id", pkg, "-e", "--silent", "--accept-package-agreements", "--accept-source-agreements"]
        print(f"Running winget {verb} {pkg} ...")
        code, out, err = run(cmd)
        rc = rc or code
        if out:
            print(out)
        if err:
            print(err)
        _log_store_event("winget", f"cli:winget:{verb}:{pkg}", {"exit_code": code, "stdout": out, "stderr": err})
    return rc


def launch_gui() -> int:
    if not ADMIN_GUI_PS1.exists():
        print("Admin GUI script not found.")
        return 1
    append_context("switch:cli->gui")
    _log_store_event("switch", "cli->gui", None)
    cmd = ["powershell", "-ExecutionPolicy", "Bypass", "-File", str(ADMIN_GUI_PS1)]
    print("Launching Admin GUI ...")
    code, out, err = run(cmd)
    if out:
        print(out)
    if err:
        print(err)
    return code


def install_or_repair() -> int:
    packages = [
        "Git.Git",
        "Python.Python.3.12",
        "Microsoft.VisualStudioCode",
        "Microsoft.WindowsTerminal",
        "Docker.DockerDesktop",
        "Nvidia.CUDA",
    ]
    print("Install/Repair selected components via winget ...")
    append_context("cli:install-repair")
    _log_store_event("action", "cli:install-repair", None)
    return winget_batch(packages, upgrade=False)


def update_components() -> int:
    packages = [
        "Git.Git",
        "Python.Python.3.12",
        "Microsoft.VisualStudioCode",
        "Microsoft.WindowsTerminal",
        "Docker.DockerDesktop",
        "Nvidia.CUDA",
    ]
    print("Updating components via winget ...")
    append_context("cli:update-components")
    _log_store_event("action", "cli:update-components", None)
    return winget_batch(packages, upgrade=True)


def open_debug_console(activate_venv: bool = False) -> None:
    activate = ""
    if activate_venv and (REPO_ROOT / "venv" / "Scripts" / "Activate.ps1").exists():
        activate = f". '{(REPO_ROOT / 'venv' / 'Scripts' / 'Activate.ps1')}'; "
    ps_cmd = f"& {{ Set-Location -LiteralPath '{REPO_ROOT}'; {activate} Write-Host 'PLM debug console ready at {REPO_ROOT}'; }}"
    subprocess.Popen([
        "powershell",
        "-NoExit",
        "-ExecutionPolicy",
        "Bypass",
        "-Command",
        ps_cmd,
    ])
    print("Debug console opened.")
    append_context("cli:debug-console:venv" if activate_venv else "cli:debug-console")
    _log_store_event("action", "cli:debug-console", {"venv": bool(activate_venv)})


def export_report() -> Path:
    stamp = datetime.datetime.utcnow().strftime("%Y%m%d-%H%M%S")
    path = Path(tempfile.gettempdir()) / f"plm-debug-{stamp}.log"
    env = detect_environment()
    lines = [
        f"PLM Debug Report {stamp}",
        f"Repo: {REPO_ROOT}",
        "Environment:" + " ".join(f"{k}={v}" for k, v in env.items()),
        "",
    ]
    path.write_text("\n".join(lines), encoding="utf-8")
    print(f"Debug report written: {path}")
    append_context("cli:export-report")
    _log_store_event("action", "cli:export-report", {"path": str(path)})
    return path


def handle_actions(args: argparse.Namespace) -> bool:
    if args.env:
        print_environment(detect_environment())
        return True
    if args.smoke:
        run_smoke(full=False)
        return True
    if args.pytest:
        run_smoke(full=True)
        return True
    if args.probe_cuda:
        probe_cuda()
        return True
    if args.enable_cuda:
        toggle_cuda(True)
        return True
    if args.disable_cuda:
        toggle_cuda(False)
        return True
    if args.launch_gui:
        launch_gui()
        return True
    if args.install_repair:
        install_or_repair()
        return True
    if args.update_components:
        update_components()
        return True
    if args.debug_console:
        open_debug_console(False)
        return True
    if args.venv_console:
        open_debug_console(True)
        return True
    if args.export_report:
        export_report()
        return True
    if args.docs:
        open_docs()
        return True
    return False


def menu_loop() -> None:
    append_context("cli:menu")
    actions = {
        "1": ("Detect environment", lambda: print_environment(detect_environment())),
        "2": ("Run smoke test", lambda: run_smoke(False)),
        "3": ("Run full pytest", lambda: run_smoke(True)),
        "4": ("Probe CUDA/GPU", probe_cuda),
        "5": ("Enable CUDA", lambda: toggle_cuda(True)),
        "6": ("Disable CUDA", lambda: toggle_cuda(False)),
        "7": ("Install / Repair components", install_or_repair),
        "8": ("Update components", update_components),
        "9": ("Launch Admin GUI", launch_gui),
        "10": ("Open debug console", lambda: open_debug_console(False)),
        "11": ("Open option 2 console (venv)", lambda: open_debug_console(True)),
        "12": ("Export debug report", export_report),
        "13": ("Open operator guide", open_docs),
        "0": ("Exit", None),
    }
    while True:
        print("\nPLM Operator Console")
        for k in sorted(actions, key=lambda x: int(x) if x.isdigit() else 99):
            title = actions[k][0]
            print(f" {k}. {title}")
        choice = input("Select option: ").strip()
        if choice == "0":
            break
        action = actions.get(choice)
        if not action:
            print("Invalid selection")
            continue
        fn = action[1]
        if fn:
            fn()


def curses_menu() -> None:
    try:
        import curses
    except ImportError:
        print("curses not available; install windows-curses or run without --curses")
        return menu_loop()

    actions = [
        ("Detect environment", lambda: print_environment(detect_environment())),
        ("Run smoke test", lambda: run_smoke(False)),
        ("Run full pytest", lambda: run_smoke(True)),
        ("Probe CUDA/GPU", probe_cuda),
        ("Enable CUDA", lambda: toggle_cuda(True)),
        ("Disable CUDA", lambda: toggle_cuda(False)),
        ("Install / Repair components", install_or_repair),
        ("Update components", update_components),
        ("Launch Admin GUI", launch_gui),
        ("Open debug console", lambda: open_debug_console(False)),
        ("Open option 2 console (venv)", lambda: open_debug_console(True)),
        ("Export debug report", export_report),
        ("Open operator guide", open_docs),
    ]

    def _menu(stdscr):
        curses.curs_set(0)
        idx = 0
        while True:
            stdscr.clear()
            stdscr.addstr(0, 0, "PLM Operator Console (curses)")
            for i, (title, _) in enumerate(actions):
                marker = "> " if i == idx else "  "
                stdscr.addstr(2 + i, 0, f"{marker}{title}")
            stdscr.addstr(2 + len(actions) + 1, 0, "Press Enter to run, q to quit")
            stdscr.refresh()
            ch = stdscr.getch()
            if ch in (ord("q"), 27):
                break
            if ch in (curses.KEY_UP, ord("k")):
                idx = (idx - 1) % len(actions)
            elif ch in (curses.KEY_DOWN, ord("j")):
                idx = (idx + 1) % len(actions)
            elif ch in (curses.KEY_ENTER, ord("\n"), ord("\r")):
                curses.endwin()
                actions[idx][1]()
                input("Press Enter to return to menu...")
                curses.initscr()
                curses.curs_set(0)

    curses.wrapper(_menu)


def main() -> None:
    parser = argparse.ArgumentParser(description="PLM Operator Console (GUI parity)")
    parser.add_argument("--env", action="store_true", help="Detect environment")
    parser.add_argument("--smoke", action="store_true", help="Run smoke test")
    parser.add_argument("--pytest", action="store_true", help="Run full pytest")
    parser.add_argument("--probe-cuda", action="store_true", help="Probe CUDA/GPU")
    parser.add_argument("--enable-cuda", action="store_true", help="Enable CUDA via Configure-CUDA.ps1")
    parser.add_argument("--disable-cuda", action="store_true", help="Disable CUDA via Configure-CUDA.ps1")
    parser.add_argument("--launch-gui", action="store_true", help="Launch Admin GUI")
    parser.add_argument("--install-repair", action="store_true", help="Install/Repair core components via winget")
    parser.add_argument("--update-components", action="store_true", help="Update core components via winget")
    parser.add_argument("--debug-console", action="store_true", help="Open debug console")
    parser.add_argument("--venv-console", action="store_true", help="Open debug console with venv activated")
    parser.add_argument("--export-report", action="store_true", help="Export debug report")
    parser.add_argument("--docs", action="store_true", help="Open operator guide")
    parser.add_argument("--menu", action="store_true", help="Interactive menu (default if no action)")
    parser.add_argument("--curses", dest="use_curses", action="store_true", help="Try curses-based menu UI")
    args = parser.parse_args()

    check_collision()

    if handle_actions(args):
        return

    if args.use_curses:
        return curses_menu()

    # default to menu
    menu_loop()


if __name__ == "__main__":
    main()
