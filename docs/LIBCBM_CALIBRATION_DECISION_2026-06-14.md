# libcbm calibration: finalized decision

Date 2026-06-14. Finalizes which libcbm calibration is canonical for the harmonized assessment
and for the GCBM-vs-libcbm engine gap. This is a deliberate methodological choice and a refinement
relative to standard CBM practice.

## Decision
Adopt the B1.3 FIA-expansion calibration as canonical: per-state volume-to-biomass coefficients
fit to that state's FIA tree data, plus FIA B1.3 inventory expansion so the libcbm initial stock
matches the FIA design inventory ("inventory parity"). Source: cbm_states/shared/tools/
build_vol_to_bio_state.R (per-state fit, QA in vol_to_bio_<ST>_fit_qa.pdf) and the b13fia libcbm
runs (libcbm_pools_<ST>_b13_50yr.csv). The engine gap in cbm_engine_gap.csv is locked to this
calibration (basis measured_density_gap_b13fia_20260531).

## Why this, and how it refines standard CBM (e.g. MSU)
Standard CBM-CFS3 (the configuration MSU and most CBM applications use) applies Boudewyn et al.
volume-to-biomass expansion factors derived from Canadian forest data, with the default CBM
inventory. That is portable but not calibrated to US conditions, and it can bias biomass density
in US forest types.

Our refinement keeps the Boudewyn functional form but REFITS the coefficients to each state's FIA
tree measurements, and expands the inventory to FIA B1.3 totals. The result is a libcbm whose
biomass tracks the FIA inventory rather than a Canadian default. Two consequences:
1. libcbm becomes a FIA-anchored reference, so the GCBM-vs-libcbm gap is interpretable as GCBM's
   deviation from FIA ground truth, not a difference between two un-validated engines.
2. The assessment is internally consistent: every model is anchored to the same FIA 2025 total, and
   now the CBM engine reference is calibrated to the same FIA basis.

## Implication for the engine gap and CBM uncertainty
On the finalized calibration the measured GCBM-over-libcbm gaps are ME +40%, MN +0%, WA -17%,
IN -25%, OR -27%, GA -34% (year-5 aboveground density). These are now in cbm_engine_gap.csv and the
cross-model CI and ensemble. The gap therefore reads as: where GCBM (spatial) sits above or below
the FIA-calibrated stratum engine. Maine GCBM runs high (+40%); the others run at or below the FIA
reference.

CAVEAT, retained as methodological uncertainty: the gap is sensitive to the libcbm calibration. The
same six states under the prior Boudewyn-default-style calibration (v6) gave ME +27%, MN +24%,
GA -5%, WA +26%, OR +21%. The difference between the FIA-expansion and Boudewyn calibrations is a
real source of CBM structural uncertainty and should be reported as such; we adopt the FIA-expansion
result as canonical because FIA is our common anchor and ground truth, but the cross-calibration
spread is the honest envelope.

## Status and next
The FIA-expansion libcbm reference exists for all 48 states (cbm_states/cross_state/libcbm/<ST>).
The GCBM spatial side exists for 6 (GA, IN, ME, MN, OR, WA), so the measured gap covers those 6;
the remaining 42 keep regional defaults until GCBM runs for them via cbm_states/port_new_state.sh.
The daily monitor launches the GCBM expansion wave as queue slots free and measures each new gap on
this finalized calibration.
