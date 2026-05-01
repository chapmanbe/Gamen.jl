### A Pluto.jl notebook ###
# v0.20.4

using Markdown
using InteractiveUtils

# ╔═╡ e1e2e3e4-0001-0001-0001-000000000001
md"""
# Chapter 14: Temporal Logics

This notebook follows Chapter 14 of [Boxes and Diamonds](https://bd.openlogicproject.org)
using the **Gamen.jl** package.

We cover:
- Temporal formula types P, H, F, G (Definition 14.2)
- Temporal models M = ⟨T, ≺, V⟩ (Definition 14.3)
- Truth conditions for temporal operators (Definition 14.4)
- The binary Since and Until operators (Definition 14.5)
- Frame correspondence properties (Table 14.1)
"""

# ╔═╡ e1e2e3e4-0026-0026-0026-000000000026
md"""
## Why Temporal Logic?

Consider a scenario familiar from clinical care: a patient arrives with sepsis.
The treatment protocol specifies:

1. **Blood cultures must be drawn *before* antibiotics are administered.**
2. **Antibiotics must be given *within one hour* of sepsis recognition.**
3. **If the patient was already on antibiotics, the protocol does not apply.**

These sentences are not just true or false — they describe *relationships across
time*. "Before," "within," "already," "eventually" are temporal qualifiers that
plain propositional logic cannot capture.

Temporal logic gives us operators that reason over *sequences of events*:
- **G**A: "A is always true from now on" — invariants, safety properties
- **F**A: "A is eventually true" — liveness, guaranteed outcomes
- **H**A: "A has always been true in the past" — historical invariants
- **P**A: "A was true at some past time" — past witnessing

These are not mere programming conveniences. They are *formal tools* for
specifying, verifying, and reasoning about sequential processes — clinical
workflows, treatment timelines, event logs, and audit trails.

**Learning objectives:** After this notebook you will be able to:
1. Construct temporal formulas using the P, H, F, G, Since, and Until operators
2. Build and evaluate temporal Kripke models in Gamen.jl
3. Explain the duality between past and future operators
4. Identify frame correspondence properties (transitivity, linearity, density) and their valid formulas
"""

# ╔═╡ e1e2e3e4-0002-0002-0002-000000000002
begin
	using Gamen
	using PlutoUI
	import CairoMakie, GraphMakie, Graphs
end

# ╔═╡ e1e2e3e4-0003-0003-0003-000000000003
begin
	p = Atom(:p)
	q = Atom(:q)
	r = Atom(:r)
end;

# ╔═╡ e1e2e3e4-0004-0004-0004-000000000004
md"""
## Introduction

Temporal logic extends modal logic with operators for *time*. Instead of
"possible worlds," we have *time points* with a *precedence relation* ≺.

Instead of a single □/◇ pair, temporal logic uses four operators:

| Operator | Reading | Dual |
|:---------|:--------|:-----|
| **P**A | "previously" — A was true at some past time | **H** |
| **H**A | "historically" — A has always been true in the past | **P** |
| **F**A | "eventually" — A will be true at some future time | **G** |
| **G**A | "always" — A will always be true in the future | **F** |

Just as ◇ and □ are duals (◇A = ¬□¬A), so PA = ¬H¬A and FA = ¬G¬A.

Temporal logics are interpreted in *relational models* — the same kind of
Kripke models we've been using throughout, just with a temporal reading.
"""

# ╔═╡ e1e2e3e4-0005-0005-0005-000000000005
md"""
## The Language
Temporal formulas extend the propositional base with four unary operators:
- **P**A: A was true at some t' with t' ≺ t ("previously")
- **H**A: A was true at all t' with t' ≺ t ("historically")
- **F**A: A will be true at some t' with t ≺ t' ("eventually")
- **G**A: A will be true at all t' with t ≺ t' ("always")

And two binary operators (Definition 14.5):
- **S**BC: "B has been the case since C was" (Since)
- **U**BC: "B will be the case until C will be" (Until)
"""

