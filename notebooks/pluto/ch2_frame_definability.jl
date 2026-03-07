### A Pluto.jl notebook ###
# v0.20.4

using Markdown
using InteractiveUtils

# ╔═╡ 2a2b3c4d-0001-0001-0001-000000000001
md"""
# Chapter 2: Frame Definability

This notebook follows Chapter 2 of [Boxes and Diamonds](https://bd.openlogicproject.org)
using the **Gamen.jl** package.

We cover:
- Validity on a frame (Definition 2.1)
- Frame properties: reflexivity, symmetry, transitivity, seriality, euclideanness (Definition 2.3)
- The correspondence between modal schemas and frame properties
"""

# ╔═╡ 2a2b3c4d-0002-0002-0002-000000000002
begin
	using Pkg
	Pkg.activate(joinpath(@__DIR__, "..", ".."))
	using Gamen
end

# ╔═╡ 2a2b3c4d-0030-0030-0030-000000000030
md"""
### Unicode Modal Operators

Gamen.jl exports `□` and `◇` as Unicode aliases for `Box` and `Diamond`. Type `\square<tab>` and `\diamond<tab>` in the Julia REPL. Throughout this notebook, we use these Unicode operators to write formulas that mirror the mathematical notation.
"""

# ╔═╡ 2a2b3c4d-0003-0003-0003-000000000003
md"""
## 2.1 Validity on a Frame

Recall from Chapter 1 that a formula can be *true in a model*. But a model
includes a specific valuation $V$. A stronger notion is *validity on a frame*:

> **Definition 2.1.** A formula $A$ is *valid on a frame* $F = \langle W, R \rangle$
> if $A$ is true in every model $M = \langle W, R, V \rangle$ based on $F$ —
> that is, for every possible valuation $V$.

This tells us what a frame's *structure* (its accessibility relation) forces
to be true, independent of which propositions hold where.
"""

# ╔═╡ 2a2b3c4d-0004-0004-0004-000000000004
begin
	p = Atom(:p)
	q = Atom(:q)

	frame = KripkeFrame([:w1, :w2], [:w1 => :w2])

	# □⊤ is valid on any frame — ⊤ is true everywhere, so □⊤ is too
	# Using Unicode: □ === Box, ◇ === Diamond (type \square<tab> / \diamond<tab>)
	is_valid_on_frame(frame, □(Top()))
end

# ╔═╡ 2a2b3c4d-0005-0005-0005-000000000005
# But □p → p is NOT valid on this frame — it's not reflexive
is_valid_on_frame(frame, Implies(□(p), p))

# ╔═╡ 2a2b3c4d-0006-0006-0006-000000000006
md"""
## 2.2 Frame Properties (Definition 2.3)

The key insight of frame definability is that certain *structural properties*
of the accessibility relation correspond to specific modal *schemas*.

The five main properties are:

| Property | Condition | Intuition |
|:---------|:----------|:----------|
| Reflexive | $\forall w.\; Rww$ | Every world accesses itself |
| Symmetric | $\forall w, w'.\; Rww' \to Rw'w$ | Access goes both ways |
| Transitive | $\forall w, w', w''.\; Rww' \land Rw'w'' \to Rww''$ | Access chains compose |
| Serial | $\forall w.\; \exists w'.\; Rww'$ | Every world has a successor |
| Euclidean | $\forall w, w', w''.\; Rww' \land Rww'' \to Rw'w''$ | Successors see each other |
"""

# ╔═╡ 2a2b3c4d-0007-0007-0007-000000000007
md"""
### Testing Frame Properties

Let's build some frames and check their properties:
"""

# ╔═╡ 2a2b3c4d-0008-0008-0008-000000000008
begin
	# A reflexive, transitive frame (a preorder)
	preorder = KripkeFrame([:w1, :w2, :w3],
		[:w1 => :w1, :w2 => :w2, :w3 => :w3,   # reflexive loops
		 :w1 => :w2, :w2 => :w3, :w1 => :w3])   # transitive chain

	(reflexive = is_reflexive(preorder),
	 symmetric = is_symmetric(preorder),
	 transitive = is_transitive(preorder),
	 serial = is_serial(preorder),
	 euclidean = is_euclidean(preorder))
