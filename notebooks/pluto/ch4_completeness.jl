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
	Pkg.activate(joinpath(@__DIR__, ".."))
	using Gamen
	import CairoMakie, GraphMakie, Graphs
end

# ╔═╡ 4a4b4c4d-0038-0038-0038-000000000038
md"""
## Why Completeness Matters

Soundness (Chapter 3) told us that our proof system is *safe*: everything we can prove is actually true. But soundness alone leaves a nagging question:

> **If something is true in all models with property X, can we always *prove* it from axioms?**

Completeness says **yes**. It is the guarantee that our proof system is not missing anything. If a formula is valid -- true in every model of the appropriate class -- then there exists a derivation from the axioms.

The contrapositive is equally important: **if no proof of inconsistency exists, then a consistent model exists.** You can trust a negative result. When the proof system fails to derive a contradiction from your assumptions, that is not because the system is weak -- it is because those assumptions genuinely *can* coexist.

For health informatics, this matters concretely: suppose you formalize a set of clinical guidelines and check them for consistency. If the proof system reports "no contradiction found," completeness guarantees that a model exists where all the guidelines can be simultaneously satisfied. Without completeness, "no contradiction found" might just mean "our proof system isn't powerful enough to detect the contradiction." With completeness, silence really does mean safety.

The key construction is the **canonical model** -- a model built directly from the syntax of the proof system, whose worlds are *maximal consistent sets of formulas*. It is perhaps the most elegant construction in modal logic: we build a model out of pure logic, and prove that it has exactly the right properties.
"""

# ╔═╡ 4a4b4c4d-0003-0003-0003-000000000003
md"""
## 4.1 Introduction

The soundness theorem (Theorem 3.31) tells us that everything derivable
in a modal system is valid. *Completeness* is the converse: every valid
formula is derivable.

The key construction is the **canonical model**, whose worlds are
*complete Sigma-consistent sets* of formulas.
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

# ╔═╡ 4a4b4c4d-0039-0039-0039-000000000039
md"""
**Exercise 1.** How many formulas are in the closure of {p, □(p → q)}? Think about it, then check below.

$(Markdown.MD(Markdown.Admonition("hint", "Reveal answer", [md"The subformulas of □(p → q) are: □(p → q), p → q, p, q. Adding p gives {p, q, p → q, □(p → q)}. The closure adds negations: {p, ¬p, q, ¬q, p → q, ¬(p → q), □(p → q), ¬□(p → q)} -- 8 formulas total. Try `length(formula_closure([p, Box(Implies(p, q))]))` to verify."])))
"""

# ╔═╡ 4a4b4c4d-0009-0009-0009-000000000009
md"""
## 4.2 Derivability and Consistency

**Derivability from a set** (Definition 3.36): Gamma ⊢\_Sigma A means A is derivable
from premises in Gamma within system Sigma. By soundness and completeness, we
can check this *semantically*: A holds at every world where all of Gamma hold,
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

# ╔═╡ 4a4b4c4d-0040-0040-0040-000000000040
md"""
**Exercise 2.** Is □p → □□p derivable in K? What about in K4? Why does this make sense?

$(Markdown.MD(Markdown.Admonition("hint", "Reveal answer", [md"Not derivable in K, but derivable in K4. K4 includes axiom 4 (□p → □□p), which corresponds to transitivity. In a transitive frame, if p holds at all accessible worlds, it also holds at all worlds accessible from those -- so □p implies □□p. Try: `is_derivable_from(SYSTEM_K, Formula[], Implies(Box(p), Box(Box(p))); max_worlds=2)` and compare with `SYSTEM_K4`."])))
"""

# ╔═╡ 4a4b4c4d-0011-0011-0011-000000000011
md"""
**Consistency** (Definition 3.39): A set Gamma is Sigma-consistent iff ⊥ is not
derivable from Gamma. Equivalently, there exists a model in the appropriate
class with a world satisfying all formulas in Gamma.
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

# ╔═╡ 4a4b4c4d-0041-0041-0041-000000000041
md"""
**Exercise 3.** Is {□p, □¬p} consistent in K? What about in KD? Explain the difference.

