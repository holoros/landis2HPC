#!/usr/bin/env Rscript
# s46 Track K amended (post unblinding follow-on, not gate eligible): Track K ratios by state, window and
# scorer, change from the fixed baseline, plus netted fractions, class shares and valuation. Aggregates only.
suppressPackageStartupMessages(library(data.table))
T <- "/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s46/cem_netdonor"; SUF <- "_postunblind_followon_not_gate_eligible"
ST6 <- c("ME","NH","VT","MI","WI","MN")
fn <- function(sc, s, cfg) {
  suf <- if (sc == "reg") "_20261016e" else "_s43netted"
  p <- list.files(file.path(T, "scores", sc), pattern = sprintf("^cem_gate_%s_%s%s.*\\.csv$", s, cfg, SUF), full.names = TRUE)
  p <- p[!grepl("diag", p)]; stopifnot(length(p) == 1); x <- fread(p); x[, `:=`(scorer = sc, cfg = cfg)]; x[, .(state, quantity, scorer, cfg, ratio, pass)] }
r <- rbindlist(lapply(ST6, function(s) rbindlist(lapply(c("reg","net"), function(sc) rbindlist(lapply(c("f20a","k20net","k10ref","k10net"), function(cf) fn(sc, s, cf)))))))
r[, window := fifelse(cfg %in% c("f20a","k20net"), "2020", "2010")]
r[, role := fifelse(cfg %in% c("f20a","k10ref"), "fixed_baseline", "netted")]
w <- dcast(r, state + quantity + scorer + window ~ role, value.var = c("ratio","pass"))
w[, change := ratio_netted - ratio_fixed_baseline]
st <- w[, .(state_pass_trackK = all(pass_netted)), by = .(state, scorer, window)]
w[, label := "post unblinding follow-on, not gate eligible"]
fwrite(w, file.path(T, "out", sprintf("trackK_ratios_s46%s.csv", SUF)))
options(width = 220)
print(w[, .(window, scorer, state, quantity, fixed = round(ratio_fixed_baseline, 4), netted = round(ratio_netted, 4), change = round(change, 4), pass_netted)][order(window, scorer, state, quantity)])
print(st)
nf <- rbindlist(lapply(ST6, function(s) rbindlist(lapply(c("k20net","k10net"), function(cf) fread(file.path(T, "out", sprintf("netfrac_%s_%s%s.csv", s, cf, SUF)))))), fill = TRUE)
print(nf[, .(config, state, class, module_loss_Tgyr = signif(module_loss_Tgyr, 4), donor_mort = signif(donor_mort_all_subjects_Tgyr, 4),
             frac_floor = round(frac_removed_floor, 4), frac_aggr = round(frac_removed_aggregate, 4), share_module = round(share_of_module_loss, 4))])
dsh <- nf[class != "all", .(class, donor_class_share = donor_mort_all_subjects_Tgyr / sum(donor_mort_all_subjects_Tgyr)), by = .(config, state)]
print(dsh[class == "10"])
vm <- rbindlist(lapply(ST6, function(s) rbindlist(lapply(c("k20net","k10net"), function(cf) fread(file.path(T, "out", sprintf("valuation_%s_%s%s.csv", s, cf, SUF)))))))
print(vm[, .(config, state, kill = signif(loss_at_kill_Tgyr, 4), mid = signif(loss_at_midpoint_Tgyr, 4), kill_over_midpoint = round(kill_over_midpoint, 4))])
fwrite(dsh, file.path(T, "out", sprintf("donor_class_share_s46%s.csv", SUF)))
