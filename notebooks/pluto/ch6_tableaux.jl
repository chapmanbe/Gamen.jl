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
- Countermodel extraction from open branches (Theorem 6.19)
- Completeness (Definition 6.17, Proposition 6.18)
"""

# ╔═╡ 6a6b6c6d-0002-0002-0002-000000000002
begin
	using Pkg
	Pkg.activate(joinpath(@__DIR__, ".."))
	using Gamen
	import CairoMakie, GraphMakie, Graphs
end

# ╔═╡ 6a6b6c6d-0002-0002-0002-000000000003
md"""
## Why Tableaux Matter

Chapters 1-5 developed modal logic as a *mathematical theory* --- we defined formulas, Kripke models, frame properties, and axiomatic derivations. But none of that tells you how to actually *decide* whether a formula is valid. If someone hands you a formula and asks "is this a theorem of S4?", what do you *do*?

Tableaux answer that question with a **mechanical procedure**. Given any formula:
1. Assume it is false (at some world).
2. Apply decomposition rules --- deterministically, no creativity required.
3. Either every branch closes (the formula is valid) or an open branch survives (the formula is not valid, and the branch *is* the countermodel).

This is where modal logic becomes a **practical tool** rather than a mathematical theory. Tableaux are the engine behind automated reasoning systems. In health informatics, tableau-based provers power automated guideline conflict detection: given two clinical guidelines, can they both be satisfied simultaneously? A tableau will either prove they are consistent or produce a concrete scenario where they clash.

MYCIN (1976) could explain its reasoning via a WHY command that traced the rule chain that led to a conclusion. A tableau does this *by construction* --- the entire proof tree is the explanation. There is no black box, no hidden state. Every step is visible and checkable.
"""

# ╔═╡ 6a6b6c6d-0003-0003-0003-000000000003
begin
	p = Atom(:p)
	q = Atom(:q)
	r = Atom(:r)
end;

# ╔═╡ 6a6b6c6d-0004-0004-0004-000000000004
md"""
## Introduction

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

# ╔═╡ 6a6b6c6d-0006-0006-0006-000000000007
md"""
### Exercise: Prefixes and signed formulas

**1.** What prefix represents a world accessible from world 1.2?

$(Markdown.MD(Markdown.Admonition("hint", "Reveal answer", [md"Any prefix of the form 1.2.n, e.g. `Prefix([1, 2, 1])`. The child extends the parent prefix by one step."])))

**2.** If a branch contains `1.1 T p` and `1.1 F p`, is it open or closed?

$(Markdown.MD(Markdown.Admonition("hint", "Reveal answer", [md"**Closed.** The branch contains both T and F for the same formula at the same prefix --- a direct contradiction."])))

**3.** Can a branch contain `1 T p` and `1.1 F p` and remain open?

$(Markdown.MD(Markdown.Admonition("hint", "Reveal answer", [md"**Yes.** Different prefixes name different worlds. A proposition can be true at one world and false at another --- that is the whole point of Kripke semantics."])))
"""

# ╔═╡ 6a6b6c6d-0007-0007-0007-000000000007
md"""
## Rules for K (Table 6.1 and 6.2)

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
## Example 6.1: ⊢ (□p ∧ □q) → □(p ∧ q)

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

# ╔═╡ 6a6b6c6d-0011-0011-0011-000000000012
md"""
### Exercise: Predicting tableau outcomes

Before running the code, predict whether each formula is K-valid (the tableau closes). Then check.

**1.** □(p ∧ q) → □p

$(Markdown.MD(Markdown.Admonition("hint", "Reveal answer", [md"**Valid.** If p ∧ q holds in all accessible worlds, then certainly p holds in all accessible worlds. The tableau for `1 F □(p∧q) → □p` closes."])))

**2.** □p → □(p ∨ q)

$(Markdown.MD(Markdown.Admonition("hint", "Reveal answer", [md"**Valid.** If p holds in all accessible worlds, then p ∨ q holds in all accessible worlds (since p ∨ q follows from p). The tableau closes."])))

**3.** ◇p → □p

