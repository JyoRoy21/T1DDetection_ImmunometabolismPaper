
## ----load libraries-----------------------------------------------------------------------------------------------------------------------------------
setwd("/Users/jyotirmoyroy/Desktop/Immunometabolism T1D Paper/Data/Sequencing/SingleCellRNASeq")
library(Seurat)
library(SoupX)
library(parallel)
library(purrr)
library(tibble)
library(presto)
library(dplyr)
library(patchwork)
library(plyr)
library(RColorBrewer)
library(multtest)
library(metap) 
library(ggprism)
library(glmGamPoi)
devtools::install_github("jinworks/CellChat")
library(CellChat)
library(patchwork)
options(stringsAsFactors = FALSE)
# reticulate::use_python("/Users/suoqinjin/anaconda3/bin/python", required=T) 

## ----load Object and subset objects-----
T1D_Timepoints<-readRDS("./annotated_T1D_Timepoints_v4.rds")
unique(T1D_Timepoints$group)
unique(T1D_Timepoints$time)
DimPlot(T1D_Timepoints)
Idents(T1D_Timepoints)<-T1D_Timepoints$CellSubType
T1D_Timepoints$samples<-T1D_Timepoints$sample
T1D_Timepoints$sample<-NULL
W12_Progressor <- subset(T1D_Timepoints, subset = time == "Week6" & group == "Progressor")
W6_NonProgressor <- subset(T1D_Timepoints, subset = time == "Week6" & group == "Non-Progressor")
W12_Progressor <- subset(T1D_Timepoints, subset = time == "Week12" & group == "Progressor")
W12_NonProgressor <- subset(T1D_Timepoints, subset = time == "Week12" & group == "Non-Progressor")

# Single Datasets ####
## ----W6_Progressor-----

### 1. Create cellchat object----
cellChat_W6_Progressor  <- createCellChat(object = W6_Progressor, group.by = "ident", assay = "RNA")

#Set Ligand Receptor Database
CellChatDB <- CellChatDB.mouse # use CellChatDB.mouse if running on mouse data
showDatabaseCategory(CellChatDB)
#dplyr::glimpse(CellChatDB$interaction)

# use all CellChatDB except for "Non-protein Signaling" for cell-cell communication analysis
CellChatDB.use <- subsetDB(CellChatDB)

# use all CellChatDB for cell-cell communication analysis
# CellChatDB.use <- CellChatDB # simply use the default CellChatDB. We do not suggest to use it in this way because CellChatDB v2 includes "Non-protein Signaling" (i.e., metabolic and synaptic signaling). 

# set the used database in the object
cellChat_W6_Progressor@DB <- CellChatDB.use

### 2. Preprocessing the expression data ----
# subset the expression data of signaling genes for saving computation cost
cellChat_W6_Progressor <- subsetData(cellChat_W6_Progressor) # This step is necessary even if using the whole database
future::plan("multisession", workers = 4) # do parallel
cellChat_W6_Progressor <- identifyOverExpressedGenes(cellChat_W6_Progressor)
cellChat_W6_Progressor <- identifyOverExpressedInteractions(cellChat_W6_Progressor)
#The number of highly variable ligand-receptor pairs used for signaling inference is 1317 
options(future.globals.maxSize = 1e9)  # Set limit to 1GB (adjust based on available memory)
library(future)
future::plan("multisession", workers = 4) 
gc()  # Free up memory before running the next computation

### 3. Compute the communication probability ----
ptm = Sys.time()
cellChat_W6_Progressor <- computeCommunProb(cellChat_W6_Progressor, type = "triMean")
cellChat_W6_Progressor <- filterCommunication(cellChat_W6_Progressor, min.cells = 10)

### 4. Infer communication at signaling pathway level ----

cellChat_W6_Progressor <- computeCommunProbPathway(cellChat_W6_Progressor)

### 5. Calculate the aggregated cell-cell communication network ----
cellChat_W6_Progressor <- aggregateNet(cellChat_W6_Progressor)
execution.time = Sys.time() - ptm
print(as.numeric(execution.time, units = "secs"))

ptm = Sys.time()
groupSize <- as.numeric(table(cellChat_W6_Progressor@idents))
par(mfrow = c(1,1), xpd=TRUE)
#netVisual_circle(cellChat_W6_Progressor@net$count, vertex.weight = groupSize, weight.scale = T, label.edge= F, title.name = "Number of interactions")
netVisual_circle(cellChat_W6_Progressor@net$weight, vertex.weight = groupSize, weight.scale = T, label.edge= F, title.name = "Interaction weights/strength-Week 6 Progressor")


