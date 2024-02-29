"""
Functions for transforming matrix representations of a graph.

Created by: Ankit Khambhati

2023-03-30
"""

import numpy as np

def adj_to_cfg(adj_matr):
    """
    Convert adjacency matrix (or tensor) to a vectorized representation.

    Parameters
    ----------
    adj_matr: numpy.ndarray, shape: [: x ... x : x n_node x n_node]
        Adjacency tensor where the last two axes correspond to the number
        of nodes in the network. 

    Returns
    -------
    cfg_matr: numpy.ndarray, shape: [: x ... x : x n_conn]
        Unraveled adjacency matrix where the last axis is the number of unique node pairs
        or connections in the network.
        
    undirected: bool
        Specifies whether the graph is undirected (True) or directed (False).        
    """
    
    # Check if graph is symmetry (undirected)
    if (adj_matr == np.swapaxes(adj_matr, -1, -2)).all():
        undirected = True
        triu_ix, triu_iy = np.triu_indices(adj_matr.shape[-1], k=1)
        return adj_matr[..., triu_ix, triu_iy], undirected
    else:
        undirected = False
        triu_ix, triu_iy = np.triu_indices(adj_matr.shape[-1], k=1)
        tril_ix, tril_iy = np.tril_indices(adj_matr.shape[-1], k=-1)
        return np.concatenate([adj_matr[..., triu_ix, triu_iy],
                               adj_matr[..., tril_ix, tril_iy]], axis=1), undirected

    
def cfg_to_adj(cfg_matr, undirected):
    """
    Convert adjacency matrix (or tensor) to a vectorized representation.

    Parameters
    ----------
    cfg_matr: numpy.ndarray, shape: [: x ... x : x n_conn]
        Unraveled adjacency matrix where the last axis is the number of unique node pairs
        or connections in the network.
        
    undirected: bool
        Specifies whether the graph is undirected (True) or directed (False). 

    Returns
    -------
    adj_matr: numpy.ndarray, shape: [: x ... x : x n_node x n_node]
        Adjacency tensor where the last two axes correspond to the number
        of nodes in the network.        
    """
    
 
    if undirected:
        n_node = int(np.ceil(np.sqrt(cfg_matr.shape[-1]*2)))
        shape = cfg_matr.shape[:-2] + (n_node, n_node)
        adj_matr = np.zeros(shape)
        
        triu_ix, triu_iy = np.triu_indices(n_node, k=1)
        adj_matr[..., triu_ix, triu_iy] = cfg_matr[...]
        adj_matr[..., triu_iy, triu_ix] = cfg_matr[...]
        
        return adj_matr
    else:
        n_node = int(np.ceil(np.sqrt(cfg_matr.shape[-1])))
        shape = cfg_matr.shape[:-2] + (n_node, n_node)
        adj_matr = np.zeros(shape)
        
        triu_ix, triu_iy = np.triu_indices(n_node, k=1)
        tril_ix, tril_iy = np.tril_indices(n_node, k=-1)
        adj_matr[..., triu_ix, triu_iy] = cfg_matr[..., :len(triu_ix)]
        adj_matr[..., tril_ix, tril_iy] = cfg_matr[..., len(triu_ix):]
        
        return adj_matr