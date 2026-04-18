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

# ╔═╡ e1e2e3e4-0002-0002-0002-000000000002
begin
	using Pkg
	Pkg.activate(joinpath(@__DIR__, ".."))
	using Gamen
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
	spq = Since(p, q)   # SpBC: since q was true, p has been true
	upq = Until(p, q)   # UpBC: until q becomes true, p holds

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

	# U(q)(p) at t1: ∃t' with t1≺t' and q at t', and p holds strictly between
	# Direct successors of t1: t2 and t3.
	# t' = t3: q at t3 ✓; s strictly between t1 and t3: s with t1→s and t3∈successors(s)
	#   → s = t2 (t1→t2, t2→t3). Is p at t2? Yes ✓ → Until holds
	println("U(q)(p) at t1: ", satisfies(m2, :t1, Until(q, p)))

	# S(p)(q) at t3: ∃t' ≺ t3 with p at t', and q holds strictly between t' and t3
	# Predecessors of t3: t2 (via t2→t3) and t1 (via t1→t3)
	# t' = t2: p at t2 ✓; strictly between t2 and t3: nothing → vacuously ✓
	println("S(p)(q) at t3: ", satisfies(m2, :t3, Since(p, q)))

	# U(q)(q) at t1: need q at t' and q between; t3 has q but t2 (between) doesn't
	println("U(q)(q) at t1: ", satisfies(m2, :t1, Until(q, q)))
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

# ╔═╡ e1e2e3e4-0025-0025-0025-000000000025
md"""
## Summary

| Concept | Gamen.jl |
|:--------|:---------|
| Past possibility (P) | `PastDiamond(A)` or `𝐏(A)` |
| Past necessity (H) | `PastBox(A)` or `𝐇(A)` |
| Future possibility (F) | `FutureDiamond(A)` or `𝐅(A)` |
| Future necessity (G) | `FutureBox(A)` or `𝐆(A)` |
| Since | `Since(B, C)` |
| Until | `Until(B, C)` |
| Temporal model | `KripkeModel` (same type, temporal reading) |
| Truth evaluation | `satisfies(model, t, formula)` |
| Frame properties | `is_transitive_frame`, `is_linear_frame`, `is_dense_frame`, `is_unbounded_past`, `is_unbounded_future` |

Temporal logic reuses the full Kripke model infrastructure — only the operators
and their reading change. The same `satisfies` function dispatches on the new
formula types.
"""

# ╔═╡ Cell order:
# ╠═e1e2e3e4-0001-0001-0001-000000000001
# ╠═e1e2e3e4-0002-0002-0002-000000000002
# ╠═e1e2e3e4-0003-0003-0003-000000000003
# ╠═e1e2e3e4-0004-0004-0004-000000000004
# ╠═e1e2e3e4-0005-0005-0005-000000000005
# ╠═e1e2e3e4-0006-0006-0006-000000000006
# ╠═e1e2e3e4-0007-0007-0007-000000000007
# ╠═e1e2e3e4-0008-0008-0008-000000000008
# ╠═e1e2e3e4-0009-0009-0009-000000000009
# ╠═e1e2e3e4-0010-0010-0010-000000000010
# ╠═e1e2e3e4-0011-0011-0011-000000000011
# ╠═e1e2e3e4-0012-0012-0012-000000000012
# ╠═e1e2e3e4-0013-0013-0013-000000000013
# ╠═e1e2e3e4-0014-0014-0014-000000000014
# ╠═e1e2e3e4-0015-0015-0015-000000000015
# ╠═e1e2e3e4-0016-0016-0016-000000000016
# ╠═e1e2e3e4-0017-0017-0017-000000000017
# ╠═e1e2e3e4-0018-0018-0018-000000000018
# ╠═e1e2e3e4-0019-0019-0019-000000000019
# ╠═e1e2e3e4-0020-0020-0020-000000000020
# ╠═e1e2e3e4-0021-0021-0021-000000000021
# ╠═e1e2e3e4-0022-0022-0022-000000000022
# ╠═e1e2e3e4-0023-0023-0023-000000000023
# ╠═e1e2e3e4-0024-0024-0024-000000000024
# ╠═e1e2e3e4-0025-0025-0025-000000000025
