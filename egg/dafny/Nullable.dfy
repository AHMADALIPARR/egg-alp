// EGG-001 Dafny contracts for nullable device counts.
// A cell is an option: None = missing (never zero-imputed), Some(v) = observed count.
// Valid count: 0 <= v <= 200.  Statements concern the specification's finite sums only.

datatype Cell = Missing | Obs(v: int)

predicate CellOk(c: Cell) { c.Obs? ==> 0 <= c.v <= 200 }

predicate AllOk(s: seq<Cell>) { forall i :: 0 <= i < |s| ==> CellOk(s[i]) }

// Sum over observed cells only.
function SumValid(s: seq<Cell>): int decreases |s| {
  if |s| == 0 then 0
  else (if s[0].Obs? then s[0].v else 0) + SumValid(s[1..])
}

// Number of observed cells.
function CountValid(s: seq<Cell>): int decreases |s| {
  if |s| == 0 then 0
  else (if s[0].Obs? then 1 else 0) + CountValid(s[1..])
}

function CountMissing(s: seq<Cell>): int decreases |s| {
  if |s| == 0 then 0
  else (if s[0].Missing? then 1 else 0) + CountMissing(s[1..])
}

// The forbidden operation, defined only so we can prove it differs.
function ImputeZero(s: seq<Cell>): seq<Cell> decreases |s| {
  if |s| == 0 then [] else [Obs(if s[0].Obs? then s[0].v else 0)] + ImputeZero(s[1..])
}

// ---- Missing is not zero; counts partition the cells ----

lemma MissingNotZero() ensures Missing != Obs(0) {}

lemma CountPartition(s: seq<Cell>)
  ensures CountValid(s) + CountMissing(s) == |s|
  ensures 0 <= CountValid(s) <= |s|
  decreases |s|
{ if |s| > 0 { CountPartition(s[1..]); } }

lemma MissingNotCounted(s: seq<Cell>)
  ensures CountValid([Missing] + s) == CountValid(s)
  ensures CountValid([Obs(0)] + s) == CountValid(s) + 1
  ensures SumValid([Missing] + s) == SumValid(s)
{ assert ([Missing] + s)[1..] == s; assert ([Obs(0)] + s)[1..] == s; }

lemma ImputeZeroCount(s: seq<Cell>)
  ensures CountValid(ImputeZero(s)) == |s|
  ensures SumValid(ImputeZero(s)) == SumValid(s)
  decreases |s|
{
  if |s| > 0 {
    ImputeZeroCount(s[1..]);
    assert ImputeZero(s)[1..] == ImputeZero(s[1..]);
  }
}

// Zero imputation changes the count whenever a cell is missing: it silently inflates n.
lemma ImputeZeroChangesCount(s: seq<Cell>)
  requires CountMissing(s) > 0
  ensures CountValid(ImputeZero(s)) != CountValid(s)
{ ImputeZeroCount(s); CountPartition(s); }

// ---- Sum and mean bounds over valid cells ----

lemma SumBounds(s: seq<Cell>)
  requires AllOk(s)
  ensures 0 <= SumValid(s) <= 200 * CountValid(s)
  decreases |s|
{
  if |s| > 0 {
    assert AllOk(s[1..]) by { forall i | 0 <= i < |s[1..]| ensures CellOk(s[1..][i]) { assert s[1..][i] == s[i+1]; } }
    SumBounds(s[1..]);
  }
}

// Mean over valid cells, as a real, is only defined when count > 0 and lies in [0,200].
function MeanValid(s: seq<Cell>): real
  requires CountValid(s) > 0
{ SumValid(s) as real / CountValid(s) as real }

lemma MeanBounds(s: seq<Cell>)
  requires AllOk(s) && CountValid(s) > 0
  ensures 0.0 <= MeanValid(s) <= 200.0
{
  SumBounds(s);
  var n := CountValid(s) as real;
  assert SumValid(s) as real <= 200.0 * n;
  assert 0.0 <= SumValid(s) as real;
  assert n > 0.0;
  DivLe(SumValid(s) as real, 200.0 * n, n);
  MulDivCancel(200.0, n);
}

