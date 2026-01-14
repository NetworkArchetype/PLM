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
DOCKER_DESKTOP_EXE = Path(os.environ.get("ProgramFiles", "C:/Program Files")) / "Docker" / "Docker" / "Docker Desktop.exe"
DOCKER_BACKEND_EXE = Path(os.environ.get("ProgramFiles", "C:/Program Files")) / "Docker" / "Docker" / "resources" / "com.docker.backend.exe"
CONTEXT_PATH = REPO_ROOT / ".plm_session.ndjson"
DOC_PATH = REPO_ROOT / "docs" / "Admin-GUI-and-CLI-Guide.md"
SESSION_ID = str(uuid.uuid4())
USERNAME = os.environ.get("USERNAME") or os.environ.get("USER") or "unknown"
LOG_LEVEL = "info"  # info|debug


def which(cmd: str) -> Optional[str]:
    path = shutil.which(cmd)
    return path


def find_nvcc_path() -> Optional[str]:
    path = which("nvcc")
    if path:
        return path

    cuda_path = os.environ.get("CUDA_PATH") or os.environ.get("CUDA_PATH_V12_0") or os.environ.get("CUDA_PATH_V11_0")
    if cuda_path:
        candidate = Path(cuda_path) / "bin" / "nvcc.exe"
        if candidate.exists():
            return str(candidate)

    cuda_root = Path(os.environ.get("ProgramFiles", "C:/Program Files")) / "NVIDIA GPU Computing Toolkit" / "CUDA"
    if cuda_root.exists():
        versions = sorted(cuda_root.glob("v*"), reverse=True)
        for vdir in versions:
            cand = vdir / "bin" / "nvcc.exe"
            if cand.exists():
                return str(cand)
    return None


def run(cmd: List[str], capture: bool = True, check: bool = False) -> Tuple[int, str, str]:
    try:
        log(f"RUN {' '.join(cmd)}", "debug", context=False)
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
        "nvcc": bool(find_nvcc_path()),
    }
    return env


def sleep(seconds: float) -> None:
    try:
        import time

        time.sleep(seconds)
    except Exception:
        subprocess.run([sys.executable, "-c", f"import time; time.sleep({seconds})"], check=False)


def _utc_iso() -> str:
    return datetime.datetime.now(datetime.timezone.utc).isoformat()


def set_log_level(level: str) -> None:
    """Set global log verbosity (info/debug)."""
    global LOG_LEVEL
    lvl = level.lower()
    if lvl not in {"info", "debug", "normal"}:
        return
    LOG_LEVEL = "debug" if lvl == "debug" else "info"


def log(msg: str, level: str = "info", context: bool = True) -> None:
    """Emit a log line respecting the configured level and optionally mirror to context."""
    allowed = LOG_LEVEL == "debug" or level.lower() != "debug"
    if not allowed:
        return
    ts = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    print(f"[{ts}] {msg}")
    if context:
        append_context(f"{level}:{msg}")


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


def print_environment(env: Dict[str, bool]) -> None:
    """Pretty-print environment detection results."""
    log("Environment detection:")
    for k, v in env.items():
        status = "OK" if v else "Missing/Not ready"
        log(f"- {k}: {status}", context=False)
    append_context("cli:env")
    _log_store_event("env", "cli:env", {"env": env})


def open_docs() -> None:
    """Open the operator guide (GUI/CLI parity)."""
    if not DOC_PATH.exists():
        print("Operator guide not found.")
        return
    print(f"Opening operator guide: {DOC_PATH}")
    append_context("cli:docs")
    _log_store_event("docs", "cli:docs", {"path": str(DOC_PATH)})
    try:
        if os.name == "nt":
            os.startfile(DOC_PATH)  # type: ignore[attr-defined]
        else:
            subprocess.Popen(["xdg-open", str(DOC_PATH)])
    except Exception as exc:  # pragma: no cover - platform dependent
        print(f"Failed to open docs: {exc}")


