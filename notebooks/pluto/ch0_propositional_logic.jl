### A Pluto.jl notebook ###
# v0.20.4

using Markdown
using InteractiveUtils

# ╔═╡ 0a0b0c0d-0001-0001-0001-000000000001
md"""
# Chapter 0: Propositional Logic — A Foundation for Modal Logic

This notebook provides a self-contained review of **propositional logic** for students
who have not taken a formal logic course. It covers the concepts needed to engage with
[Boxes and Diamonds](https://bd.openlogicproject.org) Chapter 1 and beyond.

We cover:
- What is a proposition?
- Logical connectives: ¬, ∧, ∨, →, ↔
- Truth tables and evaluation
- Modus ponens and logical inference
- Tautologies and contradictions
- The limits of propositional logic — why we need modality

**No prior logic background is assumed.**
"""

# ╔═╡ 0a0b0c0d-0002-0002-0002-000000000002
begin
	using Pkg
	Pkg.activate(joinpath(@__DIR__, ".."))
	using Gamen
end

# ╔═╡ 0a0b0c0d-0003-0003-0003-000000000003
md"""
## What Is a Proposition?

A **proposition** is a declarative statement that is either **true** or **false** — not both,
not neither.

| Statement | Proposition? | Why? |
|:----------|:------------|:-----|
| "It is raining" | ✓ Yes | Can be true or false |
| "2 + 2 = 4" | ✓ Yes | True |
| "2 + 2 = 5" | ✓ Yes | False (but still a proposition!) |
| "Close the door" | ✗ No | A command — not true or false |
| "Is it raining?" | ✗ No | A question — not true or false |

Propositions are the **atoms** of formal logic. We represent them with variables like p ("It is raining") and q ("The ground is wet"), and build complex statements by combining them with logical connectives.

In Gamen.jl, we create atomic propositions with `Atom`:
"""

# ╔═╡ 0a0b0c0d-0004-0004-0004-000000000004
begin
	p = Atom(:p)
	q = Atom(:q)
	r = Atom(:r)
	(p, q, r)
end

# ╔═╡ 0a0b0c0d-0005-0005-0005-000000000005
md"""
## Logical Constants and Connectives

Before introducing connectives, two special constants are worth knowing:

- **⊥** ("bottom" or "falsity") — a formula that is *always false*. In Gamen.jl: `Bottom()`
- **⊤** ("top" or "truth") — a formula that is *always true*. Defined as ¬⊥. In Gamen.jl: `Top()`

These may seem trivial, but they play important roles: ⊥ is used to define inconsistency (a set of formulas is inconsistent if you can derive ⊥ from it), and ⊤ is useful as a placeholder that is trivially satisfied.

We build complex statements from simple ones using **connectives**:

| Connective | Symbol | Name | Gamen.jl | Meaning |
|:-----------|:-------|:-----|:---------|:--------|
| NOT | ¬ | Negation | `Not(p)` | "It is not the case that p" |
| AND | ∧ | Conjunction | `And(p, q)` | "Both p and q" |
| OR | ∨ | Disjunction | `Or(p, q)` | "p or q (or both)" |
| IF...THEN | → | Implication | `Implies(p, q)` | "If p then q" |
| IF AND ONLY IF | ↔ | Biconditional | `Iff(p, q)` | "p exactly when q" |

Let's build some formulas:
"""

# ╔═╡ 0a0b0c0d-0006-0006-0006-000000000006
md"""
### Negation: ¬p — "not p"

A negation is true when p is false
"""

# ╔═╡ 0a0b0c0d-0007-0007-0007-000000000007
not_p = Not(p)

# ╔═╡ 0a0b0c0d-0008-0008-0008-000000000008
md"""
### Conjunction: p ∧ q — "p and q"

A conjunction is true only when **both** parts are true.
"""

# ╔═╡ 0a0b0c0d-0009-0009-0009-000000000009
p_and_q = And(p, q)

# ╔═╡ 0a0b0c0d-0010-0010-0010-000000000010
md"""
### Disjunction: p ∨ q — "p or q"

A disjunction is true when **at least one** part is true. This is the inclusive "or" —
both can be true.
"""

# ╔═╡ 0a0b0c0d-0011-0011-0011-000000000011
p_or_q = Or(p, q)

