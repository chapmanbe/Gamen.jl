### A Pluto.jl notebook ###
# v0.20.10

using Markdown
using InteractiveUtils

# ╔═╡ 1a2b3c4d-0002-0002-0002-000000000002
begin
	using Pkg
	Pkg.activate(joinpath(@__DIR__, ".."))
	using Gamen
	import CairoMakie, GraphMakie, Graphs
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

# ╔═╡ 1a2b3c4d-0050-0050-0050-000000000050
md"""
## Why Modal Logic?

> *"Can't an LLM just do all the reasoning for me?"*

Short answer: no. An LLM can generate plausible text about reasoning, but it cannot *guarantee* that its conclusions follow from its premises. It cannot prove that a set of rules is consistent. It cannot tell you whether a guideline conflict is resolvable. It hallucinates — confidently producing conclusions that are grammatically correct and logically wrong.

Modal logic exists because ordinary propositional logic — "true or false" — is not expressive enough for how we actually reason:

- **"It is raining"** is propositional. True or false.
- **"It might rain tomorrow"** is modal. It's about *possibility* across situations.
- **"You must file your taxes"** is modal. It's about *obligation* across acceptable outcomes.
- **"She knows the password"** is modal. It's about what's true *in every situation consistent with her information*.

These are not exotic philosophical puzzles. They are the structure of everyday reasoning about rules, plans, knowledge, and time. Modal logic gives us a precise language for it — and that precision is what lets us *compute* with it.

### A Brief History

Modal logic began with C. I. Lewis in 1918, who was dissatisfied with the paradoxes of material implication in classical logic (the fact that "if 2+2=5 then the moon is made of cheese" is technically true). He introduced operators for *strict* implication — necessity and possibility — to capture what we intuitively mean by "if...then."

Saul Kripke, as a teenager in the late 1950s, provided the semantics that made modal logic rigorous: **possible worlds** connected by an **accessibility relation**. This turned a philosophical intuition into a mathematical framework — and opened the door to computation.

Today, modal logic is the foundation of:
- **Software verification** — proving that programs satisfy safety and liveness properties (temporal logic)
- **AI and multi-agent systems** — reasoning about what agents know and believe (epistemic logic)
- **Legal and ethical reasoning** — formalizing obligations, permissions, and prohibitions (deontic logic)
- **Clinical decision support** — ensuring that guideline recommendations are consistent and computable
- **Database theory** — query languages for graph-structured data
- **Linguistics** — the semantics of "must," "might," "knows," and "will"

The LLM on your laptop uses none of this. It predicts the next token. Modal logic *proves things*.
"""

# ╔═╡ 1a2b3c4d-0003-0003-0003-000000000003
md"""
## The Language of Basic Modal Logic

The language of modal logic (Definition 1.1, B&D) starts with the language of propositional logic (1-3 below) and extends it with two new operators (4 and 5 below):

1. The propositional constant for falsity: $\bot$
2. Propositional variables: $p_0, p_1, p_2, \ldots$
3. Propositional connectives: $\lnot, \land, \lor, \to$
4. The modal operator $\square$ (box) — "necessarily" / "in all accessible situations"
5. The modal operator $\diamond$ (diamond) — "possibly" / "in some accessible situation"

The key insight: $\square$ and $\diamond$ are *quantifiers over situations*, not truth values. To evaluate them, we need a structured space of situations — a **Kripke model**, named after the logician Saul Kripke, who developed this "possible worlds" semantics as a teenager in the late 1950s.
"""

# ╔═╡ 1a2b3c4d-0004-0004-0004-000000000004
md"""
### Atomic Formulas

We can create propositional variables ("atoms") by name or by index:
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

# ╔═╡ 1a2b3c4d-0051-0051-0051-000000000051
md"""
### Practice: Translate English to Formulas

Before we move to semantics, practice translating English sentences into modal formulas. Try writing each one in Gamen.jl, then expand the hint to check your answer.

Let $p$ = "it is raining" and $q$ = "I have an umbrella."

**1. "It is not raining."**