def run_smoke(full: bool = False) -> int:
    """Run smoke test or full pytest suite."""
    py = get_python()
    cmd = [str(py)]
    label = "Smoke test"
    if full:
        cmd += ["-m", "pytest"]
        label = "Full pytest suite"
    else:
        cmd += ["test_installation.py"]
    append_context(f"cli:{label}")
    log(f"Running {label} with {py} ...")
    code, out, err = run(cmd, capture=True)
    if out:
        log(out, context=False)
    if err:
        log(err, context=False)
    log(f"Exit code: {code}")
    append_context(f"cli:{label}:exit={code}")
    _log_store_event("diagnostic", label, {"exit_code": code, "full": full})
    return code


def probe_cuda() -> None:
    print("CUDA/GPU probe...")
    append_context("cli:probe-cuda")
    _log_store_event("probe", "cli:probe-cuda", None)

    result = {
        "nvidia_smi": {"present": False, "raw": ""},
        "nvcc": {"present": False, "raw": ""},
        "tensorflow": {"present": False, "raw": "", "gpus": []},
        "torch": {"present": False, "raw": "", "cuda_available": False, "gpus": []},
        "cupy": {"present": False, "raw": "", "device_count": 0},
        "docker": {"present": bool(which("docker")), "gpu_runtime": False, "raw": ""},
        "cuda_capable": False,
    }

    cuda_path = os.environ.get("CUDA_PATH") or os.environ.get("CUDA_PATH_V12_0") or os.environ.get("CUDA_PATH_V11_0")
    if cuda_path:
        print(f"- CUDA_PATH: {cuda_path}")

    nvcc_path = find_nvcc_path()
    if nvcc_path:
        if nvcc_path not in os.environ.get("PATH", ""):
            os.environ["PATH"] = f"{Path(nvcc_path).parent}{os.pathsep}" + os.environ.get("PATH", "")
        print(f"- nvcc path: {nvcc_path}")

    code_smi, out_smi, err_smi = run(["nvidia-smi"])
    if code_smi == 0:
        result["nvidia_smi"]["present"] = True
        result["nvidia_smi"]["raw"] = out_smi
        print("- nvidia-smi OK")
        if out_smi:
            print(out_smi)
    else:
        print(f"- nvidia-smi not available ({err_smi or code_smi})")
    _log_store_event("probe", "cli:nvidia-smi", {"exit_code": code_smi, "stdout": out_smi, "stderr": err_smi})

    nvcc_ready = False
    if nvcc_path:
        code_nvcc, out_nvcc, err_nvcc = run([nvcc_path, "--version"])
        if code_nvcc == 0:
            nvcc_ready = True
            result["nvcc"]["present"] = True
            result["nvcc"]["raw"] = out_nvcc
            print("- nvcc detected (Toolkit ready)")
            if out_nvcc:
                print(out_nvcc)
        else:
            print(f"- nvcc found but could not run ({err_nvcc or code_nvcc})")
        _log_store_event("probe", "cli:nvcc", {"exit_code": code_nvcc, "stdout": out_nvcc, "stderr": err_nvcc, "path": nvcc_path})

    py = get_python()

    tf_cmd = [
        str(py),
        "-c",
        "import json,sys\n"
        "try:\n"
        " import tensorflow as tf\n"
        " info={'ver':getattr(tf,'__version__','?'),'gpus':[d.name for d in tf.config.list_physical_devices('GPU')]}\n"
        " print(json.dumps(info))\n"
        " sys.exit(0)\n"
        "except Exception as e:\n"
        " print('ERROR '+str(e)); sys.exit(1)\n",
    ]
    code_tf, out_tf, err_tf = run(tf_cmd)
    if code_tf == 0:
        result["tensorflow"]["present"] = True
        result["tensorflow"]["raw"] = out_tf
        try:
            parsed = json.loads(out_tf)
            result["tensorflow"]["gpus"] = parsed.get("gpus") or []
        except Exception:
            pass
        log(f"- tensorflow: {out_tf}")
    else:
        log(f"- tensorflow not ready ({err_tf or out_tf or code_tf})")
    _log_store_event("probe", "cli:tensorflow", {"exit_code": code_tf, "stdout": out_tf, "stderr": err_tf})

    torch_cmd = [
        str(py),
        "-c",
        "import json,sys\n"
        "try:\n"
        " import torch\n"
        " info={'ver':getattr(torch,'__version__','?'),'cuda_available':bool(torch.cuda.is_available())}\n"
        " info['gpus']=[torch.cuda.get_device_name(i) for i in range(torch.cuda.device_count())] if info['cuda_available'] else []\n"
        " print(json.dumps(info))\n"
        " sys.exit(0)\n"
        "except Exception as e:\n"
        " print('ERROR '+str(e)); sys.exit(1)\n",
    ]
    code_torch, out_torch, err_torch = run(torch_cmd)
    if code_torch == 0:
        result["torch"]["present"] = True
        result["torch"]["raw"] = out_torch
        try:
            parsed = json.loads(out_torch)
            result["torch"]["cuda_available"] = bool(parsed.get("cuda_available"))
            result["torch"]["gpus"] = parsed.get("gpus") or []
        except Exception:
            pass
        log(f"- torch: {out_torch}")
    else:
        log(f"- torch not ready ({err_torch or out_torch or code_torch})")
    _log_store_event("probe", "cli:torch", {"exit_code": code_torch, "stdout": out_torch, "stderr": err_torch})

    cupy_cmd = [
        str(py),
        "-c",
        "import json,sys\n"
        "try:\n"
        " import cupy as cp\n"
        " cnt=int(cp.cuda.runtime.getDeviceCount())\n"
        " print(json.dumps({'ver':getattr(cp,'__version__','?'),'device_count':cnt}))\n"
        " sys.exit(0)\n"
        "except Exception as e:\n"
        " print('ERROR '+str(e)); sys.exit(1)\n",
    ]
    code_cupy, out_cupy, err_cupy = run(cupy_cmd)
    if code_cupy == 0:
        result["cupy"]["present"] = True
        result["cupy"]["raw"] = out_cupy
        try:
            parsed = json.loads(out_cupy)
            result["cupy"]["device_count"] = int(parsed.get("device_count") or 0)
        except Exception:
            pass
        log(f"- cupy: {out_cupy}")
    else:
        log(f"- cupy not ready ({err_cupy or out_cupy or code_cupy})")
    _log_store_event("probe", "cli:cupy", {"exit_code": code_cupy, "stdout": out_cupy, "stderr": err_cupy})

    docker_gpu_ready = False
    if which("docker"):
        code_docker, out_docker, err_docker = run(
            ["docker", "run", "--rm", "--gpus", "all", "nvidia/cuda:12.4.0-base-ubuntu22.04", "nvidia-smi"]
        )
        if code_docker == 0:
            docker_gpu_ready = True
            result["docker"]["gpu_runtime"] = True
            result["docker"]["raw"] = out_docker
            log("- docker GPU probe OK (CUDA via container ready)")
            if out_docker:
                log(out_docker, context=False)
        else:
            log(f"- docker GPU probe failed ({err_docker or code_docker})")
        _log_store_event("probe", "cli:docker-gpu", {"exit_code": code_docker, "stdout": out_docker, "stderr": err_docker})

    tf_ready = bool(result["tensorflow"]["present"])
    torch_cuda = bool(result["torch"]["cuda_available"])
    cupy_cuda = bool(result["cupy"]["device_count"])
    cuda_hw = bool(result["nvidia_smi"]["present"]) or nvcc_ready or docker_gpu_ready
    result["cuda_capable"] = bool(cuda_hw or torch_cuda or cupy_cuda)

    if result["cuda_capable"]:
        print("CUDA preference: CUDA (when supported); CPU fallback only if required")
    else:
        print("CUDA preference: CPU (no CUDA-capable GPU detected)")

    ready_msgs: List[str] = []
    if result["nvidia_smi"]["present"]:
        ready_msgs.append("nvidia-smi OK")
    if nvcc_ready:
        ready_msgs.append("nvcc OK")
    if docker_gpu_ready:
        ready_msgs.append("CUDA via docker OK")
    if tf_ready:
        ready_msgs.append("TensorFlow present")
    if result["torch"]["present"]:
        ready_msgs.append("Torch present")
    if result["cupy"]["present"]:
        ready_msgs.append("CuPy present")

    if ready_msgs:
        print(f"Status: {'; '.join(ready_msgs)}")
    else:
        print("Status: no GPU/ML components detected")

    if os.name == "nt" and result["nvidia_smi"]["present"] and not (result["tensorflow"]["gpus"]):
        print("Note: On Windows, TensorFlow GPU is not supported natively; use Torch/CuPy or Docker/WSL2 for TF GPU.")