# ╔═╡ 0a0b0c0d-0012-0012-0012-000000000012
md"""
### Implication: p → q — "if p then q"

This is the most important connective for understanding rules and inference.
An implication is **false only when p is true and q is false**. If p is false,
the implication is true regardless of q (vacuous truth).

Think of it as a promise: "If it rains, I will bring an umbrella." The promise
is only broken if it rains and you don't bring an umbrella.
"""

# ╔═╡ 0a0b0c0d-0013-0013-0013-000000000013
p_implies_q = Implies(p, q)

# ╔═╡ 0a0b0c0d-0040-0040-0040-000000000040
md"""
### Biconditional: p ↔ q — "p if and only if q"

A biconditional is true when both sides have the **same** truth value — both true or both false. It is equivalent to (p → q) ∧ (q → p): the implication goes both ways.

"You pass if and only if you score above 70" means: above 70 guarantees passing, AND passing guarantees you were above 70.
"""

# ╔═╡ 0a0b0c0d-0041-0041-0041-000000000041
p_iff_q = Iff(p, q)

# ╔═╡ 0a0b0c0d-0014-0014-0014-000000000014
md"""
## Truth Tables via Model Checking

In propositional logic, we determine truth by assigning truth values to atoms
and evaluating. In Gamen.jl, we use **Kripke models** for this — even for
propositional formulas. A single world with no accessibility relation is
equivalent to a truth assignment.

Let's evaluate $p \land q$ under different assignments:
"""

# ╔═╡ 0a0b0c0d-0015-0015-0015-000000000015
begin
	# World where p=true, q=true
	w_tt = KripkeModel(KripkeFrame([:w], Pair{Symbol,Symbol}[]), [:p => [:w], :q => [:w]])
	# World where p=true, q=false
	w_tf = KripkeModel(KripkeFrame([:w], Pair{Symbol,Symbol}[]), [:p => [:w]])
	# World where p=false, q=true
	w_ft = KripkeModel(KripkeFrame([:w], Pair{Symbol,Symbol}[]), [:q => [:w]])
	# World where p=false, q=false
	w_ff = KripkeModel(KripkeFrame([:w], Pair{Symbol,Symbol}[]), Pair{Symbol,Vector{Symbol}}[])

	md"""
	### Truth table for p ∧ q (conjunction)

	| p | q | p ∧ q |
	|:--|:--|:------|
	| T | T | $(satisfies(w_tt, :w, p_and_q) ? "T" : "F") |
	| T | F | $(satisfies(w_tf, :w, p_and_q) ? "T" : "F") |
	| F | T | $(satisfies(w_ft, :w, p_and_q) ? "T" : "F") |
	| F | F | $(satisfies(w_ff, :w, p_and_q) ? "T" : "F") |

	As expected: conjunction is true only when **both** are true.
	"""
end

# ╔═╡ 0a0b0c0d-0016-0016-0016-000000000016
md"""
### Truth table for p → q (implication)

| p | q | p → q |
|:--|:--|:------|
| T | T | $(satisfies(w_tt, :w, p_implies_q) ? "T" : "F") |
| T | F | $(satisfies(w_tf, :w, p_implies_q) ? "T" : "F") |
| F | T | $(satisfies(w_ft, :w, p_implies_q) ? "T" : "F") |
| F | F | $(satisfies(w_ff, :w, p_implies_q) ? "T" : "F") |

Note: when $p$ is false, $p \to q$ is **always true**. This is *vacuous truth* —
the promise is not broken because the condition was never triggered.
"""

# ╔═╡ 0a0b0c0d-0017-0017-0017-000000000017
md"""
## Modus Ponens: The Core Inference Rule

**Modus ponens** (Latin: "mode where affirming affirms") is the fundamental rule of logical inference:

> If **P** is true, and **P → Q** is true, then **Q** must be true.

Every "if...then" rule works this way — from everyday reasoning to legal codes to game rules:

```
IF   you land on another player's property AND you don't own it    (P)
THEN you must pay rent                                             (Q)
```

When the conditions are met (P is true), the conclusion follows (Q must be true). This is the engine behind every rule-based system, from board games to tax codes to clinical decision support.

Let's verify modus ponens is a valid inference in Gamen.jl:
"""

# ╔═╡ 0a0b0c0d-0018-0018-0018-000000000018
begin
	# Modus ponens: from P and P→Q, conclude Q
	# This is valid iff P ∧ (P→Q) → Q is a tautology
	modus_ponens = Implies(And(p, Implies(p, q)), q)
	is_tautology(modus_ponens)
