"""Configuration for the PERSEUS scenario backend.

All host-specific values are read from environment variables so the same code runs
from a developer laptop, an OSC OnDemand app, or a CRSF virtual machine. Nothing
secret is hard-coded; the SSH key path is supplied by the operator.
"""
import os

# Cardinal / SSH access. The operator provides a key that is registered on Cardinal.
CARDINAL_USER = os.environ.get("CARDINAL_USER", "crsfaaron")
CARDINAL_HOST = os.environ.get("CARDINAL_HOST", "cardinal.osc.edu")
SSH_KEY = os.environ.get("CARDINAL_SSH_KEY", os.path.expanduser("~/.ssh/id_osc"))
# The Cowork sandbox needs -F /dev/null to bypass a broken system ssh config; harmless elsewhere.
SSH_OPTS = [
    "-F", "/dev/null",
    "-o", "UserKnownHostsFile=/dev/null",
    "-o", "StrictHostKeyChecking=no",
    "-o", "LogLevel=ERROR",
    "-o", "ConnectTimeout=20",
]

# Optional API key. If set, action endpoints require a matching X-API-Key header.
# Leave unset for local development (endpoints stay open).
API_KEY = os.environ.get("PERSEUS_API_KEY", "")

LANDIS_ROOT = os.environ.get("LANDIS_ROOT", "/fs/scratch/PUOM0008/crsfaaron/landis2")
TOOLS = f"{LANDIS_ROOT}/tools"
ACCOUNT = os.environ.get("OSC_ACCOUNT", "PUOM0008")
# Where per-request scenario runs and result JSON are written on Cardinal.
WORK = os.environ.get("PERSEUS_API_WORK", f"{LANDIS_ROOT}/api_runs")

# States that have a production calibration and a per-plot scenario builder.
# Production tier reflects v1.4 (2026-05-29). All six states at Tier 2 per-species.
# WA promoted to v2.0 (iter9_cand4, per-plot LL -0.6254 over n=1415) after chain landed.
# GA promoted to v2.0 (iter8_cand5, per-plot LL -0.8802 over n=1249) after chain landed.
# MN/WI/MI all at v1.2.
STATES = {
    "ME": {"name": "Maine", "tier": "Tier 2 per-species v1.0 (26 params)",
           "builder": "build_plot_scenario_ME.sh"},
    "WA": {"name": "Washington", "tier": "Tier 2 per-species v2.0 (50 params)",
           "builder": "build_plot_scenario_WA.sh"},
    "GA": {"name": "Georgia", "tier": "Tier 2 per-species v2.0",
           "builder": "build_plot_scenario_GA.sh"},
    "MN": {"name": "Minnesota", "tier": "Tier 2 per-species v1.2",
           "builder": "build_plot_scenario_MN.sh"},
    "WI": {"name": "Wisconsin", "tier": "Tier 2 per-species v1.2",
           "builder": "build_plot_scenario_WI.sh"},
    "MI": {"name": "Michigan", "tier": "Tier 2 per-species v1.2",
           "builder": "build_plot_scenario_MI.sh"},
}

# GUI scenario options mapped to the arguments the pipeline scripts expect.
# build_plot_scenario_{ST}.sh takes <PLOT_ID> <CLIM> <HARV>.
CLIMATE = {"baseline": "baseline", "ssp245": "ssp245", "ssp585": "ssp585"}
# Harvest intensity maps to a harvest prescription tag. "none" disables harvest;
# the perseus prescriptions are intensity variants (BA-target removals).
HARVEST = {"none": "none", "light": "perseus", "moderate": "perseus", "heavy": "perseus"}

# Years at which biomass is extracted from the LANDIS output to form a trajectory.
TRAJ_YEARS = [0, 25, 50, 75, 100]
