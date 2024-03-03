# Replicate first code example in Section 8.5.2 Dynamic Linear Models

# ==============================================================================
# load data
# ==============================================================================

load("IEA_counts_Example1.RData")
dlm_data <- IEA_counts_Example1[, 1]

# ==============================================================================
# Create DLM object (pg. 189)
# ==============================================================================

library(dlm)
my_dlm <- dlmModPoly(order = 1, dV = 1, dW = 1)

# ==============================================================================
# run Kalman Filter and Smoother (pg. 190)
# ==============================================================================

my_filter = dlmFilter(dlm_data, my_dlm)
my_smoother = dlmSmooth(dlm_data, my_dlm)

head(my_filter$m)
head(my_smoother$s)