##
## Chapter 9. Spectral Analysis of Electrophysiological Data
## Authors: Marco Pinto-Orellana, Hernando Ombao
## This source code is provided under the LGPL License 2.1
##

# Minimal required libraries:
# install.packages(c("ggplot", "signal", "oce", "wavethresh", "RSEIS"))
library(signal)
library(oce) # We will need this library to estimate Welch's spectrum


###################################################################################################
# Additional functions
#
# First, we will also use define additional helper functions for simulating EEGs:
# Ombao, H., & Pinto, M. (2022). Spectral dependence. Econometrics and Statistics.
# https://doi.org/10.1016/j.ecosta.2022.10.005


# We will use a function to simulate unstable oscillators, i.e, signals with pseudo-oscillatory
#  patterns around a specific frequency.
# (This procedure is borrowed from the "ecosta-spectral-dependence" package)
simulate_unstable_oscillator <- function(N, f, tau=1, fs=200, sigma=1, rescale=TRUE) {
  stopifnot(f < 0.5 * fs)
  stopifnot(tau >= 0)
  stopifnot(sigma > 0)
  phi_1 <- 2 / (1 + exp(-tau)) * cos(2 * pi * f / fs)
  phi_2 <- -1 / (1 + exp(-tau)) ^ 2
  y <- as.numeric(arima.sim(model=list(ar=c(phi_1, phi_2)), n=N, sd=if(rescale) 1 else sigma))
  (y - mean(y)) * (if(rescale) sigma / sd(y) else 1)
}
# Alternatively, we can load the original code (LGPL-licensed):
# source("https://raw.githubusercontent.com/biostatistics-kaust/ecosta-spectral-dependence/main/ECOSTASpecDepRef/R/simulate_unstable_oscillator.R")


# Then, we also will use a procedure to simulate EEGs as a sum of these unstable oscillators:
# (This procedure is borrowed from the "ecosta-spectral-dependence" package)
simulate_EEG <- function(N, fs=200, f=c(0,2,4,10,20,34,45), tau=c(1,1,1,1,1,1,1), sigma=c(1,1,1,1,1,1,1), electrical_line=NULL) {
  stopifnot(all(f < 0.5 * fs))
  stopifnot(all(tau >= 0))
  stopifnot(all(sigma > 0))
  stopifnot(is.null(electrical_line) || electrical_line > 40)
  stopifnot(length(f) == length(tau) && length(tau) == length(sigma))
  y <- 0
  for(i in 1:length(f)){
    y <- y + simulate_unstable_oscillator(N, f=f[i], tau=tau[i], sigma=sigma[i], fs=fs)
  }
  if(!is.null(electrical_line)){
    y <- y + simulate_unstable_oscillator(N, f=electrical_line, tau=10, sigma=0.5*mean(sigma))
  }
  y
}
# Alternatively, we can load the original code (LGPL-licensed):
# source("https://raw.githubusercontent.com/biostatistics-kaust/ecosta-spectral-dependence/main/ECOSTASpecDepRef/R/simulate_eeg.R")


# We will also use a band-pass filter helper function: 
simple_bandpass_filter = function(y, freqs, fs, order=100, causal=FALSE){
  coeffs_low <- signal::fir1(order, freqs/(0.5 * fs), type="pass")
  if(causal)
    y_filtered <- as.numeric(signal::filter(coeffs_low, y))
  else
    y_filtered <- as.numeric(signal::filtfilt(coeffs_low, y))
  y_filtered
}


###################################################################################################
# Spectral-Encoded Information in EEG
# Section 9.2

# Let's start by simulating a two-second EEG signal at 120Hz:
fs = 120
N = fs * 2
time = (1:N) / fs;
y_sample_eeg = simulate_EEG(N, fs);
# Plot the time series
plot(y_sample_eeg, type="l")

# Plot the spectrum (using a periodogram)
spec = spectrum(y_sample_eeg, method="pgram", plot=TRUE, spans = c(7,7));

# Now, let's decompose it in the five main oscillatory components (rhythms):
# * Delta band (0-4Hz)
y_delta = simple_bandpass_filter(y_sample_eeg, c(0, 4), fs);
# * Theta band (4-8Hz)
y_theta = simple_bandpass_filter(y_sample_eeg, c(4, 8), fs);
# * Alpha band (8-12Hz)
y_alpha = simple_bandpass_filter(y_sample_eeg, c(8, 12), fs);
# * Beta band (0-4Hz)
y_beta = simple_bandpass_filter(y_sample_eeg, c(12, 30), fs);
# * Gamma band (0-4Hz)
y_gamma = simple_bandpass_filter(y_sample_eeg, c(30, 50), fs);

