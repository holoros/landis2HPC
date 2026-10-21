# P1 redraw for the 16 Oct 2026 Sounding Board deck: area weighted six state mean (Aaron, 15 Oct: +54 on the face).
# Identical to P1 in ncasi-soundingboard-plain-figures_DRAFT_2026-10-16.R except the mean is weighted by measured
# FIA forest area and the caption says so. Reproduction gate: the simple mean must give 106, 127, 146, 168 and +59
# (the figure on the 15 Oct deck) and the weighted mean 98.5, 115.6, 133.8, 152.1 (MEMORY session 39 later).
suppressMessages({library(ggplot2); library(data.table)})
args <- commandArgs(TRUE); IN <- args[1]; OUT <- args[2]
GREEN <- "#1A3D28"; GOLD <- "#C5A55A"; SLATE <- "#6B7C85"; INK <- "#222A26"; PALE <- "#E9EEEA"
FF <- "Carlito"; TPA <- 1.10231 / 2.47105
th <- theme_minimal(base_family = FF, base_size = 20) +
  theme(panel.grid = element_blank(), plot.background = element_rect(fill = "white", colour = NA),
        axis.text = element_text(colour = INK), axis.title = element_text(colour = SLATE),
        plot.margin = margin(10, 20, 10, 10))
fv <- fread(file.path(IN, "oct-figure-values_DATA_2026-10-15.csv"))
ar <- fread(file.path(IN, "fia-forest-area-sixstate_DATA_2026-10-15.csv"))
f15 <- fv[figure == "F15", .(curves = group, inv = label, state = key, v = as.numeric(value))]
stopifnot(nrow(f15) == 24, uniqueN(f15$state) == 6)
f15 <- merge(f15, ar[, .(state, a = forest_area_ha)], by = "state"); stopifnot(nrow(f15) == 24)
m <- f15[, .(simple = mean(v), mean = sum(v * a) / sum(a)), by = .(curves, inv)]
key <- function(col) m[curves == "Maine fallback curves" & inv == "As is inventory"][[col]]
m[, `:=`(pct = 100 * (mean / key("mean") - 1), pct_s = 100 * (simple / key("simple") - 1), tpa = mean * TPA, tpa_s = simple * TPA)]
setorder(m, tpa)
stopifnot(all(round(m$tpa_s) == c(106, 127, 146, 168)), round(max(m$pct_s)) == 59,
          all(abs(m$tpa - c(98.5, 115.6, 133.8, 152.1)) < 0.05))
cat("REPRODUCTION GATE PASSED\n"); print(m)
m[, x := ifelse(curves == "Maine fallback curves", 1, 2)][, y := ifelse(inv == "As is inventory", 1, 2)]
m[, sub := ifelse(pct == 0, "model default", sprintf("+%.0f%%", pct))]
base_lab <- sprintf("%.0f", key("mean") * TPA)
p1 <- ggplot(m) +
  geom_tile(aes(x, y, fill = mean), width = 0.96, height = 0.94, colour = "white") +
  scale_fill_gradient(low = PALE, high = "#5E8A6C", guide = "none") +
  geom_text(aes(x, y + 0.13, label = sprintf("%.0f", tpa)), family = FF, fontface = "bold", size = 22, colour = GREEN) +
  geom_text(aes(x, y - 0.2, label = sub), family = FF, size = 8.5, colour = INK) +
  annotate("segment", x = 1.3, y = 1.3, xend = 1.7, yend = 1.7, colour = GOLD, linewidth = 2.2,
           arrow = arrow(length = unit(0.25, "in"), type = "closed")) +
  scale_x_continuous(breaks = 1:2, labels = c("Borrowed Maine\ncurves", "Each state's own\ncurves"),
                     position = "top", expand = c(0, 0)) +
  scale_y_continuous(breaks = 1:2, labels = c("Plots\nunweighted", "Plots weighted\nto FIA design"), expand = c(0, 0)) +
  labs(x = NULL, y = NULL, caption = paste0("CBM-CFS3 carbon at year 50, short tons per acre, six states weighted by forest area\n",
                                            "Whole forest: trees, dead wood and soil; each cell compared with ", base_lab)) +
  th + theme(axis.text.x.top = element_text(size = 20, face = "bold", colour = GREEN, margin = margin(b = 6)),
             axis.text.y = element_text(size = 19, face = "bold", colour = GREEN, hjust = 1),
             plot.caption = element_text(size = 15, colour = SLATE, hjust = 0.5))
ggsave(file.path(OUT, "p1-carbon-2x2-areaweighted_FIG_2026-10-16.png"), p1, width = 9.6, height = 6.0, dpi = 200, type = "cairo", bg = "white")
fwrite(m[, .(fig = "p1aw", curves, inv, value = round(tpa, 1), metric_MgC_ha = round(mean, 1), pct = round(pct, 1),
             simple_value = round(tpa_s, 1), simple_pct = round(pct_s, 1))],
       file.path(OUT, "p1-areaweighted-values_DATA_2026-10-16.csv"))
cat("DONE\n")
