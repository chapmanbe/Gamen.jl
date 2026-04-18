### A Pluto.jl notebook ###
# v0.20.4

using Markdown
using InteractiveUtils

# ╔═╡ f1f2f3f4-0001-0001-0001-000000000001
md"""
# Chapter 15: Epistemic Logics

This notebook follows Chapter 15 of [Boxes and Diamonds](https://bd.openlogicproject.org)
using the **Gamen.jl** package.

We cover:
- The knowledge operator K_a (Definitions 15.1–15.2)
- Group and common knowledge (Definition 15.3)
- Multi-agent relational models (Definition 15.4)
- Truth conditions for K_a (Definition 15.5)
- Epistemic principles and frame correspondence (Table 15.1)
- Common knowledge via transitive closure (Definition 15.6)
- Bisimulations (Definition 15.7, Theorem 15.8)
- Public Announcement Logic (Definitions 15.9–15.11)
"""

# ╔═╡ f1f2f3f4-0002-0002-0002-000000000002
begin
	using Pkg
	Pkg.activate(joinpath(@__DIR__, ".."))
	using Gamen
end

# ╔═╡ f1f2f3f4-0003-0003-0003-000000000003
begin
	p = Atom(:p)
	q = Atom(:q)
	r = Atom(:r)
end;

# ╔═╡ f1f2f3f4-0004-0004-0004-000000000004
md"""
## Introduction

Epistemic logic interprets the modal operators as *knowledge* rather than
necessity/possibility. The formula K_a A reads "agent a knows A."

Key examples:
- K_richard (Calgary is in Alberta)
- K_richard (K_audrey (class is on Tuesdays))
- ∀a ∈ G: K_a (a year has 12 months)

Multi-agent epistemic logic tracks the knowledge of multiple agents simultaneously.
Each agent a has their own accessibility relation R_a — when R_a ww' holds, world
w' is *consistent with a's information at w*.
"""

# ╔═╡ f1f2f3f4-0005-0005-0005-000000000005
md"""
## The Language
The epistemic language extends propositional logic with:
- K_a A for each agent a ∈ G: "agent a knows A"

A formula is *modal-free* if it contains no K_a operators.
"""

# ╔═╡ f1f2f3f4-0006-0006-0006-000000000006
begin
	# Knowledge formula construction
	ka_p = Knowledge(:a, p)           # K[a]p: agent a knows p
	kb_q = Knowledge(:b, q)           # K[b]q: agent b knows q
	ka_kb_p = Knowledge(:a, Knowledge(:b, p))  # K[a]K[b]p: a knows that b knows p

	println(ka_p)
	println(kb_q)
	println(ka_kb_p)
	println("is_modal_free(K[a]p): ", is_modal_free(ka_p))
end

# ╔═╡ f1f2f3f4-0007-0007-0007-000000000007
md"""
## Relational Models
A *multi-agent model* M = ⟨W, R, V⟩ where:
1. W is a nonempty set of possible worlds
2. R = {R_a : a ∈ G} is a family of accessibility relations, one per agent
3. V(p) ⊆ W is the set of worlds where propositional variable p is true

When R_a ww' holds, w' is *accessible by a from w* — agent a cannot distinguish
w from w'.
"""

# ╔═╡ f1f2f3f4-0008-0008-0008-000000000008
begin
	# Build a simple 3-world model with two agents a and b
	# Based on Figure 15.1 (B&D)
	# w1: p false, q false; w2: p true, q true; w3: p false, q false
	# Agent a: w1 can see w2; w2 and w3 only see themselves
	# Agent b: w1 can see w3; w2 and w3 only see themselves

	frame = EpistemicFrame(
		[:w1, :w2, :w3],
		[:a => [:w1 => :w2, :w2 => :w2, :w3 => :w3],
		 :b => [:w1 => :w3, :w2 => :w2, :w3 => :w3]]
	)

	model = EpistemicModel(frame, [:p => [:w2], :q => [:w2]])

	println("Worlds: ", sort(collect(frame.worlds)))
	println("Agent a's successors of w1: ", sort(collect(accessible(frame, :a, :w1))))
	println("Agent b's successors of w1: ", sort(collect(accessible(frame, :b, :w1))))
	println("Agents: ", sort(collect(agents(frame))))
