"""s46 Track L: the single registered spinup table function (plan v8 L1, v9 L4, v6 L2).
I: array (K, 3) of annual increments I(1..K) (merch, foliage, other), row k-1 = I(k).
Returns J (K, 3) for input labels 1..K: J(1) = I(1)+...+I(1+shift); J(k) = I(k+shift), k >= 2;
I(k) = 0 for k > K (s45 curve loader continuation). shift 0 = unshifted (s45 pre-shift),
shift 1 = REGISTERED, shift 2 = evidence only (must fail the null test)."""
import numpy as np
def spinup_table(I, shift):
    I = np.asarray(I, dtype=np.float64)
    if I.ndim != 2: raise ValueError("I must be (K, n)")
    K = I.shape[0]
    if shift == 0: return I.copy()
    Ip = np.vstack([I, np.zeros((shift, I.shape[1]))])
    J = Ip[shift:shift + K].copy()
    J[0] = Ip[:shift + 1].sum(axis=0)
    return J
