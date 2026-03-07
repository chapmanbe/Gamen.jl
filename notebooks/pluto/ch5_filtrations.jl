### A Pluto.jl notebook ###
# v0.20.4

using Markdown
using InteractiveUtils

# ╔═╡ 5a5b5c5d-0001-0001-0001-000000000001
md"""
# Chapter 5: Filtrations and Decidability

This notebook follows Chapter 5 of [Boxes and Diamonds](https://bd.openlogicproject.org)
using the **Gamen.jl** package.

We cover:
- Closure under subformulas and modal closure (Definition 5.1)
- Γ-equivalence of worlds (Definition 5.2, Proposition 5.3)
- Filtrations: definition and the Filtration Lemma (Definitions 5.4, 5.7, 5.9; Theorem 5.5)
- Finest and coarsest filtrations (Definitions 5.7, 5.9)
- Filtrations are finite (Proposition 5.12)
- K and S5 have the finite model property (Proposition 5.14, Corollary 5.16)
- S5 is decidable (Theorem 5.17)
- Filtrations and frame properties (Theorem 5.18)
"""

# ╔═╡ 5a5b5c5d-0002-0002-0002-000000000002
begin
	using Pkg
	Pkg.activate(joinpath(@__DIR__, ".."))
	using Gamen
end

# ╔═╡ 5a5b5c5d-0003-0003-0003-000000000003
begin
	p = Atom(:p)
	q = Atom(:q)
	r = Atom(:r)
end;

# ╔═╡ 5a5b5c5d-0004-0004-0004-000000000004
md"""
## 5.1 Introduction

Filtrations give us a way to turn an infinite (counter)model into a finite one.
The key idea: identify worlds that agree on all formulas in a finite set Γ.
If Γ is the set of subformulas of some formula A, the resulting finite model
still makes A true or false in the same way as the original.

This yields the **finite model property** for K and S5, and hence their
**decidability**: to check if A is valid, we only need to check all models
up to a bounded finite size.
"""

# ╔═╡ 5a5b5c5d-0005-0005-0005-000000000005
md"""
## 5.2 Closure Properties (Definition 5.1)

A set Γ is **closed under subformulas** if every subformula of every A ∈ Γ
is also in Γ.

The set of subformulas of a formula is always closed under subformulas by construction.
"""

# ╔═╡ 5a5b5c5d-0006-0006-0006-000000000006
begin
	# Subformulas of □p → p: {(□p → p), □p, p}
	Γ₁ = subformula_closure(Implies(Box(p), p))
	(formulas = Γ₁, closed = is_closed_under_subformulas(Γ₁))
end

# ╔═╡ 5a5b5c5d-0007-0007-0007-000000000007
begin
	# Remove p — no longer closed
	Γ_broken = setdiff(Γ₁, Set{Formula}([p]))
	(formulas = Γ_broken, closed = is_closed_under_subformulas(Γ_broken))
end

# ╔═╡ 5a5b5c5d-0008-0008-0008-000000000008
md"""
A set Γ is **modally closed** if it is closed under subformulas and moreover
A ∈ Γ implies □A, ◇A ∈ Γ. This is an infinite requirement: p requires □p and
◇p, which in turn require □□p, ◇□p, □◇p, ◇◇p, and so on. No non-trivial
finite set of formulas is modally closed.

The set of subformulas of □p is *not* modally closed since □p ∈ Γ but □□p ∉ Γ:
"""

# ╔═╡ 5a5b5c5d-0009-0009-0009-000000000009
begin
	Γ_box_p = subformula_closure(Box(p))  # {□p, p}
	(closed_under_subformulas = is_closed_under_subformulas(Γ_box_p),
	 modally_closed = is_modally_closed(Γ_box_p))
end

# ╔═╡ 5a5b5c5d-0010-0010-0010-000000000010
md"""
## 5.3 Γ-Equivalence (Definition 5.2)

Two worlds u, v in a model M are **Γ-equivalent** (written u ≡_Γ v) if they
agree on every formula in Γ:

∀A ∈ Γ : M, u ⊩ A ⟺ M, v ⊩ A

By Proposition 5.3, ≡_Γ is an equivalence relation (reflexive, symmetric,
transitive), so it partitions the worlds into equivalence classes [w].
"""

# ╔═╡ 5a5b5c5d-0011-0011-0011-000000000011
begin
	# Figure 1.1 model: W = {w1, w2, w3}, R = {w1→w2, w1→w3}
	# V(p) = {w1, w2}, V(q) = {w2}
	frame₁ = KripkeFrame([:w1, :w2, :w3], [:w1 => :w2, :w1 => :w3])
	model₁ = KripkeModel(frame₁, [:p => [:w1, :w2], :q => [:w2]])

	# With Γ = {p}: w1 and w2 both satisfy p; w3 does not
	Γ_p = subformula_closure(p)
	(w1_w2_equiv = world_equivalent(model₁, Γ_p, :w1, :w2),
	 w1_w3_equiv = world_equivalent(model₁, Γ_p, :w1, :w3))
