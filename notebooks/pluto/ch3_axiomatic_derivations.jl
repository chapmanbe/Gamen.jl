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
	import CairoMakie, GraphMakie, Graphs
end

# ╔═╡ 3a3b3c3d-0050-0050-0050-000000000050
md"""
## Why Axiomatic Derivations Matter

In Chapter 2, we checked whether a formula is valid by examining frames — testing it against every possible valuation. That works when the frame is finite. But there are infinitely many frames, and the frames themselves can be infinite. How do you check validity across *all* of them?

The answer is one of the great ideas in logic, originating with David Hilbert in the early 20th century: instead of checking infinitely many models, write down a small number of **axiom schemas** and **inference rules**, and show that every valid formula can be *derived* from them in finitely many steps.

> **The skeptic's question:** "Why not just check every model?"
>
> **The answer:** Because there are infinitely many. A derivation is a *finite certificate* of validity — a proof you can write on paper (or verify by computer) that a formula holds in every model of the logic, without examining a single model.

This is the difference between *semantics* (Chapters 1--2) and *syntax* (this chapter). Semantics asks "is it true in all models?" Syntax asks "can we derive it from the axioms?" The great discovery of completeness (Chapter 4) is that these two questions have the same answer.

Hilbert-style derivations are admittedly not the most natural way to *find* proofs — tableau methods (Chapter 6) are better for that. But they are the right tool for *defining* a logic: the axiom schemas tell you precisely which inferences the logic sanctions, and nothing more.

$(Markdown.MD(Markdown.Admonition("note", "Knowledge Representation Lens", [md"Davis, Shrobe & Szolovits (1993) identify Role 3 of a knowledge representation: 'a fragmentary theory of intelligent reasoning' that determines which inferences are *sanctioned* (permitted by the formalism) vs. *recommended* (efficient to compute). An axiom system is the purest expression of Role 3 — it defines exactly which conclusions follow from which premises, with no ambiguity. Buchanan (2006) adds that 'making assumptions explicit is valuable, whether or not the system is correct.' The axiom schemas of a modal system make the reasoning assumptions completely explicit: K says necessity distributes over implication; T says what's necessary is true; D says obligations must be achievable. When you choose a system, you choose which of these assumptions you endorse."])))
"""

# ╔═╡ 3a3b3c3d-0003-0003-0003-000000000003
md"""
## Substitution

A *substitution* replaces propositional variables with arbitrary formulas.
This is the mechanism by which axiom *schemas* generate their *instances*:
a schema like p → (q → p) becomes □r → (◇s → □r)
by substituting □r for p and ◇s for q.
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

# ╔═╡ 3a3b3c3d-0051-0051-0051-000000000051
md"""
### Exercise: Substitution

**1.** What is the result of applying the substitution {p ↦ ◇q, q ↦ p} to the formula □(p → q)?

$(Markdown.MD(Markdown.Admonition("hint", "Reveal answer", [md"□(◇q → p). The substitution replaces p with ◇q and q with p inside the scope of □, giving □(◇q → p). Try it: `substitute(□(Implies(p, q)), Dict(:p => ◇(q), :q => p))`"])))

**2.** Can a substitution change a tautology into a non-tautology?

$(Markdown.MD(Markdown.Admonition("hint", "Reveal answer", [md"No. A key property of substitution is that tautological instances remain tautological under any substitution. If the propositional skeleton is a tautology, substituting complex formulas for its variables preserves that property. This is why axiom schemas work: every instance of a tautology is itself a tautology."])))
"""

# ╔═╡ 3a3b3c3d-0007-0007-0007-000000000007
md"""
## Tautologies and Tautological Instances

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

# ╔═╡ 3a3b3c3d-0052-0052-0052-000000000052
md"""
### Exercise: Tautological Instances

**1.** Is ◇p → (□q → ◇p) a tautological instance?

$(Markdown.MD(Markdown.Admonition("hint", "Reveal answer", [md"Yes. The propositional skeleton is A → (B → A), which is the weakening tautology. The modal subformulas ◇p and □q act as atomic placeholders. Try: `is_tautological_instance(Implies(◇(p), Implies(□(q), ◇(p))))`"])))

**2.** Is □p → ◇p a tautological instance?

$(Markdown.MD(Markdown.Admonition("hint", "Reveal answer", [md"No. The skeleton is A → B, where A and B are distinct propositional variables. This is not a propositional tautology (it fails when A is true and B is false). Note that □p → ◇p is a *theorem of KD* (it follows from the D axiom), but it is not a tautological instance."])))
"""

