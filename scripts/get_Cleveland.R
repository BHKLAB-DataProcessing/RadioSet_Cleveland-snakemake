##########################################
#
# Create a RadioGx object
#
##########################################

# library(Biobase)
# library(xlsx)
# library(gdata)
library(readxl)
library(parallel)
library(abind)
library(RadioGx)

sessionInfo()

library(PharmacoGx)
options(stringsAsFactors = FALSE)

args <- commandArgs(trailingOnly = TRUE)
work_dir <- args[1]
filename <- args[2]

# work_dir <- '/Users/minoru/Code/bhklab/DataProcessing/RadioGenomics/RadioSet_Cleveland-snakemake/'

responsedata <- read_excel(paste0(work_dir, "download/XRT_CTD2_Dose_Response.xlsx"))
# responsedata <- responsedata[, -c(43:48)]


#### Now the cell.all file has the correct annotations.

cell.all <- read.csv(paste0(work_dir, "download/cell_annotation_all.csv"))
# cell.all <- read.csv("~/Code/Github/PharmacoGx-private/inst/extdata/cell_annotation_all.csv")
cell.exact.match <- match(responsedata$cell_line, cell.all$Cleveland.cellid)

unique.cellid <- cell.all[cell.exact.match, "unique.cellid"]
unique.tissueid <- cell.all[cell.exact.match, "unique.tissueid"]
# rownames(responsedata) <- responsedata$cell_line

responsedata1 <- responsedata[, c(2:12, 22, 25, 40:42)]
colnames(responsedata1) <- c(
  "CellLine", "SeedingDensity", "1Gy-rep1", "1Gy-rep2", "2Gy", "3Gy", "4Gy", "5Gy", "6Gy", "8Gy", "10Gy", "AUC", "CellLineSynonym",
  "Primarysite", "Histology", "HistologySubType"
)

cell <- data.frame(responsedata1$CellLine, responsedata1$Primarysite, responsedata1$Histology, responsedata1$HistologySubType)
cell <- cbind(cellid = unique.cellid, tissueid = unique.tissueid, cell)

cell <- cell[!duplicated(cell$cellid), ]

colnames(cell) <- c("cellid", "tissueid", "CellLine", "Primarysite", "Histology", "Subhistology")
rownames(cell) <- cell$cellid

# sensitivity object
info <- data.frame(
  unique.cellid, rep("radiation", nrow(responsedata1)), rep(1, each = nrow(responsedata1)), rep(1, each = nrow(responsedata1)),
  rep(2, each = nrow(responsedata1)), rep(3, each = nrow(responsedata1)), rep(4, each = nrow(responsedata1)), rep(5, each = nrow(responsedata1)),
  rep(6, each = nrow(responsedata1)), rep(8, each = nrow(responsedata1)), rep(10, each = nrow(responsedata1))
)
colnames(info) <- c(
  "cellid", "radiation.type", "Dose1-1Gy-rep1", "Dose1-1Gy-rep2", "Dose2-2Gy", "Dose3-3Gy", "Dose4-4Gy",
  "Dose5-5Gy", "Dose6-6Gy", "Dose8-8Gy", "Dose10-10Gy"
)
rownames(info) <- paste(info$cellid, info$radiationtype, seq(1, nrow(info)), sep = "_")

test1 <- info[, c(3:11)]
test2 <- responsedata1[, c(3:11)]
raw <- abind(test1, test2, along = 3)
rownames(raw) <- rownames(info)

colnames(raw) <- paste0("doses", seq_len(ncol(raw)))

dimnames(raw)[[3]] <- c("Dose", "Viability")

profiles <- data.frame(responsedata1$AUC)
colnames(profiles) <- c("AUC_published")
rownames(profiles) <- rownames(info)

CCLE <- readRDS(paste0(work_dir, "download/CCLE.rds"))

curationCell <- cell.all[cell.exact.match, c("unique.cellid", "Cleveland.cellid")]
curationTissue <- cell.all[cell.exact.match, c("unique.tissueid", "Cleveland.tissueid")]

curationTissue <- curationTissue[!duplicated(curationCell[, "unique.cellid"]), ]
curationCell <- curationCell[!duplicated(curationCell[, "unique.cellid"]), ]
rownames(curationCell) <- curationCell[, "unique.cellid"]
rownames(curationTissue) <- curationCell[, "unique.cellid"]

cells <- PharmacoGx::cellInfo(CCLE)
CCLEint <- PharmacoGx::subsetTo(CCLE, cells = intersect(rownames(cell), rownames(cells)))


