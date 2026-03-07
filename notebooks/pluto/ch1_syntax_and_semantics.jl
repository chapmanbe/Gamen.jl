### A Pluto.jl notebook ###
# v0.20.10

using Markdown
using InteractiveUtils

# ╔═╡ 1a2b3c4d-0002-0002-0002-000000000002
begin
	using Pkg
	Pkg.activate(joinpath(@__DIR__, ".."))
	using Gamen
	using CairoMakie, GraphMakie, Graphs
end

# ╔═╡ 1a2b3c4d-0001-0001-0001-000000000001
md"""
# Chapter 1: Syntax and Semantics

This notebook follows Chapter 1 of [Boxes and Diamonds](https://bd.openlogicproject.org),
an open introduction to modal logic, using the **Gamen.jl** package.

We cover:
- The language of basic modal logic (Definition 1.1)
- Building formulas (Definition 1.2)
- Relational models (Definition 1.6)
- Truth at a world (Definition 1.7)
- Truth in a model (Definition 1.9)
- Validity and entailment
"""

# ╔═╡ 1a2b3c4d-0003-0003-0003-000000000003
md"""
## 1.1 The Language of Basic Modal Logic

The language of modal logic (Definition 1.1) contains:

1. The propositional constant for falsity: $\bot$
2. Propositional variables: $p_0, p_1, p_2, \ldots$
3. Propositional connectives: $\lnot, \land, \lor, \to$
4. The modal operator $\square$ (box / necessity)
5. The modal operator $\diamond$ (diamond / possibility)
"""

# ╔═╡ 1a2b3c4d-0004-0004-0004-000000000004
md"""
### Atomic Formulas

We can create propositional variables by name or by index:
"""

# ╔═╡ 1a2b3c4d-0005-0005-0005-000000000005
begin
	# Named atoms
	p = Atom(:p)
	q = Atom(:q)
	r = Atom(:r)

	# Indexed atoms (Definition 1.1, item 2)
	p0 = Atom(0)
	p1 = Atom(1)

	(p, q, r, p0, p1)
end

# ╔═╡ 1a2b3c4d-0006-0006-0006-000000000006
md"""
### Building Formulas (Definition 1.2)

Formulas are built inductively. Every atom is a formula, and if $A$ and $B$
are formulas, so are $\lnot A$, $(A \land B)$, $(A \lor B)$, $(A \to B)$,
$\square A$, and $\diamond A$.
"""

# ╔═╡ 1a2b3c4d-0007-0007-0007-000000000007
begin
	# Falsity and truth (Definition 1.3)
	falsum = Bottom()
	verum = Top()  # ⊤ abbreviates ¬⊥

	(falsum, verum)
end

# ╔═╡ 1a2b3c4d-0008-0008-0008-000000000008
begin
	# Propositional connectives
	neg_p = Not(p)
	p_and_q = And(p, q)
	p_or_q = Or(p, q)
	p_implies_q = Implies(p, q)
	p_iff_q = Iff(p, q)  # A ↔ B abbreviates (A → B) ∧ (B → A)

	(neg_p, p_and_q, p_or_q, p_implies_q, p_iff_q)
end

# ╔═╡ 1a2b3c4d-0009-0009-0009-000000000009
begin
	# Modal operators — verbose syntax
	box_p = Box(p)        # □p: "necessarily p"
	diamond_q = Diamond(q) # ◇q: "possibly q"

	# Unicode syntax — type \square<tab> and \diamond<tab> in the Julia REPL
	box_p_unicode = □(p)        # identical to Box(p)
	diamond_q_unicode = ◇(q)    # identical to Diamond(q)

	# They construct the exact same objects
	@assert □(p) === Box(p)
	@assert ◇(q) === Diamond(q)

	# Nested formulas (both syntaxes work)
	box_p_implies_p = Implies(□(p), p)  # □p → p
	k_schema = Implies(□(Implies(p, q)), Implies(□(p), □(q)))  # □(p → q) → (□p → □q)

	(box_p, diamond_q, box_p_unicode, diamond_q_unicode, box_p_implies_p, k_schema)
end

# ╔═╡ 1a2b3c4d-0030-0030-0030-000000000030
md"""
### Unicode Syntax for Modal Operators

Gamen.jl exports `□` and `◇` as aliases for `Box` and `Diamond`. In the Julia REPL, type `\square<tab>` for □ and `\diamond<tab>` for ◇. They are full type aliases — `□(p)` constructs a `Box`, and `◇(q) isa Diamond` is `true`.

This lets you write formulas that closely mirror the mathematical notation:
"""

# ╔═╡ 1a2b3c4d-0031-0031-0031-000000000031
begin
	# Compare: verbose vs Unicode
	verbose_formula = Implies(Box(Implies(p, q)), Implies(Box(p), Box(q)))
	unicode_formula = Implies(□(Implies(p, q)), Implies(□(p), □(q)))

	# They are identical
	verbose_formula == unicode_formula, □ === Box, ◇ === Diamond
