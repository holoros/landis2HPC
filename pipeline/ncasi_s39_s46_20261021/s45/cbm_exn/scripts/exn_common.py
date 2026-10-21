"""s45 Track L shared helpers for cbm_exn (libcbm 2.10.2). Carbon fraction CF = 0.5 in and out (plan v2 L4)."""
import json, os
import numpy as np, pandas as pd
from libcbm.model.cbm_exn import cbm_exn_model, cbm_exn_variables
from libcbm.model.model_definition.model_variables import ModelVariables
from libcbm.storage.backends import BackendType

CF = 0.5
T = "/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s45/cbm_exn"
def dry_to_c(x): return np.asarray(x, float) * CF
def c_to_dry(x): return np.asarray(x, float) / CF
def exn_dir(st): return os.path.join(T, "dump", st, "exn_params")
def spin_settings(st): return json.load(open(os.path.join(T, "dump", st, "spinup_settings.json")))

def bare_vars(model, n, spu, sw_hw, species, age, mat, area=None):
    """cbm_vars for n stands with empty pools (Input = 1), enabled, undisturbed."""
    v = cbm_exn_variables.init_cbm_vars(n, model.pool_names, model.flux_names, BackendType.numpy).to_pandas()
    for p in model.pool_names:
        v["pools"][p] = 0.0
    v["pools"]["Input"] = 1.0
    s = v["state"]
    s["area"] = 1.0 if area is None else area
    s["spatial_unit_id"] = spu; s["age"] = age; s["species"] = species; s["sw_hw"] = sw_hw
    s["time_since_last_disturbance"] = age; s["time_since_land_use_change"] = -1; s["land_class_id"] = -1
    s["last_disturbance_type"] = 0; s["enabled"] = 1
    pr = v["parameters"]
    pr["mean_annual_temperature"] = mat; pr["disturbance_type"] = 0
    pr["merch_inc"] = 0.0; pr["foliage_inc"] = 0.0; pr["other_inc"] = 0.0
    return v

def step(model, v, merch, fol, oth, dist=None):
    v["parameters"]["merch_inc"] = merch; v["parameters"]["foliage_inc"] = fol; v["parameters"]["other_inc"] = oth
    v["parameters"]["disturbance_type"] = 0 if dist is None else dist
    out = model.step(ModelVariables.from_pandas(v))
    return out.to_pandas()
