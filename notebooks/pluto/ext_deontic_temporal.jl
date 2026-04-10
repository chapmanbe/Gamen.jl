### A Pluto.jl notebook ###
# v0.20.4

using Markdown
using InteractiveUtils

# ╔═╡ 5a1b3c4d-0001-0001-0001-000000000001
md"""
# Combined Deontic-Temporal Logic (TABLEAU\_KDt)

B&D treats deontic logic (Chapter 3) and temporal logic (Chapter 14) as separate
systems. But real reasoning often mixes them:

- *"It is obligatory that p eventually holds."*
- *"It has always been obligatory that q."*
- *"If the patient is admitted, it must always be the case that monitoring occurs."*

**TABLEAU\_KDt** is a combined system that extends Gamen.jl beyond B&D by
unifying deontic and temporal operators in a single tableau prover.

This notebook explores what that combination gives us: mixed formulas, new
theorems, and consistency checking for deontic-temporal specifications.
"""

# ╔═╡ 5a1b3c4d-0002-0002-0002-000000000002
begin
	using Pkg
	Pkg.activate(joinpath(@__DIR__, ".."))
	using Gamen
	using PlutoUI
end

# ╔═╡ 5a1b3c4d-0003-0003-0003-000000000003
begin
	p = Atom(:p)
	q = Atom(:q)
	r = Atom(:r)
end;

# ╔═╡ 5a1b3c4d-0004-0004-0004-000000000004
md"""
## The TABLEAU\_KDt System

TABLEAU\_KDt combines two sets of frame constraints on a shared accessibility
relation:

| Component | Operators | Frame conditions | Axiom |
|:----------|:----------|:-----------------|:------|
| **Deontic** | □ (obligatory), ◇ (permissible) | Seriality | D: □p → ◇p |
| **Temporal** | **G** (always), **F** (eventually) | Reflexivity + Transitivity | T: **G**p → p, 4: **G**p → **GG**p |

**Phase 1 simplification:** Both operator families share a *single* accessibility
relation. This means the deontic "ought" and the temporal "future" are interpreted
over the same set of successors. This is a deliberate starting point; Phase 2 will
introduce multi-relational prefixes to distinguish R\_d from R\_t.

The combined system inherits all theorems of KD and all theorems of the temporal
fragment (reflexivity + transitivity), plus new mixed theorems that arise from
the interaction.
"""

# ╔═╡ 5a1b3c4d-0005-0005-0005-000000000005
md"""
## Combined Formulas

With both deontic (□/◇) and temporal (**G**/**F**) operators available, we can
build formulas that nest them freely.
"""

# ╔═╡ 5a1b3c4d-0006-0006-0006-000000000006
begin
	# "Obligatory that p eventually holds"
	f1 = Box(FutureDiamond(p))

	# "Always obligatory that p"
	f2 = FutureBox(Box(p))

	# "Obligatory that p always holds"
	f3 = Box(FutureBox(p))

	# "If p then it is obligatory that q never holds"
	f4 = Implies(p, Box(FutureBox(Not(q))))

	println("O(Fp):       ", f1)
	println("G(Op):       ", f2)
	println("O(Gp):       ", f3)
	println("p → O(G¬q):  ", f4)
end

# ╔═╡ 5a1b3c4d-0007-0007-0007-000000000007
md"""
## Theorem Proving with TABLEAU\_KDt

The tableau prover applies deontic rules (seriality) and temporal rules
(reflexivity, transitivity) together. This yields theorems that neither system
proves alone.
"""

# ╔═╡ 5a1b3c4d-0008-0008-0008-000000000008
begin
	# Temporal reflexivity: Gp → p
	r1 = tableau_proves(TABLEAU_KDt, Formula[], Implies(FutureBox(p), p))
	println("KDt ⊢ Gp → p:  ", r1)
end

# ╔═╡ 5a1b3c4d-0009-0009-0009-000000000009
begin
	# G implies F: always p implies eventually p
	r2 = tableau_proves(TABLEAU_KDt, Formula[], Implies(FutureBox(p), FutureDiamond(p)))
	println("KDt ⊢ Gp → Fp:  ", r2)
end

# ╔═╡ 5a1b3c4d-0010-0010-0010-000000000010
begin
	# D axiom through temporal: □(Fp) → ◇(Fp)
	r3 = tableau_proves(TABLEAU_KDt, Formula[],
		Implies(Box(FutureDiamond(p)), Diamond(FutureDiamond(p))))
	println("KDt ⊢ □(Fp) → ◇(Fp):  ", r3)
