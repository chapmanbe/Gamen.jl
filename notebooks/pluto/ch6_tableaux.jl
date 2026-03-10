### A Pluto.jl notebook ###
# v0.20.4

using Markdown
using InteractiveUtils

# ╔═╡ 6a6b6c6d-0001-0001-0001-000000000001
md"""
# Chapter 6: Modal Tableaux

This notebook follows Chapter 6 of [Boxes and Diamonds](https://bd.openlogicproject.org)
using the **Gamen.jl** package.

We cover:
- Prefixed signed formulas (Definition 6.1)
- Tableau rules for K (Tables 6.1 and 6.2)
- Examples 6.1 and 6.2: closed tableaux in K
- Soundness for K (Theorem 6.6)
- Extended rules for KT, KD, KB, K4, S4, S5 (Tables 6.3 and 6.4)
- Completeness (Definition 6.17, Proposition 6.18)
"""

# ╔═╡ 6a6b6c6d-0002-0002-0002-000000000002
begin
	using Pkg
	Pkg.activate(joinpath(@__DIR__, ".."))
	using Gamen
end

# ╔═╡ 6a6b6c6d-0003-0003-0003-000000000003
begin
	p = Atom(:p)
	q = Atom(:q)
	r = Atom(:r)
end;

# ╔═╡ 6a6b6c6d-0004-0004-0004-000000000004
md"""
## 6.1 Introduction

Tableaux are downward-branching trees of *signed formulas*. For modal logic,
each formula is also *prefixed* by a sequence of positive integers naming a world.

A **prefixed signed formula** has the form `σ T A` (A is true at world σ)
or `σ F A` (A is false at world σ), where σ = 1, 1.2, 1.2.3, etc.

If σ names world w, then σ.n names a world *accessible* from w.

A branch is **closed** if it contains both σ T A and σ F A for some σ, A.
A tableau is **closed** (a proof) if every branch is closed.
"""

# ╔═╡ 6a6b6c6d-0005-0005-0005-000000000005
begin
	# Create prefixes
	σ = Prefix([1])      # the root world
	σ1 = Prefix([1, 1])  # a world accessible from root
	σ12 = Prefix([1, 2]) # another accessible world

	println("Root prefix: ", σ)
	println("Child prefix: ", σ1)
	println("extend(σ, 3): ", extend(σ, 3))
	println("parent of σ1: ", parent_prefix(σ1))
end

# ╔═╡ 6a6b6c6d-0006-0006-0006-000000000006
begin
	# Create prefixed signed formulas
	f1 = pf_true(σ, Box(Implies(p, q)))   # 1 T □(p→q)
	f2 = pf_false(σ, Implies(Box(p), Box(q)))  # 1 F (□p→□q)

	println("Formula 1: ", f1)
	println("Formula 2: ", f2)
end

# ╔═╡ 6a6b6c6d-0007-0007-0007-000000000007
md"""
## 6.2 Rules for K (Table 6.1 and 6.2)

**Propositional rules** apply to a formula at prefix σ, adding conclusions at σ.
- ¬T: `σ T ¬A` → add `σ F A`
- ¬F: `σ F ¬A` → add `σ T A`
- ∧T: `σ T A∧B` → add `σ T A`, `σ T B`
- ∧F: `σ F A∧B` → split: `σ F A | σ F B`
- ∨T: `σ T A∨B` → split: `σ T A | σ T B`
- ∨F: `σ F A∨B` → add `σ F A`, `σ F B`
- →T: `σ T A→B` → split: `σ F A | σ T B`
- →F: `σ F A→B` → add `σ T A`, `σ F B`

**Modal rules for K** use child prefixes:
- □T: `σ T □A` → add `σ.n T A` for each **used** prefix σ.n
- □F: `σ F □A` → add `σ.n F A` for a **new** prefix σ.n
- ◇T: `σ T ◇A` → add `σ.n T A` for a **new** prefix σ.n
- ◇F: `σ F ◇A` → add `σ.n F A` for each **used** prefix σ.n

The distinction "used vs. new" is essential for soundness (Definition 6.2).
"""

