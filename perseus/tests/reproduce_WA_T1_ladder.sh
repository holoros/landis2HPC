#!/bin/bash
# Reproduce the WA Tier 1 theta ladder from this paper.
# Requires: OSC Cardinal access OR equivalent SLURM cluster with apptainer + LANDIS-II v8 image.
# Compute: ~10 hr at 150-task concurrency for full 12-theta sweep.
set -euo pipefail
cd "$(dirname "$0")/.."
echo "1. Build per-plot scenarios..."
bash tools/submit_WA_t0.sh
echo "2. Sweep theta ladder..."
bash tools/submit_WA_t1_ladder.sh "0.10 0.15 0.20 0.25 0.30 0.40 0.50 0.65 0.75 0.85 1.00"
echo "3. Run leaderboard..."
# See: docs/methods_paper_section_3_REFRESH.md
