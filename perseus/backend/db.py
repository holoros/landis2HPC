"""SQLite job store for the PERSEUS scenario API.

Replaces the in-memory registry so submitted jobs survive a service restart. Single
file at PERSEUS_API_DB (default perseus_jobs.db next to this module). Small and
dependency-free; swap for Postgres if the service grows.
"""
import json
import os
import sqlite3
import time

DB_PATH = os.environ.get("PERSEUS_API_DB",
                         os.path.join(os.path.dirname(os.path.abspath(__file__)), "perseus_jobs.db"))


def _conn():
    c = sqlite3.connect(DB_PATH)
    c.row_factory = sqlite3.Row
    return c


def init():
    with _conn() as c:
        c.execute("""CREATE TABLE IF NOT EXISTS jobs(
            job_tag   TEXT PRIMARY KEY,
            job_id    TEXT,
            spec      TEXT,
            submitted REAL)""")


def add(job_tag, job_id, spec):
    with _conn() as c:
        c.execute("INSERT OR REPLACE INTO jobs(job_tag, job_id, spec, submitted) VALUES(?,?,?,?)",
                  (job_tag, job_id, json.dumps(spec), time.time()))


def get(job_tag):
    with _conn() as c:
        r = c.execute("SELECT job_tag, job_id, spec, submitted FROM jobs WHERE job_tag=?",
                      (job_tag,)).fetchone()
    if not r:
        return None
    return {"job_tag": r["job_tag"], "job_id": r["job_id"],
            "spec": json.loads(r["spec"]), "submitted": r["submitted"]}


def recent(limit=50):
    with _conn() as c:
        rows = c.execute("SELECT job_tag, job_id, submitted FROM jobs ORDER BY submitted DESC LIMIT ?",
                         (limit,)).fetchall()
    return [{"job_tag": r["job_tag"], "job_id": r["job_id"], "submitted": r["submitted"]} for r in rows]