# ╔═╡ 6a6b6c6d-0008-0008-0008-000000000008
md"""
## 6.3 Example 6.1: ⊢ (□p ∧ □q) → □(p ∧ q)

**Assumption:** `1 F (□p ∧ □q) → □(p ∧ q)`

The tableau closes via:
1. `→F`: `1 T (□p ∧ □q)`, `1 F □(p ∧ q)`
2. `∧T`: `1 T □p`, `1 T □q`
3. `□F`: `1.1 F (p ∧ q)` (new prefix)
4. `□T` on `1 T □p` for prefix `1.1`: `1.1 T p`
5. `□T` on `1 T □q` for prefix `1.1`: `1.1 T q`
6. `∧F` on `1.1 F (p ∧ q)`: split → `1.1 F p | 1.1 F q`
   - Left branch: `1.1 T p` and `1.1 F p` → **closed** ⊗
   - Right branch: `1.1 T q` and `1.1 F q` → **closed** ⊗
"""

# ╔═╡ 6a6b6c6d-0009-0009-0009-000000000009
begin
	# Verify Example 6.1 automatically
	formula_6_1 = Implies(And(Box(p), Box(q)), Box(And(p, q)))
	result_6_1 = tableau_proves(TABLEAU_K, Formula[], formula_6_1)
	println("K ⊢ (□p ∧ □q) → □(p ∧ q): ", result_6_1)
end

# ╔═╡ 6a6b6c6d-0010-0010-0010-000000000010
md"""
## Example 6.2: ⊢ ◇(p ∨ q) → (◇p ∨ ◇q)

**Assumption:** `1 F ◇(p ∨ q) → (◇p ∨ ◇q)`

The tableau closes via:
1. `→F`: `1 T ◇(p ∨ q)`, `1 F (◇p ∨ ◇q)`
2. `∨F`: `1 F ◇p`, `1 F ◇q`
3. `◇T`: `1.1 T (p ∨ q)` (new prefix)
4. `◇F` on `1 F ◇p` for `1.1`: `1.1 F p`
5. `◇F` on `1 F ◇q` for `1.1`: `1.1 F q`
6. `∨T` on `1.1 T (p ∨ q)`: split → `1.1 T p | 1.1 T q`
   - Left: `1.1 T p` + `1.1 F p` → **closed** ⊗
   - Right: `1.1 T q` + `1.1 F q` → **closed** ⊗
"""

# ╔═╡ 6a6b6c6d-0011-0011-0011-000000000011
begin
	formula_6_2 = Implies(Diamond(Or(p, q)), Or(Diamond(p), Diamond(q)))
	result_6_2 = tableau_proves(TABLEAU_K, Formula[], formula_6_2)
	println("K ⊢ ◇(p ∨ q) → (◇p ∨ ◇q): ", result_6_2)
end

# ╔═╡ 6a6b6c6d-0012-0012-0012-000000000012
md"""
## 6.4 Soundness for K (Theorem 6.6)

The tableau method is **sound**: if there is a closed tableau for a set of
assumptions, those assumptions are unsatisfiable.

Equivalently (Corollary 6.7): if Γ ⊢ A (by tableaux), then Γ ⊨ A.

**Proof idea:** An *interpretation* maps prefixes to worlds in a model,
preserving the accessibility relation (Definition 6.3). If a branch is
satisfiable (there is a model + interpretation satisfying all formulas on it),
then applying any rule produces at least one branch that is still satisfiable.
Since closed branches are unsatisfiable, a closed tableau witnesses unsatisfiability.

**Consequence:** K does *not* prove formulas that are not K-valid.
"""

# ╔═╡ 6a6b6c6d-0013-0013-0013-000000000013
begin
	# Soundness: K does not prove □p → p (T axiom, requires reflexivity)
	not_k_thm1 = tableau_proves(TABLEAU_K, Formula[], Implies(Box(p), p))
	println("K ⊢ □p → p: ", not_k_thm1, "  (should be false)")

	# K does not prove □p → □□p (4 axiom, requires transitivity)
	not_k_thm2 = tableau_proves(TABLEAU_K, Formula[], Implies(Box(p), Box(Box(p))))
	println("K ⊢ □p → □□p: ", not_k_thm2, "  (should be false)")

	# K does not prove □p → ◇p (D axiom, requires seriality)
	not_k_thm3 = tableau_proves(TABLEAU_K, Formula[], Implies(Box(p), Diamond(p)))
	println("K ⊢ □p → ◇p: ", not_k_thm3, "  (should be false)")
