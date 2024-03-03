# Replicate Figure 8.7 on pg. 186

# ==============================================================================
# load data
# ==============================================================================

load("IEA_counts_Example1.RData")

dlm_data <- IEA_counts_Example1[, 1]

# ==============================================================================
# Compute MLE of variance parameters in DLM (pg. 190)
# ==============================================================================

library(dlm)

dlm_build <- function(parm){
  dlmModPoly(order = 1, dV = 1, dW = exp(parm[1]))
}

mle = dlmMLE(dlm_data, parm = 0, build = dlm_build)
estimated_dlm = dlm_build(mle$par)

# ==============================================================================
# run Kalman Filter and Smoother
# ==============================================================================

filter_output = dlmFilter(dlm_data, estimated_dlm)
smoother_output = dlmSmooth(dlm_data, estimated_dlm)

# ==============================================================================
# plot data, filtered means, and smoothed means
# ==============================================================================

par(mfrow = c(1, 1), mar = c(2, 2, 1, 1))

T = nrow(IEA_counts_Example1)

plot(1:T, dlm_data, type = "l", lwd = 0.75, xlab = "", ylab = "", main = "")
lines(1:T, filter_output$m[2:(T + 1)], col = "black", lwd = 2)
lines(1:T, smoother_output$s[2:(T + 1)], col = "blue", lwd = 2)

legend("topleft", 
       legend = c("data", "filtered mean", "smoothed mean"), 
       lty = c(1, 1), 
       col = c("black", "black", "blue"), 
       bty = "n", 
       lwd = c(0.75, 2, 2), 
       cex = 1.25)