$(Markdown.MD(Markdown.Admonition("hint", "Reveal answer", [md"`Not(p)` — simply ¬p"])))

**2. "If it is raining, then I have an umbrella."**

$(Markdown.MD(Markdown.Admonition("hint", "Reveal answer", [md"`Implies(p, q)` — p → q"])))

**3. "It is necessarily raining."** (In all accessible situations, it is raining.)

$(Markdown.MD(Markdown.Admonition("hint", "Reveal answer", [md"`Box(p)` — □p"])))

**4. "It is possible that I have an umbrella."**

$(Markdown.MD(Markdown.Admonition("hint", "Reveal answer", [md"`Diamond(q)` — ◇q"])))

**5. "If it is necessarily raining, then it is raining."** (The T axiom — is this always true?)

$(Markdown.MD(Markdown.Admonition("hint", "Reveal answer", [md"`Implies(Box(p), p)` — □p → p. This is valid on reflexive frames (Chapter 2)."])))

**6. "It is possible that it is raining and I don't have an umbrella."**

$(Markdown.MD(Markdown.Admonition("hint", "Reveal answer", [md"`Diamond(And(p, Not(q)))` — ◇(p ∧ ¬q). There exists an accessible situation where it rains and I have no umbrella."])))

**7. "If it is necessarily the case that rain implies umbrellas, then if it necessarily rains, I necessarily have an umbrella."** (Schema K)

$(Markdown.MD(Markdown.Admonition("hint", "Reveal answer", [md"`Implies(Box(Implies(p, q)), Implies(Box(p), Box(q)))` — □(p→q) → (□p → □q). This is valid on *every* frame — it is the defining axiom of the weakest normal modal logic, K."])))
"""

# ╔═╡ 1a2b3c4d-0010-0010-0010-000000000010
md"""
### Modal-Free Formulas

A formula is *modal-free* if it contains no □ or ◇ operators:
"""

# ╔═╡ 1a2b3c4d-0011-0011-0011-000000000011
begin
	is_modal_free(And(p, Not(q))),   # true — no modal operators
	is_modal_free(Implies(p, Box(q))) # false — contains □
end

# ╔═╡ 1a2b3c4d-0054-0054-0054-000000000054
md"""
### Practice: Modal or Not?

For each English sentence, decide whether it requires modal logic or can be expressed in propositional logic alone. Then expand the hint.

**1. "The patient has a fever and a cough."**

$(Markdown.MD(Markdown.Admonition("hint", "Reveal answer", [md"**Propositional.** This is a simple conjunction of two facts: fever ∧ cough. No modality needed."])))

**2. "The bridge might collapse under heavy load."**

$(Markdown.MD(Markdown.Admonition("hint", "Reveal answer", [md"**Modal.** 'Might' expresses *possibility* — there exists a situation where the bridge collapses. This requires ◇."])))

**3. "If the test is positive, the patient is infected."**

$(Markdown.MD(Markdown.Admonition("hint", "Reveal answer", [md"**Propositional.** This is a material implication: positive → infected. No modality."])))

**4. "Every employee must complete safety training."**

$(Markdown.MD(Markdown.Admonition("hint", "Reveal answer", [md"**Modal.** 'Must' expresses *obligation* — in all acceptable scenarios, the employee completes training. This requires □ (deontic interpretation)."])))

**5. "Alice knows that the server is down."**

$(Markdown.MD(Markdown.Admonition("hint", "Reveal answer", [md"**Modal.** 'Knows' means the server is down in *every situation consistent with Alice's information*. This is epistemic □."])))

**6. "It is raining or it is not raining."**

$(Markdown.MD(Markdown.Admonition("hint", "Reveal answer", [md"**Propositional.** This is the law of excluded middle: p ∨ ¬p. A tautology — no modality needed."])))
"""

# ╔═╡ 1a2b3c4d-0012-0012-0012-000000000012
md"""
## Relational Models

A *model* $M = \langle W, R, V \rangle$ consists of three components (Definition 1.6):

1. A nonempty set of "worlds" $W$
2. A binary accessibility relation $R$ on $W$
3. A valuation function $V$ that assigns to each propositional variable $p$ the set $V(p) \subseteq W$ of worlds where $p$ is true