# ╔═╡ 3a3b3c3d-0012-0012-0012-000000000012
md"""
## Axiom Schemas

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

# ╔═╡ 3a3b3c3d-0053-0053-0053-000000000053
md"""
### Exercise: Axiom Schema Matching

**1.** Is □(□p → □p) → (□□p → □□p) an instance of Schema K?

$(Markdown.MD(Markdown.Admonition("hint", "Reveal answer", [md"Yes. It matches □(A → B) → (□A → □B) with A = □p and B = □p. Try: `is_instance(Implies(□(Implies(□(p), □(p))), Implies(□(□(p)), □(□(p)))), SchemaK())`"])))

**2.** Is □◇p → ◇p an instance of Schema T?

$(Markdown.MD(Markdown.Admonition("hint", "Reveal answer", [md"Yes. Schema T is □A → A. Here A = ◇p, so we get □(◇p) → ◇p. Try: `is_instance(Implies(□(◇(p)), ◇(p)), SchemaT())`"])))
"""

# ╔═╡ 3a3b3c3d-0018-0018-0018-000000000018
md"""
## Modal Systems

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

# ╔═╡ 3a3b3c3d-0054-0054-0054-000000000054
md"""
### Exercise: Choosing a System

Translate each English statement into modal logic and identify the weakest modal system that validates it.

**1.** "If it is necessarily the case that it is raining, then it is raining."

$(Markdown.MD(Markdown.Admonition("hint", "Reveal answer", [md"□p → p (letting p = 'it is raining'). This is exactly Schema T. The weakest system that validates it is **KT**. System K alone is insufficient because □p → p is not valid on all frames — only on reflexive ones."])))

**2.** "If it is necessarily the case that all birds fly, then it is necessarily necessary that all birds fly."

$(Markdown.MD(Markdown.Admonition("hint", "Reveal answer", [md"□p → □□p (letting p = 'all birds fly'). This is Schema 4. The weakest system that validates it is **K4**. This axiom requires transitivity of the accessibility relation."])))

**3.** "If it is obligatory to treat the patient, then it is permissible to treat the patient."

$(Markdown.MD(Markdown.Admonition("hint", "Reveal answer", [md"□p → ◇p (letting p = 'treat the patient', reading □ as obligation and ◇ as permission). This is Schema D. The weakest system that validates it is **KD**. This is the deontic interpretation: obligations must be achievable. Seriality of the accessibility relation ensures no 'dead-end' worlds where everything is obligatory but nothing is permitted."])))
"""

# ╔═╡ 3a3b3c3d-0020-0020-0020-000000000020
md"""
## Derivations and Proof Checking

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

# ╔═╡ 3a3b3c3d-0055-0055-0055-000000000055
md"""
### Exercise: Reading a Proof

Look at the four-step proof above and answer:

**1.** Why can we apply Necessitation to step 1? Doesn't that require step 1 to be a theorem, not just any formula?

$(Markdown.MD(Markdown.Admonition("hint", "Reveal answer", [md"Necessitation can be applied to any formula that has already been derived in the proof. Step 1 is derived as a tautological instance, so it is a theorem of the system. In a Hilbert derivation, every line is a theorem, so Necessitation is always applicable. (This is different from 'if p is true at a world, then □p is true' — that would be unsound.)"])))

**2.** What role does the K axiom play in step 3?

$(Markdown.MD(Markdown.Admonition("hint", "Reveal answer", [md"The K axiom is the bridge between 'it is necessary that A implies B' and 'if A is necessary then B is necessary.' Without K, Necessitation would give us □(A → B) but we could not decompose it into separate claims about □A and □B. K is what makes □ a *normal* modal operator — one that respects logical implication."])))
"""

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

# ╔═╡ 3a3b3c3d-0056-0056-0056-000000000056
md"""
### Exercise: Building a Derivation

**1.** "Every necessary truth is possibly true." Express this as a formula and identify a system where it is derivable.

$(Markdown.MD(Markdown.Admonition("hint", "Reveal answer", [md"□p → ◇p. This is Schema D, derivable in system KD (and any system containing D, such as KT, S4, S5). In KD it is a one-step derivation: `Derivation([ProofStep(Implies(□(p), ◇(p)), AxiomInst(SchemaD()))])`. In KT, you can also derive it from T plus the Dual axiom."])))

**2.** Construct a two-step proof of □⊤ in system K (Hint: ⊤ is a tautological instance, then apply Necessitation).

$(Markdown.MD(Markdown.Admonition("hint", "Reveal answer", [md"Step 1: ⊤ (tautological instance). Step 2: □⊤ (Necessitation from step 1). In code: `Derivation([ProofStep(Top(), Tautology()), ProofStep(□(Top()), Necessitation(1))])`"])))
"""

# ╔═╡ 3a3b3c3d-0027-0027-0027-000000000027
md"""
## Dual Formulas
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
	(original_dual = nested, dual_form = dual(nested))