// ---- Network Z precondition |V_t| > 0 ----
// Z^2 = S^2 / (50 n), S = sum (x-100) over observed cells, n = |V_t|.
// The function cannot be called unless n > 0 (never divides by zero).

function CenteredSum(s: seq<Cell>): int { SumValid(s) - 100 * CountValid(s) }

function NetworkZ2(s: seq<Cell>): real
  requires CountValid(s) > 0
{ (CenteredSum(s) * CenteredSum(s)) as real / (50.0 * CountValid(s) as real) }

// Total: Option-returning wrapper; None exactly when V_t is empty.
datatype MaybeReal = NoValue | Value(r: real)

function NetworkZ2Opt(s: seq<Cell>): MaybeReal {
  if CountValid(s) <= 0 then NoValue else Value(NetworkZ2(s))
}

lemma NetworkZ2OptTotal(s: seq<Cell>)
  ensures NetworkZ2Opt(s).Value? <==> CountValid(s) > 0
{ CountPartition(s); }

lemma AllMissingGivesNone(n: nat)
  ensures CountValid(seq(n, _ => Missing)) == 0
  ensures NetworkZ2Opt(seq(n, _ => Missing)) == NoValue
  decreases n
{
  if n > 0 {
    var s := seq(n, _ => Missing);
    assert s[1..] == seq(n - 1, _ => Missing);
    AllMissingGivesNone(n - 1);
  }
}

// With in-contract cells, |S| <= 100 n, so Z^2 <= 200 n.
lemma NetworkZ2Bound(s: seq<Cell>)
  requires AllOk(s) && CountValid(s) > 0
  ensures 0.0 <= NetworkZ2(s) <= 200.0 * CountValid(s) as real
{
  SumBounds(s);
  var n := CountValid(s);
  var S := CenteredSum(s);
  assert -100 * n <= S <= 100 * n;
  assert S * S <= 10000 * n * n by { NonlinearSq(S, 100 * n); }
  var nr := n as real;
  assert (S * S) as real <= 10000.0 * nr * nr;
  assert 0.0 <= (S * S) as real;
  assert 10000.0 * nr * nr / (50.0 * nr) == 200.0 * nr by { assert nr > 0.0; }
  DivLe((S * S) as real, 10000.0 * nr * nr, 50.0 * nr);
}

lemma NonlinearSq(a: int, m: int)
  requires -m <= a <= m
  ensures a * a <= m * m
{
  assert m - a >= 0 && m + a >= 0;
  assert (m - a) * (m + a) >= 0;
  assert m * m - a * a == (m - a) * (m + a);
}

lemma DivLe(x: real, y: real, d: real)
  requires d > 0.0 && 0.0 <= x <= y
  ensures 0.0 <= x / d <= y / d
{}

// ---- Rolling-window validity ----
// Window of width w ending at (exclusive) t covers indices [t-w, t).
// Qualified = inside the series and every cell observed.

predicate Qualified(s: seq<Cell>, t: int, w: int) {
  0 < w <= t <= |s| && forall k :: t - w <= k < t ==> s[k].Obs?
}

// Prefix count of observed cells: P[t] = CountValid(s[..t]).
lemma PrefixCountAdd(s: seq<Cell>, lo: int, hi: int)
  requires 0 <= lo <= hi <= |s|
  ensures CountValid(s[..hi]) == CountValid(s[..lo]) + CountValid(s[lo..hi])
  decreases hi - lo
{
  if lo < hi {
    CountSnoc(s[..hi-1], s[hi-1]);
    assert s[..hi-1] == s[..hi][..hi-1];
    PrefixCountAdd(s, lo, hi - 1);
    CountSnoc(s[lo..hi-1], s[hi-1]);
    assert s[lo..hi] == s[lo..hi-1] + [s[hi-1]];
    assert s[..hi] == s[..hi-1] + [s[hi-1]];
  } else {
    assert s[lo..hi] == [];
    assert s[..hi] == s[..lo];
  }
}