mat <- cellChat_W6_Progressor@net$weight
par(mfrow = c(3,6), xpd=TRUE)
for (i in 1:nrow(mat)) {
  mat2 <- matrix(0, nrow = nrow(mat), ncol = ncol(mat), dimnames = dimnames(mat))
  mat2[i, ] <- mat[i, ]
  netVisual_circle(mat2, vertex.weight = groupSize, weight.scale = T, edge.weight.max = max(mat), title.name = rownames(mat)[i])
}

### 6. Identify signaling roles (e.g., dominant senders, receivers) of cell groups as well as the major contributing signaling ----

# Compute the network centrality scores
cellChat_W6_Progressor <- netAnalysis_computeCentrality(cellChat_W6_Progressor, slot.name = "netP") # the slot 'netP' means the inferred intercellular communication network of signaling pathways
# Visualize the computed centrality scores using heatmap, allowing ready identification of major signaling roles of cell groups
pathways.show <- c("CXCL")
netAnalysis_signalingRole_network(cellChat_W6_Progressor, signaling = pathways.show, width = 8, height = 2.5, font.size = 10)

# Signaling role analysis on the aggregated cell-cell communication network from all signaling pathways
gg1 <- netAnalysis_signalingRole_scatter(cellChat_W6_Progressor)
gg1+ xlim(0,8) + ylim(0,9)


# Signaling role analysis on the aggregated cell-cell communication network from all signaling pathways
ht1 <- netAnalysis_signalingRole_heatmap(cellChat_W6_Progressor, pattern = "outgoing", height = 16)
ht2 <- netAnalysis_signalingRole_heatmap(cellChat_W6_Progressor, pattern = "incoming", height = 16)
ht1 + ht2

# library(NMF)
# library(ggalluvial)
# selectK(cellChat_W6_Progressor, pattern = "outgoing")
# nPatterns = 2
# cellChat_W6_Progressor <- identifyCommunicationPatterns(cellChat_W6_Progressor, pattern = "outgoing", k = nPatterns)

saveRDS(cellChat_W6_Progressor, file = "cellChat_W6_Progressor.rds")
sessionInfo()

## ----W6_NonProgressor-----

### 1. Create cellchat object----
cellChat_W6_NonProgressor  <- createCellChat(object = W6_NonProgressor, group.by = "ident", assay = "RNA")

#Set Ligand Receptor Database
CellChatDB <- CellChatDB.mouse # use CellChatDB.mouse if running on mouse data
showDatabaseCategory(CellChatDB)
#dplyr::glimpse(CellChatDB$interaction)

# use all CellChatDB except for "Non-protein Signaling" for cell-cell communication analysis
CellChatDB.use <- subsetDB(CellChatDB)

# use all CellChatDB for cell-cell communication analysis
# CellChatDB.use <- CellChatDB # simply use the default CellChatDB. We do not suggest to use it in this way because CellChatDB v2 includes "Non-protein Signaling" (i.e., metabolic and synaptic signaling). 

# set the used database in the object
cellChat_W6_NonProgressor@DB <- CellChatDB.use

### 2. Preprocessing the expression data ----
# subset the expression data of signaling genes for saving computation cost
cellChat_W6_NonProgressor <- subsetData(cellChat_W6_NonProgressor) # This step is necessary even if using the whole database
future::plan("multisession", workers = 4) # do parallel
cellChat_W6_NonProgressor <- identifyOverExpressedGenes(cellChat_W6_NonProgressor)
cellChat_W6_NonProgressor <- identifyOverExpressedInteractions(cellChat_W6_NonProgressor)
#The number of highly variable ligand-receptor pairs used for signaling inference is 1214  
options(future.globals.maxSize = 1e9)  # Set limit to 1GB (adjust based on available memory)
library(future)
future::plan("multisession", workers = 4) 
gc()  # Free up memory before running the next computation

### 3. Compute the communication probability ----
ptm = Sys.time()
cellChat_W6_NonProgressor <- computeCommunProb(cellChat_W6_NonProgressor, type = "triMean")
cellChat_W6_NonProgressor <- filterCommunication(cellChat_W6_NonProgressor, min.cells = 10)

### 4. Infer communication at signaling pathway level ----

cellChat_W6_NonProgressor <- computeCommunProbPathway(cellChat_W6_NonProgressor)

### 5. Calculate the aggregated cell-cell communication network ----
cellChat_W6_NonProgressor <- aggregateNet(cellChat_W6_NonProgressor)
execution.time = Sys.time() - ptm
print(as.numeric(execution.time, units = "secs"))

ptm = Sys.time()
groupSize <- as.numeric(table(cellChat_W6_NonProgressor@idents))
par(mfrow = c(1,1), xpd=TRUE)
#netVisual_circle(cellChat_W6_NonProgressor@net$count, vertex.weight = groupSize, weight.scale = T, label.edge= F, title.name = "Number of interactions")
netVisual_circle(cellChat_W6_NonProgressor@net$weight, vertex.weight = groupSize, weight.scale = T, label.edge= F, title.name = "Interaction weights/strength-Week 6 Non-Progressor")