end

# ╔═╡ 0a0b0c0d-0019-0019-0019-000000000019
md"""
`is_tautology` returns `true` — modus ponens is valid under **every** truth assignment.
This is why rule-based inference works: if the premises hold, the conclusion is guaranteed.
"""

# ╔═╡ 0a0b0c0d-0020-0020-0020-000000000020
md"""
## Tautologies and Contradictions

A **tautology** is a formula that is true under every possible truth assignment.
A **contradiction** is a formula that is false under every assignment.

Some classical tautologies:
"""

# ╔═╡ 0a0b0c0d-0021-0021-0021-000000000021
begin
	# Law of excluded middle: p ∨ ¬p
	excluded_middle = Or(p, Not(p))

	# Double negation: ¬¬p → p
	double_neg = Implies(Not(Not(p)), p)

	# Contrapositive: (p → q) → (¬q → ¬p)
	contrapositive = Implies(Implies(p, q), Implies(Not(q), Not(p)))

	# Contradiction: p ∧ ¬p (should NOT be a tautology)
	contradiction = And(p, Not(p))

	md"""
	| Formula | Name | Tautology? |
	|:--------|:-----|:-----------|
	| p ∨ ¬p | Law of excluded middle | $(is_tautology(excluded_middle)) |
	| ¬¬p → p | Double negation elimination | $(is_tautology(double_neg)) |
	| (p → q) → (¬q → ¬p) | Contrapositive | $(is_tautology(contrapositive)) |
	| p ∧ ¬p | Contradiction | $(is_tautology(contradiction)) |
	"""
end

# ╔═╡ 0a0b0c0d-0022-0022-0022-000000000022
md"""
## Building Complex Arguments

We can chain implications to build multi-step arguments. Consider:

1. If it is raining, the ground is wet. ($p \to q$)
2. If the ground is wet, the road is slippery. ($q \to r$)
3. Therefore: if it is raining, the road is slippery. ($p \to r$)

This pattern is called **hypothetical syllogism** (chain rule). Is it a tautology?
"""

# ╔═╡ 0a0b0c0d-0023-0023-0023-000000000023
begin
	# Hypothetical syllogism: (p→q) ∧ (q→r) → (p→r)
	chain_rule = Implies(And(Implies(p, q), Implies(q, r)), Implies(p, r))
	is_tautology(chain_rule)
end

# ╔═╡ 0a0b0c0d-0024-0024-0024-000000000024
md"""
Yes! The chain rule is valid. This is how complex reasoning works — each conclusion becomes a premise for the next step, and the chain is logically sound. Sherlock Holmes, tax law, medical diagnosis — any domain where conclusions feed into further reasoning relies on this pattern.
"""

# ╔═╡ 0a0b0c0d-0025-0025-0025-000000000025
md"""
## The Limits of Propositional Logic

Propositional logic handles **what is true right now**. But clinical reasoning often
needs more:

| Statement | Logic needed |
|:----------|:-------------|
| "The patient has a fever" | Propositional ✓ |
| "The patient **might** have meningitis" | **Possibility** — ◇ |
| "Antibiotics **must** be started within 1 hour" | **Obligation** — □ |
| "The clinician **knows** the culture result" | **Knowledge** — K |
| "The patient **will eventually** recover" | **Temporal** — F |

These words — might, must, knows, eventually — are not truth values.
They are **modalities**: ways of qualifying truth.

Propositional logic can express:
- "The patient is on aspirin" (true or false)

It **cannot** express:
- "The patient **should** be on aspirin" (obligation)
- "The patient **might** benefit from aspirin" (possibility)
- "In **all** guideline-compliant scenarios, the patient is on aspirin" (necessity)

This is why we need **modal logic** — the subject of Chapter 1 and beyond.

$(Markdown.MD(Markdown.Admonition("note", "Knowledge Representation Lens", [md"Davis, Shrobe & Szolovits (1993) argue that every knowledge representation is a *surrogate* — a stand-in for the real thing inside a reasoning system. Propositional formulas are surrogates for facts about the world, and like all surrogates, they are imperfect. The gap we just identified — propositional logic can't express obligation, possibility, or knowledge — is a gap in the *surrogate's* fidelity. Modal logic narrows this gap by adding operators that capture more of how we actually reason. But no surrogate is ever perfect: even modal logic can't represent everything about clinical reasoning. The question is always whether the surrogate is *good enough* for the reasoning task at hand."])))
"""

