# illustrate the connection between ARMA models and DLMs. That is, to fit an 
# ARMA model, we rewrite it as a DLM and use the Kalman filter to evaluate the 
# likelihood function. 

# ==============================================================================
# load data
# ==============================================================================

load("IEA_counts_Example3.RData")

# ==============================================================================
# fit ARMA(1, 1) with `arima`
# ==============================================================================

my_arma = arima(IEA_counts_Example3[, 1], order = c(1,0,1), 
                include.mean = FALSE, transform.pars = FALSE, method = "ML")

my_arma$coef

# ==============================================================================
# fit ARMA(1, 1) with `dlm`
# ==============================================================================

library(dlm)

my_ARMA_dlm <- function(parm){
  dlmModARMA(ar = parm[1], ma = parm[2], sigma2 = parm[3])
}

mle = dlmMLE(IEA_counts_Example3[, 1], parm = c(0, 0, 1), build = my_ARMA_dlm)

mle$par