def run_plm_simulation() -> int:
    """Run full PLM quantum temporal simulation."""
    from plm_formalized.stateful import PLMState, StatefulPLM, PLMInputs
    from plm_formalized.quantum_temporal import simulate_time_series, QuantumTemporalConfig
    from decimal import Decimal
    import math

    print("Running PLM quantum temporal simulation...")

    # Sample inputs
    pi = Decimal(math.pi)
    lam = Decimal('1.61803398874989484820458683436563811772030917980576286213544862270526046281890244970720720418939113748475')  # phi
    mu = Decimal('2.718281828459045235360287471352662497757247093699959574966967627724076630353547594571382178525166427427')  # e

    x = 42
    public_hash_hex = 'abcdef1234567890'
    block_size = 128
    crc_decimal = 12345

    inputs = PLMInputs(pi=pi, lam=lam, mu=mu, x=x, public_hash_hex=public_hash_hex, block_size=block_size, crc_decimal=crc_decimal)

    def update(state):
        new_x = state.inputs.x + 1
        new_inputs = PLMInputs(pi=state.inputs.pi, lam=state.inputs.lam, mu=state.inputs.mu, x=new_x, public_hash_hex=state.inputs.public_hash_hex, block_size=state.inputs.block_size, crc_decimal=state.inputs.crc_decimal)
        return PLMState(t=state.t + 1, inputs=new_inputs)

    initial_state = PLMState(t=0, inputs=inputs)
    machine = StatefulPLM(initial_state, update)

    cfg = QuantumTemporalConfig(shots=1000, scale=1.0)
    results = simulate_time_series(machine, steps=10, cfg=cfg)

    print("PLM Quantum Temporal Simulation Results:")
    for r in results:
        print(f"t={r['t']}, S={r['S'][:30]}..., theta={r['theta']:.3f}, p1={r['p1']:.3f}, expZ={r['expZ']:.3f}")

    print("Simulation complete.")
    return 0


