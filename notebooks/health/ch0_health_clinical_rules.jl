### A Pluto.jl notebook ###
# v0.20.4

using Markdown
using InteractiveUtils

# ╔═╡ 0b0b0c0d-0001-0001-0001-000000000001
md"""
# Clinical Rules and Propositional Logic

This notebook parallels **Chapter 0 (Propositional Logic)** but uses clinical examples
throughout. It shows how propositional logic underlies the rule-based clinical decision
support systems embedded in every modern EHR — and why propositional logic alone is
insufficient for the normative language of clinical guidelines.

### Background

Expert systems like MYCIN (Shortliffe et al., 1975) encoded clinical knowledge as
**production rules** — IF-THEN statements with the logical form of implications.
MYCIN's approximately 100 rules could recommend antibiotics at a level comparable to
infectious disease specialists (Yu et al., 1979). Every clinical decision support
alert in a modern EHR is a descendant of these rules.

**No prior logic background is assumed.**
"""

# ╔═╡ 0b0b0c0d-0002-0002-0002-000000000002
begin
	using Pkg
	Pkg.activate(joinpath(@__DIR__, ".."))
	using Gamen
end

# ╔═╡ 0b0b0c0d-0003-0003-0003-000000000003
md"""
## Clinical Propositions

In clinical reasoning, propositions represent observable facts about a patient:

| Proposition | Variable | Type |
|:------------|:---------|:-----|
| "The patient has a fever" | `fever` | Observation |
| "The organism is gram-positive" | `gram_pos` | Lab result |
| "The morphology is coccus" | `coccus` | Lab result |
| "The growth pattern is chains" | `chains` | Lab result |
| "The organism is streptococcus" | `strep` | Conclusion |

Each of these is either true or false for a given patient. Let's create them:
"""

# ╔═╡ 0b0b0c0d-0004-0004-0004-000000000004
begin
	fever     = Atom(:fever)
	gram_pos  = Atom(:gram_pos)
	coccus    = Atom(:coccus)
	chains    = Atom(:chains)
	strep     = Atom(:strep)
	erythro   = Atom(:erythromycin)
	pcn       = Atom(:penicillin)
	allergy   = Atom(:pcn_allergy)
	bacteremia = Atom(:bacteremia)
end

# ╔═╡ 0b0b0c0d-0005-0005-0005-000000000005
md"""
## Clinical Rules as Implications

A MYCIN-style production rule has the form:

```
IF   gram-positive AND coccus AND chains
THEN the organism is streptococcus
```

In propositional logic, this is an **implication**:

$(\text{gram\_pos} \land \text{coccus} \land \text{chains}) \to \text{strep}$
"""

# ╔═╡ 0b0b0c0d-0006-0006-0006-000000000006
begin
	# MYCIN Rule 1: organism identification
	rule_strep = Implies(And(gram_pos, And(coccus, chains)), strep)
end

# ╔═╡ 0b0b0c0d-0007-0007-0007-000000000007
md"""
### Evaluating the Rule

Let's create two clinical scenarios and check whether the rule's conclusion holds:

**Scenario A**: gram-positive cocci in chains (all premises true)

**Scenario B**: gram-positive cocci but no chains (one premise false)
"""

# ╔═╡ 0b0b0c0d-0008-0008-0008-000000000008
begin
	# Scenario A: all premises hold, conclusion holds
	scenario_a = KripkeModel(
		KripkeFrame([:w], Pair{Symbol,Symbol}[]),
		[:gram_pos => [:w], :coccus => [:w], :chains => [:w], :strep => [:w]]
	)

	# Scenario B: chains not observed, strep not concluded
	scenario_b = KripkeModel(
		KripkeFrame([:w], Pair{Symbol,Symbol}[]),
		[:gram_pos => [:w], :coccus => [:w]]
	)

	md"""
	| Scenario | gram\_pos | coccus | chains | Rule fires? |
	|:---------|:---------|:-------|:-------|:------------|
	| A | T | T | T | $(satisfies(scenario_a, :w, rule_strep) ? "T — conclusion follows" : "F") |
	| B | T | T | F | $(satisfies(scenario_b, :w, rule_strep) ? "T — vacuously true (premise not met)" : "F") |

	In Scenario B, the rule is **vacuously true**: since not all premises are met,
	the rule makes no claim. This is the **closed-world assumption** — if the evidence
	doesn't trigger the rule, the system draws no conclusion.
	"""
end

# ╔═╡ 0b0b0c0d-0009-0009-0009-000000000009
md"""
## Modus Ponens in Clinical Inference

**Modus ponens** is the engine that drives rule-based clinical AI:

> If the **premises** are true and the **rule** is true, the **conclusion** must be true.

In MYCIN's case:
1. We observe: gram-positive, coccus, chains (premises are true)
2. The rule says: if these, then streptococcus
3. Therefore: the organism is streptococcus

Let's verify this is always valid:
"""

