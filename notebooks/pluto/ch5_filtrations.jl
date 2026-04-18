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
	import CairoMakie, GraphMakie, Graphs
end

# ╔═╡ 5a5b5c5d-0050-0050-0050-000000000050
md"""
## Why Filtrations and Decidability?

> *"Can a computer always determine whether a formula is valid?"*

This is not an abstract question. If you are building a clinical decision support system that checks whether a set of guideline recommendations is consistent, you need to know: **will the checker always terminate?** Or could it run forever on certain inputs?

The answer depends on the logic. For some logics, validity is *undecidable* — no algorithm can always answer "yes" or "no." But for the modal logics we use in practice (K, KT, S4, S5), validity *is* decidable. Chapter 5 proves this, and the proof technique is **filtration**.

The key insight is the **finite model property**: if a modal formula has a counterexample at all, it has a *finite* counterexample. Why does this matter? Because a computer can enumerate all finite models up to a bounded size. If the formula fails in one of them, it is not valid. If it passes all of them, it is valid. The procedure is guaranteed to terminate.

For health informatics, this has a direct practical consequence: automated guideline consistency checking is *guaranteed to terminate*. When you ask "are these two clinical guidelines logically compatible?", the system will always give you an answer — it will never loop forever. This guarantee comes from the mathematics of filtrations.
"""

# ╔═╡ 5a5b5c5d-0003-0003-0003-000000000003
begin
	p = Atom(:p)
	q = Atom(:q)
	r = Atom(:r)
end;

# ╔═╡ 5a5b5c5d-0004-0004-0004-000000000004
md"""
## Introduction

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
## Closure Properties
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

# ╔═╡ 5a5b5c5d-0051-0051-0051-000000000051
md"""
### Exercise: Closure Properties

**1. What are the subformulas of ◇(p ∧ q)?**

$(Markdown.MD(Markdown.Admonition("hint", "Reveal answer", [md"The subformulas are: ◇(p ∧ q), p ∧ q, p, and q. The subformula closure has 4 elements."])))

**2. Is the set {□p → q, □p, q} closed under subformulas?**

$(Markdown.MD(Markdown.Admonition("hint", "Reveal answer", [md"No! The subformula p is missing. □p contains p as a subformula, so any set containing □p must also contain p to be closed under subformulas."])))

**3. Could a finite set ever be modally closed? Why or why not?**

$(Markdown.MD(Markdown.Admonition("hint", "Reveal answer", [md"No (unless it contains only ⊥ or ⊤). If any atom p is in Γ, then modal closure requires □p ∈ Γ, then □□p ∈ Γ, then □□□p ∈ Γ, and so on forever. A finite set cannot contain infinitely many distinct formulas."])))
"""

# ╔═╡ 5a5b5c5d-0010-0010-0010-000000000010
md"""
## Γ-Equivalence
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

# ╔═╡ 5a5b5c5d-0052-0052-0052-000000000052
md"""
Let's visualize this model to see which worlds will be identified:
"""

# ╔═╡ 5a5b5c5d-0053-0053-0053-000000000053
visualize_model(model₁,
	positions = Dict(:w1 => (0.0, 0.0), :w2 => (2.0, 1.0), :w3 => (2.0, -1.0)),
	title = "Original model: w₁ has p, w₂ has p and q, w₃ has neither")

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

# ╔═╡ 5a5b5c5d-0054-0054-0054-000000000054
md"""
### Exercise: Γ-Equivalence

Consider the model above with worlds w₁ (p true), w₂ (p and q true), w₃ (both false).

**1. With Γ = {q}, which worlds are Γ-equivalent?**

$(Markdown.MD(Markdown.Admonition("hint", "Reveal answer", [md"w₁ and w₃ are Γ-equivalent (both have q false), while w₂ is in its own class (q true). Two equivalence classes: {w₁, w₃} and {w₂}."])))

**2. With Γ = {p, q}, how many equivalence classes are there?**

$(Markdown.MD(Markdown.Admonition("hint", "Reveal answer", [md"Three classes: {w₁} has p true and q false, {w₂} has both true, {w₃} has both false. A larger Γ gives finer distinctions and more classes."])))

**3. What is the maximum number of equivalence classes when Γ has n formulas?**

$(Markdown.MD(Markdown.Admonition("hint", "Reveal answer", [md"At most 2^n classes. Each class corresponds to a distinct truth assignment to the n formulas in Γ. This bound is crucial for decidability (Proposition 5.12)."])))
"""

# ╔═╡ 5a5b5c5d-0014-0014-0014-000000000014
md"""
## Filtrations
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
## Finest and Coarsest Filtrations (Definitions 5.7, 5.9)

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

This is the central mechanism of filtrations: worlds that are indistinguishable
with respect to Γ are merged, producing a smaller model that preserves truth
for all formulas in Γ.
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

# ╔═╡ 5a5b5c5d-0055-0055-0055-000000000055
md"""
### Visualizing the Filtration