mat <- cellChat_W6_NonProgressor@net$weight
par(mfrow = c(3,6), xpd=TRUE)
for (i in 1:nrow(mat)) {
  mat2 <- matrix(0, nrow = nrow(mat), ncol = ncol(mat), dimnames = dimnames(mat))
  mat2[i, ] <- mat[i, ]
  netVisual_circle(mat2, vertex.weight = groupSize, weight.scale = T, edge.weight.max = max(mat), title.name = rownames(mat)[i])
}

### 6. Identify signaling roles (e.g., dominant senders, receivers) of cell groups as well as the major contributing signaling ----

# Compute the network centrality scores
cellChat_W6_NonProgressor <- netAnalysis_computeCentrality(cellChat_W6_NonProgressor, slot.name = "netP") # the slot 'netP' means the inferred intercellular communication network of signaling pathways
# Visualize the computed centrality scores using heatmap, allowing ready identification of major signaling roles of cell groups
pathways.show <- c("CXCL")
netAnalysis_signalingRole_network(cellChat_W6_NonProgressor, signaling = pathways.show, width = 8, height = 2.5, font.size = 10)

# Signaling role analysis on the aggregated cell-cell communication network from all signaling pathways
gg1 <- netAnalysis_signalingRole_scatter(cellChat_W6_NonProgressor)
gg1+ xlim(0,8) + ylim(0,9)

# Signaling role analysis on the aggregated cell-cell communication network from all signaling pathways
ht1 <- netAnalysis_signalingRole_heatmap(cellChat_W6_NonProgressor, pattern = "outgoing", height = 16)
ht2 <- netAnalysis_signalingRole_heatmap(cellChat_W6_NonProgressor, pattern = "incoming", height = 16)
ht1 + ht2

# library(NMF)
# library(ggalluvial)
# selectK(cellChat_W6_NonProgressor, pattern = "outgoing")
# nPatterns = 2
# cellChat_W6_NonProgressor <- identifyCommunicationPatterns(cellChat_W6_NonProgressor, pattern = "outgoing", k = nPatterns)

saveRDS(cellChat_W6_NonProgressor, file = "cellChat_W6_NonProgressor.rds")
sessionInfo()

## ----W12_Progressor-----

### 1. Create cellchat object----
cellChat_W12_Progressor  <- createCellChat(object = W12_Progressor, group.by = "ident", assay = "RNA")

#Set Ligand Receptor Database
CellChatDB <- CellChatDB.mouse # use CellChatDB.mouse if running on mouse data
showDatabaseCategory(CellChatDB)
#dplyr::glimpse(CellChatDB$interaction)

# use all CellChatDB except for "Non-protein Signaling" for cell-cell communication analysis
CellChatDB.use <- subsetDB(CellChatDB)

# use all CellChatDB for cell-cell communication analysis
# CellChatDB.use <- CellChatDB # simply use the default CellChatDB. We do not suggest to use it in this way because CellChatDB v2 includes "Non-protein Signaling" (i.e., metabolic and synaptic signaling). 

# set the used database in the object
cellChat_W12_Progressor@DB <- CellChatDB.use

### 2. Preprocessing the expression data ----
# subset the expression data of signaling genes for saving computation cost
cellChat_W12_Progressor <- subsetData(cellChat_W12_Progressor) # This step is necessary even if using the whole database
future::plan("multisession", workers = 4) # do parallel
cellChat_W12_Progressor <- identifyOverExpressedGenes(cellChat_W12_Progressor)
cellChat_W12_Progressor <- identifyOverExpressedInteractions(cellChat_W12_Progressor)
#The number of highly variable ligand-receptor pairs used for signaling inference is 973 
options(future.globals.maxSize = 1e9)  # Set limit to 1GB (adjust based on available memory)
library(future)
future::plan("multisession", workers = 4) 
gc()  # Free up memory before running the next computation

### 3. Compute the communication probability ----
ptm = Sys.time()
cellChat_W12_Progressor <- computeCommunProb(cellChat_W12_Progressor, type = "triMean")
cellChat_W12_Progressor <- filterCommunication(cellChat_W12_Progressor, min.cells = 10)

### 4. Infer communication at signaling pathway level ----

cellChat_W12_Progressor <- computeCommunProbPathway(cellChat_W12_Progressor)

### 5. Calculate the aggregated cell-cell communication network ----
cellChat_W12_Progressor <- aggregateNet(cellChat_W12_Progressor)
execution.time = Sys.time() - ptm
print(as.numeric(execution.time, units = "secs"))