# ╔═╡ e1e2e3e4-0006-0006-0006-000000000006
begin
	# Temporal formula construction
	fp = FutureDiamond(p)    # Fp: p will eventually hold
	gp = FutureBox(p)        # Gp: p will always hold
	pp = PastDiamond(p)      # Pp: p held at some past time
	hp = PastBox(p)          # Hp: p has always held in the past

	println("FutureDiamond(p) = ", fp)
	println("FutureBox(p)     = ", gp)
	println("PastDiamond(p)   = ", pp)
	println("PastBox(p)       = ", hp)

	# Unicode aliases
	println("𝐅(p) = ", 𝐅(p))
	println("𝐆(p) = ", 𝐆(p))
	println("𝐏(p) = ", 𝐏(p))
	println("𝐇(p) = ", 𝐇(p))
end

# ╔═╡ e1e2e3e4-0007-0007-0007-000000000007
begin
	# Since and Until
	spq = Since(p, q)   # S(p,q): p was true at t', q held strictly between t' and now
	upq = Until(p, q)   # U(p,q): p will be true at t', q holds strictly between now and t'

	println("Since(p, q) = ", spq)
	println("Until(p, q) = ", upq)
	println("is_modal_free(Fp): ", is_modal_free(fp))
end

# ╔═╡ e1e2e3e4-0008-0008-0008-000000000008
md"""
## Temporal Models
A *temporal model* M = ⟨T, ≺, V⟩ consists of:
1. A nonempty set T of *time points*
2. A binary *precedence relation* ≺ on T
3. A valuation V assigning to each propositional variable p a set V(p) ⊆ T

When t ≺ t' we say *t precedes t'*.

In Gamen.jl, `TemporalModel` is an alias for `KripkeModel` — we reuse the
same infrastructure. The precedence relation ≺ is the accessibility relation R:
t₁ ≺ t₂ means t₁ => t₂ in the frame.
"""

# ╔═╡ e1e2e3e4-0009-0009-0009-000000000009
begin
	# A simple linear temporal model: t1 ≺ t2 ≺ t3
	# p is true at t1 and t2; q is true at t3
	m_linear = KripkeModel(
		KripkeFrame([:t1, :t2, :t3], [:t1 => :t2, :t2 => :t3]),
		[:p => [:t1, :t2], :q => [:t3]]
	)

	println("Worlds: ", sort(collect(m_linear.frame.worlds)))
	println("Successors of t1: ", sort(collect(accessible(m_linear.frame, :t1))))
	println("Successors of t2: ", sort(collect(accessible(m_linear.frame, :t2))))
	println("Successors of t3: ", sort(collect(accessible(m_linear.frame, :t3))))
end

# ╔═╡ e1e2e3e4-0028-0028-0028-000000000028
begin
	# Visualize the linear temporal model
	# t1 → t2 → t3, p holds at t1 and t2, q holds at t3
	visualize_model(m_linear, title = "Linear temporal model: t1 ≺ t2 ≺ t3")
end

# ╔═╡ e1e2e3e4-0029-0029-0029-000000000029
md"""
$(Markdown.MD(Markdown.Admonition("note", "Knowledge Representation Lens: Temporal Models as Surrogates (Davis et al. 1993)", [md"Davis, Shrobe, and Szolovits (1993) identify the first role of a knowledge representation as a **surrogate** — a substitute for things in the world that enables reasoning. A temporal Kripke model M = ⟨T, ≺, V⟩ is a surrogate for a *sequence of events*. The time points T stand in for real moments; the precedence relation ≺ encodes their ordering; V maps propositions to the times when they hold. As Davis et al. note, 'perfect fidelity is impossible' — a temporal model of a clinical timeline omits duration, uncertainty, concurrency, and measurement error. The choice of what to include (and what to leave out) is an *ontological commitment*: by using a simple linear chain we commit to a deterministic, totally ordered history. Branching-time models (Ch 14's general frames) relax this, admitting multiple possible futures. The mismatch between the surrogate and reality is not a defect to be fixed — it is the price of tractable reasoning."])))
"""

