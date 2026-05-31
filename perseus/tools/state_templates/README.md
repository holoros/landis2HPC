# PERSEUS cluster warmstart templates

Inputs for the hybrid CONUS expansion (architecture C in `docs/CONUS_expansion_plan.md`,
scheme in `docs/conus_ecoregion_clusters.md`). `add_state.sh <FIPS> <ST> <CLUSTER>` reads
these to bootstrap a new state by warmstarting its Tier 2 CMA-ES chain from a calibrated
neighbor instead of a cold uniform start.

## Files

| File | Role |
|---|---|
| `cluster_<N>_reference_theta.csv` | warmstart x0 (per-species ANPP/BMAX multipliers) for cluster N |
| `cluster_<N>_extension_species.csv` | species in the cluster with no calibrated analog → need literature ANPP/BiomassMax |
| `apply_theta_template.py` | sed-templated to `apply_theta_<ST>_perspecies.py`; scales SppEcoregionData by the theta vector (state-agnostic; species looked up by code) |
| `build_plot_scenario_template.sh` | sed-templated to `build_plot_scenario_<ST>.sh`; single-plot scenario builder (state-agnostic: species block from SpeciesData.csv, eco name from ecoregions.txt) |

## Cluster references shipped

| Cluster | Region | Reference | Source | Status |
|---|---|---|---|---|
| N1 | Northeast hardwood-boreal | ME | ME Tier 2 v1.0 production theta (verbatim) | ready |
| N2 | Lake States | MN | MN Tier 2 v1.2 production theta (verbatim) | ready |
| N3 | Eastern hardwood central (IN, OH) | IN (not yet calibrated) → **bootstrapped from MN** | MN→IN species crosswalk; 12/23 species seeded, 11 cold at 0.60 | provisional |
| S1 | Southeast coastal plain | GA | GA Tier 2 v2.0 production theta (verbatim) | ready |
| P3 | Pacific Northwest | WA | WA Tier 2 v2.0 production theta (verbatim) | ready |

Clusters N4, S2, P1, P2, R1, R2, R3, P4 are blend/extension references that need
literature parameterization (the gating item flagged in the expansion plan) and are not
shipped here yet.

## N3 crosswalk (provisional — flagged for review)

IN and OH share an identical 23-species eastern-hardwood pool. The warmstart copies MN's
calibrated multiplier for the 12 species with a clear MN analog (WO, NRO→RO, BO, SM, RM,
BE, WAS, BAS, BSW, EWP→WP, QA, AE) and uses 0.60 (cold mid-range) for the 11 with none
(post oak, shingle/southern red oak, shagbark + mockernut hickory, yellow-poplar, black
walnut, sweetgum, blackgum, sycamore, sassafras, dogwood). A warmstart is only an
optimization hint — CMA-ES still converges from a rough x0 — so an approximate crosswalk
is safe, but the oak/hickory analog choices deserve a domain check before IN/OH are
treated as the canonical N3 reference. Once IN lands, re-freeze `cluster_N3_reference_theta.csv`
from IN's own production theta.

## REMAINING GATE before IN/OH (or any N3 state) can calibrate

`plot_ics_full/` is empty for IN and OH — this is why their 2026-05-29 chains failed.
`build_plot_ics_MN.py` cannot fill it: its FIA SPCD→species map only covers MN's pool and
would silently drop IN/OH oaks and hickories. The N3 cluster needs its own IC builder
(`build_plot_ics_N3.py`) with a curated eastern-hardwood SPCD→LANDIS map covering the 23
species above. That SPCD map is domain-sensitive (a wrong code silently drops a species)
and is the one IN/OH step deliberately left for review rather than auto-generated. Once it
exists, build ICs then submit the warmstarted chain via:

    cma_es_optimize_cluster.py --state IN --tag in_t2_v2 \
        --warmstart cluster_N3_reference_theta.csv