# ╔═╡ 0a0b0c0d-0026-0026-0026-000000000026
md"""
## Preview: From Propositions to Modality

In modal logic, we add two operators to propositional logic:

- **□p** (Box p) — "Necessarily p" / "In all accessible situations, p is true"
- **◇p** (Diamond p) — "Possibly p" / "In some accessible situation, p is true"

These are **interdefinable**: ◇p ≡ ¬□¬p (something is possible if its negation is
not necessary).

In Gamen.jl:
"""

# ╔═╡ 0a0b0c0d-0027-0027-0027-000000000027
begin
	box_p = Box(p)
	diamond_p = Diamond(p)
	(box_p, diamond_p)
end

# ╔═╡ 0a0b0c0d-0028-0028-0028-000000000028
md"""
But unlike propositional formulas, modal formulas cannot be evaluated by a simple
truth assignment. We need **Kripke models** — multiple possible worlds connected
by an accessibility relation — to determine whether □p or ◇p holds.

That is the subject of **Chapter 1: Syntax and Semantics**.

---

### Key takeaways

1. **Propositions** are statements that are true or false
2. **Connectives** (¬, ∧, ∨, →, ↔) build complex formulas from atoms
3. **Modus ponens** is the inference engine behind rule-based AI
4. **Tautologies** are formulas true under every assignment — the backbone of valid reasoning
5. Propositional logic cannot express **possibility, obligation, knowledge, or time** — for these, we need **modal logic**
"""

# ╔═╡ 0a0b0c0d-0029-0029-0029-000000000029
md"""
### Exercises

1. Build the formula $(p \lor q) \to (q \lor p)$ and check whether it is a tautology. Why should it be?

2. Is $p \to (q \to p)$ a tautology? What does it mean in plain language?

3. Build a formula that is a **contradiction** (false under every assignment) and verify it with `is_tautology(Not(your_formula))`.

4. **Challenge**: Express the following clinical rule as a propositional formula and check it:
   - "If the patient has a penicillin allergy AND the patient has a strep infection, THEN prescribe erythromycin."
   - Is the contrapositive also a tautology?
"""

# ╔═╡ Cell order:
# ╟─0a0b0c0d-0001-0001-0001-000000000001
# ╠═0a0b0c0d-0002-0002-0002-000000000002
# ╟─0a0b0c0d-0003-0003-0003-000000000003
# ╠═0a0b0c0d-0004-0004-0004-000000000004
# ╟─0a0b0c0d-0005-0005-0005-000000000005
# ╟─0a0b0c0d-0006-0006-0006-000000000006
# ╠═0a0b0c0d-0007-0007-0007-000000000007
# ╟─0a0b0c0d-0008-0008-0008-000000000008
# ╠═0a0b0c0d-0009-0009-0009-000000000009
# ╟─0a0b0c0d-0010-0010-0010-000000000010
# ╠═0a0b0c0d-0011-0011-0011-000000000011
# ╟─0a0b0c0d-0012-0012-0012-000000000012
# ╠═0a0b0c0d-0013-0013-0013-000000000013
# ╟─0a0b0c0d-0040-0040-0040-000000000040
# ╠═0a0b0c0d-0041-0041-0041-000000000041
# ╟─0a0b0c0d-0014-0014-0014-000000000014
# ╠═0a0b0c0d-0015-0015-0015-000000000015
# ╟─0a0b0c0d-0016-0016-0016-000000000016
# ╟─0a0b0c0d-0017-0017-0017-000000000017
# ╠═0a0b0c0d-0018-0018-0018-000000000018
# ╟─0a0b0c0d-0019-0019-0019-000000000019
# ╟─0a0b0c0d-0020-0020-0020-000000000020
# ╠═0a0b0c0d-0021-0021-0021-000000000021
# ╟─0a0b0c0d-0022-0022-0022-000000000022
# ╠═0a0b0c0d-0023-0023-0023-000000000023
# ╟─0a0b0c0d-0024-0024-0024-000000000024
# ╟─0a0b0c0d-0025-0025-0025-000000000025
# ╟─0a0b0c0d-0026-0026-0026-000000000026
# ╠═0a0b0c0d-0027-0027-0027-000000000027
# ╟─0a0b0c0d-0028-0028-0028-000000000028
# ╟─0a0b0c0d-0029-0029-0029-000000000029
