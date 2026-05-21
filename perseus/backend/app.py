"""PERSEUS scenario API (phase 3 seed).

A thin FastAPI service between the Forest Intelligence GUI and the Cardinal pipeline.
The GUI posts a scenario; the service submits a single-plot LANDIS run as a SLURM job,
then the GUI polls status and pulls the resulting biomass trajectory.

Run locally:  uvicorn app:app --reload --port 8000
Then:         curl -X POST localhost:8000/scenario/run -H 'content-type: application/json' \\
                   -d '{"state":"WA","climate":"baseline","harvest":"none","plot_id":"1"}'

This is a seed, not a production service. Before exposing it, add auth (OSC accounts),
rate limiting, a job table (SQLite or Postgres) instead of relying on squeue, and a
results cache. See README.md.
"""
import time
import uuid

from fastapi import FastAPI, HTTPException
from pydantic import BaseModel

import config
import cardinal_jobs

app = FastAPI(title="PERSEUS scenario API", version="0.1")

# In-memory job registry: job_tag -> {job_id, spec, submitted}. Replace with a DB later.
JOBS = {}


class ScenarioReq(BaseModel):
    state: str
    plot_id: str
    climate: str = "baseline"
    harvest: str = "none"
    disturbance: bool = False


@app.get("/health")
def health():
    return {"status": "ok", "service": "perseus-scenario-api", "version": "0.1"}


@app.get("/states")
def states():
    return {k: {"name": v["name"], "tier": v["tier"]} for k, v in config.STATES.items()}


@app.post("/scenario/run")
def run(req: ScenarioReq):
    if req.state not in config.STATES:
        raise HTTPException(400, f"unknown state {req.state}")
    if req.climate not in config.CLIMATE:
        raise HTTPException(400, f"unknown climate {req.climate}")
    if req.harvest not in config.HARVEST:
        raise HTTPException(400, f"unknown harvest {req.harvest}")
    spec = {"state": req.state, "plot_id": req.plot_id,
            "clim": config.CLIMATE[req.climate], "harv": config.HARVEST[req.harvest]}
    job_tag = f"{req.state}_{req.plot_id}_{uuid.uuid4().hex[:8]}"
    try:
        job_id = cardinal_jobs.submit(spec, job_tag)
    except Exception as e:
        raise HTTPException(502, f"submission failed: {e}")
    JOBS[job_tag] = {"job_id": job_id, "spec": spec, "submitted": time.time()}
    return {"job_tag": job_tag, "job_id": job_id, "state": "queued"}


@app.get("/scenario/status/{job_tag}")
def scenario_status(job_tag: str):
    if job_tag not in JOBS:
        raise HTTPException(404, "unknown job")
    job_id = JOBS[job_tag]["job_id"]
    st = cardinal_jobs.status(job_id)
    out = {"job_tag": job_tag, "job_id": job_id, "state": st}
    if st == "done":
        out["has_result"] = cardinal_jobs.result(job_tag) is not None
    return out


@app.get("/scenario/result/{job_tag}")
def scenario_result(job_tag: str):
    if job_tag not in JOBS:
        raise HTTPException(404, "unknown job")
    res = cardinal_jobs.result(job_tag)
    if res is None:
        raise HTTPException(202, "result not ready")
    return res
