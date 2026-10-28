-- EGG-001 component: Futhark dense / nullable-array kernels.
-- Representation of a nullable count matrix: `vals : [t][d]i32` and an explicit
-- `mask : [t][d]bool` (true = observed). Missing cells carry the sentinel -1 in
-- `vals`, but NO kernel reads `vals` unless `mask` is true (tests/futhark_garbage
-- replaces the sentinel with garbage and checks outputs are identical).
-- All sums are done on observed cells only. Missing is never treated as 0.
-- Reference model: X ~ Binomial(200, 1/2): mean 100, variance 50.

def mu : f64 = 100.0
def sig : f64 = f64.sqrt 50.0

def zc (x: i32) : f64 = (f64.i32 x - mu) / sig

-- ---- per-device moments (exact integer sums, then float) --------------------
-- outputs: n, sum, sumsq (i64, exact), mean, var_unbiased (f64; NaN if n<2)
entry device_moments [t][d] (vals: [t][d]i32) (mask: [t][d]bool)
    : ([d]i64, [d]i64, [d]i64, [d]f64, [d]f64) =
  let cols = transpose vals
  let mcols = transpose mask
  let r = map2 (\v m ->
      let n = i64.sum (map (\b -> if b then 1i64 else 0i64) m)
      let s = i64.sum (map2 (\x b -> if b then i64.i32 x else 0i64) v m)
      let ss = i64.sum (map2 (\x b -> if b then i64.i32 x * i64.i32 x else 0i64) v m)
      in (n, s, ss)) cols mcols
  let (ns, ss, sss) = unzip3 r
  let means = map2 (\n s -> if n > 0 then f64.i64 s / f64.i64 n else f64.nan) ns ss
  let vars = map3 (\n s q -> if n > 1 then
                      (f64.i64 q - f64.i64 s * f64.i64 s / f64.i64 n) / f64.i64 (n - 1)
                    else f64.nan) ns ss sss
  in (ns, ss, sss, means, vars)

-- ---- network Z[t] = sum_{i in V_t} z[i,t] / sqrt(|V_t|), defined only if |V_t|>0
-- returns (Z, nvalid). Z[t] is NaN iff nvalid[t]==0 (no division by zero is performed).
entry network_z [t][d] (vals: [t][d]i32) (mask: [t][d]bool) : ([t]f64, [t]i32) =
  let r = map2 (\v m ->
      let k = i32.sum (map (\b -> if b then 1i32 else 0i32) m)
      let s = f64.sum (map2 (\x b -> if b then zc x else 0f64) v m)
      in (if k > 0 then s / f64.sqrt (f64.i32 k) else f64.nan, k)) vals mask
  in unzip r

-- ---- pairwise-complete covariance/correlation ------------------------------
-- returns (n_pair [d][d], cov [d][d], corr [d][d]); NaN if n_pair<2 or zero variance.
entry pairwise_cov_corr [t][d] (vals: [t][d]i32) (mask: [t][d]bool)
    : ([d][d]i64, [d][d]f64, [d][d]f64) =
  let cols = transpose vals
  let mcols = transpose mask
  let one (vi: [t]i32) (mi: [t]bool) (vj: [t]i32) (mj: [t]bool) =
    let (n, sx, sy, sxx, syy, sxy) =
      reduce (\(a1,a2,a3,a4,a5,a6) (b1,b2,b3,b4,b5,b6) ->
                (a1+b1,a2+b2,a3+b3,a4+b4,a5+b5,a6+b6))
             (0i64,0i64,0i64,0i64,0i64,0i64)
             (map4 (\x mx y my ->
                  if mx && my then (1i64, i64.i32 x, i64.i32 y, i64.i32 x * i64.i32 x,
                                    i64.i32 y * i64.i32 y, i64.i32 x * i64.i32 y)
                  else (0i64,0i64,0i64,0i64,0i64,0i64)) vi mi vj mj)
    let nf = f64.i64 n
    let cxy = (f64.i64 sxy - f64.i64 sx * f64.i64 sy / nf) / (nf - 1)
    let vx = (f64.i64 sxx - f64.i64 sx * f64.i64 sx / nf) / (nf - 1)
    let vy = (f64.i64 syy - f64.i64 sy * f64.i64 sy / nf) / (nf - 1)
    let c = if n > 1 then cxy else f64.nan
    let r = if n > 1 && vx > 0 && vy > 0 then cxy / f64.sqrt (vx * vy) else f64.nan
    in (n, c, r)
  let res = map2 (\vi mi -> map2 (\vj mj -> one vi mi vj mj) cols mcols) cols mcols
  let flat = map (\row -> unzip3 row) res
  let (ns, cs, rs) = unzip3 flat
  in (ns, cs, rs)

