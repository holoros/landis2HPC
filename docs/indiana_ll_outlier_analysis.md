# Indiana per-plot LL outlier analysis — SPCD lumping review

**Date:** 2026-06-02
**Context:** Indiana production calibration (`in_t2_v3_iter2_cand11`) lands at per-plot LL = -1.3146, the weakest of the 8 PERSEUS states. Ohio, calibrated through the same cluster (N3, Eastern Hardwood Central) using the same densified-pairing pathway and warmstarted from Indiana's own production, lands at -0.8625 — within the normal range of other production calibrations. That a sibling within the same cluster fits substantially better points at an Indiana-specific issue rather than a systemic N3 problem.

The v1.6 CHANGELOG flagged the SPCD lumping in `build_plot_ics_N3.py` for review. This memo audits each lump and identifies the lumps most likely to drive Indiana's poor fit.

## Audit of SPCD-to-LANDIS mappings (build_plot_ics_N3.py)

### Oaks

| FIA SPCD | Common name | Lumped to | Defensibility |
|---|---|---|---|
| 802 | white oak | WO | direct, ✓ |
| 833 | northern red oak | NRO | direct, ✓ |
| 837 | black oak | BO | direct, ✓ |
| 835 | post oak | POST | direct, ✓ |
| 817 | shingle oak | SHO | direct, ✓ |
| 832 | chestnut oak | WO | same section, montane preference; minor in IN, defensible |
| 826 | chinkapin oak | WO | same section, limestone preference; defensible |
| 804 | **swamp white oak** | WO | same section but bottomland; loses wetness signal |
| 823 | **bur oak** | WO | same section but savanna/prairie edge; loses different growth pattern |
| 806 | blackjack oak | BO | same section, defensible |
| 812 | southern red oak | BO | same section, taller; small underestimate |
| 813 | **cherrybark oak** | BO | bottomland, much faster growing; meaningful underestimate |
| 834 | Shumard oak | NRO | same section, defensible |

### Hickories

| FIA SPCD | Common name | Lumped to | Defensibility |
|---|---|---|---|
| 407 | shagbark | SHA_HK | direct, ✓ |
| 408 | shellbark | SHA_HK | same section, defensible |
| 409 | mockernut | MOK_HK | direct, ✓ |
| 400 | generic hickory | MOK_HK | rough catchall, defensible |
| 402 | **bitternut** | MOK_HK | moist sites, faster-growing; small underestimate |
| 403 | pignut | MOK_HK | same upland section as mockernut, defensible |

### Maples

| FIA SPCD | Common name | Lumped to | Defensibility |
|---|---|---|---|
| 318 | sugar maple | SM | direct, ✓ |
| 316 | red maple | RM | direct, ✓ |
| 317 | **silver maple** | RM | bottomland, much faster-growing; meaningful underestimate |
| 313 | boxelder | RM | small statue, defensible (different but lower productivity) |

### Aspen / poplar (the big one)

| FIA SPCD | Common name | Lumped to | Defensibility |
|---|---|---|---|
| 746 | quaking aspen | QA | direct, ✓ |
| 743 | bigtooth aspen | QA | same genus, defensible |
| 742 | **eastern cottonwood** | QA | **bottomland giant, much faster-growing; large underestimate** |
| 741 | balsam poplar | QA | small in IN, defensible |

### Others (defensible)

Ashes (541/544/545 -> WAS, 543 -> BAS), elms (972/975/971/977 -> AE), 1:1 mappings for YP/BE/WALN/SWEETGUM/BLACKGUM/SYC/SASSAFRAS/DOGWOOD/EWP/BSW.

## Top suspects for Indiana's poor fit

Pattern: the lumps that most likely understate productivity are bottomland species collapsed to upland counterparts. Indiana's extensive Ohio River, White River, and Wabash River bottomland forests carry high-productivity species (eastern cottonwood, silver maple, cherrybark oak, swamp white oak) that are being modeled as their upland kin (quaking aspen, red maple, black oak, white oak). LANDIS will then predict slower growth than the IN plots actually exhibit, generating large negative residuals.

Ranked by likely magnitude of impact:

1. **Eastern cottonwood (742) -> QA**. Cottonwood grows to 30+ m, very fast (multiple meters per year on good sites); aspen is 15-20 m, slow on the same sites. This is the most severe single lump in the table.
2. **Silver maple (317) -> RM**. Silver maple is one of the fastest-growing North American bottomland species; red maple is a moderate generalist.
3. **Cherrybark oak (813) -> BO**. Southern bottomland oak, much faster than upland black oak.
4. **Swamp white oak (804) -> WO**. Bottomland white-oak section; modest impact but consistent direction.
5. **Bitternut hickory (402) -> MOK_HK**. Smaller impact; bitternut is moist-site but stature similar.

## Why Ohio fits better despite the same lumps

Ohio's major rivers are smaller (Maumee, Cuyahoga, Scioto) and its southern forests are more upland mixed (Appalachian foothills). The proportion of plots with eastern cottonwood or silver maple as a dominant cohort is much lower in OH than in IN. The cluster reference (frozen from IN's calibrated theta) embeds the IN-specific bottomland under-prediction as a feature; OH applies that bias to a population where the bias has less weight per plot, yielding a tolerable per-plot LL.

## Recommended fixes (ranked by effort)

### Low effort (1 to 2 hours): route bottomland species to SYC

The IN species pool already includes SYC (American sycamore) — a bottomland fast-grower. Rerouting:
- 742 cottonwood -> SYC instead of QA
- 317 silver maple -> SYC instead of RM (or BLACKGUM as an alternative bottomland proxy)
- 813 cherrybark oak -> SYC (poor section match but right productivity regime)

Pros: small change to `SPCD_TO_LANDIS`. Re-run the IC builder, then rerun the IN T2 chain (1.5 days) and expect a per-plot LL improvement toward OH's range.

Cons: SYC is the only bottomland fast-grower in the N3 pool. Conflating cottonwood + silver maple + cherrybark under a sycamore proxy is rough; some species-specific signal is lost.

### Medium effort (1 day): add 1 to 2 new species to the N3 pool

Add COTT (eastern cottonwood) and SIM (silver maple) as new LANDIS species in IN/inputs/SpeciesData.csv and SppEcoregionData.csv with literature-derived parameters. This requires extending `SPECIES_IN` in `apply_theta_IN_perspecies.py` and producing extension literature defaults (2 to 4 hours per new species).

Pros: full ecological resolution; matches what other LANDIS-II Eastern Hardwood applications use; OH benefits too since its sample includes some cottonwood and silver maple.

Cons: extends the theta vector from 46 to 50 entries; the CMA-ES chain takes slightly longer to converge; cluster N3 reference theta would need to be re-frozen after re-calibrating both IN and OH.

### High effort (2 to 4 days): full bottomland species set

Add COTT, SIM, CHRO (cherrybark oak), SWWO (swamp white oak) and re-parameterize. This is the gold standard but the marginal LL gain over option (b) is probably small for IN (the first two species account for the bulk of the underprediction).

## Recommendation

Pursue option (b): add COTT and SIM to the N3 species pool, re-derive the SPCD map, and re-calibrate both IN and OH. The cluster reference theta should be re-frozen from the re-calibrated IN (or OH, whichever fits better) for downstream Eastern Hardwood Central state additions.

Expected outcome: IN per-plot LL moves from -1.31 toward the -0.5 to -0.9 range (Great Lakes / Ohio neighborhood). OH per-plot LL likely improves modestly (-0.86 to perhaps -0.7). Both states would carry a more defensible bottomland signal for the statewide carbon trajectory.

If a shorter path is needed, option (a) is the cheap probe: change three SPCD mappings, rerun the IC builder, rerun the IN T2 chain. If the LL improves meaningfully, that's evidence the bottomland-lumping hypothesis is right and worth investing in option (b).

## Out of scope for this memo

The current IN production theta and the soon-to-land IN statewide carbon trajectory (job 11207176) are computed under the existing (lumped) IC builder. If option (a) or (b) is pursued later, both the per-plot calibration and the statewide carbon trajectory should be re-run for consistency. This is not a v1.9 blocker since the existing trajectory remains internally consistent with the existing IC.