### What are "worlds"?

The word "worlds" sounds metaphysical, but think of them concretely as **situations** or **states**:

- **Software verification** — states of a running program
- **Game theory** — positions in a game (e.g., board configurations in chess)
- **Clinical reasoning** — possible patient scenarios under different treatment choices
- **Epistemic logic** — situations consistent with what an agent knows
- **Deontic logic** — outcomes that comply with the rules

The accessibility relation says which situations are reachable or relevant from which. When we write Rww', we mean: from the perspective of situation w, situation w' is an accessible alternative.
"""

# ╔═╡ 1a2b3c4d-0070-0070-0070-000000000070
md"""
$(Markdown.MD(Markdown.Admonition("note", "Example: Tic-tac-toe", [md"Imagine a tic-tac-toe game where X has just moved. Each *world* is a board state. The accessibility relation connects the current board to all boards reachable by O's next move. □(X wins) means 'X wins no matter what O does' — true in *every* accessible state. ◇(O wins) means 'there exists a move where O wins' — true in *some* accessible state. If □(X wins) is false but ◇(X wins) is true, the game is still open."])))

$(Markdown.MD(Markdown.Admonition("note", "Example: Clinical treatment", [md"A patient presents with an infection. Each *world* is a possible treatment outcome. The accessibility relation connects the current state to outcomes reachable by different antibiotic choices. □(patient recovers) means 'the patient recovers under every treatment option' — a strong claim. ◇(adverse reaction) means 'there exists a treatment that causes an adverse reaction' — a weaker but important warning."])))
"""

# ╔═╡ 1a2b3c4d-0071-0071-0071-000000000071
md"""
### Figure 1.1 from Boxes and Diamonds

The book's first example model (Figure 1.1) has three worlds with the following valuation: $p$ is true at $w_1$ and $w_2$, while $q$ is true only at $w_2$.

- $W = \{w_1, w_2, w_3\}$
- $R = \{w_1 \to w_2,\; w_1 \to w_3\}$
- $V(p) = \{w_1, w_2\}$ and $V(q) = \{w_2\}$
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
## Truth at a World

We use the **satisfaction operator** ⊩ (also called "forces" or "satisfies") to express that a formula is true at a particular world in a model (Definition 1.7, B&D). We write M, w ⊩ A to mean "formula A is true at world w in model M."

The satisfaction relation is defined inductively — propositional cases first, then the modal cases that give □ and ◇ their meaning:

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

Clauses 1–6 are standard propositional logic. Clauses 7–8 are the modal heart:
- **□B** is true at $w$ if B holds in *every* world accessible from $w$
- **◇B** is true at $w$ if B holds in *some* world accessible from $w$

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
Reading the results:

- **Item 1 → false.** V(q) = {w₂}, so q is false at w₁.
- **Item 2 → true.** q is false at w₃, so ¬q is true there.
- **Item 3 → true.** p is true at w₁, so p ∨ q holds (only one disjunct needed).
- **Item 4 → false.** □(p ∨ q) at w₁ requires p ∨ q at both w₂ and w₃. But w₃ has neither p nor q, so it fails.
- **Item 5 → true (vacuously).** w₃ has no accessible worlds. □q requires q at *all* successors — when there are none, this is vacuously satisfied.
- **Item 6 → true (vacuously).** Same reasoning: □⊥ at a dead-end world is vacuously true, because there are no successors to check.
- **Item 7 → true.** ◇q at w₁ requires q at *some* successor. w₂ is accessible and q holds there.
- **Item 8 → false.** □q at w₁ requires q at *all* successors. w₃ is accessible but q fails there.
- **Item 9 → false.** □□¬q is true at w₁: both w₂ and w₃ have no successors, making □¬q vacuously true at both. Since □□¬q is true, ¬□□¬q is false.
"""

# ╔═╡ 1a2b3c4d-0052-0052-0052-000000000052
md"""
### Practice: Evaluate Formulas on Figure 1.1

