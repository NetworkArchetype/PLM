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

        tf_any: Any = tf

        info["present"] = True
        info["version"] = getattr(tf_any, "__version__", "unknown")
        try:
            info["built_with_cuda"] = bool(tf_any.test.is_built_with_cuda())
        except Exception:
            info["built_with_cuda"] = False
        try:
            devices = tf_any.config.list_physical_devices("GPU")
            info["gpus"] = [getattr(d, "name", str(d)) for d in devices]
        except Exception as exc:
            info["gpus_error"] = str(exc)
    except Exception as exc:  # pragma: no cover - best effort
        info["error"] = str(exc)
    return info


def probe_torch() -> Dict[str, Any]:
    info: Dict[str, Any] = {
        "present": False,
        "cuda_available": False,
        "cuda_version": None,
        "gpus": [],
        "error": None,
    }
    try:
        import torch  # type: ignore

        torch_any: Any = torch

        info["present"] = True
        info["version"] = getattr(torch_any, "__version__", "unknown")
        try:
            info["cuda_available"] = bool(torch_any.cuda.is_available())
            info["cuda_version"] = getattr(getattr(torch_any, "version", None), "cuda", None)
            if info["cuda_available"]:
                count = int(torch_any.cuda.device_count())
                info["gpus"] = [torch_any.cuda.get_device_name(i) for i in range(count)]
        except Exception as exc:
            info["cuda_error"] = str(exc)
    except Exception as exc:  # pragma: no cover - best effort
        info["error"] = str(exc)
    return info


def probe_cupy() -> Dict[str, Any]:
    info: Dict[str, Any] = {"present": False, "devices": [], "error": None}
    try:
        import cupy as cp  # type: ignore

        cp_any: Any = cp

        info["present"] = True
        info["version"] = getattr(cp_any, "__version__", "unknown")
        try:
            count = int(cp_any.cuda.runtime.getDeviceCount())
            info["device_count"] = count
            devices: List[str] = []
            for i in range(count):
                props = cp_any.cuda.runtime.getDeviceProperties(i)
                name = props.get("name")
                if isinstance(name, (bytes, bytearray)):
                    name = name.decode("utf-8", errors="replace")
                devices.append(name or str(props))
            info["devices"] = devices
        except Exception as exc:
            info["cuda_error"] = str(exc)
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
    report["torch"] = probe_torch()
    report["cupy"] = probe_cupy()
    report["nvidia_smi"] = probe_nvidia_smi()
    report["nvcc"] = probe_nvcc()

    nvidia_smi: Dict[str, Any] = report.get("nvidia_smi") or {}
    torch_info: Dict[str, Any] = report.get("torch") or {}
    cupy_info: Dict[str, Any] = report.get("cupy") or {}
    cuda_hw = bool(nvidia_smi.get("available"))
    torch_cuda = bool(torch_info.get("cuda_available"))
    cupy_cuda = bool(cupy_info.get("device_count", 0))
    report["cuda_capable"] = bool(cuda_hw or torch_cuda or cupy_cuda)

    print(json.dumps(report))


if __name__ == "__main__":
    main()
