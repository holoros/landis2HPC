# Session 36, 6 Oct 2026. Realism target for LANDIS stage eight (decision 3).
# FIA EVALIDator (evaluation group 2024, sensitivity 2025): average annual gross growth, mortality,
# net growth (gross growth minus mortality), removals and net change of live tree aboveground biomass,
# trees >= 1 inch, forest land. A harvest and disturbance free LANDIS run is compared with net growth
# (it carries mortality but no removals). LANDIS: mean annual change over 10 years, anchored run copy
# (anch, year zero = 2024 FIADB stock) and unit fix (unanchored), from anch_landscape_20261006.csv.
# Gates: E1 EVALIDator 2024 stock equals the 1 Oct local FIADB stock to 0.05 Tg (anchoring reference);
# E2 net_growth = gross_growth - mortality and net_change = net_growth - removals to 0.01 Tg;
# E3 anchored LANDIS year zero equals EVALIDator stock to 0.5 pct.
suppressMessages({library(data.table); library(ggplot2)})
ev <- fread("evalidator_agb_fourstate_24_25_20261006.csv")
ev[, yr := as.integer(substr(eval_grp, 3, 6))]
w <- dcast(ev, state + yr ~ quantity, value.var = "Tg")
se <- dcast(ev, state + yr ~ quantity, value.var = "se_pct")
fail <- character()
loc <- data.table(state = c("NH","VT","MI","WI"), local_stock = c(314.26, 294.27, 1050.96, 814.17))
e1 <- merge(w[yr == 2024, .(state, stock)], loc, by = "state")
if (e1[, any(abs(stock - local_stock) > 0.05)]) fail <- c(fail, "E1")
if (w[, any(abs(gross_growth - mortality - net_growth) > 0.01 | abs(net_growth - removals - net_change) > 0.01)]) fail <- c(fail, "E2")
ls <- fread("anch_landscape_20261006.csv")[, .(state, run, t0_Tg, t10_Tg)]
ls[, annual_Tg := (t10_Tg - t0_Tg) / 10]
e3 <- merge(ls[run == "anch"], w[yr == 2024, .(state, stock)], by = "state")
if (e3[, any(abs(t0_Tg / stock - 1) > 0.005)]) fail <- c(fail, "E3")
f <- merge(w, se[, .(state, yr, se_ng = net_growth, se_gg = gross_growth, se_m = mortality)], by = c("state","yr"))
f[, `:=`(ng_lo = net_growth * (1 - 1.96 * se_ng / 100), ng_hi = net_growth * (1 + 1.96 * se_ng / 100))]
f[, `:=`(ng_pct_stock = round(100 * net_growth / stock, 2), nc_pct_stock = round(100 * net_change / stock, 2))]
cmp <- merge(dcast(ls, state ~ run, value.var = "annual_Tg"), f[yr == 2024], by = "state")
setnames(cmp, c("anch","unitfix"), c("landis_anch_Tg_yr","landis_unitfix_Tg_yr"))
cmp[, `:=`(ratio_anch_to_netgrowth = round(landis_anch_Tg_yr / net_growth, 3),
           ratio_anch_lo = round(landis_anch_Tg_yr / ng_hi, 3), ratio_anch_hi = round(landis_anch_Tg_yr / ng_lo, 3),
           ratio_unitfix_to_netgrowth = round(landis_unitfix_Tg_yr / net_growth, 3),
           anch_pct_stock = round(100 * landis_anch_Tg_yr / stock, 2))]
out <- cmp[, .(state, stock_Tg = round(stock, 2), fia_gross_growth = round(gross_growth, 3), fia_mortality = round(mortality, 3),
               fia_net_growth = round(net_growth, 3), fia_ng_lo = round(ng_lo, 3), fia_ng_hi = round(ng_hi, 3),
               fia_removals = round(removals, 3), fia_net_change = round(net_change, 3),
               fia_ng_pct_stock = ng_pct_stock, landis_anch_Tg_yr = round(landis_anch_Tg_yr, 3), anch_pct_stock,
               ratio_anch_to_netgrowth, ratio_anch_lo, ratio_anch_hi,
               landis_unitfix_Tg_yr = round(landis_unitfix_Tg_yr, 3), ratio_unitfix_to_netgrowth)]
fwrite(out, "grm_realism_fourstate_20261006.csv")
fwrite(f[order(state, yr)], "evalidator_wide_24_25_20261006.csv")
print(e1); print(out)
print(f[, .(state, yr, stock, net_growth, se_ng, ng_pct_stock, net_change, nc_pct_stock)])
# Figure: annual change, FIA net growth with 95 pct CI against LANDIS anchored and unit fix (Tg yr-1)
pd <- rbind(out[, .(state, source = "FIA net growth (gross minus mortality)", v = fia_net_growth, lo = fia_ng_lo, hi = fia_ng_hi)],
            out[, .(state, source = "LANDIS, anchored IC", v = landis_anch_Tg_yr, lo = NA_real_, hi = NA_real_)],
            out[, .(state, source = "LANDIS, unanchored IC", v = landis_unitfix_Tg_yr, lo = NA_real_, hi = NA_real_)])
pd[, state := factor(state, levels = c("NH","VT","WI","MI"))]
p <- ggplot(pd, aes(state, v, fill = source)) +
  geom_col(position = position_dodge(0.8), width = 0.75, colour = "grey20", linewidth = 0.2) +
  geom_errorbar(aes(ymin = lo, ymax = hi), position = position_dodge(0.8), width = 0.25, na.rm = TRUE) +
  scale_fill_manual(values = c("grey35", "#2c7fb8", "#a6bddb"), name = NULL) +
  labs(x = NULL, y = expression("Live AGB change (Tg"~yr^{-1}*")")) +
  theme_classic(base_size = 10) + theme(legend.position = "top", legend.direction = "vertical", plot.margin = margin(5, 8, 5, 8))
ok <- tryCatch({ ggsave("fig_grm_realism_fourstate_20261006.png", p, width = 120, height = 100, units = "mm", dpi = 300, device = png, type = "cairo"); TRUE },
               error = function(e) { message("png failed: ", conditionMessage(e)); FALSE })
if (!ok) ggsave("fig_grm_realism_fourstate_20261006.pdf", p, width = 120, height = 100, units = "mm")
cat("GATES:", if (length(fail)) paste(fail, collapse = "; ") else "ALL PASS", "\n")
if (length(fail)) quit(status = 1)
