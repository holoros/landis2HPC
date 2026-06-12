#!/usr/bin/env Rscript
# fig_uncertainty.R - publication figure of harmonized reserve uncertainty.
# Panel A: CONUS reserve carbon, each full-coverage model + inter-model ensemble band.
# Panel B: state-level between-model CV at 2100 (structural uncertainty), ranked.
# module load gcc/12.3.0 R/4.4.0
suppressPackageStartupMessages({library(data.table); library(ggplot2)})
FIA <- "/fs/scratch/PUOM0008/crsfaaron/FIA"
conus <- fread(file.path(FIA,"uncertainty_conus.csv"))
ens   <- fread(file.path(FIA,"uncertainty_by_state_year.csv"))

theme_pub <- theme_bw(base_size=12) +
  theme(panel.grid.minor=element_blank(), legend.position="top",
        legend.title=element_blank(), plot.title=element_text(face="bold"))

# Panel A: CONUS, long over models
mlong <- melt(conus[, .(year, FVS, YieldCurve, CBM)], id.vars="year",
              variable.name="model", value.name="TgC")
pA <- ggplot() +
  geom_ribbon(data=conus, aes(year, ymin=lo, ymax=hi), fill="grey80", alpha=.6) +
  geom_line(data=conus, aes(year, ensemble_median), linewidth=1.1, colour="grey25") +
  geom_line(data=mlong, aes(year, TgC, colour=model), linewidth=.9) +
  geom_point(data=mlong, aes(year, TgC, colour=model), size=1.8) +
  scale_colour_manual(values=c(FVS="#2c7fb8", YieldCurve="#d95f0e", CBM="#31a354")) +
  scale_y_continuous(limits=c(0,NA)) +
  labs(title="A. CONUS reserve carbon: inter-model structural uncertainty",
       subtitle="grey band = full-model envelope; line = ensemble median. All anchored to FIA 2025.",
       x=NULL, y="Aboveground live C (Tg)") + theme_pub

# Panel B: 2100 between-model CV by state
b <- ens[year==2100 & n_models>=3][order(-between_model_cv_pct)]
b[, state:=factor(state, levels=rev(state))]
pB <- ggplot(b, aes(state, between_model_cv_pct, fill=n_models)) +
  geom_col() + coord_flip() +
  scale_fill_gradient(low="#bdd7e7", high="#08519c", name="n models") +
  labs(title="B. State-level structural uncertainty at 2100",
       subtitle="between-model coefficient of variation (%)",
       x=NULL, y="Between-model CV (%)") + theme_pub +
  theme(legend.position="right", axis.text.y=element_text(size=7))

ggsave(file.path(FIA,"fig_uncertainty_A_conus.png"), pA, width=8, height=5, dpi=200)
ggsave(file.path(FIA,"fig_uncertainty_B_states.png"), pB, width=7, height=8, dpi=200)

# Panel C: variance decomposition - mean component SD by year (structural / parameter / sampling).
# Restricted to states with a REAL FVS Bayesian posterior band so the parameter term is a true
# parameter estimate (not the cal-vs-def proxy, which folds in structural differences).
dec <- ens[within_fvs_src=="posterior", .(Structural=mean(between_model_sd),
               `Parameter (FVS)`=mean(within_fvs_param),
               `FIA sampling`=mean(anchor_se)), by=year]
dl <- melt(dec, id.vars="year", variable.name="component", value.name="sd")
dl[, component:=factor(component, levels=c("Structural","Parameter (FVS)","FIA sampling"))]
pC <- ggplot(dl[year>2025], aes(factor(year), sd, fill=component)) +
  geom_col(position="dodge") +
  scale_fill_manual(values=c(Structural="#762a83", `Parameter (FVS)`="#1b7837", `FIA sampling`="#999999")) +
  labs(title="C. Uncertainty decomposition (mean state-level component SD)",
       subtitle="inter-model structure dominates parameter and sampling uncertainty",
       x="Year", y="Component SD (Tg C)") + theme_pub
ggsave(file.path(FIA,"fig_uncertainty_C_decomposition.png"), pC, width=8, height=5, dpi=200)
cat("figures written\n")
