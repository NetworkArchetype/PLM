#!/usr/bin/env python3
"""Shared event store for PLM GUI/CLI.

- Uses SQLite by default (standard library sqlite3)
- Falls back to dbm (Berkeley DB style) when sqlite is unavailable
- Purpose: logging/synchronization only (no calculations)
"""
from __future__ import annotations

import argparse
import datetime
import json
import os
import sqlite3
import sys
import uuid
import dbm
from pathlib import Path
from typing import Any, Dict, List, Optional

REPO_ROOT = Path(__file__).resolve().parents[1]
SQLITE_PATH = REPO_ROOT / ".plm_store.sqlite"
DBM_PATH = REPO_ROOT / ".plm_store.dbm"


def _utc_iso() -> str:
    return datetime.datetime.utcnow().isoformat()


class SQLiteStore:
    def __init__(self, path: Path) -> None:
        self.path = path
        self._ensure()

    def _ensure(self) -> None:
        conn = sqlite3.connect(self.path)
        try:
            conn.execute(
                """
                create table if not exists events (
                    id integer primary key autoincrement,
                    ts text not null,
                    source text,
                    kind text,
                    session text,
                    user text,
                    msg text,
                    payload text
                )
                """
            )
            conn.commit()
        finally:
            conn.close()

    def log_event(
        self,
        *,
        source: str,
        kind: str,
        msg: str,
        session: Optional[str],
        user: Optional[str],
        payload: Optional[Dict[str, Any]],
    ) -> None:
        conn = sqlite3.connect(self.path)
        try:
            conn.execute(
                "insert into events(ts, source, kind, session, user, msg, payload) values (?,?,?,?,?,?,?)",
                (_utc_iso(), source, kind, session, user, msg, json.dumps(payload or {}, separators=(",", ":"))),
            )
            conn.commit()
        finally:
            conn.close()

    def recent(self, limit: int = 50) -> List[Dict[str, Any]]:
        conn = sqlite3.connect(self.path)
        try:
            cur = conn.execute(
                "select ts, source, kind, session, user, msg, payload from events order by id desc limit ?",
                (limit,),
            )
            rows = cur.fetchall()
        finally:
            conn.close()
        out: List[Dict[str, Any]] = []
        for ts, source, kind, session, user, msg, payload in rows:
            try:
                payload_obj = json.loads(payload) if payload else {}
            except json.JSONDecodeError:
                payload_obj = {}
            out.append(
                {
                    "ts": ts,
                    "source": source,
                    "kind": kind,
                    "session": session,
                    "user": user,
                    "msg": msg,
                    "payload": payload_obj,
                }
            )
        return out


class DbmStore:
    def __init__(self, path: Path) -> None:
        self.path = path
        self._ensure()

    def _ensure(self) -> None:
        with dbm.open(self.path.as_posix(), "c") as db:
            if b"counter" not in db:
                db[b"counter"] = b"0"

    def _next_key(self) -> bytes:
        with dbm.open(self.path.as_posix(), "c") as db:
            counter = int(db.get(b"counter", b"0")) + 1
            db[b"counter"] = str(counter).encode()
            return f"event:{counter:09d}".encode()

    def log_event(
        self,
        *,
        source: str,
        kind: str,
        msg: str,
        session: Optional[str],
        user: Optional[str],
        payload: Optional[Dict[str, Any]],
    ) -> None:
        entry = {
            "ts": _utc_iso(),
            "source": source,
            "kind": kind,
            "session": session,
            "user": user,
            "msg": msg,
            "payload": payload or {},
        }
        blob = json.dumps(entry, separators=(",", ":")).encode()
        key = self._next_key()
        with dbm.open(self.path.as_posix(), "c") as db:
            db[key] = blob

    def recent(self, limit: int = 50) -> List[Dict[str, Any]]:
        with dbm.open(self.path.as_posix(), "c") as db:
            keys = sorted([k for k in db.keys() if k.startswith(b"event:")], reverse=True)[:limit]
            out: List[Dict[str, Any]] = []
            for k in keys:
                try:
                    entry = json.loads(db[k])
                    out.append(entry)
                except Exception:
                    continue
            return out


def get_store(engine: str = "auto"):
    engine = engine.lower()
    if engine == "sqlite" or engine == "auto":
        try:
            return SQLiteStore(SQLITE_PATH)
        except Exception:
            if engine == "sqlite":
                raise
    return DbmStore(DBM_PATH)


def log_event(
    *,
    source: str,
    kind: str,
    msg: str,
    session: Optional[str] = None,
    user: Optional[str] = None,
    payload: Optional[Dict[str, Any]] = None,
    engine: str = "auto",
) -> None:
    store = get_store(engine)
    store.log_event(source=source, kind=kind, msg=msg, session=session, user=user, payload=payload)


def recent(limit: int = 50, engine: str = "auto") -> List[Dict[str, Any]]:
    store = get_store(engine)
    return store.recent(limit=limit)


def _cli(argv: List[str]) -> int:
    p = argparse.ArgumentParser(description="PLM shared event store (logging only)")
    p.add_argument("--engine", choices=["auto", "sqlite", "dbm"], default="auto")
    sub = p.add_subparsers(dest="cmd", required=True)

    log_p = sub.add_parser("log", help="Log a single event")
    log_p.add_argument("--source", required=True)
    log_p.add_argument("--kind", required=True)
    log_p.add_argument("--msg", required=True)
    log_p.add_argument("--session")
    log_p.add_argument("--user")
    log_p.add_argument("--payload-json")
    log_p.add_argument("--payload-file")

    rec_p = sub.add_parser("recent", help="Show recent events")
    rec_p.add_argument("--limit", type=int, default=50)

    args = p.parse_args(argv)

    try:
        if args.cmd == "log":
            payload: Optional[Dict[str, Any]] = None
            if args.payload_json:
                payload = json.loads(args.payload_json)
            elif args.payload_file:
                payload = json.loads(Path(args.payload_file).read_text(encoding="utf-8"))
            log_event(
                source=args.source,
                kind=args.kind,
                msg=args.msg,
                session=args.session,
                user=args.user,
                payload=payload,
                engine=args.engine,
            )
            return 0
        if args.cmd == "recent":
            rows = recent(limit=args.limit, engine=args.engine)
            print(json.dumps(rows, indent=2))
            return 0
    except Exception as exc:  # noqa: BLE001
        print(f"store error: {exc}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(_cli(sys.argv[1:]))