# ╔═╡ e1e2e3e4-0010-0010-0010-000000000010
md"""
## Truth Conditions
The temporal operators are evaluated as follows:

| Operator | M,t ⊩ A iff... |
|:---------|:----------------|
| **P**A | M,t' ⊩ A for some t' with t' ≺ t |
| **H**A | M,t' ⊩ A for all t' with t' ≺ t |
| **F**A | M,t' ⊩ A for some t' with t ≺ t' |
| **G**A | M,t' ⊩ A for all t' with t ≺ t' |

Note: **H** and **G** are vacuously true when there are no predecessors or
successors respectively. An endpoint "always satisfies" any G/H formula.

Also note: these are *direct* (one-step) accessibility, not transitive closure.
Fp means there is a direct successor where p holds — not some eventual future.
"""

# ╔═╡ e1e2e3e4-0011-0011-0011-000000000011
begin
	# F: eventually — direct successors only
	println("Fp at t1: ", satisfies(m_linear, :t1, FutureDiamond(p)))
	# t1 → t2, and p is true at t2 → true
	println("Fq at t1: ", satisfies(m_linear, :t1, FutureDiamond(q)))
	# t1 → t2, q is NOT at t2 (q only at t3) → false
	println("Fq at t2: ", satisfies(m_linear, :t2, FutureDiamond(q)))
	# t2 → t3, q is at t3 → true
end

# ╔═╡ e1e2e3e4-0012-0012-0012-000000000012
begin
	# G: always — all direct successors
	println("Gp at t1: ", satisfies(m_linear, :t1, FutureBox(p)))
	# t1 → t2, p at t2 ✓; but t2 → t3 is not a direct successor of t1 → true (only t2 checked)
	println("Gq at t2: ", satisfies(m_linear, :t2, FutureBox(q)))
	# t2 → t3, q at t3 ✓ → true
	println("Gp at t3: ", satisfies(m_linear, :t3, FutureBox(p)))
	# t3 has no successors → vacuously true
end

# ╔═╡ e1e2e3e4-0013-0013-0013-000000000013
begin
	# P: previously — some predecessor has A
	println("Pp at t1: ", satisfies(m_linear, :t1, PastDiamond(p)))
	# t1 has no predecessors → false
	println("Pp at t2: ", satisfies(m_linear, :t2, PastDiamond(p)))
	# t1 ≺ t2, p at t1 → true
	println("Pp at t3: ", satisfies(m_linear, :t3, PastDiamond(p)))
	# t2 ≺ t3, p at t2 → true
end

# ╔═╡ e1e2e3e4-0014-0014-0014-000000000014
begin
	# H: historically — all predecessors have A
	println("Hq at t1: ", satisfies(m_linear, :t1, PastBox(q)))
	# t1 has no predecessors → vacuously true
	println("Hq at t2: ", satisfies(m_linear, :t2, PastBox(q)))
	# t1 ≺ t2, q NOT at t1 → false
	println("Hp at t3: ", satisfies(m_linear, :t3, PastBox(p)))
	# t2 ≺ t3, p at t2 ✓ → true (only direct predecessor checked)
end

# ╔═╡ e1e2e3e4-0030-0030-0030-000000000030
md"""
## Exercises: Temporal Operators

Work through these before revealing the answers.

**1. In the linear model t1 ≺ t2 ≺ t3 (p at t1,t2; q at t3), evaluate G(p) at t1.**

Recall G looks at *all* direct successors. At t1, the only direct successor is t2.

$(Markdown.MD(Markdown.Admonition("hint", "Reveal answer", [md"**True.** The only direct successor of t1 is t2, and p holds at t2. G looks one step ahead, not transitively — so t3 is not checked. Gp at t1 = true."])))

**2. In the same model, is G(q) valid at t1? What about at t2?**

$(Markdown.MD(Markdown.Admonition("hint", "Reveal answer", [md"**G(q) at t1 = false.** The direct successor of t1 is t2, and q does NOT hold at t2. **G(q) at t2 = true.** The direct successor of t2 is t3, and q holds at t3."])))

**3. Translate into temporal formula: 'p has been continuously true since the beginning (from the current time looking back, all predecessors satisfy p).'**

$(Markdown.MD(Markdown.Admonition("hint", "Reveal answer", [md"H(p) — PastBox(p). The H operator says: for every t' ≺ t (direct predecessor), p holds at t'. At t1 this is vacuously true (no predecessors). At t2 it checks t1, and at t3 it checks t2 only."])))
"""