end

# ╔═╡ 5a5b5c5d-0012-0012-0012-000000000012
begin
	# Two equivalence classes: {w1, w2} and {w3}
	classes_p = equivalence_classes(model₁, Γ_p)
	length(classes_p)
end

# ╔═╡ 5a5b5c5d-0013-0013-0013-000000000013
begin
	# With Γ = subformulas(□p): w1 sees p at all successors, w2/w3 don't
	# → all three worlds are in distinct classes
	Γ_box_p2 = subformula_closure(Box(p))
	classes_box_p = equivalence_classes(model₁, Γ_box_p2)
	length(classes_box_p)
end

# ╔═╡ 5a5b5c5d-0014-0014-0014-000000000014
md"""
## 5.4 Filtrations (Definition 5.4)

A **filtration** M* of M through Γ is any model with:
1. W* = {[w] : w ∈ W} — worlds are the equivalence classes
2. R* satisfies the sandwich conditions (2a)–(2c):
   - (2a) If Ruv then R*[u][v]
   - (2b) If R*[u][v] and □A ∈ Γ and M,u ⊩ □A then M,v ⊩ A
   - (2c) If R*[u][v] and ◇A ∈ Γ and M,v ⊩ A then M,u ⊩ ◇A
3. V*(p) = {[u] : u ∈ V(p)}

**Theorem 5.5 (Filtration Lemma):** For every A ∈ Γ and w ∈ W:
M, w ⊩ A  iff  M*, [w] ⊩ A.

The filtration lemma is what makes filtrations useful: truth is preserved.
"""

# ╔═╡ 5a5b5c5d-0015-0015-0015-000000000015
md"""
## 5.5 Finest and Coarsest Filtrations (Definitions 5.7, 5.9)

There are many possible filtrations of M through Γ — they differ only in
which pairs R*[u][v] hold. Two canonical choices:

**Finest filtration** (Definition 5.7): R*[u][v] iff ∃u' ∈ [u] ∃v' ∈ [v] : Ru'v'
— the *fewest* possible edges.

**Coarsest filtration** (Definition 5.9): R*[u][v] iff
- for all □A ∈ Γ: M,u ⊩ □A implies M,v ⊩ A, and
- for all ◇A ∈ Γ: M,v ⊩ A implies M,u ⊩ ◇A

— the *most* possible edges (subject to the filtration conditions).

Both are valid filtrations and both satisfy the Filtration Lemma.
"""

# ╔═╡ 5a5b5c5d-0016-0016-0016-000000000016
begin
	Γ₂ = subformula_closure(Implies(Box(p), p))
	filt_fine = finest_filtration(model₁, Γ₂)
	filt_coarse = coarsest_filtration(model₁, Γ₂)
	(finest = filt_fine, coarsest = filt_coarse)
end

# ╔═╡ 5a5b5c5d-0017-0017-0017-000000000017
begin
	(finest_lemma = filtration_lemma_holds(filt_fine),
	 coarsest_lemma = filtration_lemma_holds(filt_coarse))
end

# ╔═╡ 5a5b5c5d-0018-0018-0018-000000000018
md"""
### Example: World Collapsing

Consider a model where worlds w1 and w2 agree on all formulas in Γ = {p}.
The filtration collapses them into a single equivalence class.
"""

# ╔═╡ 5a5b5c5d-0019-0019-0019-000000000019
begin
	# 4 worlds, but only p matters: w1,w2 have p; w3,w4 don't
	frame_big = KripkeFrame([:w1, :w2, :w3, :w4],
		[:w1 => :w2, :w1 => :w3, :w2 => :w4])
	model_big = KripkeModel(frame_big, [:p => [:w1, :w2]])

	Γ_only_p = subformula_closure(p)
	filt_big = finest_filtration(model_big, Γ_only_p)

	# Collapses to 2 classes: {w1,w2} and {w3,w4}
	(original_worlds = length(model_big.frame.worlds),
	 filtration_classes = length(filt_big.classes),
	 lemma_holds = filtration_lemma_holds(filt_big))
end

# ╔═╡ 5a5b5c5d-0020-0020-0020-000000000020
md"""
## 5.6 Filtrations are Finite (Proposition 5.12)

If Γ is finite with n formulas, then any filtration M* through Γ has at most
**2ⁿ worlds** — one per subset of Γ (since each class is determined by which
formulas in Γ hold at its worlds).

This is the key to decidability: the filtration of any model is a *finite* model.
"""

