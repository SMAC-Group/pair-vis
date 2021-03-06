library(shiny)
library(readxl)
library(magrittr)
library(NetCluster)
library(factoextra)
library(cluster)
library(clues)
library(igraph)
library(edgebundleR)

# choose from 1-9
n_clusters = 2
# choose from 0-1
tension = 0.5

# Specified Dataset 
path = "dataset/clean_small.xlsx"
name_path = "dataset/names.xlsx"

read_file = function(path, columns = c(1,2)){
  df = read_excel(path)[,columns]
  genes = df %>% sapply(trimws)
  return(genes)
}

# Extract Numeric Pairs 
gene_file = read_file(path, c(1,2)) %>% na.omit 
genes = apply(gene_file, 2, function(x) gsub("[^0-9]", "", x))

# Get Gene File and Names
gene_file = read_file(name_path) %>% na.omit 
gene_names = gene_file[,2] %>% gsub(" |EN.*", "", .)
names(gene_names) = gene_file[,1]

# Replace Numbers with the Gene Names
genes = apply(genes, 2, function(x) gene_names[x])

# Get Unique Genes 
unique_genes = genes %>% c %>% unlist %>% unique
mat_rows = nrow(genes)


# Initialize Adjacency Matrix 
n = length(unique_genes)
adj_mat = diag(1, n, n)
dimnames(adj_mat) = list(unique_genes, unique_genes)

for(i in seq_len(n)){ # create adjacency matrix 
  adj_mat[genes[,1][i], genes[,2][i]] =  1
  adj_mat[genes[,2][i], genes[,1][i]] =  1
}

# Clustering algorithm 
adj_mat_cor = cor(adj_mat)
dissimilarity = 1 - adj_mat_cor
adj_mat_dist = as.dist(dissimilarity)
adj_mat_hclust = hclust(adj_mat_dist)

# Manually choose number of clusters                           
locations = cutree(adj_mat_hclust, k=n_clusters)

# Create object that makes igraph structure 
obj = structure(list(ID = unique_genes, 
                     Loc = locations), 
                .Names = c("ID", "Loc"), 
                class = "data.frame",
                row.names = c(NA, -n) 
)

obj$key = obj$ID
obj$ID = paste0(obj$Loc,".",obj$ID)
add_on = locations[genes %>% c %>% unlist]
genes_addon = genes %>% c %>% unlist %>% paste0(add_on, ".", .)
rel = data.frame(V1 = genes_addon[1:mat_rows], V2 = genes_addon[(mat_rows+1):(mat_rows*2)])
g = graph.data.frame(rel, directed = F, vertices = obj)
V(g)$size = centralization.degree(g)$res

# Fix wrongly clustered elements 
deg_1 = V(g)[centralization.degree(g)$res==1]
all_adj = adjacent_vertices(g, V(g))
deg_1_idx = which(centralization.degree(g)$res==1)
deg_1_vertex = all_adj[deg_1_idx]

a = sapply(deg_1_vertex, function(x) gsub("\\..*", "", x$name))

for (i in seq_along(deg_1_idx)){
  g = set.vertex.attribute(g, "name", index = deg_1_idx[i], value = gsub("^[0-9]{1}", a[i], names(a)[i]))
}

# First order them by the number of clusters 
vecs = names(V(g))
gsub("\\..*","",vecs) %>% as.numeric %>% order -> move
names(move) = seq_along(move)
bynum = order(move)
g = permute(g, bynum)

# Seperate vertices into seperate lists 
vecs2 = centralization.degree(g)$res
names(vecs2) = names(V(g))
gsub("\\..*","",names(vecs2)) %>% as.numeric %>% as.factor -> splitline

vecs_list = split(vecs2, splitline)

# Essentially create a tent, where center of cluster has largest degrees 

# from http://stackoverflow.com/questions/30151676/sort-a-vector-where-the-largest-is-at-the-center-in-r
makeTent = function(ints) {
  ints_o = ints[order(ints)]
  if((length(ints) %% 2) == 0) {
    # even number of observations
    ints_tent = c((ints_o[seq.int(from = 1, to = (length(ints) - 1), by = 2)]),
                  rev(ints_o[seq.int(from = 2, to = length(ints), by = 2)]))
  } else {
    # odd number of observations
    ints_tent = c((ints_o[seq.int(from = 2, to = (length(ints) - 1), by = 2)]),
                  rev(ints_o[seq.int(from = 1, to = length(ints), by = 2)]))
  }
  return(ints_tent)
}

# Perform ordering 
names(vecs_list) = NULL
a = lapply(vecs_list, makeTent) %>% unlist
a = names(a)

b = names(move) %>% as.numeric
names(b) = names(vecs2)

c = b[a]
names(c) = seq_along(vecs)
bynum2 = order(c)

# Permute to final graph
g = permute(g, bynum2)


for (i in seq_along(vecs)){
  g = set.vertex.attribute(g, "name", index = seq_along(vecs)[i], value = gsub("^[0-9]{1}", 1, names(V(g)[i])))
}


edgebundle(g, tension = tension, fontsize = 14)