# Now, we can plot them in the time domain
par(mfrow = c(3, 2)) # Create a new window with 6 subplots in 2 columns
plot(y_sample_eeg, type="l", main="Entire signal")
plot(y_delta, type="l", main="Delta component")
plot(y_theta, type="l", main="Theta component")
plot(y_alpha, type="l", main="Alpha component")
plot(y_beta, type="l", main="Beta component")
plot(y_gamma, type="l", main="Gamma component")

# Plot the spectrum of each component
par(mfrow = c(3, 2)) # Create a new window with 6 subplots in 2 columns
spec_entire = spectrum(y_sample_eeg, method="pgram", plot=TRUE, spans = c(7,7), main="Entire signal");
spec_delta = spectrum(y_delta, method="pgram", plot=TRUE, spans = c(7,7), main="Delta component");
spec_theta = spectrum(y_theta, method="pgram", plot=TRUE, spans = c(7,7), main="Theta component");
spec_alpha = spectrum(y_alpha, method="pgram", plot=TRUE, spans = c(7,7), main="Alpha component");
spec_beta = spectrum(y_beta, method="pgram", plot=TRUE, spans = c(7,7), main="Beta component");
spec_gamma = spectrum(y_gamma, method="pgram", plot=TRUE, spans = c(7,7), main="Gamma component");
# Note that the domain in the previous plots is 0 to 0.5

# Let's create time series of the signals, 
# to keep the sampling frequency information
ts_sample_eeg <- ts(y_sample_eeg, frequency=fs);
ts_delta <- ts(y_delta, frequency=fs);
ts_theta <- ts(y_theta, frequency=fs);
ts_alpha <- ts(y_alpha, frequency=fs);
ts_beta <- ts(y_beta, frequency=fs);
ts_gamma <- ts(y_gamma, frequency=fs);

# Let's plot again the spectrum
par(mfrow = c(3, 2)) # Create a new window with 6 subplots in 2 columns
spec_entire = spectrum(ts_sample_eeg, method="pgram", plot=TRUE, spans = c(7,7), main="Entire signal");
spec_delta = spectrum(ts_delta, method="pgram", plot=TRUE, spans = c(7,7), main="Delta component");
spec_theta = spectrum(ts_theta, method="pgram", plot=TRUE, spans = c(7,7), main="Theta component");
spec_alpha = spectrum(ts_alpha, method="pgram", plot=TRUE, spans = c(7,7), main="Alpha component");
spec_beta = spectrum(ts_beta, method="pgram", plot=TRUE, spans = c(7,7), main="Beta component");
spec_gamma = spectrum(ts_gamma, method="pgram", plot=TRUE, spans = c(7,7), main="Gamma component");

par(mfrow = c(1, 1)) # restore the subplot configuration

###################################################################################################
# Deterministic and Nondeterministic Spectrum
# Section 9.3

# Example 9.3.1
set.seed(100);
time_series_length = 300
central_frequency = 10 # In Hertz
fs = 100 # In Hertz
# Create a vector of frequencies from 0 to fs/2
w = seq(0, fs/2, length.out=time_series_length/2);
# Then, we adjust the bandwith of the unstable oscillator:
tau = 2
phi_1 <- 2 / (1 + exp(-tau)) * cos(2 * pi * central_frequency / fs)
phi_2 <- -1 / (1 + exp(-tau)) ^ 2
# If tau=2, we expect (phi_1, phi_2) be c(1.425, -0.776)
print(c(phi_1, phi_2))
# This is the (theoretical) power spectrum density
theoretical_psd = 1 / abs(1 - phi_1 * exp(-1i * 2 * pi * w / fs) - phi_2 * exp(-2i * 2 * pi * w / fs)) ^ 2;

# Now, let us simulate 10 cases of our system
simulations_in_psd_estimation = 10
# For each one, we will save the time series
esd_samples= matrix(nrow=simulations_in_psd_estimation, ncol=time_series_length/2);
# and the energy spectrum density (ESD)
signal_samples = matrix(nrow=simulations_in_psd_estimation, ncol=time_series_length);
for(k in 1:simulations_in_psd_estimation){
  signal_samples[k,] = simulate_unstable_oscillator(time_series_length, f=central_frequency, tau=tau, fs=fs, sigma=1, rescale=FALSE);
  esd_samples[k,] = spectrum(signal_samples[k,], method="pgram", plot=FALSE)$spec; # Store the spectrum values without plotting 
}

