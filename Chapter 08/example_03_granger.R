# Replicate the code example on inferring Granger causality by using the LASSO
# to produce sparse estimate of VAR coefficients (pg. 183 - 184)

# ==============================================================================
# load data
# ==============================================================================

load("IEA_counts_Example4.RData")

# ==============================================================================
# LASSO fit for VAR (pg. 183 - 184)
# ==============================================================================

library(BigVAR)
mymodel <- constructModel(as.matrix(IEA_counts_Example4), p = 3, 
                          struct = "Basic", 
                          cv = "Rolling", gran = c(150, 150))
results <- cv.BigVAR(mymodel)

# ==============================================================================
# plot sparsity pattern (Figure 8.5 on pg. 184)
# ==============================================================================

par(mar = c(1, 1, 4, 1))
SparsityPlot.BigVAR.results(results)