Before looking at the model checker output, try to work out each answer by hand using the diagram above. Then expand the hint to check.

**1.** Does M, w₂ ⊩ □p hold?

$(Markdown.MD(Markdown.Admonition("hint", "Reveal answer", [md"**Yes (vacuously).** w₂ has no accessible worlds, so □p is true at w₂ for any formula — there are no worlds to check. `satisfies(model, :w2, Box(p))` returns `true`."])))

**2.** Does M, w₁ ⊩ ◇(p ∧ q) hold?

$(Markdown.MD(Markdown.Admonition("hint", "Reveal answer", [md"**Yes.** w₂ is accessible from w₁, and both p and q are true at w₂. `satisfies(model, :w1, Diamond(And(p, q)))` returns `true`."])))

**3.** Does M, w₁ ⊩ □p hold?

$(Markdown.MD(Markdown.Admonition("hint", "Reveal answer", [md"**No.** w₃ is accessible from w₁, but V(p) = {w₁, w₂}, so p is false at w₃. Therefore □p fails at w₁. `satisfies(model, :w1, Box(p))` returns `false`."])))

**4.** Does M, w₁ ⊩ ◇q ∧ ◇¬q hold?

$(Markdown.MD(Markdown.Admonition("hint", "Reveal answer", [md"**Yes.** ◇q: w₂ is accessible and q holds there. ◇¬q: w₃ is accessible and q fails there. Both diamonds are satisfied, so the conjunction holds. `satisfies(model, :w1, And(Diamond(q), Diamond(Not(q))))` returns `true`. This means: from w₁'s perspective, q is *contingent* — both possible and possibly false."])))

**5. Challenge:** Construct a formula that is true at w₃ but false at w₁ and w₂.

$(Markdown.MD(Markdown.Admonition("hint", "Reveal answer", [md"Several work: `And(Not(p), Not(q))` — neither p nor q holds at w₃, but at least one holds at the other worlds. Or `Box(Bottom())` — vacuously true at w₃ (no successors), false at w₁ (has successors)."])))
"""

# ╔═╡ 1a2b3c4d-0018-0018-0018-000000000018
md"""
## Duality of □ and ◇

□ and ◇ are **duals** — each can be defined in terms of the other (Proposition 1.8, B&D):

- □A is equivalent to ¬◇¬A ("necessarily A" means "it is not possible that not-A")
- ◇A is equivalent to ¬□¬A ("possibly A" means "it is not necessary that not-A")

This is analogous to how ∀x P(x) is equivalent to ¬∃x ¬P(x) in predicate logic — "for all" and "there exists" are duals in exactly the same way.

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
## Truth in a Model

A formula A is *true in a model* M (written M ⊩ A) if it is true at every world in M (Definition 1.9, B&D):
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
## Entailment

A set of formulas Γ *entails* A in model M if: whenever all formulas in Γ are true at a world w, then A is also true at w (Definition 1.23, B&D).
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

# ╔═╡ 1a2b3c4d-0053-0053-0053-000000000053
md"""
### Practice: Translate and Check

For each English sentence, translate it into a modal formula, then use `satisfies` to check it on the Figure 1.1 model. Use p = "it is sunny" and q = "there is traffic."

**1. "In every accessible situation, it is sunny or there is traffic."**

$(Markdown.MD(Markdown.Admonition("hint", "Reveal answer", [md"`Box(Or(p, q))` — □(p ∨ q). Check at w₁: `satisfies(model, :w1, Box(Or(p, q)))` returns `false` because w₃ has neither p nor q."])))

**2. "There is some accessible situation where it is sunny but there is no traffic."**

$(Markdown.MD(Markdown.Admonition("hint", "Reveal answer", [md"`Diamond(And(p, Not(q)))` — ◇(p ∧ ¬q). Try it: `satisfies(model, :w1, Diamond(And(p, Not(q))))` returns `false`! At w₂, p is true but q is also true, so p ∧ ¬q fails. At w₃, neither p nor q holds, so p ∧ ¬q also fails. Careful model checking catches an intuitive mistake."])))

**3. "If it is necessarily sunny, then it is sunny."** (Is this true at every world?)

$(Markdown.MD(Markdown.Admonition("hint", "Reveal answer", [md"`Implies(Box(p), p)` — □p → p. This is Schema T, valid on *reflexive* frames. Our frame is NOT reflexive (no world accesses itself), so it can fail. At w₃, □p is vacuously true (no successors) but p is false. So `is_true_in(model, Implies(Box(p), p))` returns `false`."])))
"""

