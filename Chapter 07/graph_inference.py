"""
Functions for measuring graph edges in a time-series based functional network

Created by: Ankit Khambhati

2023-03-30
"""

import numpy as np

def xcorr_full(signal, fs, tau_min=0, tau_max=None):
    """
    Compute cross-correlation function between all pairs of graph nodes.

    Parameters
    ----------
    signal: numpy.ndarray, shape: [n_sample x n_node]
        Multivariate time-series signal across nodes.

    fs: float
        Sampling frequency of the signal.

    Returns
    -------
    xcr_matr: numpy.ndarray, shape: [n_lag x n_node x n_node]
        Cross-correlation adjacency matrix between all node pairs.

    lags: numpy.ndarray, shape:[n_lag]
        Lags at which cross-correlation is computed.
    """

    # Get data attributes
    n_samp, n_node = signal.shape

    # Normalize the signal
    signal -= signal.mean(axis=0)
    signal /= signal.std(axis=0)

    # Initialize adjacency matrix
    lags = np.hstack((range(0, n_samp, 1),
                      range(-n_samp, 0, 1))) / fs
    adj = np.zeros((len(lags), n_node, n_node))

    # Use FFT to compute cross-correlation
    sig_fft = np.fft.rfft(
        np.vstack((signal, np.zeros_like(signal))),
        axis=0)

    # Iterate over all edges
    for n1 in range(n_node):
        for n2 in range(n_node):
            if n1 == n2:
                xc = 0
            else:
                xc = 1 / n_samp * np.fft.irfft(
                    sig_fft[:, n1] * np.conj(sig_fft[:, n2]), axis=0)
            adj[:, n1, n2] = np.abs(xc)

    # Unwrap
    adj = adj[np.argsort(lags)]
    lags = np.sort(lags)
    
    return adj, lags

def xcorr_full_to_adj(xcr_matr, lags, tau_cut=(0, np.inf)):
    """
    Compute inter-electrode cross-correlation of the iEEG signal.

    XC = max(abs(xcorr(x1, x2)))
    delay = argmax(abs(xcorr(x1, x2)))

    Parameters
    ----------
    xcr_matr: numpy.ndarray, shape: [n_lag x n_node x n_node]
        Cross-correlation adjacency matrix between all node pairs.

    lags: numpy.ndarray, shape:[n_lag]
        Lags at which cross-correlation is computed.

    tau_cut: tuple, shape: [2]
        Shortest and longest latencies to consider in the
        cross-correlation window estimate

    Returns
    -------
    adj_matr: numpy.ndarray, shape: [n_chan x n_chan]
        Peak magnitude cross-correlation between channels per frequency.
    """

    # Get data attributes
    tau_ix = np.flatnonzero((np.abs(lags) >= tau_cut[0]) &
                            (np.abs(lags) <= tau_cut[1]))

    # Unwrap
    adj_matr = np.max(np.abs(xcr_matr[tau_ix]), axis=0)
    
    return adj_matr