end

# ╔═╡ 3a3b3c3d-0057-0057-0057-000000000057
md"""
### Exercise: Duals

**1.** What is the dual of ◇(p → q)?

$(Markdown.MD(Markdown.Admonition("hint", "Reveal answer", [md"Since p → q is ¬p ∨ q, the dual swaps ◇ to □ and ∨ to ∧, and negates atoms: □(p ∧ ¬q). Verify with `dual(◇(Implies(p, q)))`. Note that implication is first expanded before the dual is computed."])))

**2.** If a formula A is valid, what can we say about dual(A)?

$(Markdown.MD(Markdown.Admonition("hint", "Reveal answer", [md"If A is valid (true in all models), then ¬A is unsatisfiable, and since A ↔ ¬(dual(A)), dual(A) is also unsatisfiable. Equivalently, ¬(dual(A)) is valid. The dual flips validity and unsatisfiability in a precise way."])))
"""

# ╔═╡ 3a3b3c3d-0030-0030-0030-000000000030
md"""
## Soundness
If a formula is provable in a modal system, it is valid on the
corresponding class of frames. We can verify this semantically:
K-provable formulas should be valid on *all* frames, and
system-specific theorems should be valid on the appropriate frame class.

Let us build some concrete frames and check that our derived theorem □p → □(q → p) holds on all of them.
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

# ╔═╡ 3a3b3c3d-0058-0058-0058-000000000058
md"""
We can visualize these frames to see their different structures. Despite their differences, the K-provable theorem □p → □(q → p) holds on all of them — that is what soundness guarantees.
"""

# ╔═╡ 3a3b3c3d-0059-0059-0059-000000000059
begin
	model1_s = KripkeModel(frame1_s, [:p => [:w1, :w2]])
	visualize_model(model1_s,
		positions = Dict(:w1 => (0.0, 0.0), :w2 => (2.0, 0.0)),
		title = "Frame 1: simple (w₁ → w₂)")
end

# ╔═╡ 3a3b3c3d-0060-0060-0060-000000000060
begin
	model2_s = KripkeModel(frame2_s, [:p => [:w1]])
	visualize_model(model2_s,
		positions = Dict(:w1 => (0.0, 0.0)),
		title = "Frame 2: reflexive singleton (w₁ → w₁)")
end

# ╔═╡ 3a3b3c3d-0061-0061-0061-000000000061
begin
	model3_s = KripkeModel(frame3_s, [:p => [:w1, :w2, :w3]])
	visualize_model(model3_s,
		positions = Dict(:w1 => (0.0, 0.0), :w2 => (2.0, 0.0), :w3 => (4.0, 0.0)),
		title = "Frame 3: chain (w₁ → w₂ → w₃)")
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

# ╔═╡ 3a3b3c3d-0062-0062-0062-000000000062
md"""
Schema T (□p → p) is valid on reflexive frames but fails on non-reflexive ones. Let us visualize a counterexample — a non-reflexive frame where □p → p fails:
"""

# ╔═╡ 3a3b3c3d-0063-0063-0063-000000000063
begin
	# Counterexample: p is true at w2 only, so □p is vacuously true at w2
	# (w2 has no successors) but p is false at w1
	counterex_model = KripkeModel(non_reflexive_s, [:p => [:w2]])
	visualize_model(counterex_model,
		positions = Dict(:w1 => (0.0, 0.0), :w2 => (2.0, 0.0)),
		title = "Counterexample to □p → p (non-reflexive)")
end

# ╔═╡ 3a3b3c3d-0064-0064-0064-000000000064
md"""
In the model above, w₂ has no successors, so □p is vacuously true at w₂. But if we evaluate at w₁: w₁ accesses only w₂ where p is true, so □p holds at w₁. Yet p is false at w₁. Thus □p → p fails at w₁ — the frame is not reflexive, so Schema T is not valid on it.
"""

# ╔═╡ 3a3b3c3d-0065-0065-0065-000000000065
md"""
### Exercise: Soundness and Counterexamples

**1.** "If □(p → q) holds, then □p → □q must hold." Is this a valid inference on all frames? What axiom is this?

$(Markdown.MD(Markdown.Admonition("hint", "Reveal answer", [md"Yes, this is exactly the K axiom: □(p → q) → (□p → □q). It is valid on all frames, which is why K is the base axiom for *every* normal modal logic. You cannot have a normal modal logic without it."])))

**2.** Construct a Kripke frame where □p → ◇p (Schema D) fails. What property does the frame lack?

