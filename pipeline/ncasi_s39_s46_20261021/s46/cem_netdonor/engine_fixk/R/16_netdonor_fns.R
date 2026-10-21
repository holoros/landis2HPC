# s45 Track K (post unblinding follow-on, not gate eligible).
# Disturbance module loss net of matched donor disturbance agent mortality.
# Spec: 2026-10-20_ncasi-january-preregistration_PLAN.md Track K, revisions v5 > v4 > v3 > v2 > original.
# Only defines functions; active only when CEM_NETDONOR=1 (default off = original engine).
# Module mode: BY AGENT. Module event to agent class map: spruce budworm -> 10 (insect),
#   windstorm -> 50 (weather), wildfire -> 30 (fire). The module has no class 20 or 40 events.
# Attribution of a plot's combined loss to events follows the module's own multiplicative
#   order (total_red = sbw_red * wind_red * fire_red): a10 = 1 - sbw_red,
#   a50 = sbw_red * (1 - wind_red), a30 = sbw_red * wind_red * (1 - fire_red); a10 + a50 + a30 = 1 - total_red.
# Units: engine biomass is lb per plot acre (unadjusted). Condition area basis = value / CONDPROP_UNADJ.
#   lb/ac to Mg/ha: 4.5359237e-4 / 0.40468564.
ND_LBAC_MGHA <- 4.5359237e-4 / 0.40468564
ND_CLASSES <- c("10", "20", "30", "40", "50")

# Donor table builder. Per T2 condition, annual (no REMPER division; GRM TPAMORT is per year)
# aboveground biomass mortality on forest land: sum over MORTALITY1/2 rows of
# MICR_TPAMORT_UNADJ_AL_FOREST x TREE_GRM_MIDPT DRYBIO_AG x ADJ_FACTOR (by GRM subplot type),
# split by agent class floor(AGENTCD/10) in 1..5; codes 60, 70, 80 and 0/NA are excluded from
# the netting (kept as Dexcl). Divided by the donor condition's CONDPROP_UNADJ (condition area basis).
# Inputs (data.table): gc(TRE_CN, PLT_CN, comp, typ, tm), mi(TRE_CN, m), tre(TRE_CN, CONDID, AGENTCD),
#   plt(PLT_CN, REMPER), adj(PLT_CN, A1, A2, A3), cnd(PLT_CN, CONDID, CONDPROP_UNADJ).
# Returns lb/ac/yr of condition area with ADJ applied, plus the plot acre sums (Dall_pa) for the snum 335 check.
nd_build_donor <- function(gc, mi, tre, plt, adj, cnd) {
  x <- gc[!is.na(typ) & typ > 0 & comp %chin% c("MORTALITY1", "MORTALITY2")]
  x <- mi[x, on = "TRE_CN"]
  x <- tre[x, on = "TRE_CN"]
  x <- plt[x, on = "PLT_CN"][!is.na(REMPER) & REMPER > 0 & !is.na(CONDID)]
  x <- adj[x, on = "PLT_CN"]
  for (v in c("m", "tm")) set(x, which(is.na(x[[v]])), v, 0)
  x[, A := fcase(typ == 1L, A1, typ == 2L, A2, typ == 3L, A3, default = NA_real_)]
  x[, adj_missing := is.na(A)]
  x[is.na(A), A := 0]
  x[, v := tm * m * A]          # annual, adjusted, lb per plot acre
  x[, ac := floor(fcoalesce(as.numeric(AGENTCD), 0) / 10)]
  x[, cls := fifelse(ac %in% 1:5, sprintf("D%d0", as.integer(ac)), "Dexcl")]
  w <- dcast(x[, .(v = sum(v)), by = .(PLT_CN, CONDID, cls)], PLT_CN + CONDID ~ cls, value.var = "v", fill = 0)
  for (k in c(paste0("D", ND_CLASSES), "Dexcl")) if (!k %in% names(w)) w[, (k) := 0]
  w[, Dall_pa := D10 + D20 + D30 + D40 + D50 + Dexcl]
  am <- x[, .(n_adj_missing = sum(adj_missing)), by = .(PLT_CN, CONDID)]
  w <- am[w, on = c("PLT_CN", "CONDID")]
  w <- cnd[, .(PLT_CN, CONDID, CONDPROP_UNADJ)][w, on = c("PLT_CN", "CONDID")]
  ok <- is.finite(w$CONDPROP_UNADJ) & w$CONDPROP_UNADJ > 0
  for (k in c(paste0("D", ND_CLASSES), "Dexcl")) {
    set(w, j = paste0(k, "_ca"), value = fifelse(ok, w[[k]] / w$CONDPROP_UNADJ, 0))
  }
  w[, cp_ok := ok]
  w[]
}