end

# ╔═╡ 5a1b3c4d-0011-0011-0011-000000000011
begin
	# Temporal reflexivity through deontic: G(□p) → □p
	r4 = tableau_proves(TABLEAU_KDt, Formula[],
		Implies(FutureBox(Box(p)), Box(p)))
	println("KDt ⊢ G(□p) → □p:  ", r4)
end

# ╔═╡ 5a1b3c4d-0012-0012-0012-000000000012
md"""
All four hold in KDt:
- **Gp → p** from temporal reflexivity (T axiom for time)
- **Gp → Fp** since reflexivity gives p now, which witnesses Fp
- **□(Fp) → ◇(Fp)** from deontic seriality (D axiom) applied to Fp
- **G(□p) → □p** from temporal reflexivity applied to □p

These illustrate that the combined system is *not* just the union of theorems
from each fragment; nesting lets the axioms interact.
"""

# ╔═╡ 5a1b3c4d-0013-0013-0013-000000000013
md"""
## Consistency Checking

`tableau_consistent` detects whether a set of formulas can all be true
simultaneously in some model satisfying the KDt frame conditions.
"""

# ╔═╡ 5a1b3c4d-0014-0014-0014-000000000014
begin
	# O(Fp) ∧ O(G¬p) — obligatory eventually p AND obligatory always ¬p
	c1 = !tableau_consistent(TABLEAU_KDt,
		Formula[Box(FutureDiamond(p)), Box(FutureBox(Not(p)))])
	println("□(Fp) ∧ □(G¬p) inconsistent: ", c1)
end

# ╔═╡ 5a1b3c4d-0015-0015-0015-000000000015
begin
	# Gp ∧ F¬p — always p but eventually ¬p
	c2 = !tableau_consistent(TABLEAU_KDt,
		Formula[FutureBox(p), FutureDiamond(Not(p))])
	println("Gp ∧ F¬p inconsistent: ", c2)
end

# ╔═╡ 5a1b3c4d-0016-0016-0016-000000000016
begin
	# Consistent: conditional obligation + temporal possibility
	c3 = tableau_consistent(TABLEAU_KDt,
		Formula[Implies(p, Box(FutureBox(Not(q)))), Box(FutureDiamond(q))])
	println("(p → □G¬q) ∧ □Fq consistent: ", c3)
end

# ╔═╡ 5a1b3c4d-0017-0017-0017-000000000017
md"""
The first two are inconsistent because the combined frame conditions make them
unsatisfiable:
- Obligatory-eventually-p requires every successor to have a further successor
  where p holds. But obligatory-always-not-p requires every successor (and their
  successors, by transitivity) to satisfy not-p. Contradiction.
- Always-p plus eventually-not-p directly contradicts reflexivity and
  transitivity.

The third set is consistent because the conditional `p → □G¬q` only fires when
p holds, and nothing forces p.
"""

# ╔═╡ 5a1b3c4d-0018-0018-0018-000000000018
md"""
## Interactive Formula Builder

Use the dropdowns to build a combined deontic-temporal formula and check it.
"""

# ╔═╡ 5a1b3c4d-0019-0019-0019-000000000019
begin
	op_choices = ["none", "Box (□)", "Diamond (◇)", "FutureBox (G)", "FutureDiamond (F)"]
	atom_choices = ["p", "q", "r"]
end;

# ╔═╡ 5a1b3c4d-0020-0020-0020-000000000020
md"**Outer operator:** $(@bind outer_op Select(op_choices))"

# ╔═╡ 5a1b3c4d-0021-0021-0021-000000000021
md"**Inner operator:** $(@bind inner_op Select(op_choices))"

# ╔═╡ 5a1b3c4d-0022-0022-0022-000000000022
md"**Atom:** $(@bind chosen_atom Select(atom_choices))"

# ╔═╡ 5a1b3c4d-0023-0023-0023-000000000023
md"**Negate?** $(@bind negate CheckBox())"

