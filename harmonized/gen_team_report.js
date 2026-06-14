const fs = require("fs");
const { Document, Packer, Paragraph, TextRun, Table, TableRow, TableCell,
  AlignmentType, LevelFormat, HeadingLevel, BorderStyle, WidthType, ShadingType } = require("docx");

const NAVY = "1F3864", BLUE = "2E75B6", HEADfill = "D5E8F0", ALT = "F2F7FB";
const border = { style: BorderStyle.SINGLE, size: 1, color: "BFBFBF" };
const borders = { top: border, bottom: border, left: border, right: border };

function H1(t){ return new Paragraph({ heading: HeadingLevel.HEADING_1, children:[new TextRun(t)] }); }
function H2(t){ return new Paragraph({ heading: HeadingLevel.HEADING_2, children:[new TextRun(t)] }); }
function P(t,opts={}){ return new Paragraph({ spacing:{after:120}, children:[new TextRun({text:t,...opts})] }); }
function BUL(t){ return new Paragraph({ numbering:{reference:"b",level:0}, spacing:{after:60}, children:[new TextRun(t)] }); }
function NUM(t){ return new Paragraph({ numbering:{reference:"n",level:0}, spacing:{after:60}, children:[new TextRun(t)] }); }

function cell(text, w, {head=false, alt=false, bold=false}={}){
  return new TableCell({ borders, width:{size:w,type:WidthType.DXA},
    shading:{ fill: head?HEADfill:(alt?ALT:"FFFFFF"), type:ShadingType.CLEAR },
    margins:{top:60,bottom:60,left:110,right:110},
    children:[new Paragraph({ children:[new TextRun({text:text, bold:head||bold, size:18,
      color: head?NAVY:"000000"})] })] });
}
function table(widths, rows){
  return new Table({ width:{size:widths.reduce((a,b)=>a+b,0),type:WidthType.DXA}, columnWidths:widths,
    rows: rows.map((r,ri)=> new TableRow({ children: r.map((c,ci)=>
      cell(c, widths[ci], {head: ri===0, alt: ri>0 && ri%2===0})) })) });
}