ptm = Sys.time()
groupSize <- as.numeric(table(cellChat_W12_Progressor@idents))
par(mfrow = c(1,1), xpd=TRUE)
#netVisual_circle(cellChat_W12_Progressor@net$count, vertex.weight = groupSize, weight.scale = T, label.edge= F, title.name = "Number of interactions")
netVisual_circle(cellChat_W12_Progressor@net$weight, vertex.weight = groupSize, weight.scale = T, label.edge= F, title.name = "Interaction weights/strength-Week 12 Progressor")


mat <- cellChat_W12_Progressor@net$weight
par(mfrow = c(3,6), xpd=TRUE)
for (i in 1:nrow(mat)) {
  mat2 <- matrix(0, nrow = nrow(mat), ncol = ncol(mat), dimnames = dimnames(mat))
  mat2[i, ] <- mat[i, ]
  netVisual_circle(mat2, vertex.weight = groupSize, weight.scale = T, edge.weight.max = max(mat), title.name = rownames(mat)[i])
}

### 6. Identify signaling roles (e.g., dominant senders, receivers) of cell groups as well as the major contributing signaling ----

# Compute the network centrality scores
cellChat_W12_Progressor <- netAnalysis_computeCentrality(cellChat_W12_Progressor, slot.name = "netP") # the slot 'netP' means the inferred intercellular communication network of signaling pathways
# Visualize the computed centrality scores using heatmap, allowing ready identification of major signaling roles of cell groups
pathways.show <- c("CXCL")
netAnalysis_signalingRole_network(cellChat_W12_Progressor, signaling = pathways.show, width = 8, height = 2.5, font.size = 10)

# Signaling role analysis on the aggregated cell-cell communication network from all signaling pathways
gg1 <- netAnalysis_signalingRole_scatter(cellChat_W12_Progressor)
#gg1# Add x and y axis limits
gg1 + xlim(0,8) + ylim(0,9)

# Signaling role analysis on the aggregated cell-cell communication network from all signaling pathways
ht1 <- netAnalysis_signalingRole_heatmap(cellChat_W12_Progressor, pattern = "outgoing", height = 16)
ht2 <- netAnalysis_signalingRole_heatmap(cellChat_W12_Progressor, pattern = "incoming", height = 16)
ht1 + ht2

saveRDS(cellChat_W12_Progressor, file = "cellChat_W12_Progressor.rds")
sessionInfo()


## ----W12_NonProgressor-----

### 1. Create cellchat object----
cellChat_W12_NonProgressor  <- createCellChat(object = W12_NonProgressor, group.by = "ident", assay = "RNA")

#Set Ligand Receptor Database
CellChatDB <- CellChatDB.mouse # use CellChatDB.mouse if running on mouse data
showDatabaseCategory(CellChatDB)
#dplyr::glimpse(CellChatDB$interaction)

# use all CellChatDB except for "Non-protein Signaling" for cell-cell communication analysis
CellChatDB.use <- subsetDB(CellChatDB)

# use all CellChatDB for cell-cell communication analysis
# CellChatDB.use <- CellChatDB # simply use the default CellChatDB. We do not suggest to use it in this way because CellChatDB v2 includes "Non-protein Signaling" (i.e., metabolic and synaptic signaling). 

# set the used database in the object
cellChat_W12_NonProgressor@DB <- CellChatDB.use

### 2. Preprocessing the expression data ----
# subset the expression data of signaling genes for saving computation cost
cellChat_W12_NonProgressor <- subsetData(cellChat_W12_NonProgressor) # This step is necessary even if using the whole database
future::plan("multisession", workers = 4) # do parallel
cellChat_W12_NonProgressor <- identifyOverExpressedGenes(cellChat_W12_NonProgressor)
cellChat_W12_NonProgressor <- identifyOverExpressedInteractions(cellChat_W12_NonProgressor)
#The number of highly variable ligand-receptor pairs used for signaling inference is 1214  
options(future.globals.maxSize = 1e9)  # Set limit to 1GB (adjust based on available memory)
library(future)
future::plan("multisession", workers = 4) 
gc()  # Free up memory before running the next computation

### 3. Compute the communication probability ----
ptm = Sys.time()
cellChat_W12_NonProgressor <- computeCommunProb(cellChat_W12_NonProgressor, type = "triMean")
cellChat_W12_NonProgressor <- filterCommunication(cellChat_W12_NonProgressor, min.cells = 10)

### 4. Infer communication at signaling pathway level ----

cellChat_W12_NonProgressor <- computeCommunProbPathway(cellChat_W12_NonProgressor)

### 5. Calculate the aggregated cell-cell communication network ----
cellChat_W12_NonProgressor <- aggregateNet(cellChat_W12_NonProgressor)
execution.time = Sys.time() - ptm
print(as.numeric(execution.time, units = "secs"))

