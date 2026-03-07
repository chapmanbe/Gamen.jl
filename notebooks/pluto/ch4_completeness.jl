### A Pluto.jl notebook ###
# v0.20.4

using Markdown
using InteractiveUtils

# ╔═╡ 4a4b4c4d-0001-0001-0001-000000000001
md"""
# Chapter 4: Completeness and Canonical Models

This notebook follows Chapter 4 of [Boxes and Diamonds](https://bd.openlogicproject.org)
using the **Gamen.jl** package.

We cover:
- Subformulas and formula closure
- Derivability from sets of formulas (Definition 3.36)
- Consistency (Definition 3.39) and complete consistent sets (Definition 4.1)
- Lindenbaum's Lemma (Theorem 4.3)
- Modal operators on sets (Definition 4.5)
- Canonical model construction (Definition 4.11)
- The Truth Lemma (Proposition 4.12)
- Determination and completeness (Theorem 4.14, Corollary 4.15)
- Frame completeness (Theorem 4.16)
"""

# ╔═╡ 4a4b4c4d-0002-0002-0002-000000000002
begin
	using Pkg
	Pkg.activate(joinpath(@__DIR__, "..", ".."))
	using Gamen
end

# ╔═╡ 4a4b4c4d-0003-0003-0003-000000000003
md"""
## 4.1 Introduction

The soundness theorem (Theorem 3.31) tells us that everything derivable
in a modal system is valid. *Completeness* is the converse: every valid
formula is derivable.

The key construction is the **canonical model**, whose worlds are
*complete Σ-consistent sets* of formulas.
"""

# ╔═╡ 4a4b4c4d-0004-0004-0004-000000000004
begin
	p = Atom(:p)
	q = Atom(:q)
	r = Atom(:r)
end;

# ╔═╡ 4a4b4c4d-0005-0005-0005-000000000005
md"""
## Subformulas and Closure

Before constructing canonical models, we need tools for working with
finite languages. The `subformulas` function collects all subformulas
of a given formula.
"""

# ╔═╡ 4a4b4c4d-0006-0006-0006-000000000006
subformulas(Box(Implies(p, q)))

# ╔═╡ 4a4b4c4d-0007-0007-0007-000000000007
md"""
The `formula_closure` extends a set of formulas by adding all
subformulas and their negations. This creates a finite "language"
suitable for constructing canonical models.
"""

# ╔═╡ 4a4b4c4d-0008-0008-0008-000000000008
formula_closure([p, Box(p)])

# ╔═╡ 4a4b4c4d-0009-0009-0009-000000000009
md"""
## 4.2 Derivability and Consistency

**Derivability from a set** (Definition 3.36): Γ ⊢\_Σ A means A is derivable
from premises in Γ within system Σ. By soundness and completeness, we
can check this *semantically*: A holds at every world where all of Γ hold,
in every model of the appropriate class.
"""

# ╔═╡ 4a4b4c4d-0010-0010-0010-000000000010
begin
	# {p, p→q} ⊢_K q  (modus ponens)
	deriv_mp = is_derivable_from(SYSTEM_K, [p, Implies(p, q)], q; max_worlds=2)

	# K proves □(p→p) — necessitation of a tautology
	deriv_nec = is_derivable_from(SYSTEM_K, Formula[], Box(Implies(p, p)); max_worlds=2)

	# K does NOT prove □p→p (that requires axiom T)
	deriv_t = is_derivable_from(SYSTEM_K, Formula[], Implies(Box(p), p); max_worlds=2)

	# But KT does prove □p→p
	deriv_kt = is_derivable_from(SYSTEM_KT, Formula[], Implies(Box(p), p); max_worlds=2)

	(mp = deriv_mp, nec = deriv_nec, T_in_K = deriv_t, T_in_KT = deriv_kt)
end

# ╔═╡ 4a4b4c4d-0011-0011-0011-000000000011
md"""
**Consistency** (Definition 3.39): A set Γ is Σ-consistent iff ⊥ is not
derivable from Γ. Equivalently, there exists a model in the appropriate
class with a world satisfying all formulas in Γ.
"""

