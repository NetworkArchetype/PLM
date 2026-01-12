import json
import os
import platform
import shutil
import subprocess
import sys
from typing import Any, Dict, List


def run(cmd: List[str]) -> Dict[str, Any]:
    try:
        proc = subprocess.run(cmd, capture_output=True, text=True, check=False)
        return {
            "cmd": cmd,
            "returncode": proc.returncode,
            "stdout": proc.stdout.strip(),
            "stderr": proc.stderr.strip(),
        }
    except Exception as exc:  # pragma: no cover - defensive
        return {"cmd": cmd, "error": str(exc)}


def probe_tensorflow() -> Dict[str, Any]:
    info: Dict[str, Any] = {"present": False, "built_with_cuda": False, "gpus": [], "error": None}
    try:
        import tensorflow as tf  # type: ignore

        info["present"] = True
        info["version"] = getattr(tf, "__version__", "unknown")
        try:
            info["built_with_cuda"] = bool(tf.test.is_built_with_cuda())
        except Exception:
            info["built_with_cuda"] = False
        try:
            devices = tf.config.list_physical_devices("GPU")
            info["gpus"] = [getattr(d, "name", str(d)) for d in devices]
        except Exception as exc:
            info["gpus_error"] = str(exc)
    except Exception as exc:  # pragma: no cover - best effort
        info["error"] = str(exc)
    return info


def probe_nvidia_smi() -> Dict[str, Any]:
    if not shutil.which("nvidia-smi"):
        return {"available": False, "error": "nvidia-smi not found"}
    result = run(["nvidia-smi", "--query-gpu=name,driver_version,memory.total", "--format=csv,noheader"])
    result["available"] = result.get("returncode", 1) == 0
    return result


def probe_nvcc() -> Dict[str, Any]:
    if not shutil.which("nvcc"):
        return {"available": False, "error": "nvcc not found"}
    result = run(["nvcc", "--version"])
    result["available"] = result.get("returncode", 1) == 0
    return result


def main() -> None:
    report: Dict[str, Any] = {
        "platform": platform.platform(),
        "python": sys.version,
        "env": {"PATH": os.environ.get("PATH"), "CUDA_PATH": os.environ.get("CUDA_PATH")},
    }
    report["tensorflow"] = probe_tensorflow()
    report["nvidia_smi"] = probe_nvidia_smi()
    report["nvcc"] = probe_nvcc()
    print(json.dumps(report))


if __name__ == "__main__":
    main()
