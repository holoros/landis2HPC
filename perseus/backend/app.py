"""PERSEUS scenario API (phase 3).

A thin FastAPI service between the Forest Intelligence GUI and the Cardinal pipeline.
The GUI posts a scenario; the service submits a single-plot LANDIS run as a SLURM job,
then the GUI polls status and pulls the resulting biomass trajectory.

Run locally:  uvicorn app:app --reload --port 8000
Then:         curl -X POST localhost:8000/scenario/run -H 'content-type: application/json' \\
                   -d '{"state":"WA","climate":"baseline","harvest":"none","plot_id":"1"}'

Jobs persist in a SQLite store (survive restart). Set PERSEUS_API_KEY to require an
X-API-Key header on the action endpoints; leave it unset for local development. Still a
seed: add OSC-account auth, rate limiting, and a results cache before public exposure.
"""
import uuid

from fastapi import Depends, FastAPI, Header, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel

import config
import cardinal_jobs
import db

app = FastAPI(title="PERSEUS scenario API", version="0.2")

# CORS so the static GUI can call this service from the browser. Restrict allow_origins
# to the GUI's deployed origin before exposing the service publicly.
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["GET", "POST"],
    allow_headers=["*"],
)

db.init()


def require_key(x_api_key: str = Header(default="")):
    """Auth dependency. If PERSEUS_API_KEY is set, require a matching X-API-Key header.
    If unset, endpoints stay open (development mode)."""
    if config.API_KEY and x_api_key != config.API_KEY:
        raise HTTPException(401, "invalid or missing X-API-Key")


class ScenarioReq(BaseModel):
    state: str
    plot_id: str
    climate: str = "baseline"
    harvest: str = "none"
    disturbance: bool = False


@app.get("/health")
def health():
    return {"status": "ok", "service": "perseus-scenario-api", "version": "0.2",
            "auth": "required" if config.API_KEY else "open"}


@app.get("/states")
def states():
    return {k: {"name": v["name"], "tier": v["tier"]} for k, v in config.STATES.items()}


@app.get("/jobs")
def jobs():
    return db.recent()


@app.post("/scenario/run")
def run(req: ScenarioReq, _=Depends(require_key)):
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
    db.add(job_tag, job_id, spec)
    return {"job_tag": job_tag, "job_id": job_id, "state": "queued"}


@app.get("/scenario/status/{job_tag}")
def scenario_status(job_tag: str):
    rec = db.get(job_tag)
    if not rec:
        raise HTTPException(404, "unknown job")
    st = cardinal_jobs.status(rec["job_id"])
    out = {"job_tag": job_tag, "job_id": rec["job_id"], "state": st}
    if st == "done":
        out["has_result"] = cardinal_jobs.result(job_tag) is not None
    return out


@app.get("/scenario/result/{job_tag}")
def scenario_result(job_tag: str):
    if not db.get(job_tag):
        raise HTTPException(404, "unknown job")
    res = cardinal_jobs.result(job_tag)
    if res is None:
        raise HTTPException(202, "result not ready")
    return res