end

# ╔═╡ 6a6b6c6d-0014-0014-0014-000000000014
begin
	# But K does prove schema K: □(p→q) → (□p→□q)
	schema_K = Implies(Box(Implies(p, q)), Implies(Box(p), Box(q)))
	k_thm_K = tableau_proves(TABLEAU_K, Formula[], schema_K)
	println("K ⊢ □(p→q)→(□p→□q): ", k_thm_K, "  (should be true)")

	# And the dual equivalence ¬◇¬p ↔ □p
	dual_formula = Implies(Not(Diamond(Not(p))), Box(p))
	k_thm_dual = tableau_proves(TABLEAU_K, Formula[], dual_formula)
	println("K ⊢ ¬◇¬p → □p: ", k_thm_dual, "  (should be true)")
end

# ╔═╡ 6a6b6c6d-0015-0015-0015-000000000015
md"""
## 6.5 Rules for Other Accessibility Relations (Tables 6.3 and 6.4)

For logics determined by special frame properties, we add rules that
"know" about the accessibility relation:

| Rule | Applies to | For system |
|:-----|:-----------|:-----------|
| T□: `σ T □A → σ T A` | reflexive | KT, KB, S4, S5 |
| T◇: `σ F ◇A → σ F A` | reflexive | KT, KB, S4, S5 |
| D□: `σ T □A → σ T ◇A` | serial | KD |
| D◇: `σ F ◇A → σ F □A` | serial | KD |
| B□: `σ.n T □A → σ T A` | symmetric | KB, S5 |
| B◇: `σ.n F ◇A → σ F A` | symmetric | KB, S5 |
| 4□: `σ T □A → σ.n T □A` (used) | transitive | K4, S4, S5 |
| 4◇: `σ F ◇A → σ.n F ◇A` (used) | transitive | K4, S4, S5 |
| 4T□: `σ.n T □A → σ T □A` | euclidean | S5 |
| 4T◇: `σ.n F ◇A → σ F ◇A` | euclidean | S5 |

**Table 6.4** (from B&D):

| Logic | Frame property | Extra rules |
|:------|:---------------|:------------|
| KT | Reflexive | T□, T◇ |
| KD | Serial | D□, D◇ |
| KB | Symmetric | B□, B◇ |
| K4 | Transitive | 4□, 4◇ |
| S4 = KT4 | Reflexive + transitive | T□, T◇, 4□, 4◇ |
| S5 = KT4B | Reflexive + transitive + euclidean | T□, T◇, 4□, 4◇, 4T□, 4T◇ |
"""

# ╔═╡ 6a6b6c6d-0016-0016-0016-000000000016
begin
	# T axiom: □p → p (valid in KT, not in K)
	t_axiom = Implies(Box(p), p)
	println("KT ⊢ □p → p: ", tableau_proves(TABLEAU_KT, Formula[], t_axiom))
	println("K  ⊢ □p → p: ", tableau_proves(TABLEAU_K,  Formula[], t_axiom))
end

# ╔═╡ 6a6b6c6d-0017-0017-0017-000000000017
begin
	# D axiom: □p → ◇p (valid in KD, not in K)
	d_axiom = Implies(Box(p), Diamond(p))
	println("KD ⊢ □p → ◇p: ", tableau_proves(TABLEAU_KD, Formula[], d_axiom))
	println("K  ⊢ □p → ◇p: ", tableau_proves(TABLEAU_K,  Formula[], d_axiom))
end

