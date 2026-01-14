"""Localhost NP benchmark runner.

This is intentionally NOT part of the default CI path.

Usage examples:
- Quick smoke (30s):
    python validation_np_hard/run_benchmarks.py --minutes 0.5
- Your requested long run (90 minutes):
    python validation_np_hard/run_benchmarks.py --minutes 90

Outputs JSON to stdout and writes validation_np_hard/benchmarks.json.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path

from np_benchmarks import BenchConfig, run_np_benchmarks


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--minutes", type=float, default=5.0)
    ap.add_argument("--seed", type=int, default=1337)
    ap.add_argument("--per-problem-max-seconds", type=float, default=None)
    ap.add_argument("--use-gpu", dest="use_gpu", action="store_true", help="Use CUDA-capable accelerators (CuPy/Torch) when available")
    ap.add_argument("--no-gpu", dest="use_gpu", action="store_false", help="Force CPU-only")
    ap.set_defaults(use_gpu=True)
    args = ap.parse_args()

    cfg = BenchConfig(
        seed=args.seed,
        minutes=args.minutes,
        per_problem_max_seconds=args.per_problem_max_seconds,
        use_gpu=bool(args.use_gpu),
    )
    report = run_np_benchmarks(cfg)

    out_path = Path("validation_np_hard/benchmarks.json")
    out_path.write_text(json.dumps(report, indent=2, sort_keys=False), encoding="utf-8")
    print(json.dumps(report, indent=2, sort_keys=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
