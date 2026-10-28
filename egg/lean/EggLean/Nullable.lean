/-
  EGG-001 Lean 4 lemmas about nullable device counts (core Lean only, no Mathlib).

  Model: a cell is `Option Nat`; `none` is a missing observation and is never
  replaced by zero.  A cell is valid when its value v satisfies 0 <= v <= 200.
  All statements are about the specification's finite sums; nothing here says
  anything about the physical data.
-/

namespace Egg

/-- A device count cell: `none` = missing, `some v` = observed count v. -/
abbrev Cell := Option Nat

/-- Valid-count contract: an observed value lies in 0..200 (0 <= v is automatic in Nat). -/
def CellOk (c : Cell) : Prop := ∀ v, c = some v → v ≤ 200

/-- A column/row of cells is in contract when every cell is. -/
def AllOk (s : List Cell) : Prop := ∀ c, c ∈ s → CellOk c

/-- Sum over observed cells only (missing contributes nothing, and is not counted). -/
def sumValid (s : List Cell) : Nat := (s.filterMap id).sum

/-- Number of observed cells. -/
def countValid (s : List Cell) : Nat := (s.filterMap id).length

/-- Number of missing cells. -/
def countMissing (s : List Cell) : Nat := (s.filter Option.isNone).length

/-- The forbidden operation: zero imputation (kept only so we can prove it differs). -/
def imputeZero (s : List Cell) : List Cell := s.map (fun c => some (c.getD 0))

/-! ### Missing is not zero -/

theorem none_ne_some_zero : (none : Cell) ≠ some 0 := by simp

@[simp] theorem sumValid_nil : sumValid [] = 0 := rfl
@[simp] theorem countValid_nil : countValid [] = 0 := rfl

@[simp] theorem sumValid_none (s : List Cell) : sumValid (none :: s) = sumValid s := by
  simp [sumValid]

@[simp] theorem countValid_none (s : List Cell) : countValid (none :: s) = countValid s := by
  simp [countValid]

@[simp] theorem sumValid_some (v : Nat) (s : List Cell) :
    sumValid (some v :: s) = v + sumValid s := by
  simp [sumValid]

@[simp] theorem countValid_some (v : Nat) (s : List Cell) :
    countValid (some v :: s) = countValid s + 1 := by
  simp [countValid]

/-- A missing cell is not counted, whereas an observed zero is counted. -/
theorem missing_not_counted_as_zero (s : List Cell) :
    countValid (none :: s) ≠ countValid (some 0 :: s) := by
  simp

/-- Valid plus missing cells account for every cell. -/
theorem count_partition (s : List Cell) : countValid s + countMissing s = s.length := by
  induction s with
  | nil => rfl
  | cons c s ih =>
    cases c <;> simp [countValid, countMissing] at * <;> omega

/-- Zero imputation turns every cell into an observation, so it changes the count
    whenever any cell is missing. -/
theorem imputeZero_count (s : List Cell) : countValid (imputeZero s) = s.length := by
  induction s with
  | nil => rfl
  | cons c s ih => cases c <;> simp_all [imputeZero, countValid]

theorem imputeZero_changes_count (s : List Cell) (h : 0 < countMissing s) :
    countValid (imputeZero s) ≠ countValid s := by
  have h1 := count_partition s
  have h2 := imputeZero_count s
  omega

/-- Zero imputation leaves the sum alone but inflates the count; hence it biases any
    mean downward.  Here: the sum is unchanged. -/
theorem imputeZero_sum (s : List Cell) : sumValid (imputeZero s) = sumValid s := by
  induction s with
  | nil => rfl
  | cons c s ih => cases c <;> simp_all [imputeZero, sumValid]

/-! ### Count contract 0..200 -/

theorem count_le_length (s : List Cell) : countValid s ≤ s.length := by
  have := count_partition s; omega