# ╔═╡ 1a2b3c4d-0024-0024-0024-000000000024
md"""
## Exploring on Your Own

Try building your own models and checking formulas! Some ideas from the book:

- Verify Proposition 1.19: the schema **K**, $\square(A \to B) \to (\square A \to \square B)$, is valid on our model
- Check the invalid schemas from Table 1.1, e.g., $A \to \square A$ — and find which world falsifies it
- Build a **reflexive** frame (where every world accesses itself) and verify that Schema T, $\square A \to A$, holds
- Build the counterexample model from Figure 1.2

### Building Your Own Model

Here's a template to experiment with:

```julia
# 1. Define the frame
my_frame = KripkeFrame(
    [:a, :b, :c],                    # worlds
    [:a => :b, :b => :c, :a => :a]   # accessibility relation
)

# 2. Define the valuation
my_model = KripkeModel(my_frame, [
    :p => [:a, :b],    # p is true at a and b
    :q => [:c]          # q is true only at c
])

# 3. Check formulas
satisfies(my_model, :a, Diamond(q))   # Is ◇q true at a?
satisfies(my_model, :a, Box(p))       # Is □p true at a?

# 4. Visualize
visualize_model(my_model)
```
"""

# ╔═╡ Cell order:
# ╟─1a2b3c4d-0001-0001-0001-000000000001
# ╠═1a2b3c4d-0002-0002-0002-000000000002
# ╟─1a2b3c4d-0050-0050-0050-000000000050
# ╟─1a2b3c4d-0003-0003-0003-000000000003
# ╟─1a2b3c4d-0004-0004-0004-000000000004
# ╠═1a2b3c4d-0005-0005-0005-000000000005
# ╟─1a2b3c4d-0006-0006-0006-000000000006
# ╠═1a2b3c4d-0007-0007-0007-000000000007
# ╠═1a2b3c4d-0008-0008-0008-000000000008
# ╠═1a2b3c4d-0009-0009-0009-000000000009
# ╟─1a2b3c4d-0030-0030-0030-000000000030
# ╠═1a2b3c4d-0031-0031-0031-000000000031
# ╟─1a2b3c4d-0051-0051-0051-000000000051
# ╟─1a2b3c4d-0010-0010-0010-000000000010
# ╠═1a2b3c4d-0011-0011-0011-000000000011
# ╟─1a2b3c4d-0054-0054-0054-000000000054
# ╟─1a2b3c4d-0012-0012-0012-000000000012
# ╟─1a2b3c4d-0070-0070-0070-000000000070
# ╟─1a2b3c4d-0071-0071-0071-000000000071
# ╠═1a2b3c4d-0013-0013-0013-000000000013
# ╠═1a2b3c4d-0040-0040-0040-000000000040
# ╟─1a2b3c4d-0014-0014-0014-000000000014
# ╟─1a2b3c4d-0015-0015-0015-000000000015
# ╠═1a2b3c4d-0016-0016-0016-000000000016
# ╟─1a2b3c4d-0017-0017-0017-000000000017
# ╟─1a2b3c4d-0052-0052-0052-000000000052
# ╟─1a2b3c4d-0018-0018-0018-000000000018
# ╠═1a2b3c4d-0019-0019-0019-000000000019
# ╟─1a2b3c4d-0020-0020-0020-000000000020
# ╠═1a2b3c4d-0021-0021-0021-000000000021
# ╟─1a2b3c4d-0022-0022-0022-000000000022
# ╠═1a2b3c4d-0023-0023-0023-000000000023
# ╟─1a2b3c4d-0053-0053-0053-000000000053
# ╟─1a2b3c4d-0024-0024-0024-000000000024
