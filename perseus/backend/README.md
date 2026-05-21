# PERSEUS scenario API (phase 3 seed)

A thin FastAPI service that lets the Forest Intelligence GUI run a real LANDIS scenario
on Cardinal and read back the resulting biomass trajectory. This is the seam that turns
the scenario builder from a what if envelope into an actual model run.

## What it does today

It accepts a single-plot scenario (state, climate, harvest, plot id), submits one LANDIS
run as a SLURM job over SSH, reports status from `squeue`, and returns the biomass
trajectory at years 0, 25, 50, 75, 100. That single-plot path is the smallest live-run
unit and proves the full GUI to HPC round trip end to end. Statewide and factorial runs
reuse the same submission layer with a different job template.

## Files

`config.py` holds host, account, paths, and the mapping from GUI scenario options to the
pipeline arguments that `build_plot_scenario_{ST}.sh` expects. `cardinal_jobs.py` builds
the sbatch script, submits it over SSH, checks status, and reads `result.json`. `app.py`
is the FastAPI app with `/health`, `/states`, `/scenario/run`, `/scenario/status/{tag}`,
and `/scenario/result/{tag}`.

## Run it

```bash
export CARDINAL_SSH_KEY=/path/to/key_registered_on_cardinal
bash run_local.sh
curl -X POST localhost:8000/scenario/run -H 'content-type: application/json' \
  -d '{"state":"WA","climate":"baseline","harvest":"none","plot_id":"1"}'
# -> {"job_tag":"WA_1_xxxx","job_id":"123456","state":"queued"}
curl localhost:8000/scenario/status/WA_1_xxxx
curl localhost:8000/scenario/result/WA_1_xxxx
```

The GUI calls these endpoints instead of computing illustrative envelopes, so the growth
curve for a clicked plot becomes the model output for the exact scenario the user chose.

## Before this is production

Add authentication tied to OSC accounts; this service can submit compute, so it must not
be open. Replace the in-memory job registry with a small database so jobs survive a
restart, and cache results by scenario hash so identical requests do not resubmit. Add
rate limiting and a per-user job cap. Validate plot ids against the state inventory.
Consider paramiko with a connection pool instead of shelling out to ssh per call.

## Hosting options

An OSC OnDemand interactive app is the lowest-friction route because the auth and the
Cardinal access already exist there. A CRSF or UMaine virtual machine with a service
account key works for a public read mostly deployment. A container behind the campus
proxy is the most portable. The service holds no state of its own beyond the job
registry, so any of these scales by running more workers.