# ╔═╡ e1e2e3e4-0015-0015-0015-000000000015
md"""
## Duality

Just as □ and ◇ are duals, the temporal operators come in dual pairs:
- **H**A = ¬**P**¬A (if A has always been true ↔ it's never been that ¬A was true)
- **G**A = ¬**F**¬A (A will always be true ↔ it will never be that ¬A holds)

We can verify this holds in our model:
"""

# ╔═╡ e1e2e3e4-0016-0016-0016-000000000016
begin
	# HA = ¬P¬A duality
	for t in [:t1, :t2, :t3]
		ha = satisfies(m_linear, t, PastBox(p))
		dual_ha = !satisfies(m_linear, t, PastDiamond(Not(p)))
		println("H(p) at $t: $ha   ¬P(¬p) at $t: $dual_ha   match: $(ha == dual_ha)")
	end
end

# ╔═╡ e1e2e3e4-0017-0017-0017-000000000017
begin
	# GA = ¬F¬A duality
	for t in [:t1, :t2, :t3]
		ga = satisfies(m_linear, t, FutureBox(p))
		dual_ga = !satisfies(m_linear, t, FutureDiamond(Not(p)))
		println("G(p) at $t: $ga   ¬F(¬p) at $t: $dual_ga   match: $(ga == dual_ga)")
	end
end

# ╔═╡ e1e2e3e4-0031-0031-0031-000000000031
md"""
## Exercise: Build a Model

**4. Construct a temporal model where G(p) is true at every time point.**

What is the simplest model where G(p) holds at all worlds? Think about what frame condition would guarantee this.

$(Markdown.MD(Markdown.Admonition("hint", "Reveal answer", [md"One approach: a model with no worlds at all (empty frame) — vacuously true, but degenerate. A more informative answer: a model where p holds at every world and the frame has no dead ends. For example, a cyclic model {t1 → t1} with p at t1 satisfies G(p) everywhere, since every direct successor (t1 itself) has p. Try: `KripkeModel(KripkeFrame([:t1], [:t1 => :t1]), [:p => [:t1]])` and verify `satisfies(m, :t1, FutureBox(Atom(:p)))` returns true."])))
"""

# ╔═╡ e1e2e3e4-0018-0018-0018-000000000018
md"""
## Since and Until
**S**BC (Since): M,t ⊩ SBC iff there exists t' ≺ t such that:
- M,t' ⊩ B, and
- for all s with t' ≺ s ≺ t (strictly between t' and t): M,s ⊩ C

Intuition: "B has been the case, and C has held since then."

**U**BC (Until): M,t ⊩ UBC iff there exists t' with t ≺ t' such that:
- M,t' ⊩ B, and
- for all s with t ≺ s ≺ t' (strictly between t and t'): M,s ⊩ C

Intuition: "C holds until B becomes true."
"""

# ╔═╡ e1e2e3e4-0019-0019-0019-000000000019
begin
	# Model with direct edges t1→t2, t1→t3, t2→t3
	# p at t1,t2; q at t3
	m2 = KripkeModel(
		KripkeFrame([:t1, :t2, :t3], [:t1 => :t2, :t1 => :t3, :t2 => :t3]),
		[:p => [:t1, :t2], :q => [:t3]]
	)

	# U(q, p) at t1: left=q (B: true at t'), right=p (C: holds between)
	# Direct successors of t1: t2 and t3.
	# t' = t3: q at t3 ✓; s strictly between t1 and t3:
	#   s = t2 (t1→t2, t2→t3 ✓). Is p at t2? Yes ✓ → Until holds
	println("U(q, p) at t1: ", satisfies(m2, :t1, Until(q, p)))

	# S(p, q) at t3: left=p (B: true at t'), right=q (C: holds between)
	# Predecessors of t3: t2 (t2→t3) and t1 (t1→t3)
	# t' = t2: p at t2 ✓; strictly between t2 and t3: nothing → vacuously ✓
	println("S(p, q) at t3: ", satisfies(m2, :t3, Since(p, q)))

	# U(q, q) at t1: need q at t' and q strictly between
	# t' = t3: q at t3 ✓; s = t2 between t1 and t3, need q at t2 — NO
	println("U(q, q) at t1: ", satisfies(m2, :t1, Until(q, q)))
