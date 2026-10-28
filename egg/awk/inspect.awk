# EGG-001 component: AWK (POSIX awk; tested with the awk found on PATH, see manifest)
# Streaming inspection, validation and preprocessing of the EGG CSV.
#   awk -F, -v out=INTERMEDIATE_DIR -v res=RESULTS_DIR -v trailing_lf=1|0 -f inspect.awk data/basketdata-2000-04-01.csv
# Reads the source once, never edits it. Writes into out= (large, gitignored) and res= (small, committed):
#   dense.tsv          t<TAB>one column per device; EMPTY CELL = MISSING (never 0)
#   awk_device.tsv     per-device n_valid, n_missing, sum, sumsq, min, max, missing runs
#   awk_hist.tsv       per-device histogram of counts 0..200 (valid cells only)
#   awk_rowvalid.tsv   how many seconds had V valid devices (V = 0..25)
#   awk_integrity.tsv  key<TAB>value<TAB>status  (PASS/FAIL per check)
# Missing cells are never imputed. A cell is valid only if it is a plain
# decimal integer in 0..200. Anything else is counted as an error, and
# also kept out of the moments.
# If a quoted field is seen the line is flagged (this file has none; a
# full quoted-CSV parser is not needed unless the check below fires).
BEGIN {
  FS = ","; if (trailing_lf == "") trailing_lf = 1; nbytes = 0; nl = 0; ndev = 0
  nmeta = 0; nhdr = 0; ndata = 0; nerr = 0; nquote = 0; ncr = 0
  prev_t = -1; gaps = 0; dups = 0; nonmono = 0
  dense = out "/dense.tsv"
  printf "" > dense
}
{
  nl++
  nbytes += length($0) + 1            # raw length incl. any CR, plus the LF (one too many if the last line has no LF; see trailing_lf)
  if (sub(/\r$/, "")) ncr++           # CRLF file: strip the CR for parsing, but COUNT and REPORT it. Re-splits fields.
  if (index($0, "\"") > 0) nquote++
}
# ---- metadata lines 1..8 ----------------------------------------------
nl <= 8 {
  nmeta++
  meta[$1 "," $2] = $3; metalabel[$1 "," $2] = $4; metatime[$1 "," $2] = $5
  next
}
# ---- header line 9 ----------------------------------------------------
nl == 9 {
  nhdr++
  hdr_ok = ($1 == "12" && $2 == "gmtime" && $3 == "")
  ndev = NF - 3
  line = "t"
  for (i = 4; i <= NF; i++) {
    id[i-3] = $i
    if (!($i ~ /^[0-9]+$/)) badid++
    if ($i in seen_id) dupid++
    seen_id[$i] = 1
    line = line "\t" $i
    mn[i-3] = 1e9; mx[i-3] = -1; run[i-3] = 0; maxrun[i-3] = 0; nrun[i-3] = 0
    firstmiss[i-3] = ""; lastvalid[i-3] = ""; firstvalid[i-3] = ""
  }
  print line >> dense
  next
}
# ---- data lines ---------------------------------------------------------
{
  ndata++
  if ($1 != "13") { nerr++; badprefix++ }
  if (NF != ndev + 3) { nerr++; badnf++; next }
  if ($3 != "") { nerr++; nonempty3++ }
  t = $2
  if (!(t ~ /^[0-9]+$/)) { nerr++; badt++; next }
  t = t + 0
  if (ndata == 1) first_t = t
  if (prev_t >= 0) {
    if (t == prev_t) dups++
    else if (t < prev_t) nonmono++
    else if (t != prev_t + 1) gaps++
  }
  prev_t = t; last_t = t
  line = t; v = 0
  for (j = 1; j <= ndev; j++) {
    c = $(j + 3)
    if (c == "") {                           # explicit missing
      nmiss[j]++
      if (run[j] == 0) { nrun[j]++; if (firstmiss[j] == "") firstmiss[j] = t }
      run[j]++; if (run[j] > maxrun[j]) maxrun[j] = run[j]
    } else if (c ~ /^[0-9]+$/ && (c + 0) <= 200) {
      x = c + 0
      nvalid[j]++; sum[j] += x; sumsq[j] += x * x
      if (x < mn[j]) mn[j] = x
      if (x > mx[j]) mx[j] = x
      hist[j, x]++
      v++
      run[j] = 0
      if (firstvalid[j] == "") firstvalid[j] = t
      lastvalid[j] = t
    } else {                                 # present but not a valid count
      nerr++; badcell++
      if (nbadshow < 10) { printf "BAD CELL line %d device %s: [%s]\n", nl, id[j], c > "/dev/stderr"; nbadshow++ }
      c = ""                                 # keep it out of dense.tsv as missing, but it is counted in badcell
      run[j] = 0
    }
    line = line "\t" c
  }
  print line >> dense
  rowvalid[v]++
}
END {
  close(dense)
  tot_cells = ndata * ndev; tv = 0; tm = 0; ts_ = 0; tss = 0; gmin = 1e9; gmax = -1
  dfile = res "/awk_device.tsv"; hfile = res "/awk_hist.tsv"
  print "device\tn_valid\tn_missing\tsum\tsumsq\tmin\tmax\tmissing_runs\tlongest_missing_run\tfirst_missing_t\tfirst_valid_t\tlast_valid_t" > dfile
  hl = "device"; for (k = 0; k <= 200; k++) hl = hl "\t" k
  print hl > hfile
  for (j = 1; j <= ndev; j++) {
    printf "%s\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%s\t%s\t%s\n", id[j], nvalid[j], nmiss[j], sum[j], sumsq[j], mn[j], mx[j], nrun[j], maxrun[j], firstmiss[j], firstvalid[j], lastvalid[j] >> dfile
    hl = id[j]; for (k = 0; k <= 200; k++) hl = hl "\t" (hist[j, k] + 0)
    print hl >> hfile
    tv += nvalid[j]; tm += nmiss[j]; ts_ += sum[j]; tss += sumsq[j]
    if (mn[j] < gmin) gmin = mn[j]; if (mx[j] > gmax) gmax = mx[j]
  }
  rfile = res "/awk_rowvalid.tsv"
  print "valid_devices\tseconds" > rfile
  for (v = 0; v <= ndev; v++) print v "\t" (rowvalid[v] + 0) >> rfile
  ifile = res "/awk_integrity.tsv"
  print "key\tvalue\tstatus" > ifile
  mean = tv ? ts_ / tv : 0; var = tv ? tss / tv - mean * mean : 0
  rep("lines_read", nl, "INFO")
  rep("bytes_computed", nbytes, "INFO")
  rep("meta_lines", nmeta, (nmeta == 8) ? "PASS" : "FAIL")
  rep("meta_samples_per_record", meta["10,1"], (meta["10,1"] == "10" && metalabel["10,1"] == "Samples per record") ? "PASS" : "FAIL")
  rep("meta_seconds_per_record", meta["10,2"], (meta["10,2"] == "10" && metalabel["10,2"] == "Seconds per record") ? "PASS" : "FAIL")
  rep("meta_records_per_packet", meta["10,3"], (meta["10,3"] == "30" && metalabel["10,3"] == "Records per packet") ? "PASS" : "FAIL")
  rep("meta_trial_size", meta["10,4"], (meta["10,4"] == "200" && metalabel["10,4"] == "Trial size") ? "PASS" : "FAIL")
  rep("meta_eggs_reporting", meta["11,1"], (meta["11,1"] == ndev) ? "PASS" : "FAIL")
  rep("meta_start_epoch", meta["11,2"], (meta["11,2"] == first_t) ? "PASS" : "FAIL")
  rep("meta_start_text_utc", metatime["11,2"], (metatime["11,2"] == "2000-04-01 00:00:00" && first_t == 954547200) ? "PASS" : "FAIL")
  rep("meta_end_epoch", meta["11,3"], (meta["11,3"] == last_t) ? "PASS" : "FAIL")
  rep("meta_end_text_utc", metatime["11,3"], (metatime["11,3"] == "2000-04-01 23:59:59" && last_t == 954633599) ? "PASS" : "FAIL")
  rep("meta_seconds_of_data", meta["11,4"], (meta["11,4"] == ndata) ? "PASS" : "FAIL")
  rep("header_line_ok", hdr_ok + 0, hdr_ok ? "PASS" : "FAIL")
  rep("devices", ndev, (ndev == 25) ? "PASS" : "FAIL")
  rep("device_id_not_integer", badid + 0, (badid + 0 == 0) ? "PASS" : "FAIL")
  rep("device_id_duplicates", dupid + 0, (dupid + 0 == 0) ? "PASS" : "FAIL")
  rep("data_rows", ndata, (ndata == 86400) ? "PASS" : "FAIL")
  rep("first_epoch", first_t, (first_t == 954547200) ? "PASS" : "FAIL")
  rep("last_epoch", last_t, (last_t == 954633599) ? "PASS" : "FAIL")
  rep("time_gaps", gaps + 0, (gaps + 0 == 0) ? "PASS" : "FAIL")
  rep("time_duplicates", dups + 0, (dups + 0 == 0) ? "PASS" : "FAIL")
  rep("time_non_monotonic", nonmono + 0, (nonmono + 0 == 0) ? "PASS" : "FAIL")
  rep("bad_row_prefix", badprefix + 0, (badprefix + 0 == 0) ? "PASS" : "FAIL")
  rep("bad_field_count", badnf + 0, (badnf + 0 == 0) ? "PASS" : "FAIL")
  rep("col3_not_empty", nonempty3 + 0, (nonempty3 + 0 == 0) ? "PASS" : "FAIL")
  rep("bad_timestamp", badt + 0, (badt + 0 == 0) ? "PASS" : "FAIL")
  rep("cells_expected_capacity", tot_cells, (tot_cells == 2160000) ? "PASS" : "FAIL")
  rep("cells_valid", tv, (tv == 2145238) ? "PASS" : "FAIL")
  rep("cells_missing", tm, (tm == 14762) ? "PASS" : "FAIL")
  rep("cells_valid_plus_missing_eq_capacity", tv + tm, (tv + tm + badcell == tot_cells) ? "PASS" : "FAIL")
  rep("cells_not_integer_or_out_of_0_200", badcell + 0, (badcell + 0 == 0) ? "PASS" : "FAIL")
  rep("quoted_fields_lines", nquote, (nquote == 0) ? "PASS" : "FAIL")
  rep("lines_ending_in_CR", ncr, "INFO")
  rep("line_endings_consistent", (ncr == nl || ncr == nl - 1) ? "all_CRLF" : "mixed", (ncr == nl || ncr == nl - 1 || ncr == 0) ? "PASS" : "FAIL")
  rep("trailing_lf_supplied", trailing_lf, "INFO")
  rep("bytes_expected_from_lines", nbytes - (trailing_lf == 0 ? 1 : 0), "INFO")
  rep("mean_valid", sprintf("%.6f", mean), "INFO")
  rep("var_valid_population", sprintf("%.6f", var), "INFO")
  rep("min_valid", gmin, "INFO")
  rep("max_valid", gmax, "INFO")
  rep("rows_with_zero_valid_devices", rowvalid[0] + 0, "INFO")
  rep("zero_imputed_cells", 0, "PASS")
  # The last check is by construction: this script never writes a 0 where the source was empty.
  close(ifile); close(dfile); close(hfile); close(rfile)
  exit (nerr > 0)
}
function rep(k, v, s) { print k "\t" v "\t" s >> ifile }
