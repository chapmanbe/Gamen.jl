### A Pluto.jl notebook ###
# v0.20.4

using Markdown
using InteractiveUtils

# ╔═╡ 3a3b3c3d-0001-0001-0001-000000000001
md"""
# Chapter 3: Axiomatic Derivations

This notebook follows Chapter 3 of [Boxes and Diamonds](https://bd.openlogicproject.org)
using the **Gamen.jl** package.

We cover:
- Substitution and tautology checking
- Axiom schemas (K, Dual, T, D, B, 4, 5) and instance matching
- Modal systems (K, KT, S4, S5, ...)
- Hilbert-style derivations and proof checking
- Dual formulas (Definition 3.26)
- Soundness (Theorem 3.31)
"""

# ╔═╡ 3a3b3c3d-0002-0002-0002-000000000002
begin
	using Pkg
	Pkg.activate(joinpath(@__DIR__, ".."))
	using Gamen
end

# ╔═╡ 3a3b3c3d-0003-0003-0003-000000000003
md"""
## 3.1 Substitution

A *substitution* replaces propositional variables with arbitrary formulas.
This is the mechanism by which axiom *schemas* generate their *instances*:
a schema like $p \to (q \to p)$ becomes $\square r \to (\diamond s \to \square r)$
by substituting $\square r$ for $p$ and $\diamond s$ for $q$.
"""

# ╔═╡ 3a3b3c3d-0004-0004-0004-000000000004
begin
	p = Atom(:p)
	q = Atom(:q)
	r = Atom(:r)

	σ = Dict(:p => □(r), :q => ◇(q))
	original = Implies(p, Implies(q, p))
	substituted = substitute(original, σ)

	(original = original, substituted = substituted)
end

# ╔═╡ 3a3b3c3d-0005-0005-0005-000000000005
md"""
Substitution distributes through all connectives and modal operators:
"""

# ╔═╡ 3a3b3c3d-0006-0006-0006-000000000006
begin
	σ2 = Dict(:p => □(q), :q => ◇(r))

	(and = substitute(And(p, q), σ2),
	 box = substitute(□(p), σ2),
	 diamond = substitute(◇(Implies(p, q)), σ2))
end

# ╔═╡ 3a3b3c3d-0007-0007-0007-000000000007
md"""
## 3.2 Tautologies and Tautological Instances

A *propositional tautology* is a modal-free formula that is true under every
truth-value assignment. Gamen.jl checks this by exhaustive truth-table evaluation.
"""

# ╔═╡ 3a3b3c3d-0008-0008-0008-000000000008
begin
	# Classical tautologies
	excluded_middle = Or(p, Not(p))
	double_neg = Implies(Not(Not(p)), p)
	weakening = Implies(p, Implies(q, p))

	(excluded_middle = is_tautology(excluded_middle),
	 double_negation = is_tautology(double_neg),
	 weakening = is_tautology(weakening),
	 top = is_tautology(Top()))
end

# ╔═╡ 3a3b3c3d-0009-0009-0009-000000000009
begin
	# Non-tautologies
	(atom = is_tautology(p),
	 implication = is_tautology(Implies(p, q)),
	 bottom = is_tautology(Bottom()))
end

# ╔═╡ 3a3b3c3d-0010-0010-0010-000000000010
md"""
A *tautological instance* (Definition 3.3, item 1) is a formula whose
**propositional skeleton** is a tautology. The skeleton is obtained by
treating atoms and modal subformulas as propositional variables:
"""

# ╔═╡ 3a3b3c3d-0011-0011-0011-000000000011
begin
	# □p → □p is a tautological instance (skeleton: A → A)
	ti1 = Implies(□(p), □(p))

	# □p → (◇q → □p) is a tautological instance (skeleton: A → (B → A))
	ti2 = Implies(□(p), Implies(◇(q), □(p)))

	# □p → ◇q is NOT a tautological instance (skeleton: A → B)
	ti3 = Implies(□(p), ◇(q))

	(box_self_impl = is_tautological_instance(ti1),
	 weakening_modal = is_tautological_instance(ti2),
	 not_instance = is_tautological_instance(ti3))
end