# ╔═╡ 6a6b6c6d-0018-0018-0018-000000000018
begin
	# B axiom: □p → ◇□p (valid in KB, not in K)
	b_axiom = Implies(Box(p), Diamond(Box(p)))
	println("KB ⊢ □p → ◇□p: ", tableau_proves(TABLEAU_KB, Formula[], b_axiom))
	println("K  ⊢ □p → ◇□p: ", tableau_proves(TABLEAU_K,  Formula[], b_axiom))
end

# ╔═╡ 6a6b6c6d-0019-0019-0019-000000000019
begin
	# 4 axiom: □p → □□p (valid in K4, not in K)
	ax4 = Implies(Box(p), Box(Box(p)))
	println("K4 ⊢ □p → □□p: ", tableau_proves(TABLEAU_K4, Formula[], ax4))
	println("K  ⊢ □p → □□p: ", tableau_proves(TABLEAU_K,  Formula[], ax4))
end

# ╔═╡ 6a6b6c6d-0020-0020-0020-000000000020
md"""
## S4: Example Proof

S4 proves the 4 axiom (□p → □□p) using the 4□ rule.

**Tableau for `1 F □p → □□p`:**
1. `→F`: `1 T □p`, `1 F □□p`
2. T□ on `1 T □p`: `1 T p` (reflexivity)
3. `□F` on `1 F □□p`: `1.1 F □p` (new prefix)
4. 4□ on `1 T □p` for `1.1`: `1.1 T □p`
5. Now `1.1 T □p` and `1.1 F □p` → **closed** ⊗
"""

# ╔═╡ 6a6b6c6d-0021-0021-0021-000000000021
begin
	# S4: T axiom + 4 axiom both hold
	println("S4 ⊢ □p → p:    ", tableau_proves(TABLEAU_S4, Formula[], t_axiom))
	println("S4 ⊢ □p → □□p:  ", tableau_proves(TABLEAU_S4, Formula[], ax4))
	# But NOT the 5 axiom
	ax5 = Implies(Diamond(p), Box(Diamond(p)))
	println("S4 ⊢ ◇p → □◇p: ", tableau_proves(TABLEAU_S4, Formula[], ax5), "  (should be false)")
end

# ╔═╡ 6a6b6c6d-0022-0022-0022-000000000022
md"""
## 6.5 Example 6.9 (B&D): S5 ⊢ □A → ◇□A (B axiom)

This shows that S5 proves the B axiom.

**Tableau for `1 F □p → ◇□p`:**
1. `→F`: `1 T □p`, `1 F ◇□p`
2. T□ on `1 T □p`: `1 T p` (reflexivity)
3. `□F` on `1 F ◇□p`: `1.1 F □p` (new prefix — ◇F creates new world)

Wait — `1 F ◇□p` means `◇□p` is false at world 1. The `□F` rule applies to a
**box** formula: `1 F □p` would give `1.1 F p`. For `◇F`, we'd need `1.1 F □p`.

Actually: `1 F ◇□p` — the ◇F rule: `σ F ◇A → σ.n F A` for used `σ.n`.
Since `1.1` is used after step 3, `◇F` on `1 F ◇□p` gives `1.1 F □p`.
Then `1.1 T □p` + `1.1 F □p` → **closed** ⊗.

(The details depend on when `1.1` becomes used and the rule application order.)
"""

# ╔═╡ 6a6b6c6d-0023-0023-0023-000000000023
begin
	# S5: all main modal axioms hold
	println("S5 ⊢ □p → p:    ", tableau_proves(TABLEAU_S5, Formula[], t_axiom))
	println("S5 ⊢ □p → □□p:  ", tableau_proves(TABLEAU_S5, Formula[], ax4))
	ax5 = Implies(Diamond(p), Box(Diamond(p)))
	println("S5 ⊢ ◇p → □◇p: ", tableau_proves(TABLEAU_S5, Formula[], ax5))
	b_axiom2 = Implies(Box(p), Diamond(Box(p)))
	println("S5 ⊢ □p → ◇□p: ", tableau_proves(TABLEAU_S5, Formula[], b_axiom2), " (Example 6.9)")
end

