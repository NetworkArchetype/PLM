"""NP(-complete) benchmark suite for localhost runs.

This module intentionally focuses on:
- Deterministic generation (seeded)
- Bounded runtimes (time budget)
- Conservative exact solvers on small instances + simple heuristics on larger ones

It does NOT claim to solve arbitrary NP-hard problems efficiently.
"""

from __future__ import annotations

import math
import random
import time
from dataclasses import dataclass
from typing import Any, Dict, Iterable, List, Optional, Sequence, Tuple


@dataclass(frozen=True)
class BenchConfig:
    seed: int = 1337
    minutes: float = 5.0
    per_problem_max_seconds: Optional[float] = None
    use_gpu: bool = True


def _deadline_seconds(cfg: BenchConfig) -> float:
    return float(cfg.minutes) * 60.0


def _now() -> float:
    return time.perf_counter()


def _time_left(start: float, budget_s: float) -> float:
    return budget_s - (_now() - start)


# -----------------------
# 3-SAT
# -----------------------

Literal = Tuple[int, bool]  # (var_idx, is_negated)
Clause = Tuple[Literal, Literal, Literal]
CNF = List[Clause]


def _sat_eval_clause(bits: Sequence[bool], clause: Clause) -> bool:
    for var, neg in clause:
        val = bits[var]
        if neg:
            val = not val
        if val:
            return True
    return False


def _sat_eval_cnf(bits: Sequence[bool], cnf: CNF) -> bool:
    return all(_sat_eval_clause(bits, c) for c in cnf)


def generate_random_3sat(rng: random.Random, n_vars: int, n_clauses: int) -> CNF:
    cnf: CNF = []
    for _ in range(n_clauses):
        vars_ = rng.sample(range(n_vars), k=3)
        clause: Clause = (
            (vars_[0], bool(rng.getrandbits(1))),
            (vars_[1], bool(rng.getrandbits(1))),
            (vars_[2], bool(rng.getrandbits(1))),
        )
        cnf.append(clause)
    return cnf


def solve_3sat_bruteforce(cnf: CNF, n_vars: int, *, max_nodes: Optional[int] = None) -> Optional[List[bool]]:
    # Exhaustive over 2^n
    nodes = 0
    for mask in range(1 << n_vars):
        if max_nodes is not None and nodes >= max_nodes:
            return None
        nodes += 1
        bits = [(mask >> i) & 1 == 1 for i in range(n_vars)]
        if _sat_eval_cnf(bits, cnf):
            return bits
    return None


# -----------------------
# TSP (Euclidean)
# -----------------------

Point = Tuple[float, float]


def generate_random_points(rng: random.Random, n: int) -> List[Point]:
    return [(rng.random(), rng.random()) for _ in range(n)]


def _dist(a: Point, b: Point) -> float:
    return math.hypot(a[0] - b[0], a[1] - b[1])


def tsp_tour_length(points: Sequence[Point], tour: Sequence[int]) -> float:
    total = 0.0
    for i in range(len(tour)):
        j = (i + 1) % len(tour)
        total += _dist(points[tour[i]], points[tour[j]])
    return total


def tsp_nearest_neighbor(points: Sequence[Point], start: int = 0) -> List[int]:
    n = len(points)
    unvisited = set(range(n))
    tour = [start]
    unvisited.remove(start)
    while unvisited:
        last = tour[-1]
        nxt = min(unvisited, key=lambda j: _dist(points[last], points[j]))
        tour.append(nxt)
        unvisited.remove(nxt)
    return tour


def _detect_accelerators() -> Dict[str, Any]:
    info: Dict[str, Any] = {
        "cupy": {"present": False, "cuda": False, "device_count": 0, "error": None},
        "torch": {"present": False, "cuda": False, "device_count": 0, "error": None},
    }
    try:
        import cupy as cp  # type: ignore

        info["cupy"]["present"] = True
        try:
            cnt = int(cp.cuda.runtime.getDeviceCount())
            info["cupy"]["device_count"] = cnt
            info["cupy"]["cuda"] = cnt > 0
        except Exception as exc:
            info["cupy"]["error"] = str(exc)
    except Exception as exc:
        info["cupy"]["error"] = str(exc)

    try:
        import torch  # type: ignore

        info["torch"]["present"] = True
        try:
            cuda_ok = bool(torch.cuda.is_available())
            info["torch"]["cuda"] = cuda_ok
            info["torch"]["device_count"] = int(torch.cuda.device_count()) if cuda_ok else 0
        except Exception as exc:
            info["torch"]["error"] = str(exc)
    except Exception as exc:
        info["torch"]["error"] = str(exc)

    return info