Cleveland <- RadioSet(
  name = "Cleveland",
  cell = cell,
  molecularProfiles = CCLEint@molecularProfiles,
  radiation = data.frame("radiation", row.names = "radiation"),
  sensitivityInfo = info,
  sensitivityRaw = raw,
  sensitivityProfiles = profiles,
  datasetType = c("sensitivity"),
  curationCell = curationCell,
  curationTissue = curationTissue,
  verify = TRUE
)

saveRDS(Cleveland, file = file.path(work_dir, filename))


# radSig <- radSensitivitySig(Cleveland, "Kallisto_0.46.1.rnaseq", sensitivity.measure="AUC_published", nthread=3)

# # Micro-array
# load('~/PSets/CCLE.RData')
# cclex <- CCLE@molecularProfiles$rna@assayData$exprs
# rownames(cclex) <- CCLE@molecularProfiles$rna@featureData@data[rownames(cclex), "EntrezGeneId"]
# colnames(cclex) <- CCLE@molecularProfiles$rna@phenoData@data[colnames(cclex), "cellid"]
# cclex <- cclex[-which(is.na(rownames(cclex)) == T),] # remove all those rows that have NA, i.e. no Entrez Gene ID

# badchars <- "[\xb5]|[]|[ ,]|[;]|[:]|[-]|[+]|[*]|[%]|[$]|[#]|[{]|[}]|[[]|[]]|[|]|[\\^]|[/]|[\\]|[.]|[_]|[ ]|[(]|[)]"
# a3 <- gsub(badchars, "", colnames(cclex))
# colnames(cclex) <- toupper(a3)
# common <- intersect(rownames(responsedata),colnames(cclex))
# cclex <- cclex[,common]
# responsedata <- responsedata[common,]

# featdata <- CCLE@molecularProfiles$rna@featureData@data
# #phenodata <- CCLE@molecularProfiles$rna@phenoData@data
# phenodata <- responsedata
# phenodata <- phenodata[,-c(4:22)]
# phenodata <- phenodata[,-c(4)]
# edata.mrna <- cclex
# phenotypedata <- AnnotatedDataFrame(phenodata)
# featuresdata <- featdata[match(rownames(edata.mrna),featdata$EntrezGeneId),]
# rownames(featuresdata) <- featuresdata$EntrezGeneId
# mrna.eset <- new("ExpressionSet", exprs=as.matrix(edata.mrna),phenoData = phenotypedata,featureData = AnnotatedDataFrame(featuresdata))
# annotation(mrna.eset) <- "rna"

# # RNA-seq
# load('CCLE.RData')
# cclex <- CCLE@molecularProfiles$rnaseq@assayData$exprs
# pheno <- pData(CCLE@molecularProfiles$rnaseq)
# features <- fData(CCLE@molecularProfiles$rnaseq)
# features.entid <- subset(features,features$EntrezGeneId != "NA")
# cclex1 <- cclex[rownames(features.entid),]
# rownames(cclex1) <- features.entid$EntrezGeneId[match(rownames(cclex1),features.entid$EnsemblGeneId)]
# colnames(cclex1) <- pheno$cellid[match(colnames(cclex1),rownames(pheno))]

# badchars <- "[\xb5]|[]|[ ,]|[;]|[:]|[-]|[+]|[*]|[%]|[$]|[#]|[{]|[}]|[[]|[]]|[|]|[\\^]|[/]|[\\]|[.]|[_]|[ ]|[(]|[)]"
# a3 <- gsub(badchars, "", colnames(cclex1))
# colnames(cclex1) <- toupper(a3)
# common <- intersect(rownames(responsedata),colnames(cclex1))
# cclex1 <- cclex1[,common]
# responsedata <- responsedata[common,]

# featdata <- features.entid
# phenodata <- responsedata
# phenodata <- phenodata[,-c(4:22)]
# phenodata <- phenodata[,-c(4)]
# edata.rna <- cclex1
# phenotypedata <- AnnotatedDataFrame(phenodata)
# featuresdata <- featdata[match(rownames(edata.rna),featdata$EntrezGeneId),]
# rownames(featuresdata) <- featuresdata$EntrezGeneId
# rna.eset <- new("ExpressionSet", exprs=as.matrix(edata.rna),phenoData = phenotypedata,featureData = AnnotatedDataFrame(featuresdata))
# annotation(rna.eset) <- "rna"

# Moffit.radiation <- PharmacoSet(name="RadioGx-Moffit", molecularProfiles = list("mrna"= mrna.eset,"rnaseq"= rna.eset), cell = cell, drug = data.frame("radiation", row.names = "radiation"),
#                                 sensitivityInfo =info, sensitivityRaw = raw, sensitivityProfiles = profiles,datasetType = c("sensitivity"), verify = TRUE)

# save(Moffit.radiation,file="MoffitRadiation.RData")