# ╔═╡ 5a5b5c5d-0021-0021-0021-000000000021
begin
	φ = Implies(Box(p), p)
	Γ₃ = subformula_closure(φ)
	n = length(Γ₃)
	filt₃ = finest_filtration(model₁, Γ₃)
	(n_formulas = n,
	 max_classes = 2^n,
	 actual_classes = length(filt₃.classes))
end

# ╔═╡ 5a5b5c5d-0022-0022-0022-000000000022
md"""
## 5.7 K has the Finite Model Property (Proposition 5.14)

**K has the finite model property**: if A is false at some world in some model,
then A is false at some world in a *finite* model.

*Proof sketch:* Take a model M where M, w ⊭ A. Let Γ = subformulas(A). Build
any filtration M* of M through Γ. By the Filtration Lemma, M*, [w] ⊭ A. By
Proposition 5.12, M* is finite. K imposes no restriction on frames, so M* is
a K-model.
"""

# ╔═╡ 5a5b5c5d-0023-0023-0023-000000000023
begin
	# □p → p is not K-valid (needs reflexivity) — FMP says a finite countermodel exists
	# □(p→q) → (□p→□q) is K-valid — FMP holds vacuously
	(box_p_imp_p_fmp = has_finite_model_property(SYSTEM_K, Implies(Box(p), p)),
	 k_axiom_fmp = has_finite_model_property(SYSTEM_K, Implies(Box(Implies(p, q)), Implies(Box(p), Box(q)))))
end

# ╔═╡ 5a5b5c5d-0024-0024-0024-000000000024
md"""
## 5.8 S5 is Decidable (Theorem 5.17)

**S5 has the finite model property** (Corollary 5.16). Combined with the size
bound from Proposition 5.12, this gives:

**S5 is decidable** (Theorem 5.17): there is an algorithm that, given any
formula A, determines whether S5 ⊢ A.

*Algorithm:* Run two parallel processes:
1. Enumerate S5-proofs — if A is derivable, this terminates
2. Check all finite models up to size 2ⁿ (n = |subformulas(A)|) — if A is
   not S5-valid, this finds a finite countermodel

We can also check K-validity computationally using `is_decidable_within`:
"""

# ╔═╡ 5a5b5c5d-0025-0025-0025-000000000025
begin
	# □p → p is NOT K-valid (requires T axiom)
	result_t = is_decidable_within(SYSTEM_K, Implies(Box(p), p))
	(valid = result_t.valid,
	 subformula_count = result_t.subformula_count,
	 bound = result_t.bound)
end

# ╔═╡ 5a5b5c5d-0026-0026-0026-000000000026
begin
	# Schema K is valid in K
	result_k = is_decidable_within(SYSTEM_K,
		Implies(Box(Implies(p, q)), Implies(Box(p), Box(q))))
	(valid = result_k.valid,
	 subformula_count = result_k.subformula_count)
end

# ╔═╡ 5a5b5c5d-0027-0027-0027-000000000027
begin
	# □p → p IS KT-valid
	result_kt = is_decidable_within(SYSTEM_KT, Implies(Box(p), p))
	result_kt.valid
end

# ╔═╡ 5a5b5c5d-0028-0028-0028-000000000028
md"""
## 5.9 Filtrations and Frame Properties (Theorem 5.18)

The coarsest filtration is not necessarily symmetric or transitive even if the
original model is. We need stronger accessibility conditions (Table 5.1, B&D):

| Property    | Condition on R*[u][v]           |
|:------------|:--------------------------------|
| Symmetric   | C₁(u,v) ∧ C₂(u,v)              |
| Transitive  | C₁(u,v) ∧ C₃(u,v)              |

Where:
- **C₁**: coarsest condition (Definition 5.9)
- **C₂**: C₁ with u and v swapped (makes R* symmetric)
- **C₃**: if □A ∈ Γ and M,u ⊩ □A then M,v ⊩ □A (propagates modalities)

**Theorem 5.18:** If M is symmetric/transitive, then the corresponding
filtration is also symmetric/transitive and is a valid filtration.
"""

# ╔═╡ 5a5b5c5d-0029-0029-0029-000000000029
begin
	# Symmetric model
	frame_sym = KripkeFrame([:w1, :w2, :w3],
		[:w1 => :w2, :w2 => :w1, :w2 => :w3, :w3 => :w2])
	model_sym = KripkeModel(frame_sym, [:p => [:w1, :w2]])
	Γ_sym = subformula_closure(Implies(Box(p), p))

	filt_sym = symmetric_filtration(model_sym, Γ_sym)
	(symmetric = is_symmetric(filt_sym.model.frame),
	 lemma = filtration_lemma_holds(filt_sym))