def ensure_docker_running(auto_install: bool = False, wait_secs: int = 60) -> bool:
    """Start Docker Desktop if installed; optionally install it."""

    def _running() -> bool:
        code, out, _ = run(["docker", "info", "--format", "{{.ID}}"])
        return code == 0 and bool(out.strip())

    if _running():
        log("Docker is running.")
        return True

    if not which("docker") and auto_install:
        log("Installing Docker Desktop via winget ...")
        winget_batch(["Docker.DockerDesktop"], upgrade=False)

    # Best-effort service start; may stay 'Stopped' even when backend is active
    subprocess.run(["powershell", "-Command", "Start-Service com.docker.service"], check=False)

    # Launch the Desktop UI/back-end if present
    if DOCKER_DESKTOP_EXE.exists():
        subprocess.Popen([str(DOCKER_DESKTOP_EXE)])
    if DOCKER_BACKEND_EXE.exists():
        subprocess.Popen([str(DOCKER_BACKEND_EXE), "--unattended"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

    for _ in range(max(3, wait_secs // 2)):
        if _running():
            log("Docker started.")
            return True
        sleep(2)

    log("Docker did not start. Open Docker Desktop manually and retry.")
    return False


def install_cuda_toolkit() -> int:
    if which("nvcc"):
        log("CUDA toolkit already present (nvcc found).")
        return 0
    log("Installing NVIDIA CUDA Toolkit via winget ...")
    return winget_batch(["Nvidia.CUDA"], upgrade=False)


def install_tensorflow_gpu() -> int:
    py = get_python()
    log(f"Installing TensorFlow (GPU where available) with {py} ...")
    code_pip, out_pip, err_pip = run([str(py), "-m", "pip", "install", "--upgrade", "pip"])
    if out_pip:
        log(out_pip, context=False)
    if err_pip:
        log(err_pip, context=False)
    # Windows: TensorFlow GPU is not supported natively, so prefer explicit CPU build.
    # Linux/macOS: try tensorflow[and-cuda] then fall back to tensorflow.
    attempts: List[str] = []
    if os.name == "nt":
        attempts.append("tensorflow-cpu")
    else:
        attempts.append("tensorflow[and-cuda]")
        attempts.append("tensorflow")

    code_tf = 1
    out_tf = ""
    err_tf = ""
    for pkg in attempts:
        code_tf, out_tf, err_tf = run([str(py), "-m", "pip", "install", pkg])
        if out_tf:
            log(out_tf, context=False)
        if err_tf:
            log(err_tf, context=False)
        if code_tf == 0:
            break
        log(f"Install attempt for {pkg} failed (exit {code_tf}); trying next fallback.")

    # Make Torch part of the default preferred path.
    if code_tf == 0:
        code_torch, out_torch, err_torch = run([str(py), "-m", "pip", "install", "torch"])
        if out_torch:
            log(out_torch, context=False)
        if err_torch:
            log(err_torch, context=False)
        if code_torch != 0:
            log(f"Torch install failed (exit {code_torch}); continuing.")

        # Best-effort CuPy install when CUDA-capable hardware is present.
        code_smi, _, _ = run(["nvidia-smi"])
        if code_smi == 0:
            code_cupy, out_cupy, err_cupy = run([str(py), "-m", "pip", "install", "cupy"])
            if out_cupy:
                log(out_cupy, context=False)
            if err_cupy:
                log(err_cupy, context=False)
            if code_cupy != 0:
                log(f"CuPy install failed (exit {code_cupy}); continuing.")

    _log_store_event("action", "cli:install-tensorflow", {"pip": code_pip, "tf": code_tf})
    return code_tf


def toggle_cuda(enable: bool) -> int:
    if not CONFIG_CUDA_PS1.exists():
        log("Configure-CUDA.ps1 not found; cannot toggle CUDA.")
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
    log(("Enabling" if enable else "Disabling") + " CUDA via Configure-CUDA.ps1 ...")
    code, out, err = run(cmd)
    if out:
        log(out, context=False)
    if err:
        log(err, context=False)
    _log_store_event("action", "cli:toggle-cuda", {"enable": enable, "exit_code": code, "stdout": out, "stderr": err})
    return code


def open_cuda_shell() -> None:
    shell_cmd = f"& {{ Set-Location -LiteralPath '{REPO_ROOT}'; Write-Host 'CUDA shell - repo at {REPO_ROOT}'; }}"
    subprocess.Popen([
        "powershell",
        "-NoExit",
        "-ExecutionPolicy",
        "Bypass",
        "-Command",
        shell_cmd,
    ])
    print("CUDA shell opened (host)")
    append_context("cli:cuda-shell")
    _log_store_event("action", "cli:cuda-shell", None)


def open_docker_cuda_shell(image: str = "nvidia/cuda:12.4.0-base-ubuntu22.04") -> None:
    if not which("docker"):
        print("Docker not found; cannot open CUDA shell in container.")
        return
    cmd = "docker run --rm -it --gpus all {img} bash".format(img=image)
    subprocess.Popen([
        "powershell",
        "-NoExit",
        "-ExecutionPolicy",
        "Bypass",
        "-Command",
        cmd,
    ])
    print(f"Docker CUDA shell opened using {image}")
    append_context("cli:docker-cuda-shell")
    _log_store_event("action", "cli:docker-cuda-shell", {"image": image})


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
    if getattr(args, "log_level", None):
        set_log_level(args.log_level)
        log(f"Log level set to {LOG_LEVEL}")
    if getattr(args, "log_debug", False):
        set_log_level("debug")
        log(f"Log level set to {LOG_LEVEL}")
    if args.env:
        print_environment(detect_environment())
        return True
    if args.smoke:
        run_smoke(full=False)
        return True
    if args.run_plm:
        run_plm_simulation()
        return True
    if args.pytest:
        run_smoke(full=True)
        return True
    if args.probe_cuda:
        probe_cuda()
        return True
    if args.cuda_shell:
        open_cuda_shell()
        return True
    if args.docker_cuda_shell:
        open_docker_cuda_shell()
        return True
    if args.enable_cuda:
        toggle_cuda(True)
        return True
    if args.disable_cuda:
        toggle_cuda(False)
        return True
    if args.ensure_docker:
        ensure_docker_running(auto_install=False)
        return True
    if args.install_docker:
        ensure_docker_running(auto_install=True)
        return True
    if args.install_cuda_toolkit:
        install_cuda_toolkit()
        return True
    if args.install_tensorflow:
        install_tensorflow_gpu()
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
        "7": ("Open CUDA shell (host)", open_cuda_shell),
        "8": ("Open CUDA shell (Docker)", open_docker_cuda_shell),
        "9": ("Set log level: normal", lambda: set_log_level("info") or log("Log level set to info")),
        "10": ("Set log level: debug", lambda: set_log_level("debug") or log("Log level set to debug")),
        "11": ("Start/ensure Docker Desktop", lambda: ensure_docker_running(False)),
        "12": ("Install Docker Desktop", lambda: ensure_docker_running(True)),
        "13": ("Install CUDA Toolkit", install_cuda_toolkit),
        "14": ("Install TensorFlow GPU", install_tensorflow_gpu),
        "15": ("Install / Repair components", install_or_repair),
        "16": ("Update components", update_components),
        "17": ("Launch Admin GUI", launch_gui),
        "18": ("Open debug console", lambda: open_debug_console(False)),
        "19": ("Open option 2 console (venv)", lambda: open_debug_console(True)),
        "20": ("Export debug report", export_report),
        "21": ("Open operator guide", open_docs),
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
    parser.add_argument("--run-plm", action="store_true", help="Run full PLM quantum temporal simulation")
    parser.add_argument("--pytest", action="store_true", help="Run full pytest")
    parser.add_argument("--probe-cuda", action="store_true", help="Probe CUDA/GPU")
    parser.add_argument("--cuda-shell", action="store_true", help="Open CUDA shell (host)")
    parser.add_argument("--docker-cuda-shell", action="store_true", help="Open CUDA shell in Docker with --gpus all")
    parser.add_argument("--enable-cuda", action="store_true", help="Enable CUDA via Configure-CUDA.ps1")
    parser.add_argument("--disable-cuda", action="store_true", help="Disable CUDA via Configure-CUDA.ps1")
    parser.add_argument("--log-level", choices=["normal", "debug", "info"], help="Set log verbosity (normal/debug)")
    parser.add_argument("--log-debug", action="store_true", help="Shortcut for --log-level debug")
    parser.add_argument("--ensure-docker", action="store_true", help="Start Docker Desktop if installed; do not install")
    parser.add_argument("--install-docker", action="store_true", help="Install (and start) Docker Desktop via winget")
    parser.add_argument("--install-cuda-toolkit", action="store_true", help="Install NVIDIA CUDA toolkit via winget")
    parser.add_argument("--install-tensorflow", action="store_true", help="Install TensorFlow with CUDA support using current python")
    parser.add_argument("--launch-gui", action="store_true", help="Launch Admin GUI")
    parser.add_argument("--install-tf-gpu", dest="install_tensorflow", action="store_true", help="Install TensorFlow (GPU build where available)")
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