ptm = Sys.time()
groupSize <- as.numeric(table(cellChat_W12_NonProgressor@idents))
par(mfrow = c(1,1), xpd=TRUE)
#netVisual_circle(cellChat_W12_NonProgressor@net$count, vertex.weight = groupSize, weight.scale = T, label.edge= F, title.name = "Number of interactions")
netVisual_circle(cellChat_W12_NonProgressor@net$weight, vertex.weight = groupSize, weight.scale = T, label.edge= F, title.name = "Interaction weights/strength-Week 12 Non-Progressor")


mat <- cellChat_W12_NonProgressor@net$weight
par(mfrow = c(3,6), xpd=TRUE)
for (i in 1:nrow(mat)) {
  mat2 <- matrix(0, nrow = nrow(mat), ncol = ncol(mat), dimnames = dimnames(mat))
  mat2[i, ] <- mat[i, ]
  netVisual_circle(mat2, vertex.weight = groupSize, weight.scale = T, edge.weight.max = max(mat), title.name = rownames(mat)[i])
}

### 6. Identify signaling roles (e.g., dominant senders, receivers) of cell groups as well as the major contributing signaling ----

# Compute the network centrality scores
cellChat_W12_NonProgressor <- netAnalysis_computeCentrality(cellChat_W12_NonProgressor, slot.name = "netP") # the slot 'netP' means the inferred intercellular communication network of signaling pathways
# Visualize the computed centrality scores using heatmap, allowing ready identification of major signaling roles of cell groups
pathways.show <- c("CXCL")
netAnalysis_signalingRole_network(cellChat_W12_NonProgressor, signaling = pathways.show, width = 8, height = 2.5, font.size = 10)

# Signaling role analysis on the aggregated cell-cell communication network from all signaling pathways
gg1 <- netAnalysis_signalingRole_scatter(cellChat_W12_NonProgressor)
gg1+ xlim(0,8) + ylim(0,9)

# Signaling role analysis on the aggregated cell-cell communication network from all signaling pathways
ht1 <- netAnalysis_signalingRole_heatmap(cellChat_W12_NonProgressor, pattern = "outgoing", height = 16)
ht2 <- netAnalysis_signalingRole_heatmap(cellChat_W12_NonProgressor, pattern = "incoming", height = 16)
ht1 + ht2

# library(NMF)
# library(ggalluvial)
# selectK(cellChat_W12_NonProgressor, pattern = "outgoing")
# nPatterns = 2
# cellChat_W12_NonProgressor <- identifyCommunicationPatterns(cellChat_W12_NonProgressor, pattern = "outgoing", k = nPatterns)

saveRDS(cellChat_W12_NonProgressor, file = "cellChat_W12_NonProgressor.rds")
sessionInfo()

# Multiple Datasets Comparison ####

## Week 6- Progressor vs Non-Progressor ----

W6_NonProgressor <- readRDS("cellChat_W6_NonProgressor.rds")
W6_Progressor <- readRDS("cellChat_W6_Progressor.rds")
object.list_W6 <- list(NonProgressor = W6_NonProgressor, Progressor = W6_Progressor)
cellchat_W6_PvsNP <- mergeCellChat(object.list_W6, add.names = names(object.list_W6))

cellchat_W6_PvsNP

### 1. Identify altered interactions and cell populations ----

gg1 <- compareInteractions(cellchat_W6_PvsNP, show.legend = F, group = c(1,2))
gg2 <- compareInteractions(cellchat_W6_PvsNP, show.legend = F, group = c(1,2), measure = "weight")
gg1 + gg2

par(mfrow = c(1,1), xpd=TRUE)
netVisual_diffInteraction(cellchat_W6_PvsNP, weight.scale = T, measure = "weight")

gg1 <- netVisual_heatmap(cellchat_W6_PvsNP, measure = "weight",font.size = 12, font.size.title = 18)
#> Do heatmap based on a merged object
gg1

num.link <- sapply(object.list_W6, function(x) {rowSums(x@net$count) + colSums(x@net$count)-diag(x@net$count)})
weight.MinMax <- c(min(num.link), max(num.link)) # control the dot size in the different datasets
gg <- list()
for (i in 1:length(object.list_W6)) {
  gg[[i]] <- netAnalysis_signalingRole_scatter(object.list_W6[[i]], title = names(object.list_W6)[i], weight.MinMax = weight.MinMax)+ xlim(0,8) + ylim(0,9)
}
patchwork::wrap_plots(plots = gg)