$(Markdown.MD(Markdown.Admonition("hint", "Reveal answer", [md"Consistent in K but NOT in KD. In K, a world with no successors makes both □p and □¬p vacuously true. KD requires seriality (every world has at least one successor), so some successor must satisfy both p and ¬p -- impossible. This is why KD is the logic of obligations: you cannot be simultaneously obligated to do p and obligated to do ¬p. Try: `is_consistent(SYSTEM_K, [Box(p), Box(Not(p))]; max_worlds=2)` vs `is_consistent(SYSTEM_KD, [Box(p), Box(Not(p))]; max_worlds=2)`."])))
"""

# ╔═╡ 4a4b4c4d-0013-0013-0013-000000000013
md"""
## 4.3 Complete Sigma-Consistent Sets

**Definition 4.1:** A set Gamma is *complete Sigma-consistent* if it is
Sigma-consistent and for every formula A, either A in Gamma or ¬A in Gamma.

These are the "maximally decided" consistent sets -- they settle the
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

**Theorem 4.3 (Lindenbaum's Lemma):** Every Sigma-consistent set can be
extended to a *complete* Sigma-consistent set.

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

# ╔═╡ 4a4b4c4d-0042-0042-0042-000000000042
md"""
**Exercise 4.** If you extend {□p} using Lindenbaum's Lemma in **KT**, must p be in the result? What about in **K**?

$(Markdown.MD(Markdown.Admonition("hint", "Reveal answer", [md"In KT, yes: axiom T says □p → p, so any KT-consistent set containing □p must also contain p (otherwise you could derive a contradiction). In K, not necessarily: K has no axiom forcing □p → p, so a complete K-consistent extension of {□p} might contain ¬p. Try extending in both systems and compare."])))
"""

# ╔═╡ 4a4b4c4d-0018-0018-0018-000000000018
md"""
## 4.5 Modal Operators on Sets

**Definition 4.5** defines operations on sets of formulas that mirror
the modal operators:

- □Gamma = {□B : B in Gamma} -- prefix every formula with □
- ◇Gamma = {◇B : B in Gamma} -- prefix every formula with ◇
- □⁻¹Gamma = {B : □B in Gamma} -- strip the □ from boxed formulas
- ◇⁻¹Gamma = {B : ◇B in Gamma} -- strip the ◇ from diamond formulas
"""

# ╔═╡ 4a4b4c4d-0019-0019-0019-000000000019
begin
	Γ = Set{Formula}([Box(p), Box(q), Diamond(p), p])

	(box_of_Γ = box_set(Γ),
	 diamond_of_Γ = diamond_set(Γ),
	 box_inv_Γ = box_inverse(Γ),
	 diamond_inv_Γ = diamond_inverse(Γ))
end

# ╔═╡ 4a4b4c4d-0043-0043-0043-000000000043
md"""
**Exercise 5.** Given Gamma = {□p, □(p → q), ◇r, p}, what is □⁻¹Gamma?

$(Markdown.MD(Markdown.Admonition("hint", "Reveal answer", [md"□⁻¹Gamma = {p, p → q}. We extract the contents of formulas that start with □: □p gives p, and □(p → q) gives p → q. The formulas ◇r and p do not start with □, so they contribute nothing. This operation is central to the canonical model's accessibility relation."])))
"""

# ╔═╡ 4a4b4c4d-0020-0020-0020-000000000020
md"""
## 4.6 Canonical Models

**Definition 4.11:** The *canonical model* M^Sigma = ⟨W^Sigma, R^Sigma, V^Sigma⟩ where:

1. W^Sigma = all complete Sigma-consistent sets
2. R^Sigma Delta Delta' iff □⁻¹Delta ⊆ Delta' (if □A in Delta then A in Delta')
3. V^Sigma(p) = {Delta : p in Delta}

For a finite language, we can enumerate all complete consistent sets
and build this model explicitly.
"""

# ╔═╡ 4a4b4c4d-0044-0044-0044-000000000044
md"""
$(Markdown.MD(Markdown.Admonition("note", "Knowledge Representation Lens", [md"The canonical model construction is itself a striking example of knowledge representation. Each world is a *maximal consistent set of beliefs* -- a complete, coherent picture of what might be true. The accessibility relation encodes logical entailment between these belief sets. As Buchanan (2006) observed, 'making assumptions explicit is valuable, whether or not the system is correct.' The canonical model makes the assumptions of a logical system maximally explicit: its worlds are literally the *possible states of belief* that the axioms permit. Completeness then guarantees that these explicit axioms capture *everything* the frame properties force -- nothing is hidden."])))
"""

# ╔═╡ 4a4b4c4d-0021-0021-0021-000000000021
begin
	# Canonical model for K over {p, □p}
	cm_k = canonical_model(SYSTEM_K, [p, Box(p)]; max_worlds=3)
	cm_k
end

# ╔═╡ 4a4b4c4d-0022-0022-0022-000000000022
md"""
The canonical model for **K** over {p, □p} has 4 worlds -- all
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

# ╔═╡ 4a4b4c4d-0045-0045-0045-000000000045
md"""
### Visualizing the Canonical Model for K

Each node is a world -- a maximal consistent set. The edges represent
the canonical accessibility relation: Delta sees Delta' when □⁻¹Delta ⊆ Delta'.
"""

# ╔═╡ 4a4b4c4d-0046-0046-0046-000000000046
begin
	# Visualize the canonical model for K over {p, □p}
	n_k = length(cm_k.worlds)
	pos_k = if n_k == 4
		Dict(:Δ1 => (0.0, 1.0), :Δ2 => (2.0, 1.0),
		     :Δ3 => (0.0, -1.0), :Δ4 => (2.0, -1.0))
	elseif n_k == 3
		Dict(:Δ1 => (0.0, 0.0), :Δ2 => (2.0, 1.0), :Δ3 => (2.0, -1.0))
	elseif n_k == 2
		Dict(:Δ1 => (0.0, 0.0), :Δ2 => (2.0, 0.0))
	else
		Dict(Symbol("Δ", i) => (2.0 * cos(2π * i / n_k), 2.0 * sin(2π * i / n_k))
		     for i in 1:n_k)
	end
	visualize_model(cm_k.model,
		positions = pos_k,
		title = "Canonical model for K over {p, □p}",
		size = (600, 500))
end

# ╔═╡ 4a4b4c4d-0024-0024-0024-000000000024
md"""
## 4.7 The Truth Lemma

**Proposition 4.12 (Truth Lemma):** For every formula A in the language
and every world Delta in the canonical model:

M^Sigma, Delta ⊩ A  if and only if  A in Delta

This is the heart of the completeness proof -- it connects the semantic
notion (satisfaction) with the syntactic notion (membership).
"""

# ╔═╡ 4a4b4c4d-0025-0025-0025-000000000025
truth_lemma_holds(cm_k)

# ╔═╡ 4a4b4c4d-0047-0047-0047-000000000047
md"""
**Exercise 6.** Why is the Truth Lemma surprising? What two very different things does it equate?

$(Markdown.MD(Markdown.Admonition("hint", "Reveal answer", [md"It equates a *semantic* concept (truth at a world in a model, determined by the accessibility relation and valuation) with a *syntactic* concept (membership in a set of formulas, determined by proof-theoretic consistency). The model was built from syntax, yet it behaves exactly as a semantic model should. This is the bridge that connects proof with truth."])))
"""

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

# ╔═╡ 4a4b4c4d-0048-0048-0048-000000000048
md"""
### Visualizing Canonical Models Across Systems

Comparing canonical models for different systems reveals how axioms shape
the structure. Notice how KT's canonical model has self-loops (reflexivity)
while K's may not.
"""

# ╔═╡ 4a4b4c4d-0049-0049-0049-000000000049
begin
	# Visualize the canonical model for KT
	n_kt = length(cm_kt.worlds)
	pos_kt = if n_kt == 2
		Dict(:Δ1 => (0.0, 0.0), :Δ2 => (2.0, 0.0))
	elseif n_kt == 3
		Dict(:Δ1 => (0.0, 0.0), :Δ2 => (2.0, 1.0), :Δ3 => (2.0, -1.0))
	elseif n_kt == 4
		Dict(:Δ1 => (0.0, 1.0), :Δ2 => (2.0, 1.0),
		     :Δ3 => (0.0, -1.0), :Δ4 => (2.0, -1.0))
	else
		Dict(Symbol("Δ", i) => (2.0 * cos(2π * i / n_kt), 2.0 * sin(2π * i / n_kt))
		     for i in 1:n_kt)
	end
	visualize_model(cm_kt.model,
		positions = pos_kt,
		title = "Canonical model for KT over {p, □p} (reflexive)",
		size = (600, 500))
end

# ╔═╡ 4a4b4c4d-0030-0030-0030-000000000030
begin
	# Canonical model for KD is serial
	cm_kd = canonical_model(SYSTEM_KD, [p, Box(p)]; max_worlds=3)

	(truth_lemma = truth_lemma_holds(cm_kd),
	 serial = is_serial(cm_kd.model.frame))
end

# ╔═╡ 4a4b4c4d-0050-0050-0050-000000000050
begin
	# Visualize the canonical model for KD
	n_kd = length(cm_kd.worlds)
	pos_kd = if n_kd == 2
		Dict(:Δ1 => (0.0, 0.0), :Δ2 => (2.0, 0.0))
	elseif n_kd == 3
		Dict(:Δ1 => (0.0, 0.0), :Δ2 => (2.0, 1.0), :Δ3 => (2.0, -1.0))
	elseif n_kd == 4
		Dict(:Δ1 => (0.0, 1.0), :Δ2 => (2.0, 1.0),
		     :Δ3 => (0.0, -1.0), :Δ4 => (2.0, -1.0))
	else
		Dict(Symbol("Δ", i) => (2.0 * cos(2π * i / n_kd), 2.0 * sin(2π * i / n_kd))
		     for i in 1:n_kd)
	end
	visualize_model(cm_kd.model,
		positions = pos_kd,
		title = "Canonical model for KD over {p, □p} (serial)",
		size = (600, 500))
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

# ╔═╡ 4a4b4c4d-0051-0051-0051-000000000051
begin
	# Visualize the canonical model for S4
	n_s4 = length(cm_s4.worlds)
	pos_s4 = if n_s4 == 2
		Dict(:Δ1 => (0.0, 0.0), :Δ2 => (2.0, 0.0))
	elseif n_s4 == 3
		Dict(:Δ1 => (0.0, 0.0), :Δ2 => (2.0, 1.0), :Δ3 => (2.0, -1.0))
	elseif n_s4 == 4
		Dict(:Δ1 => (0.0, 1.0), :Δ2 => (2.0, 1.0),
		     :Δ3 => (0.0, -1.0), :Δ4 => (2.0, -1.0))
	else
		Dict(Symbol("Δ", i) => (2.0 * cos(2π * i / n_s4), 2.0 * sin(2π * i / n_s4))
		     for i in 1:n_s4)
	end
	visualize_model(cm_s4.model,
		positions = pos_s4,
		title = "Canonical model for S4 over {p, □p, □□p} (reflexive + transitive)",
		size = (600, 500))
end

# ╔═╡ 4a4b4c4d-0052-0052-0052-000000000052
md"""
**Exercise 7.** Look at the canonical model visualizations above. How can you visually tell that the KT model is reflexive? How can you tell the KD model is serial?

$(Markdown.MD(Markdown.Admonition("hint", "Reveal answer", [md"Reflexive: every node has a self-loop (an edge from itself to itself). Serial: every node has at least one outgoing edge (no dead ends). A reflexive frame is always serial (self-loops count), but a serial frame need not be reflexive -- a world might see other worlds without seeing itself."])))
"""

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

**Definition 4.13:** A model M *determines* a system Sigma if for every
formula A: M ⊩ A iff Sigma ⊢ A.

The canonical model determines its system -- that's the content of
Theorem 4.14.
"""

# ╔═╡ 4a4b4c4d-0036-0036-0036-000000000036
determines(cm_k.model, SYSTEM_K, [p]; max_worlds=3)

# ╔═╡ 4a4b4c4d-0053-0053-0053-000000000053
md"""
$(Markdown.MD(Markdown.Admonition("note", "Knowledge Representation Lens", [md"Davis, Shrobe & Szolovits (1993) identify a key role of knowledge representations: they serve as a *theory of intelligent reasoning* by defining which inferences are sanctioned. Completeness tells us exactly when a proof system's sanctioned inferences match the semantic truth. Without completeness, your representation might silently *miss* valid inferences. With it, you know the axioms capture everything the frame properties force. As Buchanan (2006) put it, 'making assumptions explicit is valuable, whether or not the system is correct.' Completeness goes further: it guarantees that those explicit assumptions are *sufficient*."])))
"""

# ╔═╡ 4a4b4c4d-0054-0054-0054-000000000054
md"""
**Exercise 8.** Suppose you formalize a clinical guideline set and find it is KD-consistent. A colleague says: "Maybe there is a hidden contradiction that KD just cannot detect." How does completeness help you respond?

$(Markdown.MD(Markdown.Admonition("hint", "Reveal answer", [md"Completeness guarantees that if no proof of inconsistency exists, then a consistent model exists -- a serial Kripke model where all the guidelines are simultaneously satisfied. So 'KD-consistent' is not a limitation of the proof system: it means the guidelines genuinely can coexist in a world where every obligation is achievable. Your colleague's worry would be valid for an *incomplete* proof system, but not for a complete one."])))
"""

# ╔═╡ 4a4b4c4d-0037-0037-0037-000000000037
md"""
## Summary

Chapter 4 establishes the **completeness** of modal logics:

1. Every Sigma-consistent set extends to a *complete* Sigma-consistent set
   (Lindenbaum's Lemma)
2. The *canonical model* has these sets as worlds, with accessibility
   defined by □⁻¹Delta ⊆ Delta'
3. The *Truth Lemma* ensures M^Sigma, Delta ⊩ A iff A in Delta
4. Therefore every valid formula is derivable (completeness)
5. The canonical model's frame properties match the axiom schemas,
   extending completeness to KT, KD, S4, S5, etc.
"""

# ╔═╡ Cell order:
# ╟─4a4b4c4d-0001-0001-0001-000000000001
# ╠═4a4b4c4d-0002-0002-0002-000000000002
# ╟─4a4b4c4d-0038-0038-0038-000000000038
# ╟─4a4b4c4d-0003-0003-0003-000000000003
# ╠═4a4b4c4d-0004-0004-0004-000000000004
# ╟─4a4b4c4d-0005-0005-0005-000000000005
# ╠═4a4b4c4d-0006-0006-0006-000000000006
# ╟─4a4b4c4d-0007-0007-0007-000000000007
# ╠═4a4b4c4d-0008-0008-0008-000000000008
# ╟─4a4b4c4d-0039-0039-0039-000000000039
# ╟─4a4b4c4d-0009-0009-0009-000000000009
# ╠═4a4b4c4d-0010-0010-0010-000000000010
# ╟─4a4b4c4d-0040-0040-0040-000000000040
# ╟─4a4b4c4d-0011-0011-0011-000000000011
# ╠═4a4b4c4d-0012-0012-0012-000000000012
# ╟─4a4b4c4d-0041-0041-0041-000000000041
# ╟─4a4b4c4d-0013-0013-0013-000000000013
# ╠═4a4b4c4d-0014-0014-0014-000000000014
# ╟─4a4b4c4d-0015-0015-0015-000000000015
# ╠═4a4b4c4d-0016-0016-0016-000000000016
# ╠═4a4b4c4d-0017-0017-0017-000000000017
# ╟─4a4b4c4d-0042-0042-0042-000000000042
# ╟─4a4b4c4d-0018-0018-0018-000000000018
# ╠═4a4b4c4d-0019-0019-0019-000000000019
# ╟─4a4b4c4d-0043-0043-0043-000000000043
# ╟─4a4b4c4d-0020-0020-0020-000000000020
# ╟─4a4b4c4d-0044-0044-0044-000000000044
# ╠═4a4b4c4d-0021-0021-0021-000000000021
# ╟─4a4b4c4d-0022-0022-0022-000000000022
# ╠═4a4b4c4d-0023-0023-0023-000000000023
# ╟─4a4b4c4d-0045-0045-0045-000000000045
# ╠═4a4b4c4d-0046-0046-0046-000000000046
# ╟─4a4b4c4d-0024-0024-0024-000000000024
# ╠═4a4b4c4d-0025-0025-0025-000000000025
# ╟─4a4b4c4d-0047-0047-0047-000000000047
# ╟─4a4b4c4d-0026-0026-0026-000000000026
# ╠═4a4b4c4d-0027-0027-0027-000000000027
# ╟─4a4b4c4d-0028-0028-0028-000000000028
# ╠═4a4b4c4d-0029-0029-0029-000000000029
# ╟─4a4b4c4d-0048-0048-0048-000000000048
# ╠═4a4b4c4d-0049-0049-0049-000000000049
# ╠═4a4b4c4d-0030-0030-0030-000000000030
# ╠═4a4b4c4d-0050-0050-0050-000000000050
# ╠═4a4b4c4d-0031-0031-0031-000000000031
# ╠═4a4b4c4d-0051-0051-0051-000000000051
# ╟─4a4b4c4d-0052-0052-0052-000000000052
# ╟─4a4b4c4d-0032-0032-0032-000000000032
# ╠═4a4b4c4d-0033-0033-0033-000000000033
# ╠═4a4b4c4d-0034-0034-0034-000000000034
# ╟─4a4b4c4d-0035-0035-0035-000000000035
# ╠═4a4b4c4d-0036-0036-0036-000000000036
# ╟─4a4b4c4d-0053-0053-0053-000000000053
# ╟─4a4b4c4d-0054-0054-0054-000000000054
# ╟─4a4b4c4d-0037-0037-0037-000000000037