end

# ╔═╡ f1f2f3f4-0009-0009-0009-000000000009
md"""
## Truth Conditions
Truth for K_a is exactly like □ in normal modal logic, but using R_a:

M, w ⊩ K_a B  iff  for all w' ∈ W with R_a ww': M, w' ⊩ B

If agent a has no accessible worlds from w, K_a B is vacuously true at w.
This is the same issue as with □ in normal modal logic — to avoid vacuous
knowledge, we typically require reflexivity (veridicality: K_a A → A).
"""

# ╔═╡ f1f2f3f4-0010-0010-0010-000000000010
begin
	# Truth of K[a]p at each world
	for w in [:w1, :w2, :w3]
		ka = satisfies(model, w, Knowledge(:a, p))
		kb = satisfies(model, w, Knowledge(:b, p))
		println("w=$w: K[a]p=$ka  K[b]p=$kb")
	end
end

# ╔═╡ f1f2f3f4-0011-0011-0011-000000000011
begin
	# At w1: a's successors = {w2}, p at w2 → K[a]p true
	#        b's successors = {w3}, p NOT at w3 → K[b]p false
	println("K[a]p at w1: ", satisfies(model, :w1, Knowledge(:a, p)), "  (a sees w2 where p holds)")
	println("K[b]p at w1: ", satisfies(model, :w1, Knowledge(:b, p)), "  (b sees w3 where p doesn't hold)")
	println()

	# Higher-order: does a know that b doesn't know p?
	b_doesnt_know = Not(Knowledge(:b, p))
	println("K[a](¬K[b]p) at w1: ", satisfies(model, :w1, Knowledge(:a, b_doesnt_know)))
	# a sees w2; at w2, b sees w2 (p there) → K[b]p true at w2 → ¬K[b]p false at w2 → false
end

# ╔═╡ f1f2f3f4-0012-0012-0012-000000000012
md"""
## Epistemic Principles (Table 15.1)

| Principle | Formula | Frame property | Reading |
|:----------|:--------|:---------------|:--------|
| Closure (K) | K(p→q)→(Kp→Kq) | none | Knowledge closed under implication |
| Veridicality (T) | K_a p → p | Reflexive R_a | Known things are true |
| Positive Introspection (4) | K_a p → K_a K_a p | Transitive R_a | If you know, you know you know |
| Negative Introspection (5) | ¬K_a p → K_a ¬K_a p | Euclidean R_a | If you don't know, you know you don't |

Epistemic logics typically use **S5** (reflexive + transitive + euclidean = equivalence
relations), corresponding to `EPISTEMIC_S5`.
"""

# ╔═╡ f1f2f3f4-0013-0013-0013-000000000013
begin
	# Veridicality requires reflexivity: K[a]p → p
	# Build a reflexive model (each world sees itself)
	ref_frame = EpistemicFrame(
		[:w1, :w2],
		[:a => [:w1 => :w1, :w1 => :w2, :w2 => :w2]]
	)
	ref_model = EpistemicModel(ref_frame, [:p => [:w1, :w2]])

	# Check K[a]p → p at both worlds
	veridicality = Implies(Knowledge(:a, p), p)
	for w in [:w1, :w2]
		println("K[a]p→p at $w: ", satisfies(ref_model, w, veridicality))
	end
end

# ╔═╡ f1f2f3f4-0014-0014-0014-000000000014
begin
	# Without reflexivity, veridicality can fail
	# Agent a at w1 sees only w2, but p is false at w1
	non_ref_frame = EpistemicFrame(
		[:w1, :w2],
		[:a => [:w1 => :w2, :w2 => :w2]]
	)
	non_ref_model = EpistemicModel(non_ref_frame, [:p => [:w2]])

	# K[a]p at w1: a sees w2, p at w2 → true
	# p at w1: false (p only at w2)
	# So K[a]p→p fails at w1
	println("K[a]p at w1: ", satisfies(non_ref_model, :w1, Knowledge(:a, p)))
	println("p at w1:     ", satisfies(non_ref_model, :w1, p))
	println("K[a]p→p at w1: ", satisfies(non_ref_model, :w1, Implies(Knowledge(:a, p), p)))
	println("  (veridicality fails without reflexivity)")