const doc = new Document({
  styles:{ default:{ document:{ run:{ font:"Arial", size:21 } } },
    paragraphStyles:[
      { id:"Heading1", name:"Heading 1", basedOn:"Normal", next:"Normal", quickFormat:true,
        run:{ size:30, bold:true, font:"Arial", color:NAVY },
        paragraph:{ spacing:{before:280,after:140}, outlineLevel:0,
          border:{ bottom:{ style:BorderStyle.SINGLE, size:6, color:BLUE, space:2 } } } },
      { id:"Heading2", name:"Heading 2", basedOn:"Normal", next:"Normal", quickFormat:true,
        run:{ size:24, bold:true, font:"Arial", color:BLUE },
        paragraph:{ spacing:{before:200,after:100}, outlineLevel:1 } },
    ] },
  numbering:{ config:[
    { reference:"b", levels:[{ level:0, format:LevelFormat.BULLET, text:"•", alignment:AlignmentType.LEFT,
      style:{ paragraph:{ indent:{ left:560, hanging:280 } } } }] },
    { reference:"n", levels:[{ level:0, format:LevelFormat.DECIMAL, text:"%1.", alignment:AlignmentType.LEFT,
      style:{ paragraph:{ indent:{ left:560, hanging:280 } } } }] },
  ] },
  sections:[{
    properties:{ page:{ size:{ width:12240, height:15840 }, margin:{ top:1440, right:1440, bottom:1440, left:1440 } } },
    children:[
      new Paragraph({ spacing:{after:60}, children:[new TextRun({ text:"Harmonized Multi-Model CONUS Forest Carbon Assessment", bold:true, size:34, color:NAVY })] }),
      new Paragraph({ spacing:{after:40}, children:[new TextRun({ text:"Team Status Report: Inventory, Key Findings, Recommendations, and the Path to Finalizing GCBM and LANDIS", size:24, color:BLUE })] }),
      new Paragraph({ spacing:{after:240}, children:[new TextRun({ text:"Center for Research on Sustainable Forests  |  14 June 2026", italics:true, size:18, color:"595959" })] }),

      H1("Executive summary"),
      P("Five independent forest-carbon models (FVS, LANDIS-II, CBM, yield curves, and CEM) now run on one common pipeline so that model structure is the only difference. Every trajectory is anchored to the same FIA 2025 live aboveground-carbon total per state, driven by the same common harvest, the same four scenarios (reserve, conservation, BAU, intensive), and the same harvested-wood-products accounting. A full state by scenario by model stress test returns zero anomalies. The cross-model spread is real structural signal, concentrated in the West, and the comparison is sound."),
      P("The three full-coverage models (FVS, yield curves, CBM) cover all 48 states across four scenarios and two disturbance modes, with an ensemble, credible intervals, and external validation against the American Forests state CBM reports. CEM is completing its 48-state native-2100 run (33 done, 15 relaunched). LANDIS remains a nine-state regional cross-check; its spatial 270 m deck has now been fully reconstructed and is one job submission from running. This report inventories each model, presents the stress-test findings, gives refinement recommendations, states exactly what is needed to finalize GCBM and LANDIS, and recommends the resolution at which the spatial members should feed the PERSEUS decision-support tool."),

      H1("1. Model inventory"),
      P("Reserve scenario, no-disturbance, 2100. Median is the across-state median per-state total."),
      table([1500,1100,1100,2200,2360],[
        ["Model","States","Horizon","Median state 2100 (Tg C)","Status"],
        ["FVS (calibrated)","48","2100","529","Calibrated; West over-projects (intrinsic, not a bug)"],
        ["FVS (default)","48","2100","702","Default parameters; high end-member"],
        ["CBM (libcbm)","48","2100","508","Central = libcbm 76-yr stratum engine, FIA-calibrated; GCBM (spatial) is the engine-gap reference; gap measured for 6 states"],
        ["Yield curves","48","2100","431","Re-anchored to common harvest"],
        ["CEM","36 → 48","2100","120","33 native-2100; 15 relaunched; low end-member"],
        ["LANDIS-II","9","2100","838","Per-plot; 270 m spatial deck reconstructed and ready"],
      ]),
      P("Full six-model overlap: IN, NH, OH, WA. Five-model overlap: 37 states. The coverage limiters are LANDIS (9 states) and CEM (completing to 48); finishing CEM lifts the six-model overlap toward nine states.", {italics:true, size:18, color:"595959"}),

      H1("2. Stress test (model x state x scenario)"),
      P("Source: the consolidated master matrix of six models by two disturbance modes by state by four scenarios."),
      BUL("Anomalies: zero. No negative or zero carbon, no non-monotonic harvest gradients, and no reserve scenarios carrying harvested-wood-products. The reserve >= conservation >= BAU >= intensive ordering holds for every model, state, and disturbance mode."),
      BUL("Scenario gradient (CONUS 2100, no-disturbance): every model is monotone, for example FVS calibrated 32.2 / 27.4 / 22.3 / 16.0 Pg C and CBM 24.3 / 20.2 / 15.9 / 11.1 Pg C across reserve to intensive, a consistent 26 to 50 percent drawdown."),
      BUL("Cross-model divergence (reserve 2100): median across states CV of 46 percent and median fold-range of 3.9x. Divergence concentrates in the West: NV 8x, NM 11x, CA 9x, CO 8x, WA 6x, OR 3x; the East is tight at 2 to 3x."),
      P("Interpretation: the western spread is the expected structural signature. FVS individual-tree, no-disturbance growth runs highest where stands are old and disturbance-prone, while CBM, yield curves, and CEM sit lower. This is genuine model-structure spread, not error, and it is exactly the disagreement a multi-model assessment is built to surface."),

      H1("3. Key findings"),
      NUM("The harmonized engine is internally consistent everywhere; the apples-to-apples design holds across all 48 states and four scenarios."),
      NUM("Structural (between-model) uncertainty dominates parameter and sampling uncertainty by roughly 40x at 2100, and is concentrated in the West. This is the headline scientific result and should frame how the ensemble is communicated."),
      NUM("The CBM engine question is largely resolved for Maine: the measured GCBM-over-libcbm gap is about -10 percent by 2050, not the +21 percent regional default, because the eastern entry-point correction to libcbm closed most of it. This likely narrows CBM uncertainty in the corrected states."),
      NUM("Western scenario contrast is muted by a harvest-layer limitation (the TM2016 product under-detects western removals); a measured western harvest and fire layer is the single most valuable western refinement."),

      H1("4. Recommendations (priority order)"),
      NUM("Finish CEM to 48 states (in flight): the 15 relaunched states bring CEM to native-2100 everywhere and lift the six-model overlap toward nine. Highest near-term value."),
      NUM("Western fire and harvest layer: add a measured LCMS/MTBS plus FIA TPO western disturbance layer so the western scenario contrast and the Oregon net-source benchmark become testable. This addresses the largest source of cross-model divergence."),
      NUM("CBM engine gap and calibration FINALIZED: libcbm is calibrated to FIA biomass (B1.3 FIA expansion, per-state vol-to-bio fit), a refinement over the generic Boudewyn coefficients standard CBM uses; this makes the engine gap read as GCBM versus FIA ground truth. The measured gap is integrated for the 6 GCBM-complete states (ME +40, MN 0, WA -17, IN -25, OR -27, GA -34 percent); the band uses the early density gap (isolates the spatial-versus-stratum methods difference, no disturbance double-counting). Two housekeeping items for the CBM team: re-point the reserve adapter explicitly at the libcbm 76-year reserve run, and archive that no-harvest run so its disturbance config is documented. Remaining 42 states get measured gaps as GCBM runs via cbm_states/port_new_state.sh."),
      NUM("Finalize LANDIS spatial run and add a replicate band (below), then keep LANDIS as a nine-state regional cross-check."),
      NUM("Yield curves: a stand-origin (planted vs natural) split would reduce its uncertainty in plantation-heavy southeastern states."),

      H1("5. Finalizing GCBM"),
      P("Roles clarified: the CBM central estimate is the libcbm 76-year stratum engine (the source of the 48-state 2100 reserve); GCBM is the spatially explicit engine that serves as the engine-gap reference and the per-owner strata provider. A production per-state pipeline (cbm_states) has run six states (GA, IN, ME, MN, OR, WA) as 5-year spatial runs, each producing spatial mosaics and a carbon table stratified by ownership class, plus the libcbm reference for all 48 states."),
      table([3400,5960],[
        ["Component","Status"],
        ["Per-state chain (cbm_states/port_new_state.sh)","ESTABLISHED. Ten stages: yield curves from FIA, biomass expansion, disturbance history, AIDB parameters, scenarios, CBM run, validation, and spatial aggregation."],
        ["Completed states","6 of 48: GA, IN, ME, MN, OR, WA, each with aggregate, mosaics, and per-owner carbon."],
        ["Spatial outputs","Per-variable per-step rasters (aboveground live C, total ecosystem C, soil C, NPP, NEP, NBP) already produced and mosaicked."],
        ["Owner strata","gcbm_state_per_owner.csv already emits carbon by Family, Corporate, State, Federal, Local, Tribal, and Unknown classes."],
        ["Remaining 42 states","Run the same chain per state; the gate is compute time, not methodology."],
        ["Engine gap","Populate the per-state libcbm pool reference to measure GCBM versus libcbm cleanly per state."],
      ]),
      P("Six-state aboveground-live-C result (Tg C, first to last five-year step): GA 21 to 35, IN 125 to 133, ME 443 to 458, MN 255 to 268, OR 859 to 877, WA 626 to 639. Next step: run cbm_states/port_new_state.sh for the remaining states (compute-bound), and populate the libcbm reference so the engine gap is measured rather than defaulted."),

      H1("6. Finalizing LANDIS"),
      P("LANDIS-II is the nine-state regional cross-check, run per-plot to stay apples-to-apples with the other plot-based members. The spatial vs non-spatial comparison for Maine required reconstructing the SL2025 landscape deck, which a prior file cleanup had left incomplete."),
      table([3400,5960],[
        ["Step","Status / what is needed"],
        ["Co-registered grid (IC + ecoregion)","DONE. Regenerated stack, rebuilt initial communities, coarsened to a matched 270 m grid (memory wall solved: 75M cells at 30 m down to 421k active at 270 m)."],
        ["Climate (80 ecoregions)","DONE. Built an 80-ecoregion uniform-climate file consistent with the 101-240 scheme."],
        ["Succession deck (Biomass Succession 7.0)","DONE. Reconstructed with all required section keywords; verified to parse end to end."],
        ["Run submission","PENDING a job slot (currently blocked by the CEM array under the queue limit); the deck and inputs are staged and ready."],
        ["Spatial vs plot comparison","Run extract once the landscape run lands, to quantify the spatial-structure effect against the per-plot reserve."],
        ["Replicate band","Add seed-varied statewide reruns to give LANDIS a measured intra-model uncertainty band, closing the last anchor-only member."],
      ]),
      P("Next step: submit the completed 270 m landscape reserve run as soon as the queue frees, validate the trajectory, then run the spatial-versus-plot extraction and the replicate band. CONUS expansion remains optional; the best additions are CEM-covered eastern states to widen the all-model overlap."),

      H1("7. Feeding PERSEUS: spatial, temporal, and strata resolution"),
      P("Analysis on the retained Maine GCBM aboveground-live-C map (28 m native, 123.5 million forest cells). Goal: the coarsest representation that preserves decision-relevant signal."),
      H2("Temporal: coarsen aggressively"),
      P("The reserve trajectory is nearly linear. Reconstructing the full five-year series from ten-year steps gives at most 0.04 percent error, and from fifteen-year steps at most 0.02 percent. Recommendation: store PERSEUS carbon at ten-year steps for reserve and conservation; keep five-year steps only where harvest or fire pulses occur."),
      H2("Spatial: 250 m floor, and conserve totals"),
      table([2400,3400,3560],[
        ["Resolution","Spatial variance retained","Total-C inflation if coarse cells treated as fully forest"],
        ["28 m (native)","100%","0%"],
        ["83 m","63%","+11%"],
        ["250 m","47%","+19%"],
        ["750 m","38%","+25%"],
        ["~1 km","37%","+26%"],
      ]),
      P("Pixel-scale heterogeneity falls fast (half lost by 250 m), and coarsening the density map alone inflates total carbon through forest-edge blurring. Recommendation: never ship a coarse density map alone; retain a co-coarsened forest-fraction (area) layer, or summarize by strata."),
      H2("Strata: the right representation for PERSEUS"),
      P("Decision-support operates at management-unit scale, not pixels. Stand-age class alone (8 classes) explains 46 percent of pixel variance as eight numbers instead of 1.8 million cells. More importantly, the GCBM production pipeline already emits the right strata: gcbm_state_per_owner.csv gives carbon by ownership class per variable per step. For example Minnesota aboveground live C by owner is Family 53, State 30, Corporate 21, Federal 21, Local 2 Tg C, each with its forest area. Ownership is the decision-relevant stratum because different owners have different management options, so PERSEUS should ingest the per-owner table directly, complemented by forest-type by ecoregion by age strata where finer resolution is needed."),
      H2("Net PERSEUS recommendation"),
      P("Drive PERSEUS from (1) the compact state by scenario by model by year carbon and NPV matrix, plus (2) for the spatial GCBM members, the per-owner stratum tables the pipeline already emits (owner by variable by step), at ten-year steps with stratum area, optionally refined to forest-type by ecoregion by age strata. This preserves total carbon exactly, preserves the decision-relevant between-stratum signal, reduces the spatial data from hundreds of millions of pixel-steps to small tables, and reuses an output the production pipeline already produces; the native rasters stay archived for visualization."),

      H1("8. Current status snapshot"),
      BUL("Three-model CONUS backbone (FVS, yield curves, CBM): complete, with ensemble, credible intervals, geometric-mean and median central estimates, disturbance overlay, and external benchmark validation."),
      BUL("CEM: 33 of 48 states native-2100; 15 relaunched with an extended wall and running."),
      BUL("LANDIS: nine-state per-plot member integrated; 270 m spatial deck reconstructed and ready to submit."),
      BUL("GCBM: a production per-state pipeline (cbm_states) has completed six states (GA, IN, ME, MN, OR, WA) with spatial mosaics and owner-stratified carbon; the remaining states run the same chain, compute permitting."),
      BUL("A daily scheduled monitor integrates each campaign as it lands and keeps the operating documents current."),
      P("Caveat: the resolution and strata numbers are from Maine GCBM, the only retained spatial member to date; the qualitative conclusions (coarsen time hard, stratify space) generalize, but per-region strata counts should be re-derived as the other GCBM states and the LANDIS 270 m run land.", {italics:true, size:18, color:"595959"}),
    ]
  }]
});

Packer.toBuffer(doc).then(b => { fs.writeFileSync(process.argv[2], b); console.log("wrote", process.argv[2]); });