gg1 <- netAnalysis_signalingChanges_scatter(cellchat_W6_PvsNP, idents.use = "Macrophage")
gg1
gg2 <- netAnalysis_signalingChanges_scatter(cellchat_W6_PvsNP, idents.use = "Dendritic Cell")
gg2
gg3 <- netAnalysis_signalingChanges_scatter(cellchat_W6_PvsNP, idents.use = "CD8 exhausted effector-like")
gg3
gg4 <- netAnalysis_signalingChanges_scatter(cellchat_W6_PvsNP, idents.use = "CD8 memory")
gg4
gg5 <- netAnalysis_signalingChanges_scatter(cellchat_W6_PvsNP, idents.use = "Tcon memory")
gg5
gg6 <- netAnalysis_signalingChanges_scatter(cellchat_W6_PvsNP, idents.use = "Tregs")
gg6
gg7 <- netAnalysis_signalingChanges_scatter(cellchat_W6_PvsNP, idents.use = "Tcon exhausted effector-like")
gg7
gg8 <- netAnalysis_signalingChanges_scatter(cellchat_W6_PvsNP, idents.use = "Tcon activated ")
gg8
gg9 <- netAnalysis_signalingChanges_scatter(cellchat_W6_PvsNP, idents.use = "Tcon Interferon Sensing")
gg9
gg10 <- netAnalysis_signalingChanges_scatter(cellchat_W6_PvsNP, idents.use = "NK Cell")
gg10
gg11 <- netAnalysis_signalingChanges_scatter(cellchat_W6_PvsNP, idents.use = "B Cell")
gg11
gg12 <- netAnalysis_signalingChanges_scatter(cellchat_W6_PvsNP, idents.use = "ILC2")
gg12
gg13 <- netAnalysis_signalingChanges_scatter(cellchat_W6_PvsNP, idents.use = "ILC3")
gg13

unique(cellchat_W6_PvsNP@meta$ident)
### 2. Identify altered signaling with distinct interaction strength ----
gg1 <- rankNet(cellchat_W6_PvsNP, mode = "comparison", measure = "weight", sources.use = NULL, targets.use = NULL, stacked = T, do.stat = TRUE)
gg2 <- rankNet(cellchat_W6_PvsNP, mode = "comparison", measure = "weight", sources.use = NULL, targets.use = NULL, stacked = F, do.stat = TRUE)

gg1 + gg2

### 3.Compare outgoing (or incoming) signaling patterns associated with each cell population ----
library(ComplexHeatmap)
i = 1
# combining all the identified signaling pathways from different datasets 
pathway.union <- union(object.list_W6[[i]]@netP$pathways, object.list_W6[[i+1]]@netP$pathways)
ht1 = netAnalysis_signalingRole_heatmap(object.list_W6[[i]], pattern = "outgoing", signaling = pathway.union, title = names(object.list_W6)[i], width = 10, height = 18,font.size = 11,font.size.title = 14)
ht2 = netAnalysis_signalingRole_heatmap(object.list_W6[[i+1]], pattern = "outgoing", signaling = pathway.union, title = names(object.list_W6)[i+1], width = 10, height = 18,font.size = 11,font.size.title = 14)
draw(ht1 + ht2, ht_gap = unit(0.5, "cm"))

ht1 = netAnalysis_signalingRole_heatmap(object.list_W6[[i]], pattern = "incoming", signaling = pathway.union, title = names(object.list_W6)[i], width = 10, height = 18, color.heatmap = "GnBu",font.size = 11,font.size.title = 14)
ht2 = netAnalysis_signalingRole_heatmap(object.list_W6[[i+1]], pattern = "incoming", signaling = pathway.union, title = names(object.list_W6)[i+1], width = 10, height = 18, color.heatmap = "GnBu",font.size = 11,font.size.title = 14)
draw(ht1 + ht2, ht_gap = unit(0.5, "cm"))

ht1 = netAnalysis_signalingRole_heatmap(object.list_W6[[i]], pattern = "all", signaling = pathway.union, title = names(object.list_W6)[i], width = 10, height = 18, color.heatmap = "OrRd",font.size = 11,font.size.title = 14)
ht2 = netAnalysis_signalingRole_heatmap(object.list_W6[[i+1]], pattern = "all", signaling = pathway.union, title = names(object.list_W6)[i+1], width = 10, height = 18, color.heatmap = "OrRd",font.size = 11,font.size.title = 14)
draw(ht1 + ht2, ht_gap = unit(0.5, "cm"))

### 4.Identify dysfunctional signaling by comparing the communication probabities ----
netVisual_bubble(cellchat_W6_PvsNP, sources.use = 2, targets.use = c(1,3:17),  comparison = c(1, 2), angle.x = 45)
netVisual_bubble(cellchat_W6_PvsNP, sources.use = 5, targets.use = c(1:4,6:17),  comparison = c(1, 2), angle.x = 45)