def tsp_nearest_neighbor_accel(points: Sequence[Point], start: int = 0) -> Tuple[List[int], Dict[str, Any]]:
    """Nearest-neighbor tour builder, optionally GPU-accelerated.

    Uses CuPy (CUDA) if available, else Torch (CUDA) if available, else CPU.
    Returns (tour, meta).
    """

    n = len(points)
    meta: Dict[str, Any] = {"backend": "cpu", "used_gpu": False}
    if n == 0:
        return [], meta

    acc = _detect_accelerators()
    if acc["cupy"]["cuda"]:
        try:
            import cupy as cp  # type: ignore

            xs = cp.asarray([p[0] for p in points], dtype=cp.float32)
            ys = cp.asarray([p[1] for p in points], dtype=cp.float32)
            dx = xs[:, None] - xs[None, :]
            dy = ys[:, None] - ys[None, :]
            dist = cp.sqrt(dx * dx + dy * dy)

            visited = cp.zeros((n,), dtype=cp.bool_)
            tour: List[int] = [int(start)]
            visited[start] = True
            cur = int(start)
            for _ in range(n - 1):
                row = dist[cur].copy()
                row[visited] = cp.inf
                nxt = int(cp.argmin(row).get())
                tour.append(nxt)
                visited[nxt] = True
                cur = nxt

            meta = {"backend": "cupy", "used_gpu": True, "device_count": acc["cupy"]["device_count"]}
            return tour, meta
        except Exception as exc:
            meta = {"backend": "cupy_failed", "used_gpu": False, "error": str(exc)}

    if acc["torch"]["cuda"]:
        try:
            import torch  # type: ignore

            device = torch.device("cuda")
            xs = torch.tensor([p[0] for p in points], dtype=torch.float32, device=device)
            ys = torch.tensor([p[1] for p in points], dtype=torch.float32, device=device)
            dx = xs[:, None] - xs[None, :]
            dy = ys[:, None] - ys[None, :]
            dist = torch.sqrt(dx * dx + dy * dy)

            visited = torch.zeros((n,), dtype=torch.bool, device=device)
            tour: List[int] = [int(start)]
            visited[start] = True
            cur = int(start)
            for _ in range(n - 1):
                row = dist[cur].clone()
                row[visited] = float("inf")
                nxt = int(torch.argmin(row).item())
                tour.append(nxt)
                visited[nxt] = True
                cur = nxt

            meta = {"backend": "torch", "used_gpu": True, "device_count": acc["torch"]["device_count"]}
            return tour, meta
        except Exception as exc:
            meta = {"backend": "torch_failed", "used_gpu": False, "error": str(exc)}

    tour = tsp_nearest_neighbor(points, start=start)
    return tour, meta


def tsp_2opt(points: Sequence[Point], tour: List[int], *, max_swaps: int = 2000) -> List[int]:
    # Simple 2-opt improvement loop
    n = len(tour)
    if n < 4:
        return tour

    def gain(i: int, k: int) -> float:
        a, b = tour[i], tour[(i + 1) % n]
        c, d = tour[k], tour[(k + 1) % n]
        return (_dist(points[a], points[b]) + _dist(points[c], points[d])) - (
            _dist(points[a], points[c]) + _dist(points[b], points[d])
        )

    swaps = 0
    improved = True
    while improved and swaps < max_swaps:
        improved = False
        for i in range(n - 1):
            for k in range(i + 2, n - (0 if i > 0 else 1)):
                if gain(i, k) > 1e-12:
                    # reverse segment (i+1..k)
                    tour[i + 1 : k + 1] = reversed(tour[i + 1 : k + 1])
                    swaps += 1
                    improved = True
                    if swaps >= max_swaps:
                        break
            if swaps >= max_swaps:
                break
    return tour


# -----------------------
# Vertex Cover
# -----------------------

Edge = Tuple[int, int]


def generate_random_graph_edges(rng: random.Random, n: int, p: float) -> List[Edge]:
    edges: List[Edge] = []
    for u in range(n):
        for v in range(u + 1, n):
            if rng.random() < p:
                edges.append((u, v))
    return edges


def _covers_all(edges: Sequence[Edge], cover: Sequence[bool]) -> bool:
    for u, v in edges:
        if not (cover[u] or cover[v]):
            return False
    return True


def solve_vertex_cover_bruteforce(edges: Sequence[Edge], n: int, k: int) -> Optional[List[bool]]:
    # Find a vertex cover of size <= k via brute force combinations (worst-case).
    # For small n only.
    idxs = list(range(n))

    def rec(start: int, chosen: List[int]) -> Optional[List[bool]]:
        if len(chosen) > k:
            return None
        if start == n:
            cover = [False] * n
            for i in chosen:
                cover[i] = True
            return cover if _covers_all(edges, cover) else None
        # pruning: try without/with
        out = rec(start + 1, chosen)
        if out is not None:
            return out
        chosen.append(start)
        out = rec(start + 1, chosen)
        chosen.pop()
        return out

    return rec(0, [])


# -----------------------
# Knapsack (0/1)
# -----------------------

Item = Tuple[int, int]  # (weight, value)


def generate_random_knapsack(rng: random.Random, n: int, max_w: int, max_v: int) -> List[Item]:
    return [(rng.randint(1, max_w), rng.randint(1, max_v)) for _ in range(n)]


