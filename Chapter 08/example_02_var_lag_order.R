# Replicate the code example on VAR lag order selection (pg. 180)

# ==============================================================================
# pre-process data
# ==============================================================================

load("IEA_counts_Example3.RData")

# ==============================================================================
# explore lag order selection
# ==============================================================================

library(vars)

var_model_HQ  <- VAR(IEA_counts_Example3, type = "const", lag.max = 50, ic = "HQ")
var_model_SC  <- VAR(IEA_counts_Example3, type = "const", lag.max = 50, ic = "SC")
var_model_AIC <- VAR(IEA_counts_Example3, type = "const", lag.max = 50, ic = "AIC")
var_model_FPE <- VAR(IEA_counts_Example3, type = "const", lag.max = 50, ic = "FPE")

var_model_HQ$p
var_model_SC$p
var_model_AIC$p
var_model_FPE$p

c(var_model_HQ$p, var_model_SC$p, var_model_AIC$p, var_model_FPE$p)