# ╔═╡ 6a6b6c6d-0024-0024-0024-000000000024
md"""
## 6.6 Using the Tableau Checker

The `tableau_proves(system, premises, conclusion)` function builds a complete
tableau and returns `true` if it closes.

`tableau_consistent(system, formulas)` checks if a set of formulas is satisfiable
(i.e., the tableau for `{1 T A₁, …, 1 T Aₙ}` does *not* close).
"""

# ╔═╡ 6a6b6c6d-0025-0025-0025-000000000025
begin
	# tableau_proves: check derivability
	# Is □(p ∧ q) → (□p ∧ □q) K-valid?
	formula_box_split = Implies(Box(And(p, q)), And(Box(p), Box(q)))
	println("K ⊢ □(p∧q)→(□p∧□q): ", tableau_proves(TABLEAU_K, Formula[], formula_box_split))
end

# ╔═╡ 6a6b6c6d-0026-0026-0026-000000000026
begin
	# Consistency check
	# {□p, ◇q} is satisfiable in K (no contradiction)
	println("{□p, ◇q} consistent in K: ",
		tableau_consistent(TABLEAU_K, Formula[Box(p), Diamond(q)]))

	# {p, ¬p} is never satisfiable
	println("{p, ¬p} consistent in K: ",
		tableau_consistent(TABLEAU_K, Formula[p, Not(p)]))

	# {□p, ¬p} is satisfiable in K (□p doesn't imply p without reflexivity)
	println("{□p, ¬p} consistent in K:  ",
		tableau_consistent(TABLEAU_K, Formula[Box(p), Not(p)]))

	# {□p, ¬p} is NOT satisfiable in KT (□p → p, so p ∧ ¬p)
	println("{□p, ¬p} consistent in KT: ",
		tableau_consistent(TABLEAU_KT, Formula[Box(p), Not(p)]))
end

# ╔═╡ 6a6b6c6d-0027-0027-0027-000000000027
md"""
## 6.7 Completeness (Definition 6.17, Proposition 6.18)

A branch is **complete** if:
1. For every propositional stacking rule applied to `σ S A`, the conclusion is on the branch.
2. For every propositional branching rule applied to `σ S A`, at least one conclusion is on the branch.
3. For every new-prefix rule (`□F`, `◇T`) applied to `σ S A`, at least one new prefix conclusion is present.
4. For every used-prefix rule (`□T`, `◇F`) applied to `σ S A`, the conclusion is on the branch for every used prefix.

**Proposition 6.18:** Every finite set Γ has a tableau in which every branch is complete.

This completeness result combined with soundness yields:
- If A is K-valid, then there is a closed tableau for `{1 F A}`.
- If A is not K-valid, then the systematic complete tableau has an open branch that defines a countermodel.
"""

# ╔═╡ 6a6b6c6d-0028-0028-0028-000000000028
begin
	# Summary: which schemas are provable in which systems?
	systems = [
		(TABLEAU_K,  "K"),
		(TABLEAU_KT, "KT"),
		(TABLEAU_KD, "KD"),
		(TABLEAU_KB, "KB"),
		(TABLEAU_K4, "K4"),
		(TABLEAU_S4, "S4"),
		(TABLEAU_S5, "S5"),
	]

	schemas = [
		(Implies(Box(Implies(p,q)), Implies(Box(p), Box(q))), "K: □(p→q)→(□p→□q)"),
		(Implies(Box(p), p),                                  "T: □p→p"),
		(Implies(Box(p), Diamond(p)),                         "D: □p→◇p"),
		(Implies(Box(p), Diamond(Box(p))),                    "B: □p→◇□p"),
		(Implies(Box(p), Box(Box(p))),                        "4: □p→□□p"),
		(Implies(Diamond(p), Box(Diamond(p))),                "5: ◇p→□◇p"),
	]

	println("Schema validity across systems:")
	print(rpad("", 30))
	for (_, name) in systems; print(rpad(name, 6)); end
	println()

	for (formula, schema_name) in schemas
		print(rpad(schema_name, 30))
		for (sys, _) in systems
			result = tableau_proves(sys, Formula[], formula)
			print(rpad(result ? "✓" : "·", 6))
		end
		println()
	end