# ╔═╡ 3a3b3c3d-0012-0012-0012-000000000012
md"""
## 3.3 Axiom Schemas

A modal logic is determined by its axiom schemas. Every normal modal logic
includes the **K** axiom and the **Dual** axiom. Additional schemas define
stronger systems.

| Schema | Formula | Meaning |
|:-------|:--------|:--------|
| **K** | □(A → B) → (□A → □B) | □ distributes over → |
| **Dual** | ◇A ↔ ¬□¬A | ◇ is the dual of □ |
| **T** | □A → A | Necessity implies truth |
| **D** | □A → ◇A | Necessity implies possibility |
| **B** | A → □◇A | Truth implies necessary possibility |
| **4** | □A → □□A | Necessity iterates |
| **5** | ◇A → □◇A | Possibility is necessary |

The function `is_instance` checks whether a formula matches a schema:
"""

# ╔═╡ 3a3b3c3d-0013-0013-0013-000000000013
begin
	# K axiom instance: □(p→q) → (□p→□q)
	k_inst = Implies(□(Implies(p, q)), Implies(□(p), □(q)))
	is_instance(k_inst, SchemaK())
end

# ╔═╡ 3a3b3c3d-0014-0014-0014-000000000014
begin
	# K works with any subformulas, not just atoms
	k_complex = Implies(
		□(Implies(And(p, q), ◇(r))),
		Implies(□(And(p, q)), □(◇(r))))
	is_instance(k_complex, SchemaK())
end

# ╔═╡ 3a3b3c3d-0015-0015-0015-000000000015
begin
	# Dual: ◇A ↔ ¬□¬A
	dual_inst = Iff(◇(And(p, q)), Not(□(Not(And(p, q)))))

	# T: □A → A
	t_inst = Implies(□(Implies(p, q)), Implies(p, q))

	# 4: □A → □□A
	four_inst = Implies(□(◇(p)), □(□(◇(p))))

	(dual = is_instance(dual_inst, SchemaDual()),
	 t = is_instance(t_inst, SchemaT()),
	 four = is_instance(four_inst, Schema4()))
end

# ╔═╡ 3a3b3c3d-0016-0016-0016-000000000016
md"""
Schema matching is *strict* — the formula must exactly match the pattern.
Mismatched subformulas are rejected:
"""

# ╔═╡ 3a3b3c3d-0017-0017-0017-000000000017
begin
	# □p → q is NOT an instance of T (the consequent must match the boxed formula)
	(t_mismatch = is_instance(Implies(□(p), q), SchemaT()),
	 d_mismatch = is_instance(Implies(□(p), ◇(q)), SchemaD()),
	 b_mismatch = is_instance(Implies(p, □(◇(q))), SchemaB()))
end

# ╔═╡ 3a3b3c3d-0018-0018-0018-000000000018
md"""
## 3.4 Modal Systems

A **modal system** (Definition 3.9) is defined by its set of axiom schemas.
Gamen.jl provides eight standard systems:
"""

# ╔═╡ 3a3b3c3d-0019-0019-0019-000000000019
begin
	systems = [SYSTEM_K, SYSTEM_KT, SYSTEM_KD, SYSTEM_KB,
	           SYSTEM_K4, SYSTEM_K5, SYSTEM_S4, SYSTEM_S5]

	for sys in systems
		schemas = join(string.(sys.schemas), ", ")
		println("$(sys.name): $schemas")
	end
end

# ╔═╡ 3a3b3c3d-0020-0020-0020-000000000020
md"""
## 3.5 Derivations and Proof Checking

A **derivation** (Definition 3.3) is a sequence of formulas where each step
is justified by one of four rules:

1. **Tautological instance** — the propositional skeleton is a tautology
2. **Axiom instance** — the formula matches an axiom schema of the system
3. **Modus ponens** — from A and A → B, derive B
4. **Necessitation** — from A, derive □A

### Proof of Proposition 3.12: □A → □(B → A)

This is a four-step proof in system K:
"""

# ╔═╡ 3a3b3c3d-0021-0021-0021-000000000021
begin
	proof_312 = Derivation([
		# Step 1: A → (B → A) is a tautological instance
		ProofStep(Implies(p, Implies(q, p)), Tautology()),
		# Step 2: □(A → (B → A)) by necessitation from step 1
		ProofStep(□(Implies(p, Implies(q, p))), Necessitation(1)),
		# Step 3: K axiom instance
		ProofStep(
			Implies(□(Implies(p, Implies(q, p))),
			        Implies(□(p), □(Implies(q, p)))),
			AxiomInst(SchemaK())),
		# Step 4: Modus ponens from steps 2 and 3
		ProofStep(
			Implies(□(p), □(Implies(q, p))),
			ModusPonens(2, 3)),
	])

	println(proof_312)
	println()
	println("Valid in K: ", is_valid_derivation(SYSTEM_K, proof_312))
	println("Conclusion: ", conclusion(proof_312))
