#!/bin/bash
# Launch the PERSEUS scenario API locally.
# Requires an SSH key registered on Cardinal; point CARDINAL_SSH_KEY at it.
set -euo pipefail
export CARDINAL_USER="${CARDINAL_USER:-crsfaaron}"
export CARDINAL_HOST="${CARDINAL_HOST:-cardinal.osc.edu}"
export CARDINAL_SSH_KEY="${CARDINAL_SSH_KEY:-$HOME/.ssh/id_osc}"
pip install -r requirements.txt
uvicorn app:app --host 0.0.0.0 --port "${PORT:-8000}" --reload