-- ---- network Z calibrated by an empirical correlation matrix ---------------
-- For second t with observed set V, Var(Z_t) = (1/|V|) sum_{i,j in V} R_ij.
-- Zc[t] = Z[t] / sqrt(that). Only defined if |V|>0 and the variance is > 0.
-- R is supplied (estimated once from the data, so this is a calibration, not a test).
entry network_z_calibrated [t][d] (vals: [t][d]i32) (mask: [t][d]bool) (rmat: [d][d]f64)
    : ([t]f64, [t]f64) =
  let r = map2 (\v m ->
      let k = i32.sum (map (\b -> if b then 1i32 else 0i32) m)
      let s = f64.sum (map2 (\x b -> if b then zc x else 0f64) v m)
      let q = f64.sum (map2 (\i mi ->
                 f64.sum (map2 (\mj rij -> if mi && mj then rij else 0f64) m rmat[i]))
                 (iota d) m)
      let varz = if k > 0 then q / f64.i32 k else f64.nan
      let z = if k > 0 then s / f64.sqrt (f64.i32 k) else f64.nan
      in (if k > 0 && varz > 0 then z / f64.sqrt varz else f64.nan,
          varz)) vals mask
  in unzip r

-- ---- rolling (non-overlapping, step = w) per-device window statistics ------
-- Window b covers seconds [b*w, (b+1)*w). A window is "qualified" for a device iff
-- every cell is observed (nobs == w). Returns, per window per device:
-- nobs (i32), mean (NaN unless nobs>0), unbiased var (NaN unless nobs>1).
entry rolling_moments [t][d] (vals: [t][d]i32) (mask: [t][d]bool) (w: i64)
    : ([][d]i32, [][d]f64, [][d]f64) =
  let nb = t / w
  let r = tabulate nb (\b ->
    tabulate d (\j ->
      let n = i64.sum (map (\k -> if mask[b*w+k, j] then 1i64 else 0i64) (iota w))
      let s = i64.sum (map (\k -> if mask[b*w+k, j] then i64.i32 vals[b*w+k, j] else 0i64) (iota w))
      let q = i64.sum (map (\k -> if mask[b*w+k, j] then i64.i32 vals[b*w+k, j] * i64.i32 vals[b*w+k, j] else 0i64) (iota w))
      let m = if n > 0 then f64.i64 s / f64.i64 n else f64.nan
      let v = if n > 1 then (f64.i64 q - f64.i64 s * f64.i64 s / f64.i64 n) / f64.i64 (n - 1) else f64.nan
      in (i32.i64 n, m, v)))
  let flat = map unzip3 r
  in unzip3 flat

-- ---- rolling network Z: sum of Z[t] over non-overlapping windows / sqrt(n_defined)
entry rolling_network_z [t][d] (vals: [t][d]i32) (mask: [t][d]bool) (w: i64)
    : ([]i32, []f64) =
  let (z, k) = network_z vals mask
  let nb = t / w
  let r = tabulate nb (\b ->
      let n = i64.sum (map (\i -> if k[b*w+i] > 0 then 1i64 else 0i64) (iota w))
      let s = f64.sum (map (\i -> if k[b*w+i] > 0 then z[b*w+i] else 0f64) (iota w))
      in (i32.i64 n, if n > 0 then s / f64.sqrt (f64.i64 n) else f64.nan))
  in unzip r

-- ---- bulk Binomial(200,1/2) simulation reproducing the SAME missingness mask --
-- Counter-based generator: splitmix64 over (seed, cell, word). A count is the number
-- of set bits in 200 pseudo-random bits (3 full 64-bit words + low 8 bits of a 4th),
-- which is exactly Binomial(200,1/2) if the bits are fair. Deterministic for a seed.
def splitmix (x: u64) : u64 =
  let z = x + 0x9E3779B97F4A7C15u64
  let z = (z ^ (z >> 30)) * 0xBF58476D1CE4E5B9u64
  let z = (z ^ (z >> 27)) * 0x94D049BB133111EBu64
  in z ^ (z >> 31)

def binom200 (seed: u64) (cell: u64) : i32 =
  let base = splitmix (seed ^ (cell * 0xD1B54A32D192ED03u64))
  let w k = splitmix (base + u64.i32 k * 0xA24BAED4963EE407u64)
  in u64.popc (w 0) + u64.popc (w 1) + u64.popc (w 2) + u64.popc (w 3 & 0xFFu64)

-- Simulated per-device means/variances and network-Z mean/variance under the null,
-- with the observed mask. Returns (n, mean, var) per device, and (mean, var) of Z[t].
entry sim_null [t][d] (mask: [t][d]bool) (seed: i64)
    : ([d]i64, [d]f64, [d]f64, f64, f64) =
  let sd = u64.i64 seed
  let sim = tabulate_2d t d (\i j -> binom200 sd (u64.i64 (i * d + j)))
  let (ns, _, _, ms, vs) = device_moments sim mask
  let (z, k) = network_z sim mask
  let nz = i64.sum (map (\x -> if x > 0 then 1i64 else 0i64) k)
  let zm = f64.sum (map2 (\a x -> if x > 0 then a else 0f64) z k) / f64.i64 nz
  let zv = f64.sum (map2 (\a x -> if x > 0 then (a - zm) * (a - zm) else 0f64) z k) / f64.i64 (nz - 1)
  in (ns, ms, vs, zm, zv)

-- raw simulated matrix, for histogram / determinism tests
entry sim_counts [t][d] (mask: [t][d]bool) (seed: i64) : [t][d]i32 =
  let sd = u64.i64 seed
  in tabulate_2d t d (\i j -> if mask[i,j] then binom200 sd (u64.i64 (i * d + j)) else -1i32)