end

# ╔═╡ 3a3b3c3d-0022-0022-0022-000000000022
md"""
### Proof of Proposition 3.13: □(A ∧ B) → (□A ∧ □B)

This longer proof first derives □(A∧B) → □A and □(A∧B) → □B separately,
then combines them using a propositional tautology:
"""

# ╔═╡ 3a3b3c3d-0023-0023-0023-000000000023
begin
	ab = And(p, q)

	proof_313 = Derivation([
		# Part 1: □(A∧B) → □A
		ProofStep(Implies(ab, p), Tautology()),                              # 1
		ProofStep(□(Implies(ab, p)), Necessitation(1)),                      # 2
		ProofStep(Implies(□(Implies(ab, p)),
		                  Implies(□(ab), □(p))), AxiomInst(SchemaK())),      # 3
		ProofStep(Implies(□(ab), □(p)), ModusPonens(2, 3)),                  # 4

		# Part 2: □(A∧B) → □B
		ProofStep(Implies(ab, q), Tautology()),                              # 5
		ProofStep(□(Implies(ab, q)), Necessitation(5)),                      # 6
		ProofStep(Implies(□(Implies(ab, q)),
		                  Implies(□(ab), □(q))), AxiomInst(SchemaK())),      # 7
		ProofStep(Implies(□(ab), □(q)), ModusPonens(6, 7)),                  # 8

		# Combine via (p→q) → ((p→r) → (p→(q∧r)))
		ProofStep(
			Implies(Implies(□(ab), □(p)),
			        Implies(Implies(□(ab), □(q)),
			                Implies(□(ab), And(□(p), □(q))))),
			Tautology()),                                                     # 9
		ProofStep(
			Implies(Implies(□(ab), □(q)),
			        Implies(□(ab), And(□(p), □(q)))),
			ModusPonens(4, 9)),                                               # 10
		ProofStep(
			Implies(□(ab), And(□(p), □(q))),
			ModusPonens(8, 10)),                                              # 11
	])

	println("Valid in K: ", is_valid_derivation(SYSTEM_K, proof_313))
	println("Conclusion: ", conclusion(proof_313))
end

# ╔═╡ 3a3b3c3d-0024-0024-0024-000000000024
md"""
### Invalid Derivations

The proof checker catches errors — wrong references, axioms not in the
system, and mismatched formulas:
"""

# ╔═╡ 3a3b3c3d-0025-0025-0025-000000000025
begin
	# Schema T is not available in system K
	bad_proof1 = Derivation([
		ProofStep(Implies(□(p), p), AxiomInst(SchemaT())),
	])

	# But it IS valid in system KT
	(in_K = is_valid_derivation(SYSTEM_K, bad_proof1),
	 in_KT = is_valid_derivation(SYSTEM_KT, bad_proof1))
end

# ╔═╡ 3a3b3c3d-0026-0026-0026-000000000026
begin
	# Wrong modus ponens: can't derive p from (p→p) alone
	bad_proof2 = Derivation([
		ProofStep(Implies(p, p), Tautology()),
		ProofStep(p, ModusPonens(1, 1)),
	])
	is_valid_derivation(SYSTEM_K, bad_proof2)
end

# ╔═╡ 3a3b3c3d-0027-0027-0027-000000000027
md"""
## 3.6 Dual Formulas (Definition 3.26)

The *dual* of a formula is obtained by swapping:
- ⊥ ↔ ⊤
- ∧ ↔ ∨
- □ ↔ ◇

Atoms are negated, and negation distributes through the dual.
The key property is that ⊢ A ↔ ¬(dual(A)).
"""

# ╔═╡ 3a3b3c3d-0028-0028-0028-000000000028
begin
	(dual_bot = dual(Bottom()),
	 dual_atom = dual(p),
	 dual_and = dual(And(p, q)),
	 dual_or = dual(Or(p, q)),
	 dual_box = dual(□(p)),
	 dual_dia = dual(◇(p)))
end

# ╔═╡ 3a3b3c3d-0029-0029-0029-000000000029
begin
	# Nested example: dual of □(p ∧ q) = ◇(¬p ∨ ¬q)
	nested = □(And(p, q))
	(original = nested, dual_form = dual(nested))
end