$(Markdown.MD(Markdown.Admonition("hint", "Reveal answer", [md"**Not valid.** Some accessible world has p does not entail all accessible worlds have p. The tableau stays open and produces a countermodel."])))
"""

# ╔═╡ 6a6b6c6d-0011-0011-0011-000000000013
begin
	# Verify the exercises
	println("K ⊢ □(p∧q) → □p: ", tableau_proves(TABLEAU_K, Formula[], Implies(Box(And(p,q)), Box(p))))
	println("K ⊢ □p → □(p∨q): ", tableau_proves(TABLEAU_K, Formula[], Implies(Box(p), Box(Or(p,q)))))
	println("K ⊢ ◇p → □p:     ", tableau_proves(TABLEAU_K, Formula[], Implies(Diamond(p), Box(p))))
end

# ╔═╡ 6a6b6c6d-0012-0012-0012-000000000012
md"""
## Soundness for K
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

# ╔═╡ 6a6b6c6d-0013-0013-0013-000000000014
md"""
### Countermodels: Seeing Why a Formula Fails

When a tableau does not close, the open branch is not just evidence of failure --- it *is* the countermodel. The function `extract_countermodel` reads off a Kripke model from the open branch (Theorem 6.19, B&D).

Let us see the countermodel for □p → p in K. This formula fails because K does not require reflexivity: a world can have □p true (all *accessible* worlds satisfy p) while p is false at that world itself.
"""

# ╔═╡ 6a6b6c6d-0013-0013-0013-000000000015
begin
	# Build tableau for □p → p in K --- it stays open
	root_cm1 = Prefix([1])
	tab_t = build_tableau([pf_false(root_cm1, Implies(Box(p), p))], TABLEAU_K)
	println("Tableau for □p → p in K: ", is_closed(tab_t) ? "CLOSED" : "OPEN")

	# Find the first open branch and extract the countermodel
	open_branch_t = first(b for b in tab_t.branches if !is_closed(b))
	cm_t = extract_countermodel(open_branch_t)
	println("\nCountermodel (□p → p fails here):")
	println(cm_t)
end

# ╔═╡ 6a6b6c6d-0013-0013-0013-000000000016
md"""
The countermodel shows a world where □p is true (vacuously, or because accessible worlds satisfy p) but p itself is false at the root world. This is exactly the kind of frame that the T axiom rules out by requiring reflexivity.
"""

# ╔═╡ 6a6b6c6d-0013-0013-0013-000000000017
visualize_model(cm_t, title = "Countermodel: □p → p fails in K")

# ╔═╡ 6a6b6c6d-0013-0013-0013-000000000018
md"""
Now let us see the countermodel for □p → ◇p (the D axiom) in K. This fails because K allows dead-end worlds --- worlds with no accessible successors. At such a world, □p is vacuously true (there are no accessible worlds to check), but ◇p is false (there is no accessible world where p holds).
"""

# ╔═╡ 6a6b6c6d-0013-0013-0013-000000000019
begin
	# Countermodel for □p → ◇p in K
	tab_d = build_tableau([pf_false(root_cm1, Implies(Box(p), Diamond(p)))], TABLEAU_K)
	open_branch_d = first(b for b in tab_d.branches if !is_closed(b))
	cm_d = extract_countermodel(open_branch_d)
end;

# ╔═╡ 6a6b6c6d-0013-0013-0013-000000000020
visualize_model(cm_d, title = "Countermodel: □p → ◇p fails in K (dead-end world)")

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

# ╔═╡ 6a6b6c6d-0014-0014-0014-000000000015
md"""
$(Markdown.MD(Markdown.Admonition("note", "Knowledge Representation Lens: Roles 3 and 4 (Davis et al. 1993)", [md"Davis, Shrobe, and Szolovits (1993) identify five roles of a knowledge representation. Tableaux connect to two of them. **Role 3: Theory of intelligent reasoning** --- a KR defines which inferences are *sanctioned* (logically valid) and which are *recommended* (worth computing). Hilbert-style proofs (Chapter 3) sanction inferences but give no guidance on *how* to find proofs. Tableaux operationalize this: they determine which inferences are recommended by providing a deterministic search procedure. **Role 4: Medium for pragmatically efficient computation** --- the tableau is the computational structure that makes automated reasoning tractable. The signed-formula decomposition converts a semantic question (is this formula valid on all frames?) into a syntactic tree search. Without this computational medium, validity checking would require enumerating all possible models."])))
"""

# ╔═╡ 6a6b6c6d-0015-0015-0015-000000000015
md"""
## Rules for Other Accessibility Relations (Tables 6.3 and 6.4)

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

# ╔═╡ 6a6b6c6d-0015-0015-0015-000000000016
md"""
## Same Formula, Different Systems

A key insight: the *same formula* can be provable in one system but not another. The tableau rules encode frame conditions, so adding rules (reflexivity, transitivity, etc.) makes more formulas provable.