end

# ╔═╡ 6a6b6c6d-0029-0029-0029-000000000029
md"""
## Building Tableaux Manually

You can inspect the tableau structure directly using `build_tableau`.
"""

# ╔═╡ 6a6b6c6d-0030-0030-0030-000000000030
begin
	# Build and inspect a tableau for K ⊢ □(p→q) → (□p→□q)
	root = Prefix([1])
	assumptions = [pf_false(root, Implies(Box(Implies(p,q)), Implies(Box(p), Box(q))))]
	tab = build_tableau(assumptions, TABLEAU_K)
	println("Tableau closed: ", is_closed(tab))
	println("Number of branches: ", length(tab.branches))
	for (i, b) in enumerate(tab.branches)
		println("Branch $i: ", is_closed(b) ? "closed" : "open",
			" ($(length(b.formulas)) formulas)")
	end
end

# ╔═╡ 6a6b6c6d-0031-0031-0031-000000000031
md"""
## Summary

| Concept | Gamen.jl |
|:--------|:---------|
| Prefix σ | `Prefix([1,2,3])`, `extend(σ, n)`, `parent_prefix(σ)` |
| Signed formula | `pf_true(σ, A)`, `pf_false(σ, A)` |
| Branch | `TableauBranch([...])`, `is_closed(b)` |
| Build tableau | `build_tableau(assumptions, system)` |
| Check derivability | `tableau_proves(system, premises, conclusion)` |
| Check consistency | `tableau_consistent(system, formulas)` |
| Systems | `TABLEAU_K`, `TABLEAU_KT`, `TABLEAU_KD`, `TABLEAU_KB`, `TABLEAU_K4`, `TABLEAU_S4`, `TABLEAU_S5` |

Tableau methods give us a **decision procedure** for validity in any of these
systems — for propositional modal logic with finitely many atoms, the search
always terminates.
"""

# ╔═╡ Cell order:
# ╠═6a6b6c6d-0001-0001-0001-000000000001
# ╠═6a6b6c6d-0002-0002-0002-000000000002
# ╠═6a6b6c6d-0003-0003-0003-000000000003
# ╠═6a6b6c6d-0004-0004-0004-000000000004
# ╠═6a6b6c6d-0005-0005-0005-000000000005
# ╠═6a6b6c6d-0006-0006-0006-000000000006
# ╠═6a6b6c6d-0007-0007-0007-000000000007
# ╠═6a6b6c6d-0008-0008-0008-000000000008
# ╠═6a6b6c6d-0009-0009-0009-000000000009
# ╠═6a6b6c6d-0010-0010-0010-000000000010
# ╠═6a6b6c6d-0011-0011-0011-000000000011
# ╠═6a6b6c6d-0012-0012-0012-000000000012
# ╠═6a6b6c6d-0013-0013-0013-000000000013
# ╠═6a6b6c6d-0014-0014-0014-000000000014
# ╠═6a6b6c6d-0015-0015-0015-000000000015
# ╠═6a6b6c6d-0016-0016-0016-000000000016
# ╠═6a6b6c6d-0017-0017-0017-000000000017
# ╠═6a6b6c6d-0018-0018-0018-000000000018
# ╠═6a6b6c6d-0019-0019-0019-000000000019
# ╠═6a6b6c6d-0020-0020-0020-000000000020
# ╠═6a6b6c6d-0021-0021-0021-000000000021
# ╠═6a6b6c6d-0022-0022-0022-000000000022
# ╠═6a6b6c6d-0023-0023-0023-000000000023
# ╠═6a6b6c6d-0024-0024-0024-000000000024
# ╠═6a6b6c6d-0025-0025-0025-000000000025
# ╠═6a6b6c6d-0026-0026-0026-000000000026
# ╠═6a6b6c6d-0027-0027-0027-000000000027
# ╠═6a6b6c6d-0028-0028-0028-000000000028
# ╠═6a6b6c6d-0029-0029-0029-000000000029
# ╠═6a6b6c6d-0030-0030-0030-000000000030
# ╠═6a6b6c6d-0031-0031-0031-000000000031