# Let's plot the first and third samples:
par(mfrow = c(2, 2)) # create a new window with 4 subplots in 2 columns
plot(signal_samples[1, ], type="l", main="Time series (sample 1)")
plot(esd_samples[1, ], type="l", main="ESD (sample 1)")
plot(signal_samples[3, ], type="l", main="Time series (sample 3)")
plot(esd_samples[3, ], type="l", main="ESD (sample 3)")

# Calculate the average ESD across our simulations:
esd_average = apply(esd_samples, 2, mean);
# Let's plot the third simulation as a sample case, along with the average ESD and PSD
par(mfrow = c(1, 3)) # create a new window with 3 subplots
plot(esd_samples[3, ], type="l", main="ESD (sample 3)")
plot(esd_average, type="l", main="Average ESD")
plot(theoretical_psd, type="l", main="PSD")
#
par(mfrow = c(1, 1)) # restore the subplot configuration


###################################################################################################
# Digital Linear Filters
# Section 9.4
library(signal) # We will use several functions in this library

# Recall that a signal can be viewed as a linear combination of oscillations
fs = 100 # In Hertz
N = fs * 2
t = (1:N) / fs;

# Let us create three signals with frequencies 6Hz, 10Hz and 20Hz, respectively:
y_6Hz = cos(2*pi*t*6);
y_10Hz = 10*sin(2*pi*t*10);
y_20Hz = sin(2*pi*t*20);

# Then, create a signal that will be the sum of both oscillatory components:
y = y_6Hz + y_10Hz + y_20Hz;
plot(t, y, type="l")

# Now, we want to extract only the components between 4Hz and 8Hz.
# A) We can implement a band-pass filter using a fourth-order Butterworth (IIR) filter.
#    In R, we can use the "butter" method in the signal package:
filter_coeffs <- signal::butter(4, c(4, 8)/(0.5 * fs), type="pass")

#    Then, we can apply the coefficients of this filter using a
#   * One-sided (or causal) filter:
y_filtered_one_sided <- as.numeric(signal::filter(filter_coeffs, y))
plot(y_filtered_one_sided, type="l")
#   * Two-sided (or non-causal) filter:
y_filtered_two_sided <- as.numeric(signal::filtfilt(filter_coeffs, y))
plot(y_filtered_two_sided, type="l")

# B) Alternatively, we can create a 100-th FIR filter using the "fir1" method in the 
#    same package
filter_coeffs <- signal::fir1(100, c(4, 8)/(0.5 * fs), type="pass")
#    Similarly, we can use "filter" and "filtfilt"
y_filtered_one_sided <- as.numeric(signal::filter(filter_coeffs, y)) # One-sided filter
plot(y_filtered_one_sided, type="l")
y_filtered_two_sided <- as.numeric(signal::filtfilt(filter_coeffs, y)) # Two-sided filter
plot(y_filtered_two_sided, type="l")

###################################################################################################
# Univariate Stationary Spectrum
# Section 9.5
library(oce) # We will need this library to estimate Welch's spectrum

# Let us simulate a 4-second segment of an EEG recording with a sample rate of 128 Hz:
fs <- 128
N <- fs * 4
y_sample_eeg <- simulate_EEG(N, fs);
plot(y_sample_eeg)

# Compare the spectrum estimators obtained using a
# A) Periodogram
spec_pgram <- spectrum(y_sample_eeg, method="pgram", plot=TRUE)
# B) Welch's spectrum 
spec_welch <- pwelch(y_sample_eeg, plot=TRUE)
# C) 20th-order autoregressive model
spec_ar <- spectrum(y_sample_eeg, method="ar", order=20, plot=TRUE)

#  Note that the spectrum of the three methods had a domain from 0 to 0.5.
#  We would like to have the spectrum plotted from 0 to 0.5*fs (64Hz).
#  To do it, we can use the "ts" method to create a time series object
#   with our desired sampling frequency:
spec_welch <- pwelch(ts(y_sample_eeg, frequency=fs), plot=TRUE)
spec_pgram <- spectrum(ts(y_sample_eeg, frequency=fs), method="pgram", plot=TRUE)
spec_ar <- spectrum(ts(y_sample_eeg, frequency=fs), method="ar", order=20, plot=TRUE)


# Now, let us test the spectral parametrization of AR(2) models:
N <- 1024;
fs <- 128;
central_frequency <- 10; #In Hertz
y_wider <- simulate_unstable_oscillator(N, f=central_frequency, tau=0.2, fs=fs, sigma=1);
y_middle <- simulate_unstable_oscillator(N, f=central_frequency, tau=2.0, fs=fs, sigma=1);
y_narrow <- simulate_unstable_oscillator(N, f=central_frequency, tau=4.0, fs=fs, sigma=1);