end

# ╔═╡ f1f2f3f4-0015-0015-0015-000000000015
md"""
## Group and Common Knowledge
**Group knowledge** E_{G'} A = ⋀_{b∈G'} K_b A:
"Everyone in G' knows A."

**Common knowledge** C_G A:
"Everyone knows A, and everyone knows everyone knows A, and ..."
Formally, M,w ⊩ C_G A iff A holds at every world reachable via the transitive
closure of ⋃_{b∈G} R_b.

Common knowledge is strictly stronger than group knowledge. A fact can be
group knowledge (everyone knows it) without being common knowledge (not
everyone knows that everyone knows it).
"""

# ╔═╡ f1f2f3f4-0016-0016-0016-000000000016
begin
	# Model where p is true at w1 and w2, both reachable from w1
	ck_frame = EpistemicFrame(
		[:w1, :w2, :w3],
		[:a => [:w1 => :w2, :w2 => :w2, :w3 => :w3],
		 :b => [:w1 => :w2, :w2 => :w2, :w3 => :w3]]
	)
	ck_model = EpistemicModel(ck_frame, [:p => [:w1, :w2]])

	# Group knowledge: every agent knows p
	println("group_knows(w1, {a,b}, p): ",
		group_knows(ck_model, :w1, [:a, :b], p))

	# Common knowledge: BFS from w1 visits w1 (p ✓) and w2 (p ✓)
	println("common_knowledge(w1, {a,b}, p): ",
		common_knowledge(ck_model, :w1, [:a, :b], p))

	# At w3: both agents' successors are only w3, and p is not at w3
	println("group_knows(w3, {a,b}, p): ",
		group_knows(ck_model, :w3, [:a, :b], p))
end

# ╔═╡ f1f2f3f4-0017-0017-0017-000000000017
md"""
## Bisimulations
A **bisimulation** ℛ ⊆ W₁ × W₂ between two models M₁ and M₂ satisfies:
for every ⟨w₁, w₂⟩ ∈ ℛ:

1. **Atomic agreement**: w₁ ∈ V₁(p) iff w₂ ∈ V₂(p) for all propositional variables p.
2. **Forth**: for each agent a and every v₁ with R_{a,1} w₁v₁, there exists v₂ with R_{a,2} w₂v₂ and ⟨v₁,v₂⟩ ∈ ℛ.
3. **Back**: for each agent a and every v₂ with R_{a,2} w₂v₂, there exists v₁ with R_{a,1} w₁v₁ and ⟨v₁,v₂⟩ ∈ ℛ.

**Theorem 15.8**: If ⟨M₁,w₁⟩ ⟺ ⟨M₂,w₂⟩ (linked by bisimulation), then
for every formula A: M₁,w₁ ⊩ A iff M₂,w₂ ⊩ A.

Two bisimilar worlds are *epistemically indistinguishable* — no formula
can tell them apart.
"""

# ╔═╡ f1f2f3f4-0018-0018-0018-000000000018
begin
	# Figure 15.2 (B&D): M1 has 3 worlds, M2 has 2, but they are bisimilar
	# M1: w1 sees w2 and w3 (agent a); w2 and w3 only see themselves; p at w2,w3
	frame1 = EpistemicFrame(
		[:w1, :w2, :w3],
		[:a => [:w1 => :w2, :w1 => :w3, :w2 => :w2, :w3 => :w3]]
	)
	m1 = EpistemicModel(frame1, [:p => [:w2, :w3]])

	# M2: v1 sees v2 (agent a); v2 only sees itself; p at v2
	frame2 = EpistemicFrame(
		[:v1, :v2],
		[:a => [:v1 => :v2, :v2 => :v2]]
	)
	m2 = EpistemicModel(frame2, [:p => [:v2]])

	# Bisimulation: w1↔v1, w2↔v2, w3↔v2
	bis = [:w1 => :v1, :w2 => :v2, :w3 => :v2]

	println("Is bisimulation: ", is_bisimulation(m1, m2, bis))
	println("w1 ↔ v1: ", bisimilar_worlds(m1, m2, :w1, :v1, bis))
end