# Netting for one set of subjects in one cycle.
# B: biomass at time of kill (lb per plot acre); a: n x 3 matrix of attributed loss fractions with
# columns c10, c50, c30; cp: subject CONDPROP_UNADJ; D: n x 3 matrix of donor mortality (Mg/ha/yr,
# condition area basis) in the same column order; cyc: engine cycle length (yr).
# Module loss is annualised by the cycle length only. Within class: net = max(0, L - D);
# scale s = net / L, s = 1 where L = 0 (v5 item 4). Rows with invalid subject CONDPROP are not netted (s = 1).
nd_netting <- function(B, a, cp, D, cyc, total_red) {
  cp_ok <- is.finite(cp) & cp > 0 & is.finite(B)
  L <- (B * a) / ifelse(cp_ok, cp, 1) * ND_LBAC_MGHA / cyc
  L[!cp_ok, ] <- 0
  D[!is.finite(D)] <- 0
  net <- pmax(L - D, 0)  # first argument a matrix so dims are kept (unit test fix, 20 Oct)
  s <- ifelse(L > 0, net / L, 1)
  all1 <- rowSums(s == 1) == ncol(s)
  new_red <- ifelse(all1, total_red, 1 - rowSums(s * a))
  list(L = L, net = net, s = s, total_red = new_red, cp_ok = cp_ok)
}

.nd_env <- new.env()

nd_load_table <- function() {
  if (!is.null(.nd_env$tab)) return(.nd_env$tab)
  dir <- Sys.getenv("CEM_NETDONOR_TAB_DIR"); sts <- strsplit(Sys.getenv("CEM_NETDONOR_STATES"), ",")[[1]]
  tab <- data.table::rbindlist(lapply(sts, function(s) readRDS(file.path(dir, sprintf("donor_mort_%s.rds", s)))), fill = TRUE)
  tab <- unique(tab[, .(key = paste(as.character(PLT_CN), as.integer(CONDID)), D10_ca, D20_ca, D30_ca, D40_ca, D50_ca)], by = "key")
  data.table::setkey(tab, key)
  .nd_env$tab <- tab; .nd_env$counter <- 0L
  cat(sprintf("  [s45 Track K] donor mortality table loaded: %d conditions from %s; null=%s\n",
              nrow(tab), paste(sts, collapse = ","), Sys.getenv("CEM_NETDONOR_NULL")))
  tab
}

# Called from apply_disturbance when CEM_NETDONOR=1. Returns the new retained fraction.
nd_apply_in_engine <- function(df, sbw_red, wind_red, fire_red, total_red, cfg, cycle_num, sim_id) {
  tab <- nd_load_table()
  n <- nrow(df)
  a <- cbind(c10 = 1 - sbw_red, c50 = sbw_red * (1 - wind_red), c30 = sbw_red * wind_red * (1 - fire_red))
  D <- matrix(0, n, 3, dimnames = list(NULL, c("c10", "c50", "c30")))
  has_donor <- rep(FALSE, n)
  if (Sys.getenv("CEM_NETDONOR_NULL") != "1" && all(c("T2_PLT_CN", "d_CONDID") %in% names(df))) {
    k <- paste(as.character(df$T2_PLT_CN), suppressWarnings(as.integer(df$d_CONDID)))
    i <- match(k, tab$key)
    has_donor <- !is.na(i)
    D[has_donor, "c10"] <- tab$D10_ca[i[has_donor]] * ND_LBAC_MGHA
    D[has_donor, "c50"] <- tab$D50_ca[i[has_donor]] * ND_LBAC_MGHA
    D[has_donor, "c30"] <- tab$D30_ca[i[has_donor]] * ND_LBAC_MGHA
  }
  cyc <- as.numeric(cfg$cycle_length_yrs %||% 5L)
  r <- nd_netting(df$proj_drybio, a, df$CONDPROP_UNADJ, D, cyc, total_red)
  dd <- Sys.getenv("CEM_NETDONOR_DIAG")
  if (nzchar(dd)) {
    .nd_env$counter <- .nd_env$counter + 1L
    g <- function(v) if (v %in% names(df)) df[[v]] else NA
    diag <- data.table::data.table(
      STATECD = g("STATECD"), COUNTYCD = g("COUNTYCD"), PLOT = g("PLOT"), CONDID = g("CONDID"),
      sim = sim_id, cycle = cycle_num, B = df$proj_drybio, cp = df$CONDPROP_UNADJ, cp_ok = r$cp_ok,
      a10 = a[, "c10"], a50 = a[, "c50"], a30 = a[, "c30"],
      L10 = r$L[, "c10"], L50 = r$L[, "c50"], L30 = r$L[, "c30"],
      D10 = D[, "c10"], D50 = D[, "c50"], D30 = D[, "c30"],
      s10 = r$s[, "c10"], s50 = r$s[, "c50"], s30 = r$s[, "c30"],
      red_old = total_red, red_new = r$total_red, has_donor = has_donor,
      pre_drybio_ag = g("pre_drybio_ag"), T2_drybio_ag = g("T2_drybio_ag"), d_drybio_ag = g("d_drybio_ag"),
      was_harvested = g("was_harvested"), was_unmatched = g("was_unmatched"), harvest_intensity = g("harvest_intensity"),
      FORTYPCD = g("FORTYPCD"))
    saveRDS(diag, file.path(dd, sprintf("nd_diag_%03d_s%02d_c%d.rds", .nd_env$counter, as.integer(sim_id), as.integer(cycle_num))))
  }
  r$total_red
}