$(Markdown.MD(Markdown.Admonition("hint", "Reveal answer", [md"Any frame with a 'dead-end' world (one that accesses no worlds) will falsify Schema D. For example, `KripkeFrame([:w1], Pair{Symbol,Symbol}[])` — the single world w₁ has no successors. Then □p is vacuously true at w₁ (there are no accessible worlds to check), but ◇p is false (there is no accessible world where p is true). The frame lacks **seriality** — the property that every world accesses at least one world."])))
"""

# ╔═╡ 3a3b3c3d-0066-0066-0066-000000000066
md"""
$(Markdown.MD(Markdown.Admonition("note", "Knowledge Representation Lens", [md"The relationship between axiom systems and frame classes illustrates what Davis, Shrobe & Szolovits (1993) call Role 3 of a KR: 'a fragmentary theory of intelligent reasoning.' The axioms of system K sanction only the most basic modal inferences (distribution and necessitation). Adding Schema D sanctions the inference from obligation to permission — but only if you commit to seriality. Adding Schema T sanctions the inference from necessity to truth — but only if you commit to reflexivity. Each axiom extends the set of sanctioned inferences, and the Soundness Theorem (3.31) guarantees that every sanctioned inference is valid on the corresponding class of frames. The system never sanctions an inference that could lead you astray."])))
"""

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
# ╟─3a3b3c3d-0050-0050-0050-000000000050
# ╟─3a3b3c3d-0003-0003-0003-000000000003
# ╠═3a3b3c3d-0004-0004-0004-000000000004
# ╟─3a3b3c3d-0005-0005-0005-000000000005
# ╠═3a3b3c3d-0006-0006-0006-000000000006
# ╟─3a3b3c3d-0051-0051-0051-000000000051
# ╟─3a3b3c3d-0007-0007-0007-000000000007
# ╠═3a3b3c3d-0008-0008-0008-000000000008
# ╠═3a3b3c3d-0009-0009-0009-000000000009
# ╟─3a3b3c3d-0010-0010-0010-000000000010
# ╠═3a3b3c3d-0011-0011-0011-000000000011
# ╟─3a3b3c3d-0052-0052-0052-000000000052
# ╟─3a3b3c3d-0012-0012-0012-000000000012
# ╠═3a3b3c3d-0013-0013-0013-000000000013
# ╠═3a3b3c3d-0014-0014-0014-000000000014
# ╠═3a3b3c3d-0015-0015-0015-000000000015
# ╟─3a3b3c3d-0016-0016-0016-000000000016
# ╠═3a3b3c3d-0017-0017-0017-000000000017
# ╟─3a3b3c3d-0053-0053-0053-000000000053
# ╟─3a3b3c3d-0018-0018-0018-000000000018
# ╠═3a3b3c3d-0019-0019-0019-000000000019
# ╟─3a3b3c3d-0054-0054-0054-000000000054
# ╟─3a3b3c3d-0020-0020-0020-000000000020
# ╠═3a3b3c3d-0021-0021-0021-000000000021
# ╟─3a3b3c3d-0055-0055-0055-000000000055
# ╟─3a3b3c3d-0022-0022-0022-000000000022
# ╠═3a3b3c3d-0023-0023-0023-000000000023
# ╟─3a3b3c3d-0024-0024-0024-000000000024
# ╠═3a3b3c3d-0025-0025-0025-000000000025
# ╠═3a3b3c3d-0026-0026-0026-000000000026
# ╟─3a3b3c3d-0056-0056-0056-000000000056
# ╟─3a3b3c3d-0027-0027-0027-000000000027
# ╠═3a3b3c3d-0028-0028-0028-000000000028
# ╠═3a3b3c3d-0029-0029-0029-000000000029
# ╟─3a3b3c3d-0057-0057-0057-000000000057
# ╟─3a3b3c3d-0030-0030-0030-000000000030
# ╠═3a3b3c3d-0031-0031-0031-000000000031
# ╟─3a3b3c3d-0058-0058-0058-000000000058
# ╠═3a3b3c3d-0059-0059-0059-000000000059
# ╠═3a3b3c3d-0060-0060-0060-000000000060
# ╠═3a3b3c3d-0061-0061-0061-000000000061
# ╠═3a3b3c3d-0032-0032-0032-000000000032
# ╟─3a3b3c3d-0062-0062-0062-000000000062
# ╠═3a3b3c3d-0063-0063-0063-000000000063
# ╟─3a3b3c3d-0064-0064-0064-000000000064
# ╟─3a3b3c3d-0065-0065-0065-000000000065
# ╟─3a3b3c3d-0066-0066-0066-000000000066
# ╟─3a3b3c3d-0033-0033-0033-000000000033