# ╔═╡ 4a4b4c4d-0012-0012-0012-000000000012
begin
	# {p, □p} is K-consistent: some model has a world where both hold
	cons_ok = is_consistent(SYSTEM_K, [p, Box(p)]; max_worlds=2)

	# {p, ¬p} is never consistent
	cons_contra = is_consistent(SYSTEM_K, [p, Not(p)]; max_worlds=2)

	# {□p, ¬p} is K-consistent (p can fail at the current world
	# while being true at all accessible worlds)
	cons_k = is_consistent(SYSTEM_K, [Box(p), Not(p)]; max_worlds=2)

	# But {□p, ¬p} is KT-inconsistent (T says □p → p)
	cons_kt = is_consistent(SYSTEM_KT, [Box(p), Not(p)]; max_worlds=2)

	(consistent = cons_ok, contradiction = cons_contra,
	 K_box_notp = cons_k, KT_box_notp = cons_kt)
end

# ╔═╡ 4a4b4c4d-0013-0013-0013-000000000013
md"""
## 4.3 Complete Σ-Consistent Sets

**Definition 4.1:** A set Γ is *complete Σ-consistent* if it is
Σ-consistent and for every formula A, either A ∈ Γ or ¬A ∈ Γ.

These are the "maximally decided" consistent sets — they settle the
truth value of every formula.
"""

# ╔═╡ 4a4b4c4d-0014-0014-0014-000000000014
begin
	lang_simple = formula_closure([p])  # {p, ¬p}

	# {p} is complete w.r.t. {p, ¬p}: it decides p (true)
	cc_p = is_complete_consistent(SYSTEM_K, [p], lang_simple; max_worlds=2)

	# {} is NOT complete: it doesn't decide p
	cc_empty = is_complete_consistent(SYSTEM_K, Formula[], lang_simple; max_worlds=2)

	# {p, ¬p} is NOT consistent
	cc_both = is_complete_consistent(SYSTEM_K, [p, Not(p)], lang_simple; max_worlds=2)

	(p_complete = cc_p, empty_complete = cc_empty, both_complete = cc_both)
end

# ╔═╡ 4a4b4c4d-0015-0015-0015-000000000015
md"""
## 4.4 Lindenbaum's Lemma

**Theorem 4.3 (Lindenbaum's Lemma):** Every Σ-consistent set can be
extended to a *complete* Σ-consistent set.

The construction processes formulas one at a time: for each formula A,
if adding A keeps the set consistent, add A; otherwise add ¬A.
"""

# ╔═╡ 4a4b4c4d-0016-0016-0016-000000000016
begin
	lang = formula_closure([p, Box(p)])

	# Extend {p} to a complete K-consistent set
	ext_p = lindenbaum_extend(SYSTEM_K, [p], lang; max_worlds=3)
	(extension = ext_p, p_in = p ∈ ext_p, box_p_in = Box(p) ∈ ext_p)
end

# ╔═╡ 4a4b4c4d-0017-0017-0017-000000000017
begin
	# Extend {□p} — p must also be present (in KT, though not necessarily in K)
	ext_box = lindenbaum_extend(SYSTEM_K, [Box(p)], lang; max_worlds=3)
	(extension = ext_box, box_p = Box(p) ∈ ext_box)
end

# ╔═╡ 4a4b4c4d-0018-0018-0018-000000000018
md"""
## 4.5 Modal Operators on Sets

**Definition 4.5** defines operations on sets of formulas that mirror
the modal operators:

- □Γ = {□B : B ∈ Γ} — prefix every formula with □
- ◇Γ = {◇B : B ∈ Γ} — prefix every formula with ◇
- □⁻¹Γ = {B : □B ∈ Γ} — strip the □ from boxed formulas
- ◇⁻¹Γ = {B : ◇B ∈ Γ} — strip the ◇ from diamond formulas
"""

# ╔═╡ 4a4b4c4d-0019-0019-0019-000000000019
begin
	Γ = Set{Formula}([Box(p), Box(q), Diamond(p), p])

	(box_of_Γ = box_set(Γ),
	 diamond_of_Γ = diamond_set(Γ),
	 box_inv_Γ = box_inverse(Γ),
	 diamond_inv_Γ = diamond_inverse(Γ))
end

# ╔═╡ 4a4b4c4d-0020-0020-0020-000000000020
md"""
## 4.6 Canonical Models

**Definition 4.11:** The *canonical model* M^Σ = ⟨W^Σ, R^Σ, V^Σ⟩ where:

1. W^Σ = all complete Σ-consistent sets
2. R^Σ ΔΔ' iff □⁻¹Δ ⊆ Δ' (if □A ∈ Δ then A ∈ Δ')
3. V^Σ(p) = {Δ : p ∈ Δ}

For a finite language, we can enumerate all complete consistent sets
and build this model explicitly.
"""

