#!/bin/bash
# s41 step B setup: copy of the CEM engine (fia_cem_projections) with two
# output only patches, so the per plot archive carries the imputed donor pair.
#  1. R/06_projection_engine.R: donors_for_join also carries d_CONDID (donor condition).
#  2. run_projection.R keep_cols adds pre_drybio_ag, d_drybio_ag, T2_drybio_ag,
#     T2_PLT_CN, d_CONDID, remper, gr_drybio, cem_iteration.
# No numerical line is changed. Production code is not touched.
set -eu
SRC=$HOME/fia_cem_projections
E=/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s41/cem/engine
rm -rf $E; mkdir -p $E/output
cp -p $SRC/run_projection.R $E/
cp -rp $SRC/R $E/R
ln -s $SRC/config $E/config
ln -s $SRC/data $E/data
touch $E/.here
md5sum $SRC/run_projection.R $SRC/R/06_projection_engine.R
sed -i 's|    rename_with(~ paste0("d_", .), .cols = all_of(donor_t1_cols)) \|>|    rename_with(~ paste0("d_", .), .cols = all_of(donor_t1_cols)) \|>\n    mutate(d_CONDID = CONDID) \|>  # s41 patch: donor condition id (output only)|' $E/R/06_projection_engine.R
sed -i 's|                   "was_disturbed_sbw", "was_disturbed_wind", "was_disturbed_fire",|                   "was_disturbed_sbw", "was_disturbed_wind", "was_disturbed_fire",\n                   "pre_drybio_ag", "d_drybio_ag", "T2_drybio_ag", "T2_PLT_CN", "d_CONDID", "remper", "gr_drybio", "cem_iteration",  # s41 patch (output only)|' $E/run_projection.R
echo "--- diff 06"; diff $SRC/R/06_projection_engine.R $E/R/06_projection_engine.R || true
echo "--- diff run_projection"; diff $SRC/run_projection.R $E/run_projection.R || true
md5sum $E/run_projection.R $E/R/06_projection_engine.R
echo SETUP_DONE