end

# ╔═╡ 2a2b3c4d-0009-0009-0009-000000000009
begin
	# An equivalence relation (reflexive + symmetric + transitive)
	equiv = KripkeFrame([:w1, :w2],
		[:w1 => :w1, :w2 => :w2, :w1 => :w2, :w2 => :w1])

	(reflexive = is_reflexive(equiv),
	 symmetric = is_symmetric(equiv),
	 transitive = is_transitive(equiv),
	 serial = is_serial(equiv),
	 euclidean = is_euclidean(equiv))
end

# ╔═╡ 2a2b3c4d-0010-0010-0010-000000000010
md"""
## 2.3 The Correspondence Results

The central results of Chapter 2 show that each frame property corresponds
to a modal schema being valid on the frame:

| Schema | Name | Formula | Frame Property |
|:-------|:-----|:--------|:---------------|
| **K** | Distribution | $\square(p \to q) \to (\square p \to \square q)$ | *All frames* |
| **T** | Reflexivity | $\square p \to p$ | Reflexive |
| **D** | Seriality | $\square p \to \diamond p$ | Serial |
| **B** | Symmetry | $p \to \square\diamond p$ | Symmetric |
| **4** | Transitivity | $\square p \to \square\square p$ | Transitive |
| **5** | Euclideanness | $\diamond p \to \square\diamond p$ | Euclidean |

Let's verify each one.
"""

# ╔═╡ 2a2b3c4d-0011-0011-0011-000000000011
md"""
### Schema K: Valid on All Frames (Proposition 1.19)

$\square(p \to q) \to (\square p \to \square q)$

This is the *distribution axiom* — it holds on every frame, regardless of
structure. It says that $\square$ distributes over implication.
"""

# ╔═╡ 2a2b3c4d-0012-0012-0012-000000000012
begin
	# □(p → q) → (□p → □q), using Unicode □
	schema_k = Implies(□(Implies(p, q)), Implies(□(p), □(q)))

	frame1 = KripkeFrame([:w1, :w2], [:w1 => :w2])
	frame2 = KripkeFrame([:w1, :w2, :w3], [:w1 => :w2, :w2 => :w3])
	frame3 = KripkeFrame([:w1], [:w1 => :w1])

	(frame1 = is_valid_on_frame(frame1, schema_k),
	 frame2 = is_valid_on_frame(frame2, schema_k),
	 frame3 = is_valid_on_frame(frame3, schema_k))
end

# ╔═╡ 2a2b3c4d-0013-0013-0013-000000000013
md"""
### Schema T: □p → p corresponds to Reflexivity (Proposition 2.5)

If every world can see itself, then whatever is necessary is actual.
Conversely, if $\square p \to p$ is valid, the frame must be reflexive.
"""

# ╔═╡ 2a2b3c4d-0014-0014-0014-000000000014
begin
	schema_t = Implies(□(p), p)

	reflexive_frame = KripkeFrame([:w1, :w2],
		[:w1 => :w1, :w1 => :w2, :w2 => :w2])
	non_reflexive_frame = KripkeFrame([:w1, :w2], [:w1 => :w2])

	(reflexive = is_valid_on_frame(reflexive_frame, schema_t),
	 non_reflexive = is_valid_on_frame(non_reflexive_frame, schema_t))
end

# ╔═╡ 2a2b3c4d-0015-0015-0015-000000000015
md"""
### Schema D: □p → ◇p corresponds to Seriality (Proposition 2.7)

If every world has at least one successor, then whatever is necessary
is at least possible. A world with no successors makes $\square p$
vacuously true while $\diamond p$ is false.
"""