# ╔═╡ f1f2f3f4-0019-0019-0019-000000000019
begin
	# Theorem 15.8: bisimilar worlds satisfy the same formulas
	formulas_to_check = [
		(p, "p"),
		(Knowledge(:a, p), "K[a]p"),
		(Not(Knowledge(:a, Not(p))), "¬K[a]¬p"),
		(Implies(Knowledge(:a, p), p), "K[a]p→p"),
	]

	println("Formula agreement at bisimilar worlds w1 ↔ v1:")
	for (φ, name) in formulas_to_check
		v_m1 = satisfies(m1, :w1, φ)
		v_m2 = satisfies(m2, :v1, φ)
		println("  $name: M1,w1=$(v_m1)  M2,v1=$(v_m2)  agree=$(v_m1==v_m2)")
	end
end

# ╔═╡ f1f2f3f4-0020-0020-0020-000000000020
md"""
## 15.7–15.8 Public Announcement Logic (Definitions 15.9–15.11)

**Public Announcement Logic (PAL)** extends epistemic logic with the
*public announcement operator* [B]C:

M, w ⊩ [B]C  iff  if M, w ⊩ B then M|B, w ⊩ C

where the *restricted model* M|B = ⟨W', R', V'⟩ is:
- W' = {u ∈ W : M,u ⊩ B} (worlds where B holds)
- R'_a = R_a ∩ (W' × W') (relations restricted to W')
- V'(p) = V(p) ∩ W' (valuation restricted to W')

Reading: "After B is truthfully announced, C holds."

If B is false at w, [B]C holds vacuously (announcement of a falsehood can't occur).
"""

# ╔═╡ f1f2f3f4-0021-0021-0021-000000000021
begin
	# Figure 15.3 (B&D): before and after announcing p
	# M: w1 (p,¬q), w2 (¬p,¬q), w3 (p,q)
	# Agent a: w1↔w1, w3↔w3 (reflexive), w2↔w2
	# Agent b: w1↔w2 (b can't tell w1 from w2), w3↔w3
	pal_frame = EpistemicFrame(
		[:w1, :w2, :w3],
		[:a => [:w1 => :w1, :w2 => :w2, :w3 => :w3],
		 :b => [:w1 => :w1, :w1 => :w2, :w2 => :w1, :w2 => :w2, :w3 => :w3]]
	)
	pal_model = EpistemicModel(pal_frame,
		[:p => [:w1, :w3], :q => [:w3]])

	println("=== Before announcement of p ===")
	println("K[b]p at w1: ", satisfies(pal_model, :w1, Knowledge(:b, p)),
		"  (b can't tell w1 from w2, and p false at w2)")
end

# ╔═╡ f1f2f3f4-0022-0022-0022-000000000022
begin
	# After announcing p: M|p drops w2
	m_p = restrict_model(pal_model, p)
	println("=== After announcement of p ===")
	println("Worlds in M|p: ", sort(collect(m_p.frame.worlds)))
	println("K[b]p at w1 in M|p: ", satisfies(m_p, :w1, Knowledge(:b, p)),
		"  (w2 dropped, so b now knows p)")
end

# ╔═╡ f1f2f3f4-0023-0023-0023-000000000023
begin
	# [p]K[b]p: after p is announced, b knows p
	announce_formula = Announce(p, Knowledge(:b, p))
	println("[p]K[b]p at w1: ", satisfies(pal_model, :w1, announce_formula))
	println("[p]K[b]p at w2: ", satisfies(pal_model, :w2, announce_formula),
		"  (p false at w2, so [p]C is vacuously true)")
end

# ╔═╡ f1f2f3f4-0024-0024-0024-000000000024
begin
	# [p]K[a]p: after p is announced, does a know p?
	# a's relation: w1→w1 only. In M|p: w1 still in W', a sees w1 (p there) → yes
	println("[p]K[a]p at w1: ", satisfies(pal_model, :w1, Announce(p, Knowledge(:a, p))))
end

# ╔═╡ f1f2f3f4-0025-0025-0025-000000000025
md"""
## Single-Agent Epistemic Logic

For a single agent, epistemic logic reduces to standard modal logic with K_a
playing the role of □. We can wrap any `KripkeModel` as an `EpistemicModel`:
"""