# ╔═╡ 5a1b3c4d-0024-0024-0024-000000000024
begin
	function wrap_op(name, formula)
		if name == "Box (□)"
			Box(formula)
		elseif name == "Diamond (◇)"
			Diamond(formula)
		elseif name == "FutureBox (G)"
			FutureBox(formula)
		elseif name == "FutureDiamond (F)"
			FutureDiamond(formula)
		else
			formula
		end
	end

	base = Atom(Symbol(chosen_atom))
	core = negate ? Not(base) : base
	inner_wrapped = wrap_op(inner_op, core)
	user_formula = wrap_op(outer_op, inner_wrapped)

	md"""
	**Your formula:** $(string(user_formula))

	**KDt ⊢ formula?** $(tableau_proves(TABLEAU_KDt, Formula[], user_formula))

	**{formula} consistent in KDt?** $(tableau_consistent(TABLEAU_KDt, Formula[user_formula]))
	"""
end

# ╔═╡ 5a1b3c4d-0025-0025-0025-000000000025
md"""
## Comparing Systems: K vs KD vs KDt

The same formula can have different status across systems. Extra axioms make
more things provable (and fewer things consistent).
"""

# ╔═╡ 5a1b3c4d-0026-0026-0026-000000000026
begin
	compare_formulas = [
		(Implies(FutureBox(p), p),
			"Gp → p (temporal reflexivity)"),
		(Implies(Box(p), Diamond(p)),
			"□p → ◇p (seriality / D axiom)"),
		(Implies(FutureBox(p), FutureDiamond(p)),
			"Gp → Fp (always implies eventually)"),
		(Implies(Box(FutureDiamond(p)), Diamond(FutureDiamond(p))),
			"□(Fp) → ◇(Fp) (D through temporal)"),
		(Implies(FutureBox(Box(p)), Box(p)),
			"G(□p) → □p (reflexivity through deontic)"),
	]

	compare_systems = [
		(TABLEAU_K,   "K"),
		(TABLEAU_KD,  "KD"),
		(TABLEAU_KDt, "KDt"),
	]

	println("Provability across systems:")
	println()
	print(rpad("Formula", 45))
	for (_, name) in compare_systems
		print(rpad(name, 6))
	end
	println()
	println(repeat("-", 63))

	for (formula, desc) in compare_formulas
		print(rpad(desc, 45))
		for (sys, _) in compare_systems
			result = tableau_proves(sys, Formula[], formula)
			print(rpad(result ? "yes" : "no", 6))
		end
		println()
	end
end

# ╔═╡ 5a1b3c4d-0027-0027-0027-000000000027
md"""
Key observations:
- **K** proves none of these — it has no frame conditions at all.
- **KD** proves only the D axiom (□p → ◇p) and its instances. It has no
  temporal rules, so FutureBox/FutureDiamond are treated as plain Box/Diamond.
- **KDt** proves all of them, drawing on both seriality and temporal
  reflexivity/transitivity.

This shows precisely what the combined system adds.
"""

# ╔═╡ 5a1b3c4d-0028-0028-0028-000000000028
md"""
## Semantic Evaluation

We can also evaluate combined formulas directly on Kripke models. Since
`TemporalModel` is an alias for `KripkeModel`, and Box/Diamond use the same
accessibility relation, a single model serves both operator families.
"""

# ╔═╡ 5a1b3c4d-0029-0029-0029-000000000029
begin
	# A reflexive, transitive, serial frame (suitable for KDt)
	frame = KripkeFrame(
		[:w1, :w2, :w3],
		[:w1 => :w1, :w1 => :w2, :w2 => :w2, :w2 => :w3, :w3 => :w3]
	)
	model = KripkeModel(frame, [:p => [:w1, :w2, :w3], :q => [:w1]])

	println("Model: 3 worlds, p true everywhere, q true only at w1")
	println()

	# Gp at w1: p holds at all accessible worlds (w1, w2, w3 via transitivity of model)
	println("w1 ⊩ Gp:       ", satisfies(model, :w1, FutureBox(p)))

	# □p at w1: same relation, so also true
	println("w1 ⊩ □p:       ", satisfies(model, :w1, Box(p)))

	# G(□p) at w1: at every successor, □p holds
	println("w1 ⊩ G(□p):    ", satisfies(model, :w1, FutureBox(Box(p))))

	# Fq at w1: q is true at w1 itself (reflexive), so eventually q holds
	println("w1 ⊩ Fq:       ", satisfies(model, :w1, FutureDiamond(q)))

	# Gq at w1: q is NOT true at w2, so not always
	println("w1 ⊩ Gq:       ", satisfies(model, :w1, FutureBox(q)))

	# □(F¬q) at w1: at every successor, eventually ¬q?
	# w2 sees w2 (q false) and w3 (q false), so F¬q at w2. Similarly for w1 (sees w2).
	println("w1 ⊩ □(F¬q):   ", satisfies(model, :w1, Box(FutureDiamond(Not(q)))))