# ╔═╡ 2a2b3c4d-0016-0016-0016-000000000016
begin
	schema_d = Implies(□(p), ◇(p))

	serial_frame = KripkeFrame([:w1, :w2], [:w1 => :w2, :w2 => :w1])
	non_serial_frame = KripkeFrame([:w1, :w2], [:w1 => :w2])

	(serial = is_valid_on_frame(serial_frame, schema_d),
	 non_serial = is_valid_on_frame(non_serial_frame, schema_d))
end

# ╔═╡ 2a2b3c4d-0017-0017-0017-000000000017
md"""
### Schema B: p → □◇p corresponds to Symmetry (Proposition 2.9)

If you can go back wherever you came from, then if $p$ is true here,
it's necessarily possible (every accessible world can see back to where $p$ holds).
"""

# ╔═╡ 2a2b3c4d-0018-0018-0018-000000000018
begin
	schema_b = Implies(p, □(◇(p)))

	symmetric_frame = KripkeFrame([:w1, :w2],
		[:w1 => :w2, :w2 => :w1, :w1 => :w1, :w2 => :w2])
	non_symmetric_frame = KripkeFrame([:w1, :w2], [:w1 => :w2, :w2 => :w2])

	(symmetric = is_valid_on_frame(symmetric_frame, schema_b),
	 non_symmetric = is_valid_on_frame(non_symmetric_frame, schema_b))
end

# ╔═╡ 2a2b3c4d-0019-0019-0019-000000000019
md"""
### Schema 4: □p → □□p corresponds to Transitivity (Proposition 2.11)

If accessibility chains compose, then knowing something is necessary
means knowing it's necessarily necessary — you can't "escape" necessity
by going further.
"""

# ╔═╡ 2a2b3c4d-0020-0020-0020-000000000020
begin
	schema_4 = Implies(□(p), □(□(p)))

	transitive_frame = KripkeFrame([:w1, :w2, :w3],
		[:w1 => :w2, :w2 => :w3, :w1 => :w3])
	non_transitive_frame = KripkeFrame([:w1, :w2, :w3],
		[:w1 => :w2, :w2 => :w3])

	(transitive = is_valid_on_frame(transitive_frame, schema_4),
	 non_transitive = is_valid_on_frame(non_transitive_frame, schema_4))
end

# ╔═╡ 2a2b3c4d-0021-0021-0021-000000000021
md"""
### Schema 5: ◇p → □◇p corresponds to Euclideanness (Proposition 2.13)

If all successors of a world can see each other, then if something is
possible, it's necessarily possible — every accessible world agrees on
what's possible.
"""

# ╔═╡ 2a2b3c4d-0022-0022-0022-000000000022
begin
	schema_5 = Implies(◇(p), □(◇(p)))

	euclidean_frame = KripkeFrame([:w1, :w2, :w3],
		[:w1 => :w2, :w1 => :w3, :w2 => :w2, :w2 => :w3, :w3 => :w2, :w3 => :w3])
	non_euclidean_frame = KripkeFrame([:w1, :w2, :w3],
		[:w1 => :w2, :w1 => :w3])

	(euclidean = is_valid_on_frame(euclidean_frame, schema_5),
	 non_euclidean = is_valid_on_frame(non_euclidean_frame, schema_5))
end

# ╔═╡ 2a2b3c4d-0023-0023-0023-000000000023
md"""
## 2.4 Normal Modal Logics

Combining these schemas gives named systems of modal logic:

| System | Axioms | Frame Class |
|:-------|:-------|:------------|
| **K** | K | All frames |
| **T** | K + T | Reflexive frames |
| **K4** | K + 4 | Transitive frames |
| **S4** | K + T + 4 | Reflexive + transitive (preorders) |
| **S5** | K + T + 5 | Reflexive + euclidean (equivalence relations) |
| **KD** | K + D | Serial frames |

Let's verify that S4 frames (preorders) validate both T and 4:
"""