Below we see the original 4-world model and the filtered 2-world model side by side.
Worlds that agree on p (w₁ and w₂ both have p; w₃ and w₄ both lack it) are collapsed
into single equivalence classes:
"""

# ╔═╡ 5a5b5c5d-0056-0056-0056-000000000056
visualize_model(model_big,
	positions = Dict(:w1 => (0.0, 1.0), :w2 => (2.0, 1.0),
	                 :w3 => (2.0, -1.0), :w4 => (4.0, -1.0)),
	title = "Original model (4 worlds)")

# ╔═╡ 5a5b5c5d-0057-0057-0057-000000000057
visualize_model(filt_big.model,
	title = "Filtration through Γ = {p} (2 worlds)")

# ╔═╡ 5a5b5c5d-0058-0058-0058-000000000058
md"""
The filtration collapsed 4 worlds into 2: worlds w₁ and w₂ (both satisfying p)
merged into one class, and worlds w₃ and w₄ (both falsifying p) merged into another.
The key property (Filtration Lemma, Theorem 5.5) is that every formula in Γ has the
same truth value at a world and at its equivalence class.

$(Markdown.MD(Markdown.Admonition("note", "Knowledge Representation Lens", [md"Davis, Shrobe & Szolovits (1993) identify Role 4 of knowledge representations: 'a medium for efficient computation.' Filtrations are a perfect illustration. An infinite Kripke model may faithfully represent a domain, but it is computationally useless — you cannot enumerate infinitely many worlds. A filtration restructures the representation by collapsing indistinguishable worlds, producing a finite model that preserves exactly the distinctions that matter. The representation changes; the relevant truths do not. This is the essence of making knowledge computable."])))
"""

# ╔═╡ 5a5b5c5d-0059-0059-0059-000000000059
md"""
### Visualizing Finest vs Coarsest Filtrations

The finest and coarsest filtrations of the same model through the same Γ can
differ in their accessibility relations. The finest has the fewest edges (only
those inherited from the original); the coarsest adds all edges consistent with
the filtration conditions:
"""

# ╔═╡ 5a5b5c5d-0060-0060-0060-000000000060
visualize_model(filt_fine.model,
	title = "Finest filtration of Figure 1.1 through Γ = sub(□p → p)")

# ╔═╡ 5a5b5c5d-0061-0061-0061-000000000061
visualize_model(filt_coarse.model,
	title = "Coarsest filtration of Figure 1.1 through Γ = sub(□p → p)")

# ╔═╡ 5a5b5c5d-0062-0062-0062-000000000062
md"""
### Exercise: Filtrations

**1. A model has 8 worlds and you filter through Γ = {p}. What is the maximum number of worlds in the filtration? What is the minimum?**

$(Markdown.MD(Markdown.Admonition("hint", "Reveal answer", [md"Maximum: 2 (since Γ has 1 formula, there are at most 2^1 = 2 distinct truth assignments). Minimum: 1 (if all 8 worlds agree on p). The filtration always has at most 2^|Γ| worlds."])))

**2. Why does the finest filtration have fewer edges than the coarsest?**

$(Markdown.MD(Markdown.Admonition("hint", "Reveal answer", [md"The finest filtration only adds an edge R*[u][v] when some concrete u' in [u] actually accesses some v' in [v] in the original model. The coarsest adds an edge whenever the sandwich conditions (2b) and (2c) are not violated. The coarsest is more permissive — it allows edges that 'could be there' without breaking truth preservation."])))

**3. Both finest and coarsest satisfy the Filtration Lemma. Why would you ever prefer one over the other?**

$(Markdown.MD(Markdown.Admonition("hint", "Reveal answer", [md"The finest filtration better preserves the structure of the original model (fewer spurious edges). The coarsest is useful when you need the filtration to satisfy additional frame properties — the extra edges can help establish transitivity or symmetry (see Section 5.9)."])))
"""

# ╔═╡ 5a5b5c5d-0020-0020-0020-000000000020
md"""
## Filtrations are Finite
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
## K has the Finite Model Property
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

# ╔═╡ 5a5b5c5d-0063-0063-0063-000000000063
md"""
### Exercise: Finite Model Property

**1. The formula ◇p ∧ ◇¬p says "p is possible and ¬p is also possible." Is this K-valid? If not, what is the smallest countermodel?**

$(Markdown.MD(Markdown.Admonition("hint", "Reveal answer", [md"Not K-valid. A world with no successors makes both ◇p and ◇¬p false (vacuously). An even simpler countermodel: a world with one successor where p is true — then ◇p holds but ◇¬p fails. The finite model property guarantees such a finite countermodel exists."])))

**2. Why does K have the FMP 'for free' while other logics (like S5) need extra work?**

$(Markdown.MD(Markdown.Admonition("hint", "Reveal answer", [md"K imposes no conditions on the accessibility relation. Any filtration of a K-model is automatically a K-model (since any frame is a K-frame). For S5, you need to ensure the filtered model's frame is still an equivalence relation — this requires the special filtration constructions of Theorem 5.18."])))
"""

