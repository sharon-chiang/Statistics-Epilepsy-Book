# Replicate the code examples in Section 8.4.1 Vector Autoregressive Models

# ==============================================================================
# load data
# ==============================================================================

load("IEA_counts_Example2.RData")

# ==============================================================================
# Basic  OLS fit (pg. 178)
# ==============================================================================

library(vars)
my_var_model <- VAR(IEA_counts_Example2, p = 2, type = "const")

summary(my_var_model)

# ==============================================================================
# Basic Bayes fit (pg. 178 - 179)
# ==============================================================================

library(BVAR)
set.seed(8675309)
my_bvar_model <- bvar(IEA_counts_Example2, lags = 2)

summary(my_bvar_model)

# ==============================================================================
# Generate predictions (pg. 181)
# ==============================================================================

horizon <- 30
var_fcast <- predict(my_var_model, n.ahead = horizon)
bvar_fcast <- predict(my_bvar_model,
                      horizon = horizon,
                      conf_bands = (1 - seq(0.1, 0.9, 0.1)) / 2)

# ==============================================================================
# Generate fan charts (Figure 8.4 on pg. 182)
# ==============================================================================

T = nrow(IEA_counts_Example2)
fanchart(var_fcast, nc = 2,
         xlim = c(T - 50, T + horizon),
         cis = seq(0.1, 0.9, 0.1))
plot(bvar_fcast, t_back = 50, orientation = 'h', area = TRUE)

# ==============================================================================
# Basic Granger test (pg. 183)
# ==============================================================================

my_test <- causality(my_var_model, cause = "y")
my_test$Granger
