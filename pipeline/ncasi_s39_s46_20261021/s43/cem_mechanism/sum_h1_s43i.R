library(data.table); options(width = 220)
T <- "/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s43/cem_mechanism"
R <- "/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s43/cem_ablation/scores/reg"
x <- rbindlist(lapply(list.files(file.path(T, "out"), "^h1_[A-Z]{2}_c00base.csv$", full.names = TRUE), fread))
fwrite(x, file.path(T, "out", "h1_all_c00base_s43i.csv"))
print(x[, .(state, area = round(area_Mha, 3), mortTg = round(tool_mort_Tgyr, 3), M = round(donor_M_Mghayr, 3), Md = round(donor_Mdist_Mghayr, 3), Mo = round(donor_Mother_Mghayr, 3),
  ins = round(donor_M10_insect, 3), dis = round(donor_M20_disease, 3), fire = round(donor_M30_fire, 4), ani = round(donor_M40_animal, 4), wx = round(donor_M50_weather, 3),
  DL = round(module_loss_Mghayr, 3), DLsbw = round(module_loss_sbw_Mghayr, 3), ratio = round(ratio_Mdist_over_module, 3), H1)])
r <- rbindlist(lapply(list.files(R, "^cem_gate_[A-Z]{2}_c00base", full.names = TRUE), fread), fill = TRUE)
cat(names(r)[1:8], "\n"); qc <- intersect(c("quantity","q","metric"), names(r))[1]
print(r[get(qc) %in% c("mort","M"), .SD, .SDcols = c("state", qc, intersect(c("tool","tool_Tgyr","ratio"), names(r)))])