# ╔═╡ 5a5b5c5d-0024-0024-0024-000000000024
md"""
## S5 is Decidable
**S5 has the finite model property** (Corollary 5.16). Combined with the size
bound from Proposition 5.12, this gives:

**S5 is decidable** (Theorem 5.17): there is an algorithm that, given any
formula A, determines whether S5 ⊢ A.

*Algorithm:* Run two parallel processes:
1. Enumerate S5-proofs — if A is derivable, this terminates
2. Check all finite models up to size 2ⁿ (n = |subformulas(A)|) — if A is
   not S5-valid, this finds a finite countermodel

We can also check K-validity computationally using `is_decidable_within`.

**Performance note:** Frame enumeration is O(2^(n²)), where n is the number of
worlds. With max\_worlds = 4, this means checking 2^16 = 65,536 frames — feasible.
With max\_worlds = 5, it would be 2^25 = 33 million frames. We keep max\_worlds at 4.
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

# ╔═╡ 5a5b5c5d-0064-0064-0064-000000000064
md"""
### Exercise: Decidability

**1. The formula □(p ∧ q) → (□p ∧ □q) is Schema K's "distribution" over conjunction. Is it K-valid?**

$(Markdown.MD(Markdown.Admonition("hint", "Reveal answer", [md"Yes, it is K-valid. If □(p ∧ q) holds at w, then at every accessible world v, both p and q hold. So □p holds (p at all accessible worlds) and □q holds (q at all accessible worlds). This works on any frame."])))

**2. If a formula has 4 subformulas, what is the maximum model size we need to check for the finite model property?**

$(Markdown.MD(Markdown.Admonition("hint", "Reveal answer", [md"At most 2^4 = 16 worlds. By Proposition 5.12, any filtration through a set of 4 formulas has at most 16 equivalence classes. So if there is a countermodel at all, there is one with at most 16 worlds."])))
"""

# ╔═╡ 5a5b5c5d-0028-0028-0028-000000000028
md"""
## Filtrations and Frame Properties
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

# ╔═╡ 5a5b5c5d-0065-0065-0065-000000000065
md"""
Let's visualize the symmetric model and its filtration:
"""

# ╔═╡ 5a5b5c5d-0066-0066-0066-000000000066
visualize_model(model_sym,
	positions = Dict(:w1 => (0.0, 0.0), :w2 => (2.0, 0.0), :w3 => (4.0, 0.0)),
	title = "Original symmetric model")

# ╔═╡ 5a5b5c5d-0067-0067-0067-000000000067
visualize_model(filt_sym.model,
	title = "Symmetric filtration (preserves symmetry)")

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

# ╔═╡ 5a5b5c5d-0068-0068-0068-000000000068
md"""
The transitive model and its filtration:
"""

# ╔═╡ 5a5b5c5d-0069-0069-0069-000000000069
visualize_model(model_trans,
	positions = Dict(:w1 => (0.0, 0.0), :w2 => (2.0, 0.0), :w3 => (4.0, 0.0)),
	title = "Original transitive model")

# ╔═╡ 5a5b5c5d-0070-0070-0070-000000000070
visualize_model(filt_trans.model,
	title = "Transitive filtration (preserves transitivity)")

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

# ╔═╡ 5a5b5c5d-0071-0071-0071-000000000071
md"""
### Exercise: Frame Properties and Filtrations

**1. Why can't we just use the coarsest filtration for all logics?**

$(Markdown.MD(Markdown.Admonition("hint", "Reveal answer", [md"The coarsest filtration may not preserve frame properties. If the original model is symmetric (needed for B logic) or transitive (needed for S4), the coarsest filtration might lose those properties. We need the specialized constructions of Theorem 5.18 that add extra conditions (C₂ for symmetry, C₃ for transitivity) to guarantee preservation."])))

**2. S5 requires an equivalence relation (reflexive, symmetric, transitive). What filtration construction preserves all three?**

$(Markdown.MD(Markdown.Admonition("hint", "Reveal answer", [md"You need a filtration that satisfies C₁ ∧ C₂ ∧ C₃ simultaneously, plus a reflexivity condition. The symmetric filtration handles C₁ ∧ C₂, the transitive handles C₁ ∧ C₃. For S5, combine all conditions. This is how Corollary 5.16 establishes the FMP for S5."])))
"""