# ╔═╡ 3a3b3c3d-0030-0030-0030-000000000030
md"""
## 3.7 Soundness (Theorem 3.31)

If a formula is provable in a modal system, it is valid on the
corresponding class of frames. We can verify this semantically:
K-provable formulas should be valid on *all* frames, and
system-specific theorems should be valid on the appropriate frame class.
"""

# ╔═╡ 3a3b3c3d-0031-0031-0031-000000000031
begin
	# □p → □(q → p) is K-provable — valid on any frame
	thm = Implies(□(p), □(Implies(q, p)))

	frame1_s = KripkeFrame([:w1, :w2], [:w1 => :w2])
	frame2_s = KripkeFrame([:w1], [:w1 => :w1])
	frame3_s = KripkeFrame([:w1, :w2, :w3], [:w1 => :w2, :w2 => :w3])

	(frame1 = is_valid_on_frame(frame1_s, thm),
	 frame2 = is_valid_on_frame(frame2_s, thm),
	 frame3 = is_valid_on_frame(frame3_s, thm))
end

# ╔═╡ 3a3b3c3d-0032-0032-0032-000000000032
begin
	# Schema T (□p → p) is KT-provable — valid on reflexive frames only
	schema_t_s = Implies(□(p), p)

	reflexive_s = KripkeFrame([:w1, :w2],
		[:w1 => :w1, :w2 => :w2, :w1 => :w2])
	non_reflexive_s = KripkeFrame([:w1, :w2], [:w1 => :w2])

	(reflexive = is_valid_on_frame(reflexive_s, schema_t_s),
	 non_reflexive = is_valid_on_frame(non_reflexive_s, schema_t_s))
end

# ╔═╡ 3a3b3c3d-0033-0033-0033-000000000033
md"""
## Exploring on Your Own

Try these exercises:

- Construct a proof of □(A ∧ B) ← (□A ∧ □B) — the converse of Proposition 3.13
- Verify that ◇(A ∨ B) ↔ (◇A ∨ ◇B) is valid on all frames (Proposition 3.15)
- Build a derivation using Schema T in system KT
- Compute the dual of □(p → q) and verify that the original and ¬dual are equivalent on a model
"""

# ╔═╡ Cell order:
# ╟─3a3b3c3d-0001-0001-0001-000000000001
# ╠═3a3b3c3d-0002-0002-0002-000000000002
# ╟─3a3b3c3d-0003-0003-0003-000000000003
# ╠═3a3b3c3d-0004-0004-0004-000000000004
# ╟─3a3b3c3d-0005-0005-0005-000000000005
# ╠═3a3b3c3d-0006-0006-0006-000000000006
# ╟─3a3b3c3d-0007-0007-0007-000000000007
# ╠═3a3b3c3d-0008-0008-0008-000000000008
# ╠═3a3b3c3d-0009-0009-0009-000000000009
# ╟─3a3b3c3d-0010-0010-0010-000000000010
# ╠═3a3b3c3d-0011-0011-0011-000000000011
# ╟─3a3b3c3d-0012-0012-0012-000000000012
# ╠═3a3b3c3d-0013-0013-0013-000000000013
# ╠═3a3b3c3d-0014-0014-0014-000000000014
# ╠═3a3b3c3d-0015-0015-0015-000000000015
# ╟─3a3b3c3d-0016-0016-0016-000000000016
# ╠═3a3b3c3d-0017-0017-0017-000000000017
# ╟─3a3b3c3d-0018-0018-0018-000000000018
# ╠═3a3b3c3d-0019-0019-0019-000000000019
# ╟─3a3b3c3d-0020-0020-0020-000000000020
# ╠═3a3b3c3d-0021-0021-0021-000000000021
# ╟─3a3b3c3d-0022-0022-0022-000000000022
# ╠═3a3b3c3d-0023-0023-0023-000000000023
# ╟─3a3b3c3d-0024-0024-0024-000000000024
# ╠═3a3b3c3d-0025-0025-0025-000000000025
# ╠═3a3b3c3d-0026-0026-0026-000000000026
# ╟─3a3b3c3d-0027-0027-0027-000000000027
# ╠═3a3b3c3d-0028-0028-0028-000000000028
# ╠═3a3b3c3d-0029-0029-0029-000000000029
# ╟─3a3b3c3d-0030-0030-0030-000000000030
# ╠═3a3b3c3d-0031-0031-0031-000000000031
# ╠═3a3b3c3d-0032-0032-0032-000000000032
# ╟─3a3b3c3d-0033-0033-0033-000000000033