end

# ╔═╡ 1a2b3c4d-0010-0010-0010-000000000010
md"""
### Modal-Free Formulas

A formula is *modal-free* if it contains no $\square$ or $\diamond$ operators:
"""

# ╔═╡ 1a2b3c4d-0011-0011-0011-000000000011
begin
	is_modal_free(And(p, Not(q))),   # true — no modal operators
	is_modal_free(Implies(p, Box(q))) # false — contains □
end

# ╔═╡ 1a2b3c4d-0012-0012-0012-000000000012
md"""
## 1.4 Relational Models

A *model* $M = \langle W, R, V \rangle$ consists of (Definition 1.6):

1. $W$: a nonempty set of "worlds"
2. $R$: a binary accessibility relation on $W$
3. $V$: a valuation function assigning to each propositional variable $p$ the set $V(p) \subseteq W$ of worlds where $p$ is true

### Figure 1.1 from Boxes and Diamonds

The book's first example model (Figure 1.1) has three worlds:
- $W = \{w_1, w_2, w_3\}$
- $R = \{\langle w_1, w_2 \rangle, \langle w_1, w_3 \rangle\}$
- $V(p) = \{w_1, w_2\}$, $V(q) = \{w_2\}$
"""

# ╔═╡ 1a2b3c4d-0013-0013-0013-000000000013
begin
	frame = KripkeFrame([:w1, :w2, :w3], [:w1 => :w2, :w1 => :w3])
	model = KripkeModel(frame, [:p => [:w1, :w2], :q => [:w2]])
end

# ╔═╡ 1a2b3c4d-0040-0040-0040-000000000040
visualize_model(model,
	positions = Dict(:w1 => (0.0, 0.0), :w2 => (2.0, 1.0), :w3 => (2.0, -1.0)),
	title = "Figure 1.1: A simple model")

# ╔═╡ 1a2b3c4d-0014-0014-0014-000000000014
md"""
## 1.5 Truth at a World (Definition 1.7)

The satisfaction relation $M, w \Vdash A$ ("$A$ is true at world $w$ in model $M$")
is defined inductively:

| Clause | Rule |
|--------|------|
| 1 | $M, w \not\Vdash \bot$ (never) |
| 2 | $M, w \Vdash p$ iff $w \in V(p)$ |
| 3 | $M, w \Vdash \lnot B$ iff $M, w \not\Vdash B$ |
| 4 | $M, w \Vdash B \land C$ iff $M, w \Vdash B$ and $M, w \Vdash C$ |
| 5 | $M, w \Vdash B \lor C$ iff $M, w \Vdash B$ or $M, w \Vdash C$ |
| 6 | $M, w \Vdash B \to C$ iff $M, w \not\Vdash B$ or $M, w \Vdash C$ |
| 7 | $M, w \Vdash \square B$ iff $M, w' \Vdash B$ for all $w'$ with $Rww'$ |
| 8 | $M, w \Vdash \diamond B$ iff $M, w' \Vdash B$ for some $w'$ with $Rww'$ |

Let's verify using the Figure 1.1 model:
"""

# ╔═╡ 1a2b3c4d-0015-0015-0015-000000000015
md"""
### Problem 1.1 — Which of the following hold?

Working through the book's exercises on Figure 1.1:
"""

# ╔═╡ 1a2b3c4d-0016-0016-0016-000000000016
begin
	results = [
		"1. M,w₁ ⊩ q"           => satisfies(model, :w1, q),
		"2. M,w₃ ⊩ ¬q"          => satisfies(model, :w3, Not(q)),
		"3. M,w₁ ⊩ p ∨ q"       => satisfies(model, :w1, Or(p, q)),
		"4. M,w₁ ⊩ □(p ∨ q)"    => satisfies(model, :w1, Box(Or(p, q))),
		"5. M,w₃ ⊩ □q"          => satisfies(model, :w3, Box(q)),
		"6. M,w₃ ⊩ □⊥"          => satisfies(model, :w3, Box(Bottom())),
		"7. M,w₁ ⊩ ◇q"          => satisfies(model, :w1, Diamond(q)),
		"8. M,w₁ ⊩ □q"          => satisfies(model, :w1, Box(q)),
		"9. M,w₁ ⊩ ¬□□¬q"       => satisfies(model, :w1, Not(Box(Box(Not(q))))),
	]
end

# ╔═╡ 1a2b3c4d-0017-0017-0017-000000000017
md"""
Notice:
- **Item 4** is false because $w_3$ satisfies neither $p$ nor $q$, so $p \lor q$ fails there.
- **Items 5 and 6** are *vacuously true*: $w_3$ has no accessible worlds, so $\square B$ holds for any $B$ at $w_3$.
- **Item 9**: $\square\square\lnot q$ is true at $w_1$ because $w_2$ and $w_3$ have no successors, making $\square\lnot q$ vacuously true at both. So $\lnot\square\square\lnot q$ is false.
"""