# ╔═╡ 5a5b5c5d-0072-0072-0072-000000000072
md"""
$(Markdown.MD(Markdown.Admonition("note", "Knowledge Representation Lens", [md"The finite model property connects to a deeper point from Davis et al. (1993): a knowledge representation must be *computationally tractable*, not just expressively adequate. An infinite Kripke model can represent anything — but you cannot compute with it. Filtrations show that modal logic representations are inherently tractable: the finite model property guarantees that every question about validity can be answered by examining only finite structures. This is not an accident of implementation but a mathematical property of the logic itself. Buchanan (2006) makes a related point: 'making assumptions explicit is valuable, whether or not the system is correct.' The explicit subformula set Γ makes precise which distinctions matter and which can be collapsed."])))
"""

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

The practical consequence: automated reasoning over modal logics (including
clinical guideline consistency checking) is **guaranteed to terminate**. This
is the mathematical foundation that makes tools like Gamen.jl possible.
"""

# ╔═╡ Cell order:
# ╟─5a5b5c5d-0001-0001-0001-000000000001
# ╠═5a5b5c5d-0002-0002-0002-000000000002
# ╟─5a5b5c5d-0050-0050-0050-000000000050
# ╠═5a5b5c5d-0003-0003-0003-000000000003
# ╟─5a5b5c5d-0004-0004-0004-000000000004
# ╟─5a5b5c5d-0005-0005-0005-000000000005
# ╠═5a5b5c5d-0006-0006-0006-000000000006
# ╠═5a5b5c5d-0007-0007-0007-000000000007
# ╟─5a5b5c5d-0008-0008-0008-000000000008
# ╠═5a5b5c5d-0009-0009-0009-000000000009
# ╟─5a5b5c5d-0051-0051-0051-000000000051
# ╟─5a5b5c5d-0010-0010-0010-000000000010
# ╠═5a5b5c5d-0011-0011-0011-000000000011
# ╟─5a5b5c5d-0052-0052-0052-000000000052
# ╠═5a5b5c5d-0053-0053-0053-000000000053
# ╠═5a5b5c5d-0012-0012-0012-000000000012
# ╠═5a5b5c5d-0013-0013-0013-000000000013
# ╟─5a5b5c5d-0054-0054-0054-000000000054
# ╟─5a5b5c5d-0014-0014-0014-000000000014
# ╟─5a5b5c5d-0015-0015-0015-000000000015
# ╠═5a5b5c5d-0016-0016-0016-000000000016
# ╠═5a5b5c5d-0017-0017-0017-000000000017
# ╟─5a5b5c5d-0018-0018-0018-000000000018
# ╠═5a5b5c5d-0019-0019-0019-000000000019
# ╟─5a5b5c5d-0055-0055-0055-000000000055
# ╠═5a5b5c5d-0056-0056-0056-000000000056
# ╠═5a5b5c5d-0057-0057-0057-000000000057
# ╟─5a5b5c5d-0058-0058-0058-000000000058
# ╟─5a5b5c5d-0059-0059-0059-000000000059
# ╠═5a5b5c5d-0060-0060-0060-000000000060
# ╠═5a5b5c5d-0061-0061-0061-000000000061
# ╟─5a5b5c5d-0062-0062-0062-000000000062
# ╟─5a5b5c5d-0020-0020-0020-000000000020
# ╠═5a5b5c5d-0021-0021-0021-000000000021
# ╟─5a5b5c5d-0022-0022-0022-000000000022
# ╠═5a5b5c5d-0023-0023-0023-000000000023
# ╟─5a5b5c5d-0063-0063-0063-000000000063
# ╟─5a5b5c5d-0024-0024-0024-000000000024
# ╠═5a5b5c5d-0025-0025-0025-000000000025
# ╠═5a5b5c5d-0026-0026-0026-000000000026
# ╠═5a5b5c5d-0027-0027-0027-000000000027
# ╟─5a5b5c5d-0064-0064-0064-000000000064
# ╟─5a5b5c5d-0028-0028-0028-000000000028
# ╠═5a5b5c5d-0029-0029-0029-000000000029
# ╟─5a5b5c5d-0065-0065-0065-000000000065
# ╠═5a5b5c5d-0066-0066-0066-000000000066
# ╠═5a5b5c5d-0067-0067-0067-000000000067
# ╠═5a5b5c5d-0030-0030-0030-000000000030
# ╟─5a5b5c5d-0068-0068-0068-000000000068
# ╠═5a5b5c5d-0069-0069-0069-000000000069
# ╠═5a5b5c5d-0070-0070-0070-000000000070
# ╟─5a5b5c5d-0031-0031-0031-000000000031
# ╠═5a5b5c5d-0032-0032-0032-000000000032
# ╟─5a5b5c5d-0071-0071-0071-000000000071
# ╟─5a5b5c5d-0072-0072-0072-000000000072
# ╟─5a5b5c5d-0033-0033-0033-000000000033
