p='build_initial_communities_v3_fb.R'; s=open(p).read()
a=s.index('suppressPackageStartupMessages({'); b=s.index('ST       <- opt$state')
new='''# ---- firebreather adaptation (scripts_20260929) ----------------------------
# 1. optparse is not installed on firebreather: base-R parser for the same flags.
# 2. TreeMap 2022 DBF and tree table defaults point at ~/landis2_fb/TREEMAP/TM2022.
# 3. The copy of outputs up one level never overwrites (dated variant instead).
# 4. Logs STDAGE NA count (template behaviour pmax(NA,1,na.rm=TRUE)=1 kept) and COND match rate.
# Everything else is the Cardinal v3 builder unchanged.
suppressPackageStartupMessages({
  library(terra)
  library(data.table)
  library(foreign)
})
parse_flags <- function(a) {
  o <- list(); i <- 1
  while (i <= length(a)) {
    k <- sub("^--", "", a[i]); if (i == length(a)) stop("flag without value: ", a[i])
    o[[k]] <- a[i + 1]; i <- i + 2
  }
  o
}
opt <- parse_flags(commandArgs(trailingOnly = TRUE))
TM22 <- path.expand("~/landis2_fb/TREEMAP/TM2022")
if (is.null(opt$tile)) opt$tile <- NA
if (is.null(opt$`tm-dbf`)) opt$`tm-dbf` <- file.path(TM22, "TreeMap2022_CONUS.tif.vat.dbf")
if (is.null(opt$`tm-tree-fallback`)) opt$`tm-tree-fallback` <- file.path(TM22, "TreeMap2022_CONUS_Tree_Table.csv")
beside <- function(path, tag = "20260929") {
  if (!file.exists(path)) return(path)
  ext <- tools::file_ext(path); stem <- sub(paste0("[.]", ext, "$"), "", path)
  p2 <- paste0(stem, "_", tag, ".", ext)
  if (file.exists(p2)) stop("dated variant already exists: ", p2)
  message("NOTE target exists, writing dated variant: ", p2); p2
}

required <- c("state", "treemap", "tree", "cond", "lookup", "out")
miss <- required[sapply(required, function(x) is.null(opt[[x]]))]
if (length(miss) > 0) stop("Missing required args: ", paste(miss, collapse = ", "))

'''
s=s[:a]+new+s[b:]
def rep(old,new):
    global s
    assert old in s, old[:60]
    s=s.replace(old,new)
rep('''cond1 <- cond[CONDID == 1, .(PLT_CN, STDAGE = pmax(STDAGE, 1L, na.rm = TRUE))]''','''log(sprintf("   CONDID 1 rows with STDAGE NA (coerced to 1 by template pmax): %d of %d",
            cond[CONDID == 1, sum(is.na(STDAGE))], cond[CONDID == 1, .N]))
cond1 <- cond[CONDID == 1, .(PLT_CN, STDAGE = pmax(STDAGE, 1L, na.rm = TRUE))]''')
rep('''tree_st <- merge(tree_st, cond1[, .(PLT_CN, STDAGE)], by = "PLT_CN", all.x = TRUE)''','''tree_st <- merge(tree_st, cond1[, .(PLT_CN, STDAGE)], by = "PLT_CN", all.x = TRUE)
log(sprintf("   live tree rows with no COND match (median age backstop): %d of %d; plots unmatched %d of %d",
            tree_st[is.na(STDAGE), .N], nrow(tree_st), tree_st[is.na(STDAGE), uniqueN(PLT_CN)], uniqueN(tree_st$PLT_CN)))''')
rep('''file.copy(ic_ras_path, file.path(opt$out, "initial-communities.tif"), overwrite = TRUE)
file.copy(ic_path,     file.path(opt$out, "initial_communities.txt"),  overwrite = TRUE)''','''up_tif <- beside(file.path(opt$out, "initial-communities.tif"))
up_txt <- beside(file.path(opt$out, "initial_communities.txt"))
file.copy(ic_ras_path, up_tif, overwrite = FALSE)
file.copy(ic_path,     up_txt, overwrite = FALSE)
log("   installed:", up_tif, up_txt)''')
open(p,'w').write(s)
print("patched")
