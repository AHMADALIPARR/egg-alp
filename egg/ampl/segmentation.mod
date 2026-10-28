# EGG-001 AMPL model: optimal partitioning (penalized-likelihood segmentation) as a shortest path.
# STATUS: UNVERIFIED-NOT-RUN. No AMPL and no solver are installed here. The model has not been parsed by AMPL.
# Objective: minimise  sum over chosen segments (a,b] of  cost[a,b] + beta   (normal mean, known variance 1, cost = -(S_b - S_a)^2 / (b - a)).
# A path from node 0 to node n; an arc (a,b) is allowed only if the segment is at least MINSEG long.
param n integer > 0;
param MINSEG integer > 0;
param beta >= 0;
param S {0..n};                              # prefix sums of the observed (compressed) z series; missing cells never enter
set ARCS = {a in 0..n-1, b in 1..n: b - a >= MINSEG};
param cost {(a,b) in ARCS} = -(S[b] - S[a])^2 / (b - a);
var x {ARCS} binary;                         # 1 if the segment (a,b] is used
minimize total: sum {(a,b) in ARCS} (cost[a,b] + beta) * x[a,b];
subject to leave0: sum {(0,b) in ARCS} x[0,b] = 1;
subject to enter_n: sum {(a,n) in ARCS} x[a,n] = 1;
subject to flow {k in 1..n-1}: sum {(a,k) in ARCS} x[a,k] = sum {(k,b) in ARCS} x[k,b];
