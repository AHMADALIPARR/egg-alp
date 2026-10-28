% EGG-001 Octave cross-check. MATLAB-compatible code, RUN UNDER GNU OCTAVE ONLY (not run in MATLAB).
% Reads the tidy intermediate (empty = missing -> NaN). Missing is never turned into 0.
% usage: octave --no-gui --quiet egg_spectral.m  (env EGG_OUT = intermediate dir, EGG_OCT = output dir)
outd = getenv('EGG_OUT'); if isempty(outd), outd = 'out'; end
octd = getenv('EGG_OCT'); if isempty(octd), octd = fullfile(outd, 'oct'); end
A = dlmread(fullfile(outd, 'dense.tsv'), "\t", 1, 0, "emptyvalue", NaN);
t = A(:, 1); X = A(:, 2:end); [T, nd] = size(X);
M = ~isnan(X);
% device moments over observed cells only
nv = sum(M, 1); mu = zeros(1, nd); vr = zeros(1, nd);
for i = 1:nd, xi = X(M(:, i), i); mu(i) = mean(xi); vr(i) = var(xi); end   % var uses n-1
dlmwrite(fullfile(octd, 'oct_device_moments.tsv'), [nv; mu; vr]', "\t", "precision", 12);
% network Z
Z = (X - 100) / sqrt(50); Z(~M) = 0; k = sum(M, 2); Zn = zeros(T, 1); ok = k > 0;
Zn(ok) = sum(Z(ok, :), 2) ./ sqrt(k(ok));
dlmwrite(fullfile(octd, 'oct_network_z_head.tsv'), [t(1:1000), k(1:1000), Zn(1:1000)], "\t", "precision", 12);
dlmwrite(fullfile(octd, 'oct_network_z_summary.tsv'), [mean(Zn(ok)), var(Zn(ok)), sum(abs(Zn(ok)) >= 3), sum(ok)], "\t", "precision", 12);
% pairwise-complete Pearson, first 5 devices
nc = 5; R = zeros(nc);
for i = 1:nc, for j = 1:nc
  b = M(:, i) & M(:, j); xi = X(b, i); xj = X(b, j); c = corrcoef(xi, xj); R(i, j) = c(1, 2);
end, end
dlmwrite(fullfile(octd, 'oct_corr5.tsv'), R, "\t", "precision", 12);
% ACF of network Z, lags 1..60 (biased estimator, mean removed: same as R acf)
L = 60; x = Zn - mean(Zn); c0 = sum(x .^ 2) / T; ac = zeros(L, 1);
for l = 1:L, ac(l) = sum(x(1:T-l) .* x(1+l:T)) / T / c0; end
dlmwrite(fullfile(octd, 'oct_acf_network.tsv'), ac, "\t", "precision", 12);
% periodogram of network Z: |DFT|^2 / n, k = 1..n/2-1
f = fft(Zn); kk = (1:(T/2 - 1))'; I = abs(f(kk + 1)) .^ 2 / T;
[mx, ix] = max(I); dlmwrite(fullfile(octd, 'oct_periodogram.tsv'), [ix, mx, mean(I)], "\t", "precision", 12);
% Welch, own implementation, periodic Hann, 4096 s, 50% overlap, mean not removed
ns = 4096; step = 2048; w = 0.5 - 0.5 * cos(2 * pi * (0:ns-1)' / ns); U = sum(w .^ 2);
st = 1:step:(T - ns + 1); P = zeros(ns/2 + 1, 1);
for s = st, seg = Zn(s:s+ns-1) .* w; F = fft(seg); P = P + abs(F(1:ns/2+1)) .^ 2 / U; end
P = P / numel(st); dlmwrite(fullfile(octd, 'oct_welch.tsv'), [(0:ns/2)' / ns, P], "\t", "precision", 12);
% rolling 60 s variance, device index 1, only fully observed windows
w60 = 60; nw = floor(T / w60); rv = NaN(nw, 1);
for j = 1:nw, r = (j-1)*w60 + (1:w60); if all(M(r, 1)), rv(j) = var(X(r, 1)); end, end
dlmwrite(fullfile(octd, 'oct_roll60_dev1_var.tsv'), rv, "\t", "precision", 12);
printf('octave egg_spectral done: T=%d devices=%d\n', T, nd);