# ╔═╡ 4a4b4c4d-0021-0021-0021-000000000021
begin
	# Canonical model for K over {p, □p}
	cm_k = canonical_model(SYSTEM_K, [p, Box(p)]; max_worlds=3)
	cm_k
end

# ╔═╡ 4a4b4c4d-0022-0022-0022-000000000022
md"""
The canonical model for **K** over {p, □p} has 4 worlds — all
combinations of p/¬p and □p/¬□p. Let's inspect them:
"""

# ╔═╡ 4a4b4c4d-0023-0023-0023-000000000023
begin
	for (i, Δ) in enumerate(cm_k.worlds)
		wname = Symbol("Δ", i)
		succs = accessible(cm_k.model.frame, wname)
		formulas = join(sort(string.(collect(Δ))), ", ")
		println("  Δ$i = {$formulas}  sees: $succs")
	end
end

# ╔═╡ 4a4b4c4d-0024-0024-0024-000000000024
md"""
## 4.7 The Truth Lemma

**Proposition 4.12 (Truth Lemma):** For every formula A in the language
and every world Δ in the canonical model:

M^Σ, Δ ⊩ A  if and only if  A ∈ Δ

This is the heart of the completeness proof — it connects the semantic
notion (satisfaction) with the syntactic notion (membership).
"""

# ╔═╡ 4a4b4c4d-0025-0025-0025-000000000025
truth_lemma_holds(cm_k)

# ╔═╡ 4a4b4c4d-0026-0026-0026-000000000026
md"""
## 4.8 Completeness of K (Corollary 4.15)

Since the canonical model determines **K**, we have:

**K** is *complete* with respect to the class of all models.

That is: if ⊨ A (A is valid) then **K** ⊢ A (A is provable in K).
"""

# ╔═╡ 4a4b4c4d-0027-0027-0027-000000000027
begin
	# K-valid formulas are K-derivable
	k_axiom = Implies(Box(Implies(p, q)), Implies(Box(p), Box(q)))
	nec_taut = Box(Implies(p, p))

	(K_axiom_derivable = is_derivable_from(SYSTEM_K, Formula[], k_axiom; max_worlds=2),
	 nec_taut_derivable = is_derivable_from(SYSTEM_K, Formula[], nec_taut; max_worlds=2))
end

# ╔═╡ 4a4b4c4d-0028-0028-0028-000000000028
md"""
## 4.9 Frame Completeness (Theorem 4.16)

The canonical model's frame inherits the properties corresponding to
the axioms in the system. This is the key to extending completeness
beyond K.

| System | Canonical model frame property |
|:-------|:-------------------------------|
| KD     | serial                         |
| KT     | reflexive                      |
| KB     | symmetric                      |
| K4     | transitive                     |
| K5     | euclidean                      |
"""

# ╔═╡ 4a4b4c4d-0029-0029-0029-000000000029
begin
	# Canonical model for KT is reflexive
	cm_kt = canonical_model(SYSTEM_KT, [p, Box(p)]; max_worlds=3)

	(truth_lemma = truth_lemma_holds(cm_kt),
	 reflexive = is_reflexive(cm_kt.model.frame),
	 worlds = length(cm_kt.worlds))
end

# ╔═╡ 4a4b4c4d-0030-0030-0030-000000000030
begin
	# Canonical model for KD is serial
	cm_kd = canonical_model(SYSTEM_KD, [p, Box(p)]; max_worlds=3)

	(truth_lemma = truth_lemma_holds(cm_kd),
	 serial = is_serial(cm_kd.model.frame))
end

# ╔═╡ 4a4b4c4d-0031-0031-0031-000000000031
begin
	# Canonical model for S4 is reflexive AND transitive
	# (need □□p in language for transitivity to manifest)
	cm_s4 = canonical_model(SYSTEM_S4, [p, Box(p), Box(Box(p))]; max_worlds=3)

	(truth_lemma = truth_lemma_holds(cm_s4),
	 reflexive = is_reflexive(cm_s4.model.frame),
	 transitive = is_transitive(cm_s4.model.frame),
	 worlds = length(cm_s4.worlds))
end

# ╔═╡ 4a4b4c4d-0032-0032-0032-000000000032
md"""
## System Distinctness

Completeness also lets us show that systems are *distinct*: if a
formula is valid in the class of models for one system but not another,
the systems must be different.
"""