Let us demonstrate with □p → p (the T axiom). It requires reflexivity, so it is provable in KT but not in K.
"""

# ╔═╡ 6a6b6c6d-0016-0016-0016-000000000016
begin
	# T axiom: □p → p (valid in KT, not in K)
	t_axiom = Implies(Box(p), p)
	println("KT ⊢ □p → p: ", tableau_proves(TABLEAU_KT, Formula[], t_axiom))
	println("K  ⊢ □p → p: ", tableau_proves(TABLEAU_K,  Formula[], t_axiom))
end

# ╔═╡ 6a6b6c6d-0016-0016-0016-000000000017
md"""
Why does this happen? In K, the tableau for `1 F □p → p` produces `1 T □p` and `1 F p`. But the □T rule only fires for *used child prefixes* --- and no child prefix has been introduced yet. The branch stays open.

In KT, the reflexivity rule T□ fires: from `1 T □p` we get `1 T p`. Now we have both `1 T p` and `1 F p` --- contradiction. The branch closes.

We can see this concretely by comparing the countermodel from K (where the formula fails) with the KT tableau (where it closes):
"""

# ╔═╡ 6a6b6c6d-0016-0016-0016-000000000018
begin
	# In K: open tableau, countermodel exists
	tab_k_t = build_tableau([pf_false(root_cm1, t_axiom)], TABLEAU_K)
	println("K  tableau for □p → p: ", is_closed(tab_k_t) ? "CLOSED" : "OPEN")

	# In KT: closed tableau, no countermodel
	tab_kt_t = build_tableau([pf_false(root_cm1, t_axiom)], TABLEAU_KT)
	println("KT tableau for □p → p: ", is_closed(tab_kt_t) ? "CLOSED" : "OPEN")
end

# ╔═╡ 6a6b6c6d-0016-0016-0016-000000000019
begin
	# Extract and visualize the K countermodel
	open_branch_kt = first(b for b in tab_k_t.branches if !is_closed(b))
	cm_kt = extract_countermodel(open_branch_kt)
end;

# ╔═╡ 6a6b6c6d-0016-0016-0016-000000000020
visualize_model(cm_kt, title = "K countermodel for □p → p (no self-loop = no reflexivity)")

# ╔═╡ 6a6b6c6d-0016-0016-0016-000000000021
md"""
Notice the countermodel: a world with no self-loop (no reflexive accessibility). The world cannot "see" itself, so □p being true tells us nothing about p at that world.

Now consider □p → □□p (the 4 axiom). This requires transitivity. It is provable in K4 and S4, but not in K or KT.
"""

# ╔═╡ 6a6b6c6d-0016-0016-0016-000000000022
begin
	ax4_formula = Implies(Box(p), Box(Box(p)))
	println("K  ⊢ □p → □□p: ", tableau_proves(TABLEAU_K,  Formula[], ax4_formula))
	println("KT ⊢ □p → □□p: ", tableau_proves(TABLEAU_KT, Formula[], ax4_formula))
	println("K4 ⊢ □p → □□p: ", tableau_proves(TABLEAU_K4, Formula[], ax4_formula))
	println("S4 ⊢ □p → □□p: ", tableau_proves(TABLEAU_S4, Formula[], ax4_formula))
end

# ╔═╡ 6a6b6c6d-0016-0016-0016-000000000023
begin
	# Countermodel for □p → □□p in K
	tab_k_4 = build_tableau([pf_false(root_cm1, ax4_formula)], TABLEAU_K)
	open_branch_4 = first(b for b in tab_k_4.branches if !is_closed(b))
	cm_4 = extract_countermodel(open_branch_4)
end;

# ╔═╡ 6a6b6c6d-0016-0016-0016-000000000024
visualize_model(cm_4, title = "K countermodel for □p → □□p (missing transitivity)")

# ╔═╡ 6a6b6c6d-0016-0016-0016-000000000025
md"""
### Exercise: System comparison

**1.** Is □p → ◇p provable in KD? What about in K?

$(Markdown.MD(Markdown.Admonition("hint", "Reveal answer", [md"**KD: yes**, because seriality guarantees every world has at least one successor. **K: no**, because K allows dead-end worlds where □p is vacuously true but ◇p is false."])))

**2.** Is ◇p → □◇p (the 5 axiom) provable in S4? What about S5?