# ╔═╡ 0b0b0c0d-0010-0010-0010-000000000010
begin
	# Simplified: p ∧ (p → q) → q  (modus ponens)
	p = Atom(:p)
	q = Atom(:q)
	modus_ponens = Implies(And(p, Implies(p, q)), q)
	is_tautology(modus_ponens)
end

# ╔═╡ 0b0b0c0d-0011-0011-0011-000000000011
md"""
This is why MYCIN's inference was **sound** — each step follows necessarily from
the premises and the rules. When the system was wrong, it was because a **rule**
was wrong or **incomplete**, not because the inference was faulty.

This is also why errors in rule-based systems are **inspectable**: you can find and
fix the faulty rule. Compare this to a neural network, where "fixing" an error
requires retraining the entire model.

$(Markdown.MD(Markdown.Admonition("note", "Knowledge Representation Lens", [md"Buchanan (2006) traces the arc from Socrates to MYCIN: knowledge as justified true belief, formalized as explicit rules in a computer. His key insight is that *making assumptions explicit is valuable, whether or not the system is correct*. When MYCIN is wrong, the faulty rule is visible and fixable. When an LLM is wrong, the error is distributed across billions of opaque weights. This is what Davis et al. (1993) call the representation serving as a *medium of human expression* — MYCIN's rules are readable by the physicians who must trust and correct them. Clark (2003) would add that these rule systems function as *cognitive extensions* — they augment the clinician's reasoning capacity rather than replacing it, exactly as a stethoscope augments hearing."])))
"""

# ╔═╡ 0b0b0c0d-0012-0012-0012-000000000012
md"""
## Chaining Rules: Multi-Step Clinical Reasoning

Clinical reasoning chains multiple rules. Consider:

1. **Rule 1**: If gram-positive cocci in chains → streptococcus
2. **Rule 2**: If streptococcus and no penicillin allergy → prescribe penicillin
3. **Rule 3**: If streptococcus and penicillin allergy → prescribe erythromycin

This is the **hypothetical syllogism** (chain rule) applied to clinical practice.
"""

# ╔═╡ 0b0b0c0d-0013-0013-0013-000000000013
begin
	# Rule 2: strep + no allergy → penicillin
	rule_pcn = Implies(And(strep, Not(allergy)), pcn)

	# Rule 3: strep + allergy → erythromycin
	rule_erythro = Implies(And(strep, allergy), erythro)

	md"""
	**Rule 2**: strep ∧ ¬allergy → penicillin

	$(rule_pcn)

	**Rule 3**: strep ∧ allergy → erythromycin

	$(rule_erythro)
	"""
end

# ╔═╡ 0b0b0c0d-0014-0014-0014-000000000014
md"""
### Testing the Chain

Let's create a patient who is gram-positive cocci in chains with a penicillin allergy:
"""

# ╔═╡ 0b0b0c0d-0015-0015-0015-000000000015
begin
	# Patient: gram-pos cocci in chains, penicillin allergy, strep concluded, erythromycin prescribed
	allergic_patient = KripkeModel(
		KripkeFrame([:w], Pair{Symbol,Symbol}[]),
		[:gram_pos => [:w], :coccus => [:w], :chains => [:w],
		 :pcn_allergy => [:w], :strep => [:w], :erythromycin => [:w]]
	)

	md"""
	| Rule | Satisfied? |
	|:-----|:-----------|
	| Rule 1 (gram-pos ∧ coccus ∧ chains → strep) | $(satisfies(allergic_patient, :w, rule_strep)) |
	| Rule 2 (strep ∧ ¬allergy → penicillin) | $(satisfies(allergic_patient, :w, rule_pcn)) |
	| Rule 3 (strep ∧ allergy → erythromycin) | $(satisfies(allergic_patient, :w, rule_erythro)) |

	All three rules are satisfied. Rule 2 is vacuously true (the patient has an allergy,
	so the premise fails). Rule 3 fires and prescribes erythromycin. This is exactly
	how MYCIN would handle this case.
	"""
end

# ╔═╡ 0b0b0c0d-0016-0016-0016-000000000016
md"""
## The Contrapositive in Clinical Reasoning

The **contrapositive** of $p \to q$ is $\lnot q \to \lnot p$, and it is
logically equivalent:

> "If strep → prescribe penicillin" is equivalent to
> "If penicillin not prescribed → not strep (or something else overrode the rule)"

This matters for clinical auditing: if a patient with strep was *not* given an
antibiotic, either the rule was wrong or a premise was not met. The contrapositive
lets auditors reason backwards from outcomes to causes.
"""

# ╔═╡ 0b0b0c0d-0017-0017-0017-000000000017
begin
	# Contrapositive equivalence: (p→q) ↔ (¬q→¬p)
	contrapositive_equiv = Iff(Implies(p, q), Implies(Not(q), Not(p)))
	is_tautology(contrapositive_equiv)
end