# ╔═╡ 4a4b4c4d-0033-0033-0033-000000000033
begin
	# □p → p is KT-derivable but not KD-derivable (Prop 3.32: KD ⊊ KT)
	schema_t = Implies(Box(p), p)
	(KT = is_derivable_from(SYSTEM_KT, Formula[], schema_t; max_worlds=2),
	 KD = is_derivable_from(SYSTEM_KD, Formula[], schema_t; max_worlds=2))
end

# ╔═╡ 4a4b4c4d-0034-0034-0034-000000000034
begin
	# □p → □□p is not KB-derivable (Prop 3.33: KB ≠ K4)
	schema_4 = Implies(Box(p), Box(Box(p)))
	(KB = is_derivable_from(SYSTEM_KB, Formula[], schema_4; max_worlds=2),
	 K4 = is_derivable_from(SYSTEM_K4, Formula[], schema_4; max_worlds=2))
end

# ╔═╡ 4a4b4c4d-0035-0035-0035-000000000035
md"""
## Determination

**Definition 4.13:** A model M *determines* a system Σ if for every
formula A: M ⊩ A iff Σ ⊢ A.

The canonical model determines its system — that's the content of
Theorem 4.14.
"""

# ╔═╡ 4a4b4c4d-0036-0036-0036-000000000036
determines(cm_k.model, SYSTEM_K, [p]; max_worlds=3)

# ╔═╡ 4a4b4c4d-0037-0037-0037-000000000037
md"""
## Summary

Chapter 4 establishes the **completeness** of modal logics:

1. Every Σ-consistent set extends to a *complete* Σ-consistent set
   (Lindenbaum's Lemma)
2. The *canonical model* has these sets as worlds, with accessibility
   defined by □⁻¹Δ ⊆ Δ'
3. The *Truth Lemma* ensures M^Σ, Δ ⊩ A ↔ A ∈ Δ
4. Therefore every valid formula is derivable (completeness)
5. The canonical model's frame properties match the axiom schemas,
   extending completeness to KT, KD, S4, S5, etc.
"""

# ╔═╡ Cell order:
# ╟─4a4b4c4d-0001-0001-0001-000000000001
# ╠═4a4b4c4d-0002-0002-0002-000000000002
# ╟─4a4b4c4d-0003-0003-0003-000000000003
# ╠═4a4b4c4d-0004-0004-0004-000000000004
# ╟─4a4b4c4d-0005-0005-0005-000000000005
# ╠═4a4b4c4d-0006-0006-0006-000000000006
# ╟─4a4b4c4d-0007-0007-0007-000000000007
# ╠═4a4b4c4d-0008-0008-0008-000000000008
# ╟─4a4b4c4d-0009-0009-0009-000000000009
# ╠═4a4b4c4d-0010-0010-0010-000000000010
# ╟─4a4b4c4d-0011-0011-0011-000000000011
# ╠═4a4b4c4d-0012-0012-0012-000000000012
# ╟─4a4b4c4d-0013-0013-0013-000000000013
# ╠═4a4b4c4d-0014-0014-0014-000000000014
# ╟─4a4b4c4d-0015-0015-0015-000000000015
# ╠═4a4b4c4d-0016-0016-0016-000000000016
# ╠═4a4b4c4d-0017-0017-0017-000000000017
# ╟─4a4b4c4d-0018-0018-0018-000000000018
# ╠═4a4b4c4d-0019-0019-0019-000000000019
# ╟─4a4b4c4d-0020-0020-0020-000000000020
# ╠═4a4b4c4d-0021-0021-0021-000000000021
# ╟─4a4b4c4d-0022-0022-0022-000000000022
# ╠═4a4b4c4d-0023-0023-0023-000000000023
# ╟─4a4b4c4d-0024-0024-0024-000000000024
# ╠═4a4b4c4d-0025-0025-0025-000000000025
# ╟─4a4b4c4d-0026-0026-0026-000000000026
# ╠═4a4b4c4d-0027-0027-0027-000000000027
# ╟─4a4b4c4d-0028-0028-0028-000000000028
# ╠═4a4b4c4d-0029-0029-0029-000000000029
# ╠═4a4b4c4d-0030-0030-0030-000000000030
# ╠═4a4b4c4d-0031-0031-0031-000000000031
# ╟─4a4b4c4d-0032-0032-0032-000000000032
# ╠═4a4b4c4d-0033-0033-0033-000000000033
# ╠═4a4b4c4d-0034-0034-0034-000000000034
# ╟─4a4b4c4d-0035-0035-0035-000000000035
# ╠═4a4b4c4d-0036-0036-0036-000000000036
# ╟─4a4b4c4d-0037-0037-0037-000000000037
