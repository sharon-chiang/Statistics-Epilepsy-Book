# Replicate code example of fitting a time-varying parameter regression (pg. 190)

# ==============================================================================
# load data
# ==============================================================================

load("IEA_counts_Example1.RData")

x <- IEA_counts_Example1$x
y <- IEA_counts_Example1$y

# ==============================================================================
# create dynamic regression object
# ==============================================================================

my_dynamic_reg = dlmModReg(x, addInt = TRUE, dV = 1, dW = 0.1 * c(1, 1))

# ==============================================================================
# run Kalman Smoother
# ==============================================================================

my_reg_smoother = dlmSmooth(y, my_dynamic_reg)

head(my_reg_smoother$s)