gg1 <- netVisual_bubble(cellchat_W6_PvsNP, sources.use = 2, targets.use = c(1,3:17),  comparison = c(1, 2), max.dataset = 2, title.name = "Increased signaling in Progressor Vs Non-Progressor", angle.x = 45, remove.isolate = T)
#> Comparing communications on a merged object
gg2 <- netVisual_bubble(cellchat_W6_PvsNP, sources.use = 2, targets.use = c(1,3:17),  comparison = c(1, 2), max.dataset = 1, title.name = "Decreased signaling in Progressor Vs Non-Progressor", angle.x = 45, remove.isolate = T)
#> Comparing communications on a merged object
gg1 + gg2

gg1 <- netVisual_bubble(cellchat_W6_PvsNP, sources.use = 5, targets.use = c(1:4,6:17),  comparison = c(1, 2), max.dataset = 2, title.name = "Increased signaling in Progressor Vs Non-Progressor", angle.x = 45, remove.isolate = T)
#> Comparing communications on a merged object
gg2 <- netVisual_bubble(cellchat_W6_PvsNP, sources.use = 5, targets.use = c(1:4,6:17),  comparison = c(1, 2), max.dataset = 1, title.name = "Decreased signaling in Progressor Vs Non-Progressor", angle.x = 45, remove.isolate = T)
#> Comparing communications on a merged object
gg1 + gg2

saveRDS(cellchat_W6_PvsNP, file = "cellchat_W6_PvsNP.rds")
cellchat_W6_PvsNP<-readRDS("cellchat_W6_PvsNP.rds")

## Week 12- Progressor vs Non-Progressor ----

W12_NonProgressor <- readRDS("cellChat_W12_NonProgressor.rds")
W12_Progressor <- readRDS("cellChat_W12_Progressor.rds")
object.list_W12 <- list(NonProgressor = W12_NonProgressor, Progressor = W12_Progressor)
cellchat_W12_PvsNP <- mergeCellChat(object.list_W12, add.names = names(object.list_W12))

cellchat_W12_PvsNP

### 1. Identify altered interactions and cell populations ----

gg1 <- compareInteractions(cellchat_W12_PvsNP, show.legend = F, group = c(1,2))
gg2 <- compareInteractions(cellchat_W12_PvsNP, show.legend = F, group = c(1,2), measure = "weight")
gg1 + gg2

par(mfrow = c(1,1), xpd=TRUE)
netVisual_diffInteraction(cellchat_W12_PvsNP, weight.scale = T, measure = "weight")

gg1 <- netVisual_heatmap(cellchat_W12_PvsNP, measure = "weight",font.size = 12, font.size.title = 18)
#> Do heatmap based on a merged object
gg1

num.link <- sapply(object.list_W12, function(x) {rowSums(x@net$count) + colSums(x@net$count)-diag(x@net$count)})
weight.MinMax <- c(min(num.link), max(num.link)) # control the dot size in the different datasets
gg <- list()
for (i in 1:length(object.list_W12)) {
  gg[[i]] <- netAnalysis_signalingRole_scatter(object.list_W12[[i]], title = names(object.list_W12)[i], weight.MinMax = weight.MinMax)+ xlim(0,8) + ylim(0,9)
}
patchwork::wrap_plots(plots = gg)

gg1 <- netAnalysis_signalingChanges_scatter(cellchat_W12_PvsNP, idents.use = "Macrophage")
gg1
#No DC Interactions
# gg2 <- netAnalysis_signalingChanges_scatter(cellchat_W12_PvsNP, idents.use = "Dendritic Cell")
# gg2
gg3 <- netAnalysis_signalingChanges_scatter(cellchat_W12_PvsNP, idents.use = "CD8 exhausted effector-like")
gg3
gg4 <- netAnalysis_signalingChanges_scatter(cellchat_W12_PvsNP, idents.use = "CD8 memory")
gg4
gg5 <- netAnalysis_signalingChanges_scatter(cellchat_W12_PvsNP, idents.use = "Tcon memory")
gg5
gg6 <- netAnalysis_signalingChanges_scatter(cellchat_W12_PvsNP, idents.use = "Tregs")
gg6
gg7 <- netAnalysis_signalingChanges_scatter(cellchat_W12_PvsNP, idents.use = "Tcon exhausted effector-like")
gg7
gg8 <- netAnalysis_signalingChanges_scatter(cellchat_W12_PvsNP, idents.use = "Tcon activated ")
gg8
gg9 <- netAnalysis_signalingChanges_scatter(cellchat_W12_PvsNP, idents.use = "Tcon Interferon Sensing")
gg9
gg10 <- netAnalysis_signalingChanges_scatter(cellchat_W12_PvsNP, idents.use = "NK Cell")
gg10
gg11 <- netAnalysis_signalingChanges_scatter(cellchat_W12_PvsNP, idents.use = "B Cell")
gg11
gg12 <- netAnalysis_signalingChanges_scatter(cellchat_W12_PvsNP, idents.use = "ILC2")
gg12
gg13 <- netAnalysis_signalingChanges_scatter(cellchat_W12_PvsNP, idents.use = "ILC3")
gg13