par(mfrow = c(2, 3)) # create a new window with 6 subplots
plot(y_wider, type="l", main="SAR(f0=10, tau=0.2)")
plot(y_middle, type="l", main="SAR(f0=10, tau=2.0)")
plot(y_narrow, type="l", main="SAR(f0=10, tau=4.0)")

spectrum(ts(y_wider, frequency=fs), method="pgram", main="SAR(f0=10, tau=0.2)", log="no")
spectrum(ts(y_middle, frequency=fs), method="pgram", main="SAR(f0=10, tau=2.0)", log="no")
spectrum(ts(y_narrow, frequency=fs), method="pgram", main="SAR(f0=10, tau=4.0)", log="no")

par(mfrow = c(1, 1)) # restore the subplot configuration

###################################################################################################
# Univariate Nonstationary Spectrum
# Section 9.6
library(wavethresh) # Contains kernel plotting functions
library(RSEIS) #Provides STFT and Wavelet functions

## Wavelet spectrum
## Section 9.6.2

# Recall that wavelets can influence the signal decomposition. 
# A) Second-order Daubechies wavelet
order = 2;
family = "DaubExPhase";
#    Plot the mother wavelet
draw.default(filter.number=order, family=family, scaling.function=FALSE);
#    Plot the scaling function
draw.default(filter.number=order, family=family, scaling.function=TRUE);

# B) Sixth-order Daubechies wavelet
order = 6;
family = "DaubExPhase";
#    Plot the mother wavelet
draw.default(filter.number=order, family=family, scaling.function=FALSE);
#    Plot the scaling function
draw.default(filter.number=order, family=family, scaling.function=TRUE);

## Smooth localized complex exponential (SLEX) functions
## Section 9.6.3

# We will plot the SLEX window functions $\Psi_{+}(t)$, $\Psi_{-}(t)$ 
#  for $a_0=32,a_1=64,\epsilon=8$ and the SLEX basis 
#  $\psi_{\omega}(t)$ for $\omega=0.1$

# First, we need to load some additional functions for SLEX:
source("https://git.sr.ht/~mpinto/slex-polyglot-implementation/blob/main/R/slex_functions.R");

get_slex_windows_basis = function(f, fs, block_size=48, n_overlap_points=8){
  N = block_size + 2 * n_overlap_points; 
  windows = taper_function(0, block_size, n_overlap_points, N + 1, 1); 
  windows = windows$b_plus + 1i * windows$b_minus;
  C = exp(2i * pi * f * (1:N - 1) / fs)
  phi = Re(windows) * C + Im(windows) * Conj(C);
  list(window=windows, phi=phi, N=N);
}
fs = 10;
f = 1;
n_overlap_points = 8;
block_size = 48;
windows_basis = get_slex_windows_basis(f=f, fs=fs, block_size=block_size, n_overlap_points=n_overlap_points) 
t = (1:windows_basis$N - 1) / fs

par(mfrow = c(1, 2)) # create two-column plot
plot(t, Re(windows_basis$window), type="l", main="window plus psi+(t)")
plot(t, Im(windows_basis$window), type="l", main="window minus psi-(t)")

par(mfrow = c(1, 1)) # restore the subplot configuration


# Now, we need to load some additional functions for DASAR:
source("https://git.sr.ht/~mpinto/dasar-polyglot-implementation/blob/main/R/dasar_functions.R");

## Comparison of STFT, wavelets, 
##  SLEX, and DASAR

fs = 32;
N = 4*fs;
# Let w(t) be a time varying-frequency such that
#   w(t) = 10 for t in [0, 4)
#   w(t) = 4 for t in [4, 8)
#   w(t) = 0.5 for t in [8, 12)
#   w(t) = 3 for t in [12, 16)
w = c(rep(10, length=N), rep(4, length=N), rep(0.5, length=N), rep(2, length=N));
# Let x(t) be a time series which frequency will be controlled by w(t) 
y = sin(2*pi*t*w) + rnorm(16*fs, sd=0.5);

# STFT scalogram
stft_out <- evolfft(y, dt=1/fs , Nfft=128, Ns=128, Nov=64, fl=1, fh=fs/2);
plotevol(stft_out)

# Wavelet spectrogram
wavelet_out <- wlet.do(y, dt=1/fs, noctave = 6, nvoice = 20, flip = TRUE);

# SLEX spectrogram
slex_out <- slex_spectrogram(y, fs=fs, block_size=64, plot=TRUE);

# DASAR spectrogram
dasar_out <- dasar_spectrogram(y, fs, levels=4, maximum_components=5, plot=TRUE);