lemma CountConcat(a: seq<Cell>, b: seq<Cell>)
  ensures CountValid(a + b) == CountValid(a) + CountValid(b)
  decreases |a|
{
  if |a| == 0 { assert a + b == b; }
  else { CountConcat(a[1..], b); assert (a + b)[1..] == a[1..] + b; }
}

lemma CountSnoc(a: seq<Cell>, c: Cell)
  ensures CountValid(a + [c]) == CountValid(a) + (if c.Obs? then 1 else 0)
{ CountConcat(a, [c]); }

lemma CountAllObs(s: seq<Cell>)
  requires forall k :: 0 <= k < |s| ==> s[k].Obs?
  ensures CountValid(s) == |s|
  decreases |s|
{
  if |s| > 0 {
    assert forall k :: 0 <= k < |s[1..]| ==> s[1..][k].Obs? by {
      forall k | 0 <= k < |s[1..]| ensures s[1..][k].Obs? { assert s[1..][k] == s[k+1]; }
    }
    CountAllObs(s[1..]);
  }
}

lemma CountFullImpliesAllObs(s: seq<Cell>)
  requires CountValid(s) == |s|
  ensures forall k :: 0 <= k < |s| ==> s[k].Obs?
  decreases |s|
{
  if |s| > 0 {
    CountPartition(s[1..]);
    assert s[0].Obs?;
    CountFullImpliesAllObs(s[1..]);
    forall k | 0 <= k < |s| ensures s[k].Obs? {
      if k > 0 { assert s[1..][k-1] == s[k]; }
    }
  }
}

// A window is qualified exactly when it contains w observed cells (prefix-count test),
// so an O(1) check per window is sound and complete.
lemma QualifiedIffFull(s: seq<Cell>, t: int, w: int)
  requires 0 < w <= t <= |s|
  ensures Qualified(s, t, w) <==> CountValid(s[t-w..t]) == w
{
  var win := s[t-w..t];
  if Qualified(s, t, w) {
    assert forall k :: 0 <= k < |win| ==> win[k].Obs? by {
      forall k | 0 <= k < |win| ensures win[k].Obs? { assert win[k] == s[t-w+k]; }
    }
    CountAllObs(win);
  }
  if CountValid(win) == w {
    CountFullImpliesAllObs(win);
    forall k | t - w <= k < t ensures s[k].Obs? { assert win[k-(t-w)] == s[k]; }
  }
}

lemma PrefixWindowCount(s: seq<Cell>, t: int, w: int)
  requires 0 < w <= t <= |s|
  ensures Qualified(s, t, w) <==> CountValid(s[..t]) - CountValid(s[..t-w]) == w
{
  PrefixCountAdd(s, t - w, t);
  QualifiedIffFull(s, t, w);
}

// Qualified windows always have effective sample size exactly w, so a mean over them
// is defined and in 0..200 when the cells are in contract.
lemma QualifiedWindowMean(s: seq<Cell>, t: int, w: int)
  requires Qualified(s, t, w) && AllOk(s)
  ensures CountValid(s[t-w..t]) == w
  ensures 0.0 <= MeanValid(s[t-w..t]) <= 200.0
{
  QualifiedIffFull(s, t, w);
  var win := s[t-w..t];
  assert AllOk(win) by { forall k | 0 <= k < |win| ensures CellOk(win[k]) { assert win[k] == s[t-w+k]; } }
  MeanBounds(win);
}

// ---- Permutation invariance of the sum/count over devices ----

lemma SumConcat(a: seq<Cell>, b: seq<Cell>)
  ensures SumValid(a + b) == SumValid(a) + SumValid(b)
  decreases |a|
{
  if |a| == 0 { assert a + b == b; }
  else { SumConcat(a[1..], b); assert (a + b)[1..] == a[1..] + b; }
}