# ╔═╡ 1a2b3c4d-0018-0018-0018-000000000018
md"""
## Proposition 1.8 — Duality of □ and ◇

The book proves that $\square$ and $\diamond$ are duals:
- $M, w \Vdash \square A$ iff $M, w \Vdash \lnot\diamond\lnot A$
- $M, w \Vdash \diamond A$ iff $M, w \Vdash \lnot\square\lnot A$

Let's verify this holds at every world in our model:
"""

# ╔═╡ 1a2b3c4d-0019-0019-0019-000000000019
begin
	duality_results = []
	for w in [:w1, :w2, :w3]
		box_eq = satisfies(model, w, Box(p)) == satisfies(model, w, Not(Diamond(Not(p))))
		dia_eq = satisfies(model, w, Diamond(p)) == satisfies(model, w, Not(Box(Not(p))))
		push!(duality_results, w => (box_duality=box_eq, diamond_duality=dia_eq))
	end
	duality_results
end

# ╔═╡ 1a2b3c4d-0020-0020-0020-000000000020
md"""
## 1.6 Truth in a Model (Definition 1.9)

A formula $A$ is *true in a model* $M$ (written $M \Vdash A$) if it is true
at every world in $M$:
"""

# ╔═╡ 1a2b3c4d-0021-0021-0021-000000000021
begin
	# p is not true in the model (false at w3)
	is_true_in(model, p),

	# ⊤ is true in every model
	is_true_in(model, Top()),

	# □⊥ is not true in the model (false at w1, which has successors)
	is_true_in(model, Box(Bottom()))
end

# ╔═╡ 1a2b3c4d-0022-0022-0022-000000000022
md"""
## 1.10 Entailment (Definition 1.23)

A set of formulas $\Gamma$ *entails* $A$ in model $M$ if: whenever all formulas
in $\Gamma$ are true at a world $w$, then $A$ is also true at $w$.
"""

# ╔═╡ 1a2b3c4d-0023-0023-0023-000000000023
begin
	# In a model where p and q are true at all worlds,
	# p entails p ∨ q
	frame2 = KripkeFrame([:w1, :w2], [:w1 => :w2])
	model2 = KripkeModel(frame2, [:p => [:w1, :w2], :q => [:w1, :w2]])

	entails(model2, p, Or(p, q)),        # p ⊨ p ∨ q
	entails(model2, [p, q], And(p, q))   # {p, q} ⊨ p ∧ q
end

# ╔═╡ 1a2b3c4d-0024-0024-0024-000000000024
md"""
## Exploring on Your Own

Try building your own models and checking formulas! Some ideas from the book:

- Verify Proposition 1.19: the schema **K**, $\square(A \to B) \to (\square A \to \square B)$, is valid
- Check the invalid schemas from Table 1.1, e.g., $A \to \square A$
- Build the counterexample model from Figure 1.2
"""

# ╔═╡ Cell order:
# ╟─1a2b3c4d-0001-0001-0001-000000000001
# ╠═1a2b3c4d-0002-0002-0002-000000000002
# ╟─1a2b3c4d-0003-0003-0003-000000000003
# ╟─1a2b3c4d-0004-0004-0004-000000000004
# ╠═1a2b3c4d-0005-0005-0005-000000000005
# ╟─1a2b3c4d-0006-0006-0006-000000000006
# ╠═1a2b3c4d-0007-0007-0007-000000000007
# ╠═1a2b3c4d-0008-0008-0008-000000000008
# ╠═1a2b3c4d-0009-0009-0009-000000000009
# ╟─1a2b3c4d-0030-0030-0030-000000000030
# ╠═1a2b3c4d-0031-0031-0031-000000000031
# ╟─1a2b3c4d-0010-0010-0010-000000000010
# ╠═1a2b3c4d-0011-0011-0011-000000000011
# ╟─1a2b3c4d-0012-0012-0012-000000000012
# ╠═1a2b3c4d-0013-0013-0013-000000000013
# ╠═1a2b3c4d-0040-0040-0040-000000000040
# ╟─1a2b3c4d-0014-0014-0014-000000000014
# ╟─1a2b3c4d-0015-0015-0015-000000000015
# ╠═1a2b3c4d-0016-0016-0016-000000000016
# ╟─1a2b3c4d-0017-0017-0017-000000000017
# ╟─1a2b3c4d-0018-0018-0018-000000000018
# ╠═1a2b3c4d-0019-0019-0019-000000000019
# ╟─1a2b3c4d-0020-0020-0020-000000000020
# ╠═1a2b3c4d-0021-0021-0021-000000000021
# ╟─1a2b3c4d-0022-0022-0022-000000000022
# ╠═1a2b3c4d-0023-0023-0023-000000000023
# ╟─1a2b3c4d-0024-0024-0024-000000000024