unique(cellchat_W12_PvsNP@meta$ident)
### 2. Identify altered signaling with distinct interaction strength ----
gg1 <- rankNet(cellchat_W12_PvsNP, mode = "comparison", measure = "weight", sources.use = NULL, targets.use = NULL, stacked = T, do.stat = TRUE)
gg2 <- rankNet(cellchat_W12_PvsNP, mode = "comparison", measure = "weight", sources.use = NULL, targets.use = NULL, stacked = F, do.stat = TRUE)

gg1 + gg2

### 3.Compare outgoing (or incoming) signaling patterns associated with each cell population ----
library(ComplexHeatmap)
i = 1
# combining all the identified signaling pathways from different datasets 
pathway.union <- union(object.list_W12[[i]]@netP$pathways, object.list_W12[[i+1]]@netP$pathways)
ht1 = netAnalysis_signalingRole_heatmap(object.list_W12[[i]], pattern = "outgoing", signaling = pathway.union, title = names(object.list_W12)[i], width = 10, height = 18,font.size = 11,font.size.title = 14)
ht2 = netAnalysis_signalingRole_heatmap(object.list_W12[[i+1]], pattern = "outgoing", signaling = pathway.union, title = names(object.list_W12)[i+1], width = 10, height = 18,font.size = 11,font.size.title = 14)
draw(ht1 + ht2, ht_gap = unit(0.5, "cm"))

ht1 = netAnalysis_signalingRole_heatmap(object.list_W12[[i]], pattern = "incoming", signaling = pathway.union, title = names(object.list_W12)[i], width = 10, height = 18, color.heatmap = "GnBu",font.size = 11,font.size.title = 14)
ht2 = netAnalysis_signalingRole_heatmap(object.list_W12[[i+1]], pattern = "incoming", signaling = pathway.union, title = names(object.list_W12)[i+1], width = 10, height = 18, color.heatmap = "GnBu",font.size = 11,font.size.title = 14)
draw(ht1 + ht2, ht_gap = unit(0.5, "cm"))

ht1 = netAnalysis_signalingRole_heatmap(object.list_W12[[i]], pattern = "all", signaling = pathway.union, title = names(object.list_W12)[i], width = 10, height = 18, color.heatmap = "OrRd",font.size = 11,font.size.title = 14)
ht2 = netAnalysis_signalingRole_heatmap(object.list_W12[[i+1]], pattern = "all", signaling = pathway.union, title = names(object.list_W12)[i+1], width = 10, height = 18, color.heatmap = "OrRd",font.size = 11,font.size.title = 14)
draw(ht1 + ht2, ht_gap = unit(0.5, "cm"))

### 4.Identify dysfunctional signaling by comparing the communication probabities ----
netVisual_bubble(cellchat_W12_PvsNP, sources.use = 2, targets.use = c(1,3:17),  comparison = c(1, 2), angle.x = 45)


gg1 <- netVisual_bubble(cellchat_W12_PvsNP, sources.use = 2, targets.use = c(1,3:17),  comparison = c(1, 2), max.dataset = 2, title.name = "Increased signaling in Progressor Vs Non-Progressor", angle.x = 45, remove.isolate = T)
#> Comparing communications on a merged object
gg2 <- netVisual_bubble(cellchat_W12_PvsNP, sources.use = 2, targets.use = c(1,3:17),  comparison = c(1, 2), max.dataset = 1, title.name = "Decreased signaling in Progressor Vs Non-Progressor", angle.x = 45, remove.isolate = T)
#> Comparing communications on a merged object
gg1 + gg2

gg1 <- netVisual_bubble(cellchat_W12_PvsNP, sources.use = 17, targets.use = c(1:16),  comparison = c(1, 2), max.dataset = 2, title.name = "Increased signaling in Progressor Vs Non-Progressor", angle.x = 45, remove.isolate = T)
#> Comparing communications on a merged object
gg2 <- netVisual_bubble(cellchat_W12_PvsNP, sources.use = 17, targets.use = c(1:16),  comparison = c(1, 2), max.dataset = 1, title.name = "Decreased signaling in Progressor Vs Non-Progressor", angle.x = 45, remove.isolate = T)
#> Comparing communications on a merged object
gg1

saveRDS(cellchat_W12_PvsNP, file = "cellchat_W12_PvsNP.rds")
cellchat_W12_PvsNP<-readRDS("cellchat_W12_PvsNP.rds")