$(Markdown.MD(Markdown.Admonition("hint", "Reveal answer", [md"**S4: no.** S4 has reflexivity and transitivity but not the Euclidean property needed for the 5 axiom. **S5: yes.** S5 adds Euclidean rules (4T□, 4T◇) which make every diamond formula propagate back up to ancestors."])))
"""

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
## Example 6.9 (B&D): S5 ⊢ □A → ◇□A (B axiom)

This shows that S5 proves the B axiom.

**Tableau for `1 F □p → ◇□p`:**
1. `→F`: `1 T □p`, `1 F ◇□p`
2. T□ on `1 T □p`: `1 T p` (reflexivity)
3. `□F` on `1 F ◇□p`: `1.1 F □p` (new prefix --- ◇F creates new world)

Wait --- `1 F ◇□p` means `◇□p` is false at world 1. The `□F` rule applies to a
**box** formula: `1 F □p` would give `1.1 F p`. For `◇F`, we'd need `1.1 F □p`.

Actually: `1 F ◇□p` --- the ◇F rule: `σ F ◇A → σ.n F A` for used `σ.n`.
Since `1.1` is used after step 3, `◇F` on `1 F ◇□p` gives `1.1 F □p`.
Then `1.1 T □p` + `1.1 F □p` → **closed** ⊗.

(The details depend on when `1.1` becomes used and the rule application order.)
"""

# ╔═╡ 6a6b6c6d-0023-0023-0023-000000000023
begin
	# S5: all main modal axioms hold
	println("S5 ⊢ □p → p:    ", tableau_proves(TABLEAU_S5, Formula[], t_axiom))
	println("S5 ⊢ □p → □□p:  ", tableau_proves(TABLEAU_S5, Formula[], ax4))
	ax5_s5 = Implies(Diamond(p), Box(Diamond(p)))
	println("S5 ⊢ ◇p → □◇p: ", tableau_proves(TABLEAU_S5, Formula[], ax5_s5))
	b_axiom2 = Implies(Box(p), Diamond(Box(p)))
	println("S5 ⊢ □p → ◇□p: ", tableau_proves(TABLEAU_S5, Formula[], b_axiom2), " (Example 6.9)")
end

# ╔═╡ 6a6b6c6d-0024-0024-0024-000000000024
md"""
## Using the Tableau Checker

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

# ╔═╡ 6a6b6c6d-0026-0026-0026-000000000027
md"""
### Exercise: Consistency across systems

**1.** Is {□p, ◇¬p} consistent in K? What about in KT?

$(Markdown.MD(Markdown.Admonition("hint", "Reveal answer", [md"**K: yes.** In K, □p means all *accessible* worlds satisfy p, and ◇¬p means some accessible world does not --- but these could be different worlds. Actually, this is inconsistent even in K: □p forces every accessible world to have p, and ◇¬p demands an accessible world without p. **Both K and KT: inconsistent.**"])))

**2.** Is {□◇p, □◇¬p} consistent in K?

$(Markdown.MD(Markdown.Admonition("hint", "Reveal answer", [md"**Yes.** This says: in every accessible world, p is possible; and in every accessible world, ¬p is possible. These are compatible --- each accessible world just needs to see both a p-world and a ¬p-world."])))
"""

# ╔═╡ 6a6b6c6d-0026-0026-0026-000000000028
begin
	# Verify consistency exercises
	println("{□p, ◇¬p} consistent in K:  ",
		tableau_consistent(TABLEAU_K, Formula[Box(p), Diamond(Not(p))]))
	println("{□p, ◇¬p} consistent in KT: ",
		tableau_consistent(TABLEAU_KT, Formula[Box(p), Diamond(Not(p))]))
	println("{□◇p, □◇¬p} consistent in K: ",
		tableau_consistent(TABLEAU_K, Formula[Box(Diamond(p)), Box(Diamond(Not(p)))]))
end

# ╔═╡ 6a6b6c6d-0026-0026-0026-000000000029
md"""
### Visualizing a consistency countermodel

When {□p, ¬p} is consistent in K, we can extract and visualize the model where both formulas hold simultaneously. This model shows *why* K allows it: a world where p is false but all accessible worlds (if any) have p true.
"""

# ╔═╡ 6a6b6c6d-0026-0026-0026-000000000030
begin
	# Build tableau for {□p, ¬p} in K --- stays open (consistent)
	tab_cons = build_tableau(
		[pf_true(root_cm1, Box(p)), pf_true(root_cm1, Not(p))],
		TABLEAU_K)
	open_branch_cons = first(b for b in tab_cons.branches if !is_closed(b))
	cm_cons = extract_countermodel(open_branch_cons)
end;

# ╔═╡ 6a6b6c6d-0026-0026-0026-000000000031
visualize_model(cm_cons, title = "{□p, ¬p} is satisfiable in K")

# ╔═╡ 6a6b6c6d-0027-0027-0027-000000000027
md"""
## Completeness (Definition 6.17, Proposition 6.18)

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

