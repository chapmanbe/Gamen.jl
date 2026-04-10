# Bug: KD Tableau Incorrectly Closes Branches on SplitRule

## Summary

The tableau prover in Gamen.jl has a bug in `_apply_all_rules` (file `src/tableaux.jl`, lines 683-685) that causes it to falsely report consistent formula sets as inconsistent. The bug is triggered when a `SplitRule` (from `Or`, `Implies`, or `Iff`) produces one branch that adds no new formulas to the tableau — the open branch is discarded and only the (potentially closing) alternative is kept.

This is a soundness bug: the tableau reports unsatisfiability for formulas that have obvious models.

## Reproduction

```julia
using Gamen
p, q = Atom(:p), Atom(:q)

# All of these are satisfiable but the tableau reports inconsistent:
tableau_consistent(TABLEAU_KD, Formula[Implies(p, q), Not(q)])       # false — WRONG (p=F, q=F)
tableau_consistent(TABLEAU_KD, Formula[Or(Not(p), q), Not(q)])       # false — WRONG (p=F, q=F)
tableau_consistent(TABLEAU_KD, Formula[Implies(p, q), p])            # false — WRONG (p=T, q=T)
tableau_consistent(TABLEAU_KD, Formula[Or(p, q), Not(q)])            # false — WRONG (p=T, q=F)
tableau_consistent(TABLEAU_KD, Formula[p, Or(p, q), Not(q)])         # false — WRONG (p=T, q=F)

# The same formulas individually are consistent:
tableau_consistent(TABLEAU_KD, Formula[Implies(p, q)])               # true
tableau_consistent(TABLEAU_KD, Formula[Not(q)])                      # true
```

The bug also affects modal formulas:

```julia
# Clinical guideline example:
# G4: "Thrombolytics must not be given IF active bleeding"
# G7: "Patients with STEMI must receive thrombolytics"
g4 = Implies(Atom(:active_bleeding), Box(Not(Atom(:thrombolytic))))
g7 = Box(Atom(:thrombolytic))
tableau_consistent(TABLEAU_KD, Formula[g4, g7])  # false — WRONG
# Satisfiable: set active_bleeding=false, thrombolytic=true in all accessible worlds
```

## Root Cause

In `_apply_all_rules` (src/tableaux.jl), the `SplitRule` handling at lines 679-686:

```julia
left  = _add_unique(branch, result.left)
right = _add_unique(branch, result.right)
# If both branches are identical to parent, all conclusions already present
(left == branch && right == branch) && continue
# If one side is same as parent (already saturated), only return changed side
left  == branch && return [right]    # ← BUG: discards the open left arm
right == branch && return [left]     # ← BUG: discards the open right arm
return [left, right]
```

When one arm of a split adds formulas that are already present on the branch (`left == branch`), the code treats this as "already saturated" and returns only the other arm. But this is incorrect — the unchanged branch **is** the open arm of the split. Discarding it loses the satisfying model.

## Trace: `{p → q, ¬q}`

1. Start: branch = `{1T(p→q), 1T(¬q)}`
2. Process `T(¬q)` → StackRule adds `F(q)` → branch = `{1T(p→q), 1T(¬q), 1F(q)}`
3. Process `T(p→q)` → SplitRule: left = `{1F(p)}`, right = `{1T(q)}`
   - left branch: add `F(p)` → `{1T(p→q), 1T(¬q), 1F(q), 1F(p)}` — **different from parent, OPEN** (model: p=F, q=F)
   - right branch: add `T(q)` → `{1T(p→q), 1T(¬q), 1F(q), 1T(q)}` — has T(q) and F(q) → **CLOSED**
   - Both are different from parent → returns `[left, right]` → **CORRECT in this case**

Wait — this trace suggests both arms are returned. Let me re-examine...

Actually, the first formula processed is `T(p→q)` (it comes first in the list). At that point, `F(q)` has not yet been added:

1. Start: branch = `{1T(p→q), 1T(¬q)}`
2. Process `T(p→q)` → SplitRule: left = `{1F(p)}`, right = `{1T(q)}`
   - left branch: `{1T(p→q), 1T(¬q), 1F(p)}` — different → ok
   - right branch: `{1T(p→q), 1T(¬q), 1T(q)}` — different → ok
   - Returns `[left, right]`
