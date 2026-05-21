"""Cardinal job layer for the PERSEUS scenario backend.

Translates a validated scenario request into a single-plot LANDIS run on Cardinal,
submits it through SLURM over SSH, reports status from squeue, and reads the resulting
biomass trajectory back. This is the seam between the web GUI and the HPC pipeline.

The functions shell out to ssh rather than embedding a Python SSH library so the same
key and options that work everywhere else in the project work here with no new deps.
Swap in paramiko later if a long-lived service wants connection pooling.
"""
import json
import subprocess
import config


def _ssh(remote_cmd, timeout=60):
    cmd = ["ssh", *config.SSH_OPTS, "-i", config.SSH_KEY,
           f"{config.CARDINAL_USER}@{config.CARDINAL_HOST}", remote_cmd]
    return subprocess.run(cmd, capture_output=True, text=True, timeout=timeout)


def job_dir(job_tag):
    return f"{config.WORK}/{job_tag}"


def build_sbatch(spec, job_tag):
    """Return an sbatch script that builds a one-plot scenario, runs LANDIS, and writes
    a trajectory JSON. spec keys: state, plot_id, clim, harv."""
    st = spec["state"]
    builder = config.STATES[st]["builder"]
    d = job_dir(job_tag)
    years = ",".join(str(y) for y in config.TRAJ_YEARS)
    return f"""#!/bin/bash
#SBATCH --job-name=perseus_api_{job_tag}
#SBATCH --account={config.ACCOUNT}
#SBATCH --partition=batch
#SBATCH --ntasks=1 --cpus-per-task=1 --mem=4G --time=00:30:00
#SBATCH --output={d}/run.out
#SBATCH --error={d}/run.err

set -uo pipefail
TOOLS={config.TOOLS}
DST={d}
mkdir -p $DST
# Build the single-plot scenario directory (per-state builder), then run LANDIS in it.
bash $TOOLS/{builder} {spec['plot_id']} {spec['clim']} {spec['harv']} > $DST/build.log 2>&1
RUNDIR=$(ls -d {config.LANDIS_ROOT}/states/{st}/perseus/runs/plot_{spec['plot_id']}__* 2>/dev/null | head -1)
if [ -z "$RUNDIR" ]; then echo '{{"error":"scenario build failed"}}' > $DST/result.json; exit 1; fi
cd "$RUNDIR"
apptainer exec --bind /fs/scratch/PUOM0008:/fs/scratch/PUOM0008 \\
  {config.LANDIS_ROOT}/images/landis-ii_v8_allext_v1.0.sif \\
  dotnet /bin/LANDIS_Linux/build/Release/Landis.Console.dll scenario.txt > $DST/landis.log 2>&1
# Extract biomass at the requested years into result.json
apptainer exec --bind /fs/scratch/PUOM0008:/fs/scratch/PUOM0008 \\
  {config.LANDIS_ROOT}/images/landis-ii_v8_allext_v1.0.sif python3 - <<PY
from osgeo import gdal
import json, os
years=[{years}]
traj={{}}
for y in years:
    f="$RUNDIR/output/biomass/biomass-TotalBiomass-%d.tif" % y
    if os.path.exists(f):
        ds=gdal.Open(f); traj[str(y)]=round(float(ds.GetRasterBand(1).ReadAsArray().flatten()[0])*0.01,2)
json.dump({{"state":"{st}","plot_id":"{spec['plot_id']}","clim":"{spec['clim']}","harv":"{spec['harv']}","trajectory":traj}}, open("$DST/result.json","w"))
PY
echo done > $DST/COMPLETE
"""


def submit(spec, job_tag):
    """Write the sbatch script to Cardinal and submit it. Returns the SLURM job id."""
    d = job_dir(job_tag)
    _ssh(f"mkdir -p {d}")
    # write the script remotely
    write = _ssh(f"cat > {d}/job.slurm <<'EOSLURM'\n{build_sbatch(spec, job_tag)}\nEOSLURM")
    if write.returncode != 0:
        raise RuntimeError(f"failed to stage job: {write.stderr}")
    r = _ssh(f"sbatch --parsable {d}/job.slurm")
    if r.returncode != 0:
        raise RuntimeError(f"sbatch failed: {r.stderr}")
    return r.stdout.strip().split(";")[0]


def status(job_id):
    """Return queued | running | done | unknown based on squeue state."""
    r = _ssh(f"squeue -j {job_id} -h -o '%T' 2>/dev/null")
    s = r.stdout.strip()
    if not s:
        return "done"          # no longer in queue: finished (check result.json for success)
    if s.startswith("R"):
        return "running"
    return "queued"


def result(job_tag):
    """Read result.json for a finished job, or None if not present yet."""
    r = _ssh(f"cat {job_dir(job_tag)}/result.json 2>/dev/null")
    if r.returncode != 0 or not r.stdout.strip():
        return None
    try:
        return json.loads(r.stdout)
    except json.JSONDecodeError:
        return None