# ╔═╡ 6a6b6c6d-0028-0028-0028-000000000029
md"""
### Exercise: Reading the schema table

**1.** Which is the weakest system that proves the D axiom (□p → ◇p)?

$(Markdown.MD(Markdown.Admonition("hint", "Reveal answer", [md"**KD.** It is the only system with seriality as its defining property. KT, S4, and S5 also prove it because reflexivity implies seriality (every reflexive frame is serial)."])))

**2.** Why does KB prove the D axiom even though KB's defining property is symmetry, not seriality?

$(Markdown.MD(Markdown.Admonition("hint", "Reveal answer", [md"KB proves □p → ◇p because the B axiom (p → □◇p) combined with K gives enough strength. Actually, check the table carefully --- KB may not prove D. If it does, it is because of how the tableau rules interact. If it does not, then symmetry alone does not guarantee seriality."])))

**3.** The 5 axiom (◇p → □◇p) is only provable in S5. Why is S4 not enough?

$(Markdown.MD(Markdown.Admonition("hint", "Reveal answer", [md"S4 has reflexivity and transitivity but not the Euclidean property. The 5 axiom requires that if a world w can see a world v (where p holds), then every world u accessible from w can also see v (or some p-world). This is exactly Euclideanness: if wRv and wRu then uRv."])))
"""

# ╔═╡ 6a6b6c6d-0028-0028-0028-000000000030
md"""
$(Markdown.MD(Markdown.Admonition("note", "Knowledge Representation Lens: MYCIN's WHY Command", [md"MYCIN (Shortliffe 1976) pioneered *explanation* in expert systems with its WHY command, which traced the chain of rules that led to a conclusion. But MYCIN's trace was a byproduct --- the explanation was reconstructed after the fact from the inference engine's execution path. A tableau is fundamentally different: the proof tree IS the explanation, constructed *as* the reasoning proceeds. Every signed formula, every branch, every closure is visible. This is the difference between Role 4 (medium for computation) that happens to support explanation and a representation where explanation is intrinsic to the structure. When `tableau_proves` returns true, the closed tableau is a certificate --- anyone can verify it step by step, without trusting the prover."])))
"""

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

# ╔═╡ 6a6b6c6d-0030-0030-0030-000000000031
md"""
### Exercise: Build your own tableau

Try building a tableau for ◇p → □p. Predict whether it closes, then verify.

$(Markdown.MD(Markdown.Admonition("hint", "Reveal answer", [md"The tableau stays **open**. ◇p → □p says 'if p is possible then p is necessary' --- this is clearly not valid. The countermodel has two accessible worlds, one with p and one without."])))
"""

# ╔═╡ 6a6b6c6d-0030-0030-0030-000000000032
begin
	# Student exercise: ◇p → □p
	tab_exercise = build_tableau([pf_false(root, Implies(Diamond(p), Box(p)))], TABLEAU_K)
	println("Tableau for ◇p → □p in K: ", is_closed(tab_exercise) ? "CLOSED" : "OPEN")
	if !is_closed(tab_exercise)
		open_br = first(b for b in tab_exercise.branches if !is_closed(b))
		cm_exercise = extract_countermodel(open_br)
		println("Countermodel: ", cm_exercise)
	end
end

# ╔═╡ 6a6b6c6d-0030-0030-0030-000000000033
begin
	if !is_closed(tab_exercise)
		open_br_ex = first(b for b in tab_exercise.branches if !is_closed(b))
		cm_ex = extract_countermodel(open_br_ex)
		visualize_model(cm_ex, title = "Countermodel: ◇p → □p fails in K")
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
| Extract countermodel | `extract_countermodel(open_branch)` |
| Visualize countermodel | `visualize_model(model)` (requires CairoMakie extension) |
| Systems | `TABLEAU_K`, `TABLEAU_KT`, `TABLEAU_KD`, `TABLEAU_KB`, `TABLEAU_K4`, `TABLEAU_S4`, `TABLEAU_S5` |