end

# ╔═╡ e1e2e3e4-0020-0020-0020-000000000020
md"""
## Frame Correspondence Properties (Table 14.1)

Just as in normal modal logic, restricting the precedence relation yields
additional valid formulas. Table 14.1 lists several:

| Frame property | Valid formula |
|:---------------|:-------------|
| Transitive (∀uvw: u≺v∧v≺w→u≺w) | FFp → Fp |
| Linear (∀uv: u≺v∨u=v∨v≺u) | (FPp∨PFp) → (Pp∨p∨Fp) |
| Dense (∀uv: u≺v→∃w: u≺w≺v) | Fp → FFp |
| Unbounded past (∀w∃v: v≺w) | Hp → Pp |
| Unbounded future (∀w∃v: w≺v) | Gp → Fp |

Note: transitivity in temporal frames is distinct from the S4 transitivity
of □. A transitive ≺ gives FFp→Fp (if p will hold in the future's future,
then it will hold in the future — given transitivity closes the gap).
"""

# ╔═╡ e1e2e3e4-0021-0021-0021-000000000021
begin
	# Transitive frame test
	non_trans = KripkeFrame([:t1,:t2,:t3], [:t1=>:t2, :t2=>:t3])
	trans = KripkeFrame([:t1,:t2,:t3], [:t1=>:t2, :t2=>:t3, :t1=>:t3])
	println("Non-transitive frame is_transitive_frame: ", is_transitive_frame(non_trans))
	println("Transitive frame is_transitive_frame:     ", is_transitive_frame(trans))
end

# ╔═╡ e1e2e3e4-0022-0022-0022-000000000022
begin
	# Linear frame: every two distinct time points are comparable
	linear_frame = KripkeFrame([:t1,:t2,:t3], [:t1=>:t2, :t2=>:t3, :t1=>:t3])
	branching = KripkeFrame([:t1,:t2,:t3], [:t1=>:t2, :t1=>:t3])
	println("Linear frame is_linear_frame:    ", is_linear_frame(linear_frame))
	println("Branching frame is_linear_frame: ", is_linear_frame(branching))
end

# ╔═╡ e1e2e3e4-0023-0023-0023-000000000023
begin
	# Dense frame: between any two related points there is another
	# t1→t2 with t2→t2 (self-loop): between t1 and t2 we can find t2 itself
	dense_frame = KripkeFrame([:t1,:t2], [:t1=>:t2, :t2=>:t2])
	sparse = KripkeFrame([:t1,:t2], [:t1=>:t2])
	println("Dense frame is_dense_frame:  ", is_dense_frame(dense_frame))
	println("Sparse frame is_dense_frame: ", is_dense_frame(sparse))
end

# ╔═╡ e1e2e3e4-0024-0024-0024-000000000024
begin
	# Unbounded past/future
	bounded = KripkeFrame([:t1,:t2], [:t1=>:t2])
	cyclic  = KripkeFrame([:t1,:t2], [:t1=>:t2, :t2=>:t1])
	println("Bounded: unbounded_past=",  is_unbounded_past(bounded),
	        "  unbounded_future=", is_unbounded_future(bounded))
	println("Cyclic:  unbounded_past=",  is_unbounded_past(cyclic),
	        "  unbounded_future=", is_unbounded_future(cyclic))
end

