# Replicate code examples in 8.6 Circular Data Analysis

# ==============================================================================
# load packages
# ==============================================================================

library(circular)

# ==============================================================================
# simulate synthetic data
# ==============================================================================

set.seed(8675309)

n = 150
x = rvonmises(n, mu = 1.25 * pi, kappa = 1.5)
a = as.vector(x)

# ==============================================================================
# plot circular datapoints (code on pg. 194; panel 1 of Figure 8.9)
# ==============================================================================

par(mar = c(2, 2, 4, 2), cex.main = 2)

plot.circular(x, col = rgb(1, 0, 0, 0.5), main = "Circular datapoints",
              cex = 1.5)

# ==============================================================================
# plot linear histogram (panel 2 of Figure 8.9)
# ==============================================================================

par(mar = c(4.1, 4.25, 4, 2), cex.main = 2)

hist(a, xlim = c(0, 2*pi), breaks = "Scott", freq = FALSE,
     xlab = "radians", main = "Linear histogram of angles",
     col = rgb(1, 0, 0, 0.5), xaxt = "n", cex.lab = 1.5, cex.axis = 1.5)
axis(1, at = c(0, pi/2, pi, 3*pi/2, 2*pi), cex.axis = 1.5, cex.lab = 1.75,
     labels = c("0", expression(pi / 2), expression(pi), expression(3*pi/2), expression(2*pi)))

# ==============================================================================
# plot circular histogram (code on pg. 194; panel 3 of Figure 8.9)
# ==============================================================================

par(mar = c(2, 2, 4, 2), cex.main = 2)

windrose(x, rep(1, n), fill.col = rgb(1, 0, 0, 0.5),
         main = "Circular histogram", cir.ind = 0.1,
         xlim = c(-1.5, 1.5), ylim = c(-1.5, 1.5),
         tol = 0)

# ==============================================================================
# plot mean resultant length (panel 4 of Figure 8.9)
# ==============================================================================

U = cbind(cos(a), sin(a))
v = colMeans(U)
l = rho.circular(x)

par(mar = c(1, 1, 4, 1), cex.main = 2)

plot.circular(l, col = rgb(0, 0, 0, 0), cex = 1.5,
              main = paste("Mean resultant vector (length = ",
                           round(l, digits = 3), ")", sep = "")
              )
arrows(0, 0, x1 = v[1], y1 = v[2], col = rgb(1, 0, 0, 1), lwd = 2)

# ==============================================================================
# Calculate magnitude of mean resultant vector (phase-locking value) (pg. 195)
# ==============================================================================

l = rho.circular(x)

# ==============================================================================
# Rayleigh test of uniformity (pg. 195)
# ==============================================================================

rayleigh.test(x)