theorem countValid_le_200_of_length (s : List Cell) (h : s.length ≤ 200) :
    countValid s ≤ 200 := Nat.le_trans (count_le_length s) h

/-- Every in-contract observed cell is at most 200. -/
theorem sumValid_le (s : List Cell) (h : AllOk s) : sumValid s ≤ 200 * countValid s := by
  induction s with
  | nil => simp
  | cons c s ih =>
    have hs : AllOk s := fun x hx => h x (List.mem_cons_of_mem _ hx)
    have hc : CellOk c := h c (List.mem_cons_self ..)
    have := ih hs
    cases c with
    | none => simpa using this
    | some v =>
      have hv : v ≤ 200 := hc v rfl
      simp
      omega

/-- Mean over valid cells is in 0..200: sum <= 200 * count (and 0 <= sum since Nat).
    Stated without division: for count > 0, the mean sum/count is at most 200. -/
theorem mean_bounds (s : List Cell) (h : AllOk s) :
    0 ≤ sumValid s ∧ sumValid s ≤ 200 * countValid s :=
  ⟨Nat.zero_le _, sumValid_le s h⟩

/-- A typed version of the contract: `Fin 201` cells are in contract by construction. -/
theorem fin201_ok (x : Fin 201) : CellOk (some x.val) := by
  intro v hv
  cases hv
  exact Nat.le_of_lt_succ x.isLt

/-! ### Network Z precondition -/

/-- Centered integer sum over observed cells: S = sum (x - 100) = sum x - 100 n. -/
def centeredSum (s : List Cell) : Int := (sumValid s : Int) - 100 * (countValid s : Int)

/-- Network Z is defined only for nonempty valid set V_t.  We expose Z^2 = S^2 / (50 n)
    as a rational (sqrt avoided), and return `none` when n = 0 (never divide by zero). -/
def networkZ2 (s : List Cell) : Option Rat :=
  if countValid s = 0 then none
  else some (((centeredSum s) ^ 2 : Int) / (50 * (countValid s : Int) : Int))

theorem networkZ2_isSome_iff (s : List Cell) : (networkZ2 s).isSome ↔ 0 < countValid s := by
  unfold networkZ2
  split <;> simp_all [Nat.pos_iff_ne_zero]

theorem networkZ2_none_of_all_missing (n : Nat) : networkZ2 (List.replicate n none) = none := by
  have : countValid (List.replicate n (none : Cell)) = 0 := by
    induction n with
    | zero => rfl
    | succ k ih => simp [List.replicate_succ, ih]
  simp [networkZ2, this]

/-! ### Permutation invariance of device aggregates -/

/-- Reordering devices (cells travel with their identity) does not change the sum. -/
theorem sumValid_perm {a b : List Cell} (h : a.Perm b) : sumValid a = sumValid b := by
  unfold sumValid
  exact (h.filterMap id).sum_nat

theorem countValid_perm {a b : List Cell} (h : a.Perm b) : countValid a = countValid b := by
  unfold countValid
  exact (h.filterMap id).length_eq

theorem countMissing_perm {a b : List Cell} (h : a.Perm b) : countMissing a = countMissing b := by
  unfold countMissing
  exact (h.filter _).length_eq

theorem centeredSum_perm {a b : List Cell} (h : a.Perm b) : centeredSum a = centeredSum b := by
  unfold centeredSum
  rw [sumValid_perm h, countValid_perm h]

theorem networkZ2_perm {a b : List Cell} (h : a.Perm b) : networkZ2 a = networkZ2 b := by
  unfold networkZ2
  rw [countValid_perm h, centeredSum_perm h]

/-- Same, when each cell carries a device id and the permutation moves (id, cell) pairs. -/
theorem sumValid_perm_ids {a b : List (Nat × Cell)} (h : a.Perm b) :
    sumValid (a.map Prod.snd) = sumValid (b.map Prod.snd) :=
  sumValid_perm (h.map _)

end Egg