lemma PermInvariant(a: seq<Cell>, b: seq<Cell>)
  requires multiset(a) == multiset(b)
  ensures SumValid(a) == SumValid(b)
  ensures CountValid(a) == CountValid(b)
  ensures CountMissing(a) == CountMissing(b)
  decreases |a|
{
  if |a| > 0 {
    var x := a[0];
    assert x in multiset(a);
    assert x in multiset(b);
    var i :| 0 <= i < |b| && b[i] == x;
    var b2 := b[..i] + b[i+1..];
    assert b == b[..i] + [x] + b[i+1..];
    assert a == [x] + a[1..];
    assert multiset(a) == multiset{x} + multiset(a[1..]);
    assert multiset(b) == multiset(b[..i]) + multiset{x} + multiset(b[i+1..]);
    assert multiset(b2) == multiset(b[..i]) + multiset(b[i+1..]);
    assert multiset(a[1..]) == multiset(b2) by {
      forall e ensures multiset(a[1..])[e] == multiset(b2)[e] {
        assert multiset(a)[e] == multiset(b)[e];
      }
    }
    PermInvariant(a[1..], b2);
    SumConcat(b[..i] + [x], b[i+1..]);
    SumConcat(b[..i], [x]);
    CountConcat(b[..i] + [x], b[i+1..]);
    CountConcat(b[..i], [x]);
    CountMissingConcat(b[..i] + [x], b[i+1..]);
    CountMissingConcat(b[..i], [x]);
    SumConcat(b[..i], b[i+1..]);
    CountConcat(b[..i], b[i+1..]);
    CountMissingConcat(b[..i], b[i+1..]);
    assert b[..i] + [x] + b[i+1..] == (b[..i] + [x]) + b[i+1..];
  }
}

lemma CountMissingConcat(a: seq<Cell>, b: seq<Cell>)
  ensures CountMissing(a + b) == CountMissing(a) + CountMissing(b)
  decreases |a|
{
  if |a| == 0 { assert a + b == b; }
  else { CountMissingConcat(a[1..], b); assert (a + b)[1..] == a[1..] + b; }
}

// Network Z^2 is permutation invariant too.
lemma NetworkZ2Perm(a: seq<Cell>, b: seq<Cell>)
  requires multiset(a) == multiset(b)
  ensures NetworkZ2Opt(a) == NetworkZ2Opt(b)
{
  PermInvariant(a, b);
}

// ---- Input validation routine ----
// Validates a raw row: present flags + integer values -> cells; rejects out-of-contract
// values rather than clamping, and never produces Obs(0) for a missing cell.

method ParseRow(present: seq<bool>, vals: seq<int>) returns (ok: bool, cells: seq<Cell>)
  requires |present| == |vals|
  ensures |cells| == |present|
  ensures ok ==> AllOk(cells)
  ensures ok ==> forall i :: 0 <= i < |cells| ==>
            (cells[i].Missing? <==> !present[i]) && (present[i] ==> cells[i] == Obs(vals[i]))
  ensures ok <==> (forall i :: 0 <= i < |present| ==> present[i] ==> 0 <= vals[i] <= 200)
{
  cells := [];
  ok := true;
  var i := 0;
  while i < |present|
    invariant 0 <= i <= |present|
    invariant |cells| == i
    invariant ok <==> (forall j :: 0 <= j < i ==> present[j] ==> 0 <= vals[j] <= 200)
    invariant forall j :: 0 <= j < i ==>
              (cells[j].Missing? <==> !present[j]) && (present[j] ==> cells[j] == Obs(vals[j]))
    invariant ok ==> AllOk(cells)
  {
    if !present[i] {
      cells := cells + [Missing];
    } else {
      if !(0 <= vals[i] <= 200) { ok := false; }
      cells := cells + [Obs(vals[i])];
    }
    i := i + 1;
  }
}

// Index/bounds contract: device column lookup in a 25-device row never goes out of range.
method CellAt(row: seq<Cell>, i: int) returns (c: Cell)
  requires 0 <= i < |row|
  ensures c == row[i]
{ c := row[i]; }

lemma MulDivCancel(c: real, n: real)
  requires n > 0.0
  ensures c * n / n == c
{}