# ╔═╡ f1f2f3f4-0026-0026-0026-000000000026
begin
	# S5 single-agent knowledge: reflexive + transitive + euclidean
	s5_frame = KripkeFrame(
		[:w1, :w2, :w3],
		[:w1 => :w1, :w1 => :w2, :w1 => :w3,
		 :w2 => :w1, :w2 => :w2, :w2 => :w3,
		 :w3 => :w1, :w3 => :w2, :w3 => :w3]
	)
	s5_kripke = KripkeModel(s5_frame, [:p => [:w1, :w2]])
	s5_model = EpistemicModel(s5_kripke, :a)

	# Veridicality: K[a]p → p
	for w in [:w1, :w2, :w3]
		kap = satisfies(s5_model, w, Knowledge(:a, p))
		pval = satisfies(s5_model, w, p)
		ver = satisfies(s5_model, w, Implies(Knowledge(:a, p), p))
		println("w=$w: K[a]p=$kap  p=$pval  K[a]p→p=$ver")
	end
end

# ╔═╡ f1f2f3f4-0027-0027-0027-000000000027
md"""
## Summary

| Concept | Gamen.jl |
|:--------|:---------|
| Knowledge operator K_a | `Knowledge(agent, formula)` |
| Public announcement [B]C | `Announce(B, C)` |
| Multi-agent frame | `EpistemicFrame(worlds, agent_relations)` |
| Multi-agent model | `EpistemicModel(frame, valuation)` |
| Agent accessibility | `accessible(frame, agent, world)` |
| Agent set | `agents(frame)` |
| Restrict model M\|B | `restrict_model(model, formula)` |
| Group knowledge E_{G'}A | `group_knows(model, world, agents, formula)` |
| Common knowledge C_G A | `common_knowledge(model, world, agents, formula)` |
| Bisimulation check | `is_bisimulation(M1, M2, relation)` |
| Bisimilar worlds | `bisimilar_worlds(M1, M2, w1, w2, relation)` |
| From KripkeModel | `EpistemicModel(kripke_model, agent)` |

The epistemic systems are configured by frame conditions on each agent's
accessibility relation: K (none), KT (reflexive), S4 (reflexive+transitive),
S5 (reflexive+transitive+euclidean = equivalence relation).
"""

# ╔═╡ Cell order:
# ╠═f1f2f3f4-0001-0001-0001-000000000001
# ╠═f1f2f3f4-0002-0002-0002-000000000002
# ╠═f1f2f3f4-0003-0003-0003-000000000003
# ╠═f1f2f3f4-0004-0004-0004-000000000004
# ╠═f1f2f3f4-0005-0005-0005-000000000005
# ╠═f1f2f3f4-0006-0006-0006-000000000006
# ╠═f1f2f3f4-0007-0007-0007-000000000007
# ╠═f1f2f3f4-0008-0008-0008-000000000008
# ╠═f1f2f3f4-0009-0009-0009-000000000009
# ╠═f1f2f3f4-0010-0010-0010-000000000010
# ╠═f1f2f3f4-0011-0011-0011-000000000011
# ╠═f1f2f3f4-0012-0012-0012-000000000012
# ╠═f1f2f3f4-0013-0013-0013-000000000013
# ╠═f1f2f3f4-0014-0014-0014-000000000014
# ╠═f1f2f3f4-0015-0015-0015-000000000015
# ╠═f1f2f3f4-0016-0016-0016-000000000016
# ╠═f1f2f3f4-0017-0017-0017-000000000017
# ╠═f1f2f3f4-0018-0018-0018-000000000018
# ╠═f1f2f3f4-0019-0019-0019-000000000019
# ╠═f1f2f3f4-0020-0020-0020-000000000020
# ╠═f1f2f3f4-0021-0021-0021-000000000021
# ╠═f1f2f3f4-0022-0022-0022-000000000022
# ╠═f1f2f3f4-0023-0023-0023-000000000023
# ╠═f1f2f3f4-0024-0024-0024-000000000024
# ╠═f1f2f3f4-0025-0025-0025-000000000025
# ╠═f1f2f3f4-0026-0026-0026-000000000026
# ╠═f1f2f3f4-0027-0027-0027-000000000027