3. branches = `[left, right]`
4. Process left: `{1T(p→q), 1T(¬q), 1F(p)}`
   - Process `T(p→q)` → SplitRule: left2 = `{1F(p)}`, right2 = `{1T(q)}`
     - left2: add `F(p)` → **already present** → left2 == branch
     - right2: add `T(q)` → `{1T(p→q), 1T(¬q), 1F(p), 1T(q)}`
     - **left2 == branch → return [right2] only** ← discards the open branch!
   - branches[0] is replaced by right2: `{1T(p→q), 1T(¬q), 1F(p), 1T(q)}`
5. Process right2: `{1T(p→q), 1T(¬q), 1F(p), 1T(q)}`
   - Process `T(¬q)` → adds `F(q)` → now has T(q) and F(q) → **CLOSED**
6. Process right (original): `{1T(p→q), 1T(¬q), 1T(q)}`
   - Process `T(¬q)` → adds `F(q)` → has T(q) and F(q) → **CLOSED**
7. All branches closed → **falsely reports inconsistent**

The bug is that step 4 re-processes `T(p→q)` on a branch that already has `F(p)` from the first application of that split. Since `F(p)` is the left arm and is already present, the code discards the current (open) branch and replaces it with only the right arm (which then closes).

## Suggested Fix

The simplest correct fix is to **not discard unchanged arms**. Replace lines 683-685:

```julia
# BEFORE (buggy):
left  == branch && return [right]
right == branch && return [left]

# AFTER (correct):
# If one arm adds nothing, the split has already been partially applied.
# The unchanged arm IS the open branch — do not discard it.
# Skip this formula; it's already fully applied on this branch.
left  == branch && right == branch && continue  # (line 682, already correct)
left  == branch && continue   # left arm already present, branch is open for it
right == branch && continue   # right arm already present, branch is open for it
```

However, this `continue` approach means the right/left arm is never explored as a separate branch. That's fine if the other arm's formulas are never needed — but in general, both arms should be explored.

A more robust fix: **track which formulas have already been expanded** so the same SplitRule is not re-applied to a branch that already contains one of its arms. This is the standard approach in tableau implementations (marking formulas as "used").

The cleanest fix would be to add a `used::Set{Int}` or `expanded::BitSet` to `TableauBranch` that records which formula indices have had their rules applied. When re-scanning formulas, skip any that are already marked as used.

## Alternative Fix: Deduplication Guard

Another approach: when processing a SplitRule, check if the formula has already been split on this branch. If the branch already contains one arm of the split, the split was already applied — skip it:

```julia
elseif result isa SplitRule
    left  = _add_unique(branch, result.left)
    right = _add_unique(branch, result.right)
    (left == branch && right == branch) && continue
    # If one arm is already present, the other arm was explored
    # in a sibling branch. This branch is the survivor — leave it alone.
    (left == branch || right == branch) && continue
    return [left, right]
end
```

This is safe because:
- If `left == branch`, the left arm's formulas are already on this branch from a previous split. The right arm was sent to a separate branch. This branch survives as the left-arm case.
- The `continue` skips re-splitting, preventing the discarded-branch bug.

## Impact on This Project

This bug affects any consistency check involving conditional formulas — which is central to clinical guideline validation. Conditional prohibitions like "must not X **if** Y" are common in guidelines:

- "Thrombolytics must not be given if active bleeding" + "Patients with STEMI must receive thrombolytics" → falsely reported as inconsistent
- Any guideline pair where one has a conditional and the other is unconditional

**Workaround**: Use semantic evaluation (`satisfies`) on explicit Kripke models instead of `tableau_consistent` for conditional formulas. This works correctly but requires constructing the model manually.

## Affected Systems

The bug is in the core `_apply_all_rules` function, so it affects all tableau systems: `TABLEAU_K`, `TABLEAU_KT`, `TABLEAU_KD`, `TABLEAU_KB`, `TABLEAU_K4`, `TABLEAU_S4`, `TABLEAU_S5`.

## Test Cases for Validation

After fixing, these should all return `true`:

```julia
p, q = Atom(:p), Atom(:q)

# Propositional
@test tableau_consistent(TABLEAU_K, Formula[Implies(p, q), Not(q)])
@test tableau_consistent(TABLEAU_K, Formula[Implies(p, q), p])
@test tableau_consistent(TABLEAU_K, Formula[Or(p, q), Not(q)])
@test tableau_consistent(TABLEAU_K, Formula[Or(p, q), Not(p)])
@test tableau_consistent(TABLEAU_K, Formula[p, Or(p, q), Not(q)])

# Modal with conditional
@test tableau_consistent(TABLEAU_KD, Formula[Implies(p, Box(Not(q))), Box(q)])
@test tableau_consistent(TABLEAU_KD, Formula[Implies(p, Box(q)), Not(p)])
```