end

# ╔═╡ 5a5b5c5d-0030-0030-0030-000000000030
begin
	# Transitive model
	frame_trans = KripkeFrame([:w1, :w2, :w3],
		[:w1 => :w2, :w2 => :w3, :w1 => :w3])
	model_trans = KripkeModel(frame_trans, [:p => [:w1, :w3]])
	Γ_trans = subformula_closure(Box(p))

	filt_trans = transitive_filtration(model_trans, Γ_trans)
	(transitive = is_transitive(filt_trans.model.frame),
	 lemma = filtration_lemma_holds(filt_trans))
end

# ╔═╡ 5a5b5c5d-0031-0031-0031-000000000031
md"""
The coarsest filtration alone does **not** preserve symmetry or transitivity —
only the specifically designed variants do:
"""

# ╔═╡ 5a5b5c5d-0032-0032-0032-000000000032
begin
	# Coarsest filtration of symmetric model is NOT necessarily symmetric
	filt_coarse_sym = coarsest_filtration(model_sym, Γ_sym)
	(coarsest_is_symmetric = is_symmetric(filt_coarse_sym.model.frame),
	 symmetric_filt_is_symmetric = is_symmetric(filt_sym.model.frame))
end

# ╔═╡ 5a5b5c5d-0033-0033-0033-000000000033
md"""
## Summary

Chapter 5 establishes **decidability** for modal logics via filtrations:

1. **Filtration Lemma (Theorem 5.5):** A filtration M* preserves truth of
   all A ∈ Γ at corresponding worlds
2. **Finiteness (Proposition 5.12):** If Γ is finite with n formulas,
   any filtration has at most 2ⁿ worlds
3. **FMP for K (Proposition 5.14):** Every countermodel has a finite one,
   so K has the finite model property
4. **FMP for S5 (Corollary 5.16):** Universal models are closed under
   filtrations, so S5 has the finite model property
5. **Decidability (Theorem 5.17):** FMP + finiteness bound → decidability
6. **Frame properties (Theorem 5.18):** With stronger accessibility conditions,
   filtrations of symmetric/transitive models stay symmetric/transitive
"""

# ╔═╡ Cell order:
# ╟─5a5b5c5d-0001-0001-0001-000000000001
# ╠═5a5b5c5d-0002-0002-0002-000000000002
# ╠═5a5b5c5d-0003-0003-0003-000000000003
# ╟─5a5b5c5d-0004-0004-0004-000000000004
# ╟─5a5b5c5d-0005-0005-0005-000000000005
# ╠═5a5b5c5d-0006-0006-0006-000000000006
# ╠═5a5b5c5d-0007-0007-0007-000000000007
# ╟─5a5b5c5d-0008-0008-0008-000000000008
# ╠═5a5b5c5d-0009-0009-0009-000000000009
# ╟─5a5b5c5d-0010-0010-0010-000000000010
# ╠═5a5b5c5d-0011-0011-0011-000000000011
# ╠═5a5b5c5d-0012-0012-0012-000000000012
# ╠═5a5b5c5d-0013-0013-0013-000000000013
# ╟─5a5b5c5d-0014-0014-0014-000000000014
# ╟─5a5b5c5d-0015-0015-0015-000000000015
# ╠═5a5b5c5d-0016-0016-0016-000000000016
# ╠═5a5b5c5d-0017-0017-0017-000000000017
# ╟─5a5b5c5d-0018-0018-0018-000000000018
# ╠═5a5b5c5d-0019-0019-0019-000000000019
# ╟─5a5b5c5d-0020-0020-0020-000000000020
# ╠═5a5b5c5d-0021-0021-0021-000000000021
# ╟─5a5b5c5d-0022-0022-0022-000000000022
# ╠═5a5b5c5d-0023-0023-0023-000000000023
# ╟─5a5b5c5d-0024-0024-0024-000000000024
# ╠═5a5b5c5d-0025-0025-0025-000000000025
# ╠═5a5b5c5d-0026-0026-0026-000000000026
# ╠═5a5b5c5d-0027-0027-0027-000000000027
# ╟─5a5b5c5d-0028-0028-0028-000000000028
# ╠═5a5b5c5d-0029-0029-0029-000000000029
# ╠═5a5b5c5d-0030-0030-0030-000000000030
# ╟─5a5b5c5d-0031-0031-0031-000000000031
# ╠═5a5b5c5d-0032-0032-0032-000000000032
# ╟─5a5b5c5d-0033-0033-0033-000000000033