# ╔═╡ 2a2b3c4d-0024-0024-0024-000000000024
begin
	# An S4 frame: reflexive and transitive
	s4_frame = KripkeFrame([:w1, :w2, :w3],
		[:w1 => :w1, :w2 => :w2, :w3 => :w3,
		 :w1 => :w2, :w2 => :w3, :w1 => :w3])

	@assert is_reflexive(s4_frame) && is_transitive(s4_frame)

	(T_valid = is_valid_on_frame(s4_frame, schema_t),
	 schema_4_valid = is_valid_on_frame(s4_frame, schema_4))
end

# ╔═╡ 2a2b3c4d-0025-0025-0025-000000000025
md"""
And that S5 frames (equivalence relations) validate T, B, 4, and 5:
"""

# ╔═╡ 2a2b3c4d-0026-0026-0026-000000000026
begin
	# An S5 frame: equivalence relation
	s5_frame = KripkeFrame([:w1, :w2],
		[:w1 => :w1, :w2 => :w2, :w1 => :w2, :w2 => :w1])

	@assert is_reflexive(s5_frame) && is_symmetric(s5_frame) && is_transitive(s5_frame)

	(T_valid = is_valid_on_frame(s5_frame, schema_t),
	 B_valid = is_valid_on_frame(s5_frame, schema_b),
	 schema_4_valid = is_valid_on_frame(s5_frame, schema_4),
	 schema_5_valid = is_valid_on_frame(s5_frame, schema_5))
end

# ╔═╡ 2a2b3c4d-0027-0027-0027-000000000027
md"""
## Exploring on Your Own

Try these exercises:

- Build a frame that is transitive but not reflexive (K4 but not S4) and verify that schema 4 is valid but T is not
- Check whether schema D is valid on all reflexive frames (it should be — reflexivity implies seriality)
- Construct an S5 frame with 3 worlds and verify all schemas hold
"""

# ╔═╡ Cell order:
# ╟─2a2b3c4d-0001-0001-0001-000000000001
# ╠═2a2b3c4d-0002-0002-0002-000000000002
# ╟─2a2b3c4d-0030-0030-0030-000000000030
# ╟─2a2b3c4d-0003-0003-0003-000000000003
# ╠═2a2b3c4d-0004-0004-0004-000000000004
# ╠═2a2b3c4d-0005-0005-0005-000000000005
# ╟─2a2b3c4d-0006-0006-0006-000000000006
# ╟─2a2b3c4d-0007-0007-0007-000000000007
# ╠═2a2b3c4d-0008-0008-0008-000000000008
# ╠═2a2b3c4d-0009-0009-0009-000000000009
# ╟─2a2b3c4d-0010-0010-0010-000000000010
# ╟─2a2b3c4d-0011-0011-0011-000000000011
# ╠═2a2b3c4d-0012-0012-0012-000000000012
# ╟─2a2b3c4d-0013-0013-0013-000000000013
# ╠═2a2b3c4d-0014-0014-0014-000000000014
# ╟─2a2b3c4d-0015-0015-0015-000000000015
# ╠═2a2b3c4d-0016-0016-0016-000000000016
# ╟─2a2b3c4d-0017-0017-0017-000000000017
# ╠═2a2b3c4d-0018-0018-0018-000000000018
# ╟─2a2b3c4d-0019-0019-0019-000000000019
# ╠═2a2b3c4d-0020-0020-0020-000000000020
# ╟─2a2b3c4d-0021-0021-0021-000000000021
# ╠═2a2b3c4d-0022-0022-0022-000000000022
# ╟─2a2b3c4d-0023-0023-0023-000000000023
# ╠═2a2b3c4d-0024-0024-0024-000000000024
# ╟─2a2b3c4d-0025-0025-0025-000000000025
# ╠═2a2b3c4d-0026-0026-0026-000000000026
# ╟─2a2b3c4d-0027-0027-0027-000000000027
