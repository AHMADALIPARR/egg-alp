#!/bin/sh
# EGG-001: compile the Futhark kernels (C backend, CPU) and run every entry point on the data.
# usage: futhark/run.sh   (from egg/; needs out/dense.tsv from the AWK step)
set -eu
cd "$(dirname "$0")/.."
O=out; mkdir -p $O/fut
futhark c futhark/egg.fut -o $O/egg_fut
awk -F'\t' -v mode=valsmask -f awk/to_futhark.awk $O/dense.tsv > $O/fut_vm.txt
awk -F'\t' -v mode=mask -f awk/to_futhark.awk $O/dense.tsv > $O/fut_m.txt
conv() { awk -f awk/fut2tsv.awk; }
# one-value-per-line outputs -> tsv columns
$O/egg_fut -e device_moments < $O/fut_vm.txt > $O/fut/device_moments.raw
for i in 1 2 3 4 5; do sed -n ${i}p $O/fut/device_moments.raw | conv > $O/fut/dm$i.tsv; done
( echo "n	sum	sumsq	mean	var_unbiased"; paste $O/fut/dm1.tsv $O/fut/dm2.tsv $O/fut/dm3.tsv $O/fut/dm4.tsv $O/fut/dm5.tsv ) > $O/fut/device_moments.tsv
$O/egg_fut -e network_z < $O/fut_vm.txt > $O/fut/netz.raw
sed -n 1p $O/fut/netz.raw | conv > $O/fut/z.tsv; sed -n 2p $O/fut/netz.raw | conv > $O/fut/nvalid.tsv
paste $O/fut/z.tsv $O/fut/nvalid.tsv > $O/fut/network_z.tsv
$O/egg_fut -e pairwise_cov_corr < $O/fut_vm.txt > $O/fut/cc.raw
sed -n 1p $O/fut/cc.raw | conv > $O/fut/npair.tsv; sed -n 2p $O/fut/cc.raw | conv > $O/fut/cov.tsv; sed -n 3p $O/fut/cc.raw | conv > $O/fut/corr.tsv
# calibrated network Z uses the Futhark correlation matrix
awk -F'\t' 'BEGIN{printf "["} {printf "%s[", (NR>1?",":""); for(i=1;i<=NF;i++) printf "%s%s", (i>1?",":""), ($i=="NA"?"0f64":$i "f64"); printf "]"} END{print "]"}' $O/fut/corr.tsv > $O/fut/corr_in.txt
cat $O/fut_vm.txt $O/fut/corr_in.txt | $O/egg_fut -e network_z_calibrated > $O/fut/netzc.raw
sed -n 1p $O/fut/netzc.raw | conv > $O/fut/zc.tsv; sed -n 2p $O/fut/netzc.raw | conv > $O/fut/varz.tsv
paste $O/fut/zc.tsv $O/fut/varz.tsv > $O/fut/network_z_calibrated.tsv
for w in 60 300 1800; do
  ( cat $O/fut_vm.txt; echo "${w}i64" ) | $O/egg_fut -e rolling_moments > $O/fut/roll$w.raw
  sed -n 1p $O/fut/roll$w.raw | conv > $O/fut/roll${w}_n.tsv
  sed -n 2p $O/fut/roll$w.raw | conv > $O/fut/roll${w}_mean.tsv
  sed -n 3p $O/fut/roll$w.raw | conv > $O/fut/roll${w}_var.tsv
  ( cat $O/fut_vm.txt; echo "${w}i64" ) | $O/egg_fut -e rolling_network_z > $O/fut/rollz$w.raw
  sed -n 1p $O/fut/rollz$w.raw | conv > $O/fut/rollz${w}_n.tsv
  sed -n 2p $O/fut/rollz$w.raw | conv > $O/fut/rollz${w}_z.tsv
done
# null simulation with the observed mask, fixed seed
for seed in 20000401; do
  ( cat $O/fut_m.txt; echo "${seed}i64" ) | $O/egg_fut -e sim_null > $O/fut/simnull_$seed.raw
done
for i in 1 2 3 4 5; do sed -n ${i}p $O/fut/simnull_20000401.raw | conv > $O/fut/sn$i.tsv; done
( echo "n	mean	var"; paste $O/fut/sn1.tsv $O/fut/sn2.tsv $O/fut/sn3.tsv ) > $O/fut/simnull_device.tsv
( echo "zmean	zvar"; paste -d'\t' $O/fut/sn4.tsv $O/fut/sn5.tsv | tr '\n' '\t' | sed 's/\t$//; s/\t/\t/'; echo ) > $O/fut/simnull_z.tsv
echo "futhark run complete"
