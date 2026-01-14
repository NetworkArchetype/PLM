from __future__ import annotations

import sys
from pathlib import Path


def _add_path(p: Path) -> None:
    p_str = str(p)
    if p_str not in sys.path:
        sys.path.insert(0, p_str)


# Ensure optional in-repo packages are importable when running pytest in a fresh
# environment (CI installs only pytest).
_REPO_ROOT = Path(__file__).resolve().parent

_add_path(_REPO_ROOT / "Code_core_3")
_add_path(_REPO_ROOT / "Code_core_3" / "plm-formalized")
