# Replicate the code example in Section 8.4.2 Vector Autoregressive Moving Average Models

# ==============================================================================
# load data
# ==============================================================================

load("IEA_counts_Example1.RData")

# ==============================================================================
# fit VARMA(1, 1) (pg. 184 - 185)
# ==============================================================================

library(MTS)
my_varma_model <- VARMA(IEA_counts_Example1, p = 1, q = 1)