end

# ╔═╡ 5a1b3c4d-0030-0030-0030-000000000030
md"""
The semantic results confirm the tableau results: when the model satisfies the
frame conditions (reflexive, transitive, serial), the theorems of KDt all hold.
"""

# ╔═╡ 5a1b3c4d-0031-0031-0031-000000000031
md"""
## Limitations and Future Work

**Phase 1 limitation:** TABLEAU\_KDt uses a single accessibility relation for
both deontic and temporal operators. This means □ and **G** range over the same
successors. In richer systems, the deontic relation R\_d ("what ought to happen")
and the temporal relation R\_t ("what comes next in time") should be distinct.

**Phase 2 plans:**
- Multi-relational prefixes: each prefix step will be tagged with a relation
  index (R\_d vs R\_t), allowing the two operator families to range over
  different successor sets.
- This will enable formulas like "it is obligatory that p, but p is not
  temporally inevitable" — which Phase 1 cannot distinguish.

**Past operators:** PastBox (**H**) and PastDiamond (**P**) exist in the formula
language but do not yet have tableau rules. Adding them requires backward-looking
prefix rules.
"""

# ╔═╡ 5a1b3c4d-0032-0032-0032-000000000032
md"""
## Summary

| Feature | TABLEAU\_KDt |
|:--------|:-------------|
| Deontic operators | □ (obligatory), ◇ (permissible) |
| Temporal operators | **G** (always), **F** (eventually) |
| Frame conditions | Seriality (D) + Reflexivity (T) + Transitivity (4) |
| New theorems | Mixed nesting: G(□p) → □p, □(Fp) → ◇(Fp), etc. |
| Consistency checking | Detects deontic-temporal conflicts |
| Limitation | Single shared relation (Phase 1) |

TABLEAU\_KDt is the first step toward multi-operator modal reasoning in Gamen.jl.
It demonstrates that the tableau architecture generalizes cleanly: adding temporal
rules to a deontic system requires no changes to the core proof engine, only a
new `TableauSystem` configuration — exactly as the architectural principles
prescribe.
"""

# ╔═╡ Cell order:
# ╟─5a1b3c4d-0001-0001-0001-000000000001
# ╠═5a1b3c4d-0002-0002-0002-000000000002
# ╠═5a1b3c4d-0003-0003-0003-000000000003
# ╟─5a1b3c4d-0004-0004-0004-000000000004
# ╟─5a1b3c4d-0005-0005-0005-000000000005
# ╠═5a1b3c4d-0006-0006-0006-000000000006
# ╟─5a1b3c4d-0007-0007-0007-000000000007
# ╠═5a1b3c4d-0008-0008-0008-000000000008
# ╠═5a1b3c4d-0009-0009-0009-000000000009
# ╠═5a1b3c4d-0010-0010-0010-000000000010
# ╠═5a1b3c4d-0011-0011-0011-000000000011
# ╟─5a1b3c4d-0012-0012-0012-000000000012
# ╟─5a1b3c4d-0013-0013-0013-000000000013
# ╠═5a1b3c4d-0014-0014-0014-000000000014
# ╠═5a1b3c4d-0015-0015-0015-000000000015
# ╠═5a1b3c4d-0016-0016-0016-000000000016
# ╟─5a1b3c4d-0017-0017-0017-000000000017
# ╟─5a1b3c4d-0018-0018-0018-000000000018
# ╠═5a1b3c4d-0019-0019-0019-000000000019
# ╟─5a1b3c4d-0020-0020-0020-000000000020
# ╟─5a1b3c4d-0021-0021-0021-000000000021
# ╟─5a1b3c4d-0022-0022-0022-000000000022
# ╟─5a1b3c4d-0023-0023-0023-000000000023
# ╠═5a1b3c4d-0024-0024-0024-000000000024
# ╟─5a1b3c4d-0025-0025-0025-000000000025
# ╠═5a1b3c4d-0026-0026-0026-000000000026
# ╟─5a1b3c4d-0027-0027-0027-000000000027
# ╟─5a1b3c4d-0028-0028-0028-000000000028
# ╠═5a1b3c4d-0029-0029-0029-000000000029
# ╟─5a1b3c4d-0030-0030-0030-000000000030
# ╟─5a1b3c4d-0031-0031-0031-000000000031
# ╟─5a1b3c4d-0032-0032-0032-000000000032
