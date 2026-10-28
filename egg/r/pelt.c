/* PELT optimal partitioning, normal-mean cost -(S_b-S_a)^2/len (known variance 1), min segment m, penalty beta.
   Same algorithm as the R reference in 06_changepoint.R (pruning K=0). Called from R via .C. */
#include <stdlib.h>
void pelt_c(double *x, int *n_, double *beta_, int *m_, int *cp, int *ncp) {
  int n = *n_, m = *m_; double beta = *beta_;
  double *S = malloc((n + 1) * sizeof(double)), *F = malloc((n + 1) * sizeof(double));
  int *last = calloc(n + 1, sizeof(int)), *R = malloc((n + 1) * sizeof(int)), *Rn = malloc((n + 1) * sizeof(int));
  int nr = 0, t, i, j;
  S[0] = 0; for (i = 0; i < n; i++) S[i + 1] = S[i] + x[i];
  F[0] = -beta;
  for (t = m; t <= n; t++) {
    R[nr++] = t - m; double best = 1e300; int arg = 0;
    for (i = 0; i < nr; i++) { int tau = R[i]; double d = S[t] - S[tau]; double v = F[tau] - d * d / (t - tau) + beta; if (v < best) { best = v; arg = tau; } }
    F[t] = best; last[t] = arg; int k = 0;
    for (i = 0; i < nr; i++) { int tau = R[i]; double d = S[t] - S[tau]; if (F[tau] - d * d / (t - tau) <= best) Rn[k++] = tau; }
    for (j = 0; j < k; j++) R[j] = Rn[j]; nr = k;
  }
  int c = 0; t = n; int *tmp = malloc((n + 1) * sizeof(int));
  while (t > 0) { int tau = last[t]; if (tau > 0) tmp[c++] = tau; t = tau; }
  for (i = 0; i < c; i++) cp[i] = tmp[c - 1 - i];
  *ncp = c; free(S); free(F); free(last); free(R); free(Rn); free(tmp);
}