def solve_knapsack_dp(items: Sequence[Item], capacity: int) -> Tuple[int, List[int]]:
    # O(n*capacity) DP; returns (best_value, picked_indices)
    n = len(items)
    dp = [0] * (capacity + 1)
    keep: List[List[bool]] = [[False] * (capacity + 1) for _ in range(n)]

    for i, (w, v) in enumerate(items):
        for c in range(capacity, w - 1, -1):
            cand = dp[c - w] + v
            if cand > dp[c]:
                dp[c] = cand
                keep[i][c] = True

    # reconstruct
    best_c = max(range(capacity + 1), key=lambda c: dp[c])
    picked: List[int] = []
    c = best_c
    for i in range(n - 1, -1, -1):
        if keep[i][c]:
            picked.append(i)
            c -= items[i][0]
    picked.reverse()
    return dp[best_c], picked


# -----------------------
# Benchmark runner
# -----------------------


def run_np_benchmarks(cfg: BenchConfig) -> Dict[str, Any]:
    rng = random.Random(cfg.seed)
    start = _now()
    budget = _deadline_seconds(cfg)

    accelerators = _detect_accelerators()

    results: Dict[str, Any] = {
        "seed": cfg.seed,
        "minutes": cfg.minutes,
        "use_gpu": cfg.use_gpu,
        "accelerators": accelerators,
        "started_perf_counter": start,
        "problems": {},
    }

    def per_problem_budget() -> float:
        if cfg.per_problem_max_seconds is not None:
            return float(cfg.per_problem_max_seconds)
        # default: split budget evenly across the 4 NP problems
        return max(1.0, budget / 4.0)

    # 3-SAT: scale n up cautiously with brute force
    sat_start = _now()
    sat_budget = per_problem_budget()
    best_sat = {"max_n": 0, "max_m": 0, "solved": 0, "attempted": 0}
    n = 12
    while _time_left(sat_start, sat_budget) > 0.25 and _time_left(start, budget) > 0.25:
        m = 4 * n
        cnf = generate_random_3sat(rng, n_vars=n, n_clauses=m)
        best_sat["attempted"] += 1
        # Cap nodes to avoid runaway; adapt with size
        max_nodes = 1 << min(n, 22)
        sol = solve_3sat_bruteforce(cnf, n_vars=n, max_nodes=max_nodes)
        if sol is not None:
            best_sat["solved"] += 1
            best_sat["max_n"] = n
            best_sat["max_m"] = m
            n += 1
        else:
            break
    results["problems"]["3sat"] = {
        **best_sat,
        "seconds": _now() - sat_start,
    }

    # TSP: heuristic tour on larger n (exact is too slow); record improvement
    tsp_start = _now()
    tsp_budget = per_problem_budget()
    tsp_n = 200
    while _time_left(tsp_start, tsp_budget) > 0.25 and _time_left(start, budget) > 0.25:
        pts = generate_random_points(rng, tsp_n)
        if cfg.use_gpu:
            tour, tsp_meta = tsp_nearest_neighbor_accel(pts, start=0)
        else:
            tour = tsp_nearest_neighbor(pts, start=0)
            tsp_meta = {"backend": "cpu", "used_gpu": False}
        base_len = tsp_tour_length(pts, tour)
        tour2 = tsp_2opt(pts, tour, max_swaps=1000)
        improved_len = tsp_tour_length(pts, tour2)
        results["problems"]["tsp"] = {
            "n": tsp_n,
            "base_len": base_len,
            "improved_len": improved_len,
            "improvement": max(0.0, base_len - improved_len),
            "seconds": _now() - tsp_start,
            "note": "Heuristic (nearest-neighbor + 2-opt).",
            "accel": tsp_meta,
        }
        break

    # Vertex Cover: find small-k cover on small graphs (exact); scale until fail
    vc_start = _now()
    vc_budget = per_problem_budget()
    vc_n = 22
    vc_p = 0.2
    vc_best = {"n": 0, "k": 0, "found": False}
    while _time_left(vc_start, vc_budget) > 0.25 and _time_left(start, budget) > 0.25:
        edges = generate_random_graph_edges(rng, vc_n, vc_p)
        # try increasing k until found (cap)
        found = False
        found_k = None
        for k in range(0, min(vc_n, 10) + 1):
            sol = solve_vertex_cover_bruteforce(edges, vc_n, k)
            if sol is not None:
                found = True
                found_k = k
                break
        if found and found_k is not None:
            vc_best = {"n": vc_n, "k": found_k, "found": True, "m": len(edges)}
            vc_n += 1
        else:
            break
    results["problems"]["vertex_cover"] = {
        **vc_best,
        "seconds": _now() - vc_start,
        "note": "Exact (bruteforce) on small n; bounded k search.",
    }

    # Knapsack: pseudo-poly DP by capacity; pick capacity so it stays reasonable
    ks_start = _now()
    ks_budget = per_problem_budget()
    ks_n = 300
    capacity = 2000
    items = generate_random_knapsack(rng, ks_n, max_w=50, max_v=100)
    best_val, picked = solve_knapsack_dp(items, capacity)
    results["problems"]["knapsack"] = {
        "n": ks_n,
        "capacity": capacity,
        "best_value": best_val,
        "picked_count": len(picked),
        "seconds": _now() - ks_start,
        "note": "Exact DP (pseudo-polynomial in capacity).",
    }

    results["seconds_total"] = _now() - start
    results["completed"] = True
    return results