# ╔═╡ e1e2e3e4-0032-0032-0032-000000000032
md"""
## Exercise: Frame Properties

**5. Is a cyclic frame with t1 ↔ t2 (t1→t2 and t2→t1) transitive? Linear? Dense?**

$(Markdown.MD(Markdown.Admonition("hint", "Reveal answer", [md"**Transitive? Yes.** From t1→t2→t1 we need t1→t1, but that edge is absent — so actually NOT transitive without self-loops. **Linear? Yes.** Every pair of worlds is comparable (t1 and t2 each point to the other). **Dense? No.** t1→t2 requires a w with t1→w→t2; only t1 and t2 exist, and t1→t1 is absent, so no intermediate witness exists."])))

**6. A transitive, linear, unbounded-future frame corresponds to the standard integers (Z, <). What formula is valid on this frame but not on a chain with a last element?**

$(Markdown.MD(Markdown.Admonition("hint", "Reveal answer", [md"**Gp → Fp** (unbounded future). On a chain with a last element (say t3 with no successors), Gp holds vacuously at t3 but Fp requires a successor, so Gp → Fp fails. On an unbounded frame every world has a successor, so Gp → Fp is valid."])))
"""

# ╔═╡ e1e2e3e4-0025-0025-0025-000000000025
md"""
## Summary

| Concept | Gamen.jl |
|:--------|:---------|
| Past possibility (P) | `PastDiamond(A)` or `𝐏(A)` |
| Past necessity (H) | `PastBox(A)` or `𝐇(A)` |
| Future possibility (F) | `FutureDiamond(A)` or `𝐅(A)` |
| Future necessity (G) | `FutureBox(A)` or `𝐆(A)` |
| Since | `Since(B, C)` — B was true at t', C holds strictly between |
| Until | `Until(B, C)` — B will be true at t', C holds strictly between |
| Temporal model | `KripkeModel` (same type, temporal reading) |
| Truth evaluation | `satisfies(model, t, formula)` |
| Frame properties | `is_transitive_frame`, `is_linear_frame`, `is_dense_frame`, `is_unbounded_past`, `is_unbounded_future` |

Temporal logic reuses the full Kripke model infrastructure — only the operators
and their reading change. The same `satisfies` function dispatches on the new
formula types.
"""

# ╔═╡ Cell order:
# ╟─e1e2e3e4-0001-0001-0001-000000000001
# ╟─e1e2e3e4-0026-0026-0026-000000000026
# ╟─e1e2e3e4-0002-0002-0002-000000000002
# ╟─e1e2e3e4-0003-0003-0003-000000000003
# ╟─e1e2e3e4-0004-0004-0004-000000000004
# ╟─e1e2e3e4-0005-0005-0005-000000000005
# ╟─e1e2e3e4-0006-0006-0006-000000000006
# ╟─e1e2e3e4-0007-0007-0007-000000000007
# ╟─e1e2e3e4-0008-0008-0008-000000000008
# ╟─e1e2e3e4-0009-0009-0009-000000000009
# ╟─e1e2e3e4-0028-0028-0028-000000000028
# ╟─e1e2e3e4-0029-0029-0029-000000000029
# ╟─e1e2e3e4-0010-0010-0010-000000000010
# ╟─e1e2e3e4-0011-0011-0011-000000000011
# ╟─e1e2e3e4-0012-0012-0012-000000000012
# ╟─e1e2e3e4-0013-0013-0013-000000000013
# ╟─e1e2e3e4-0014-0014-0014-000000000014
# ╟─e1e2e3e4-0030-0030-0030-000000000030
# ╟─e1e2e3e4-0015-0015-0015-000000000015
# ╟─e1e2e3e4-0016-0016-0016-000000000016
# ╟─e1e2e3e4-0017-0017-0017-000000000017
# ╟─e1e2e3e4-0031-0031-0031-000000000031
# ╟─e1e2e3e4-0018-0018-0018-000000000018
# ╟─e1e2e3e4-0019-0019-0019-000000000019
# ╟─e1e2e3e4-0020-0020-0020-000000000020
# ╟─e1e2e3e4-0021-0021-0021-000000000021
# ╟─e1e2e3e4-0022-0022-0022-000000000022
# ╟─e1e2e3e4-0023-0023-0023-000000000023
# ╟─e1e2e3e4-0024-0024-0024-000000000024
# ╟─e1e2e3e4-0032-0032-0032-000000000032
# ╟─e1e2e3e4-0025-0025-0025-000000000025
