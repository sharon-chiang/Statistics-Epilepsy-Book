# Replicate code examples in Section 8.5.3 Hidden Markov Models

# ==============================================================================
# load data
# ==============================================================================

load("IEA_counts_Example1.RData")

# ==============================================================================
# Fit two-state Gaussian HMM (pg. 192)
# ==============================================================================

library(depmixS4)
y <- IEA_counts_Example1$y
hmm <- depmix(y ~ 1, nstates = 2, ntimes = length(y), family = gaussian())
fit_hmm <- fit(hmm)

# ==============================================================================
# Viterbi decoding (pg. 192)
# ==============================================================================

viterbi(fit_hmm)
identical(viterbi(fit_hmm), fit_hmm@posterior)