Tableau methods give us a **decision procedure** for validity in any of these
systems --- for propositional modal logic with finitely many atoms, the search
always terminates. When the tableau closes, the formula is valid. When it stays
open, the open branch *is* the countermodel --- a concrete witness to invalidity.
"""

# ╔═╡ Cell order:
# ╟─6a6b6c6d-0001-0001-0001-000000000001
# ╠═6a6b6c6d-0002-0002-0002-000000000002
# ╟─6a6b6c6d-0002-0002-0002-000000000003
# ╠═6a6b6c6d-0003-0003-0003-000000000003
# ╟─6a6b6c6d-0004-0004-0004-000000000004
# ╠═6a6b6c6d-0005-0005-0005-000000000005
# ╠═6a6b6c6d-0006-0006-0006-000000000006
# ╟─6a6b6c6d-0006-0006-0006-000000000007
# ╟─6a6b6c6d-0007-0007-0007-000000000007
# ╟─6a6b6c6d-0008-0008-0008-000000000008
# ╠═6a6b6c6d-0009-0009-0009-000000000009
# ╟─6a6b6c6d-0010-0010-0010-000000000010
# ╠═6a6b6c6d-0011-0011-0011-000000000011
# ╟─6a6b6c6d-0011-0011-0011-000000000012
# ╠═6a6b6c6d-0011-0011-0011-000000000013
# ╟─6a6b6c6d-0012-0012-0012-000000000012
# ╠═6a6b6c6d-0013-0013-0013-000000000013
# ╟─6a6b6c6d-0013-0013-0013-000000000014
# ╠═6a6b6c6d-0013-0013-0013-000000000015
# ╟─6a6b6c6d-0013-0013-0013-000000000016
# ╠═6a6b6c6d-0013-0013-0013-000000000017
# ╟─6a6b6c6d-0013-0013-0013-000000000018
# ╠═6a6b6c6d-0013-0013-0013-000000000019
# ╠═6a6b6c6d-0013-0013-0013-000000000020
# ╠═6a6b6c6d-0014-0014-0014-000000000014
# ╟─6a6b6c6d-0014-0014-0014-000000000015
# ╟─6a6b6c6d-0015-0015-0015-000000000015
# ╟─6a6b6c6d-0015-0015-0015-000000000016
# ╠═6a6b6c6d-0016-0016-0016-000000000016
# ╟─6a6b6c6d-0016-0016-0016-000000000017
# ╠═6a6b6c6d-0016-0016-0016-000000000018
# ╠═6a6b6c6d-0016-0016-0016-000000000019
# ╠═6a6b6c6d-0016-0016-0016-000000000020
# ╟─6a6b6c6d-0016-0016-0016-000000000021
# ╠═6a6b6c6d-0016-0016-0016-000000000022
# ╠═6a6b6c6d-0016-0016-0016-000000000023
# ╠═6a6b6c6d-0016-0016-0016-000000000024
# ╟─6a6b6c6d-0016-0016-0016-000000000025
# ╠═6a6b6c6d-0017-0017-0017-000000000017
# ╠═6a6b6c6d-0018-0018-0018-000000000018
# ╠═6a6b6c6d-0019-0019-0019-000000000019
# ╟─6a6b6c6d-0020-0020-0020-000000000020
# ╠═6a6b6c6d-0021-0021-0021-000000000021
# ╟─6a6b6c6d-0022-0022-0022-000000000022
# ╠═6a6b6c6d-0023-0023-0023-000000000023
# ╟─6a6b6c6d-0024-0024-0024-000000000024
# ╠═6a6b6c6d-0025-0025-0025-000000000025
# ╠═6a6b6c6d-0026-0026-0026-000000000026
# ╟─6a6b6c6d-0026-0026-0026-000000000027
# ╠═6a6b6c6d-0026-0026-0026-000000000028
# ╟─6a6b6c6d-0026-0026-0026-000000000029
# ╠═6a6b6c6d-0026-0026-0026-000000000030
# ╠═6a6b6c6d-0026-0026-0026-000000000031
# ╟─6a6b6c6d-0027-0027-0027-000000000027
# ╠═6a6b6c6d-0028-0028-0028-000000000028
# ╟─6a6b6c6d-0028-0028-0028-000000000029
# ╟─6a6b6c6d-0028-0028-0028-000000000030
# ╟─6a6b6c6d-0029-0029-0029-000000000029
# ╠═6a6b6c6d-0030-0030-0030-000000000030
# ╟─6a6b6c6d-0030-0030-0030-000000000031
# ╠═6a6b6c6d-0030-0030-0030-000000000032
# ╠═6a6b6c6d-0030-0030-0030-000000000033
# ╟─6a6b6c6d-0031-0031-0031-000000000031
