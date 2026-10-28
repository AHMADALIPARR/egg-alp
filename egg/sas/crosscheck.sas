/* EGG-001 SAS cross-check. STATUS: UNVERIFIED-NOT-RUN. SAS is not installed here; this file has never been executed. */
/* Purpose: independent check of R results: device mean/variance, network-Z variance, ACF/Ljung-Box. */
/* Input: tidy intermediate out/dense.tsv (empty = missing). Missing stays missing: PROC steps ignore missing values; nothing is set to 0. */
%let seed = 20000401;
proc import datafile="out/dense.tsv" out=work.dense dbms=tab replace; getnames=yes; guessingrows=max; run;
proc means data=work.dense n nmiss mean var min max; var _numeric_; run;               /* compare with results/r_device_summary.tsv */
data work.net; set work.dense;                                                           /* network Z, V_t = devices with a valid count */
  array d {*} _numeric_; k = 0; s = 0;
  do i = 1 to dim(d); if vname(d{i}) ne 't' and not missing(d{i}) then do; k + 1; s + (d{i} - 100)/sqrt(50); end; end;
  if k > 0 then z = s / sqrt(k); else z = .;                                            /* |V_t| = 0 gives missing, never 0 */
  keep t k z;
run;
proc means data=work.net n nmiss mean var; var z; run;                                  /* expect variance about 1.0033 */
proc arima data=work.net; identify var=z nlag=60; run;                                  /* ACF/PACF and Ljung-Box (white-noise check) */