# ╔═╡ 0b0b0c0d-0018-0018-0018-000000000018
md"""
## Why Propositional Logic Is Not Enough

Consider these statements from real clinical guidelines:

| Guideline Statement | Propositional? |
|:---------------------|:--------------|
| "The patient has bacteremia" | ✓ True or false |
| "Blood cultures **must** be drawn before antibiotics" | ✗ **Obligation** |
| "Aminoglycosides **may** be added for synergy" | ✗ **Permission** |
| "Vancomycin **must not** be used for MSSA" | ✗ **Prohibition** |
| "The clinician **should** reassess at 48 hours" | ✗ **Ambiguous** — obligation or recommendation? |

The first statement is a proposition. The rest express **norms** — what ought to be
done, what is allowed, what is forbidden. These are not true or false in the same
way; they are **deontic** claims about obligations and permissions.
"""

# ╔═╡ 0b0b0c0d-0019-0019-0019-000000000019
md"""
### The "Should" Problem

Lomotan et al. (2010) surveyed 445 health services professionals and found that
the word **"should"** in clinical guidelines is interpreted across a wide range of
obligation levels — from roughly 55 to 87 on a 0–100 scale.

This means: the **same guideline** produces different clinical decision support
behavior depending on who implements it:

| Implementation | Behavior | Interpretation |
|:---------------|:---------|:---------------|
| **Hard stop** | User cannot proceed without acknowledging | "should" = obligation |
| **Soft banner** | Alert appears, user can dismiss | "should" = recommendation |
| **Silent** | No alert | "should" = weak suggestion |

*Three implementers, three different systems, same guideline.*

**Deontic logic** — the modal logic of obligation (□), permission (◇), and
prohibition (□¬) — provides a formal vocabulary that resolves this ambiguity.
That is the subject of the health-application notebooks starting in Chapter 1.
"""

# ╔═╡ 0b0b0c0d-0020-0020-0020-000000000020
md"""
## Summary

| Concept | What It Means | Clinical Example |
|:--------|:-------------|:-----------------|
| **Proposition** | True or false statement | "Patient has fever" |
| **Connectives** | ¬ ∧ ∨ → ↔ | "gram-pos AND coccus AND chains" |
| **Implication** | IF...THEN rule | MYCIN production rule |
| **Modus ponens** | Premises + rule → conclusion | Forward-chaining inference |
| **Tautology** | Always true | Modus ponens, contrapositive |
| **Chain rule** | Linking multiple rules | MYCIN's multi-step reasoning |

### What propositional logic gives us
- Sound inference from explicit rules
- Inspectable, auditable reasoning chains
- The foundation of every CDS alert in every EHR

### What it cannot express
- Obligation, permission, prohibition ("must," "may," "must not")
- Possibility and necessity ("might," "always")
- Knowledge and belief ("the clinician knows...")
- Temporal sequencing ("before," "after," "eventually")

For these, we need **modal logic** — starting with **Chapter 1: Syntax and Semantics**.
"""

# ╔═╡ 0b0b0c0d-0021-0021-0021-000000000021
md"""
### Exercises

1. Write a production rule for: "If the patient has bacteremia AND fever AND the organism is gram-negative, THEN suspect E. coli." Check that it evaluates correctly.

2. Create a scenario where Rule 2 (strep ∧ ¬allergy → penicillin) fires but Rule 3 does not. Verify both.

3. A guideline says: "Patients with positive blood cultures should receive antibiotics within 1 hour." Is "should" an obligation (□) or a permission (◇)? What would change in a CDS system depending on the interpretation?

4. **Reflection**: MYCIN's rules were transparent and auditable. A modern LLM can also recommend antibiotics. What is gained and what is lost in moving from rules to neural networks?
"""

# ╔═╡ Cell order:
# ╟─0b0b0c0d-0001-0001-0001-000000000001
# ╠═0b0b0c0d-0002-0002-0002-000000000002
# ╟─0b0b0c0d-0003-0003-0003-000000000003
# ╠═0b0b0c0d-0004-0004-0004-000000000004
# ╟─0b0b0c0d-0005-0005-0005-000000000005
# ╠═0b0b0c0d-0006-0006-0006-000000000006
# ╟─0b0b0c0d-0007-0007-0007-000000000007
# ╠═0b0b0c0d-0008-0008-0008-000000000008
# ╟─0b0b0c0d-0009-0009-0009-000000000009
# ╠═0b0b0c0d-0010-0010-0010-000000000010
# ╟─0b0b0c0d-0011-0011-0011-000000000011
# ╟─0b0b0c0d-0012-0012-0012-000000000012
# ╠═0b0b0c0d-0013-0013-0013-000000000013
# ╟─0b0b0c0d-0014-0014-0014-000000000014
# ╠═0b0b0c0d-0015-0015-0015-000000000015
# ╟─0b0b0c0d-0016-0016-0016-000000000016
# ╠═0b0b0c0d-0017-0017-0017-000000000017
# ╟─0b0b0c0d-0018-0018-0018-000000000018
# ╟─0b0b0c0d-0019-0019-0019-000000000019
# ╟─0b0b0c0d-0020-0020-0020-000000000020
# ╟─0b0b0c0d-0021-0021-0021-000000000021
