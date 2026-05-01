### A Pluto.jl notebook ###
# v0.20.21

using Markdown
using InteractiveUtils

# This Pluto notebook uses @bind for interactivity. When running this notebook outside of Pluto, the following 'mock version' of @bind gives bound variables a default value (instead of an error).
macro bind(def, element)
    #! format: off
    return quote
        local iv = try Base.loaded_modules[Base.PkgId(Base.UUID("6e696c72-6542-2067-7265-42206c756150"), "AbstractPlutoDingetjes")].Bonds.initial_value catch; b -> missing; end
        local el = $(esc(element))
        global $(esc(def)) = Core.applicable(Base.get, el) ? Base.get(el) : iv(el)
        el
    end
    #! format: on
end

# ╔═╡ 9a1b3c4d-0002-0002-0002-000000000002
begin
	using Gamen
	using PlutoUI
	import CairoMakie, GraphMakie, Graphs
end

# ╔═╡ 9a1b3c4d-0001-0001-0001-000000000001
md"""
# Completeness and Clinical Guideline Validation

## A Clinical Decision Support Failure

A hospital's CDS system silently approved a new anticoagulation order for a patient already on warfarin — the checker found "no conflict." Three days later the patient had a serious bleeding event. The root cause: the checker's logic was *incomplete*. It had no rule linking the two anticoagulants, so its "no conflict" verdict was meaningless — it was not that the guidelines were compatible, only that the checker could not see the conflict.

This is the problem completeness solves. A **complete** proof system never misses a conflict: if a contradiction exists, the system will find it. Combined with **soundness** (no false alarms), a complete checker gives a genuine guarantee.

**The central question this notebook answers**: When an automated checker reports "no conflict found," can we trust that result? The completeness theorem says *yes* — if the checker finds no proof of inconsistency, a model genuinely exists where all guidelines can be simultaneously followed.

### Learning Outcomes

After working through this notebook you will be able to:
1. State the completeness theorem for modal tableaux in plain language
2. Distinguish soundness from completeness and explain why both are required for a trustworthy guideline checker
3. Interpret a countermodel extracted from an open tableau as a concrete clinical scenario
4. Explain why KD (not K) is the appropriate logic for clinical obligations
5. Articulate three limitations of completeness that require human judgment to address

### Background

Completeness is a *metalogical* property of a proof system. Soundness tells us the system never proves something false. Completeness tells us it never misses something true. For clinical guideline validation, these two properties together guarantee that the automated checker is fully reliable (within the logic it implements). This parallels Chapter 4 of [Boxes and Diamonds](https://bd.openlogicproject.org), which proves completeness for the canonical modal systems via the canonical model construction (Theorem 4.16, B&D).
"""

# ╔═╡ 9a1b3c4d-0003-0003-0003-000000000003
md"""
## The Completeness Guarantee

Recall from Chapter 4 of B&D: a modal system Σ is **complete** with respect to a class of frames ℱ if every formula valid on ℱ is derivable in Σ.

For our tableau-based approach (Chapter 6), completeness takes a concrete operational form:

> **If no closed tableau exists for a set of formulas, they are satisfiable.**

In clinical terms: if the automated conflict checker says "no conflict found," that is reliable -- there really is a way to follow all the guidelines simultaneously. The checker does not have blind spots.
"""

# ╔═╡ 9a1b3c4d-0004-0004-0004-000000000004
md"""
## Countermodel Extraction

When guidelines are consistent, completeness gives us more than a bare "no conflict" verdict. We can **extract a countermodel** from the open tableau branch -- a concrete scenario demonstrating how all the guidelines can be satisfied at once.

Let's formalize two compatible guidelines and extract such a model:
- **G1**: "Informed consent must be obtained" -- Box(consent)
- **G2**: "Thrombolytic therapy may be administered" -- Diamond(thrombolytic)
"""

# ╔═╡ 9a1b3c4d-0005-0005-0005-000000000005
begin
	consent = Atom(:consent)
	thrombolytic = Atom(:thrombolytic)
	blood_cultures = Atom(:blood_cultures)
	discharge_plan = Atom(:discharge_plan)
	active_bleeding = Atom(:active_bleeding)

	# Formalize G1 and G2
	g1 = Box(consent)
	g2 = Diamond(thrombolytic)

	# Build a tableau for consistency: assume both true at root
	root = Prefix([1])
	formulas_g1g2 = [pf_true(root, g1), pf_true(root, g2)]
	t_g1g2 = build_tableau(formulas_g1g2, TABLEAU_KD)
	t_g1g2
end

# ╔═╡ 9a1b3c4d-0006-0006-0006-000000000006
begin
	if !is_closed(t_g1g2)
		# Find an open branch and extract the countermodel
		open_branch = first(b for b in t_g1g2.branches if !is_closed(b))
		model_g1g2 = extract_countermodel(open_branch)
		md"""
		**Tableau is open** -- the guidelines are consistent.

		Extracted countermodel: $(model_g1g2)

		**Clinical interpretation**: The countermodel is a concrete scenario (a set of "worlds" representing possible clinical states) in which both guidelines are simultaneously satisfied. Consent is obtained in every accessible state (satisfying the obligation □(consent)), and at least one accessible state includes thrombolytic therapy (satisfying the permission ◇(thrombolytic)).
		"""
	else
		md"Tableau closed -- the guidelines are inconsistent (unexpected for this example)."
	end
end

# ╔═╡ 9a1b3c4d-0021-0021-0021-000000000021
begin
	if !is_closed(t_g1g2)
		open_branch_vis = first(b for b in t_g1g2.branches if !is_closed(b))
		model_vis = extract_countermodel(open_branch_vis)
		visualize_model(model_vis)
	end
end

# ╔═╡ 9a1b3c4d-0007-0007-0007-000000000007
md"""
## Soundness + Completeness Together

The two metalogical properties complement each other:

| Property | Guarantee | Clinical meaning |
|:---------|:----------|:-----------------|
| **Soundness** | If the tableau closes, the formulas are genuinely unsatisfiable | No false conflicts reported -- if the checker says "conflict," there really is one |
| **Completeness** | If the formulas are unsatisfiable, the tableau will close | No real conflicts missed -- if there is a conflict, the checker will find it |

Together: the automated checker is **fully reliable** for the logic it implements. It neither cries wolf nor lets conflicts slip through.
"""

# ╔═╡ 9a1b3c4d-0022-0022-0022-000000000022
md"""
### Exercise: Soundness vs Completeness

For each scenario, identify which metalogical property — soundness or completeness — is violated, and why.

**1.** A CDS checker reports a conflict between two guidelines, but a clinical expert reviews them and finds they are perfectly compatible. The checker flagged a non-existent conflict.

$(Markdown.MD(Markdown.Admonition("hint", "Reveal answer", [md"**Soundness** is violated. Soundness says: if the tableau closes (conflict reported), the formulas must genuinely be unsatisfiable. If the checker flags a non-existent conflict, it closed the tableau on a satisfiable set — a false alarm. A sound system never cries wolf."])))

**2.** A hospital uses a partial checker that only tests for direct negation conflicts (e.g., □p and □¬p). Two guidelines — 'start heparin within 2h' and 'do not start any anticoagulant if platelets < 50k' — are both present, but the checker reports 'no conflict.' A patient with thrombocytopenia is harmed.

$(Markdown.MD(Markdown.Admonition("hint", "Reveal answer", [md"**Completeness** is violated. Completeness says: if the formulas are genuinely unsatisfiable (a real conflict exists), the procedure must detect it. A partial checker that only looks for direct negations will miss conditional conflicts — real contradictions that its limited rule set cannot reach. The hospital's 'all clear' was meaningless."])))

**3.** A checker reports no conflict, and later a clinical informaticist discovers the formalization was wrong — the guideline 'should' was encoded as ◇ (permission) when it should have been □ (obligation).

$(Markdown.MD(Markdown.Admonition("hint", "Reveal answer", [md"**Neither property** is violated — the checker is faithfully reasoning about the formulas it was given. This is the 'garbage in, garbage out' limitation: completeness guarantees correctness with respect to the *logic*, not with respect to the *intended meaning*. The bug is in the encoding, not the proof procedure. This is why human review of formalizations is irreplaceable."])))
"""

# ╔═╡ 9a1b3c4d-0008-0008-0008-000000000008
md"""
### Demonstrating Both Directions

Let's see soundness and completeness in action with conflicting guidelines:
- **G3**: "Thrombolytics must be given" -- Box(thrombolytic)
- **G4**: "Thrombolytics must not be given" -- Box(Not(thrombolytic))
"""

# ╔═╡ 9a1b3c4d-0009-0009-0009-000000000009
begin
	g3 = Box(thrombolytic)
	g4 = Box(Not(thrombolytic))

	# Soundness direction: the tableau closes, and indeed no KD model satisfies both
	conflict_consistent = tableau_consistent(TABLEAU_KD, [g3, g4])

	md"""
	`tableau_consistent(TABLEAU_KD, [Box(thrombolytic), Box(Not(thrombolytic))])` = **$(conflict_consistent)**

	The tableau closes: these guidelines genuinely conflict. By **soundness**, this closure is not a false alarm. By **completeness**, if they had been consistent, the tableau would have remained open.
	"""
end

# ╔═╡ 9a1b3c4d-0010-0010-0010-000000000010
md"""
## Consistency as a Proxy for Clinical Feasibility

Logical consistency means: there exists a model (a possible scenario) where all guidelines can be simultaneously followed. This is a necessary condition for clinical feasibility, but not a sufficient one.

**What consistency captures:**
- No direct contradictions between guideline directives
- No impossible obligation combinations (e.g., "must give X" and "must not give X")
- Conditional compatibility (guidelines that only conflict under certain patient conditions)

**What consistency does NOT capture:**
- Resource constraints (ICU beds, staff availability)
- Timing feasibility (can the sequence actually be performed in time?)
- Patient preferences and shared decision-making
- Probabilistic reasoning (likelihood of outcomes)

However: **inconsistency definitely means infeasibility**. If guidelines are logically contradictory, no amount of resources or clever scheduling can make them all satisfiable. Logical consistency checking is therefore a sound first filter.
"""

# ╔═╡ 9a1b3c4d-0023-0023-0023-000000000023
md"""
### Exercise: Consistency and Feasibility

Consider these three candidate guidelines for a sepsis protocol:

- **GA**: "Blood cultures must be drawn" — □(blood\_cultures)
- **GB**: "Antibiotics may be given" — ◇(antibiotics)
- **GC**: "If the patient has a penicillin allergy, antibiotics must not be given" — penicillin\_allergy → □(¬antibiotics)

**Question 1**: Are GA and GB consistent in KD? Predict whether `tableau_consistent(TABLEAU_KD, [Box(blood_cultures), Diamond(antibiotics)])` returns `true` or `false`, and explain why.

$(Markdown.MD(Markdown.Admonition("hint", "Reveal answer", [md"**true** — consistent. □(blood_cultures) requires cultures in every successor world. ◇(antibiotics) requires antibiotics in at least one successor world. These are compatible: a serial frame can have a successor world where cultures are drawn AND antibiotics are given. The two guidelines impose independent constraints on different atoms."])))

**Question 2**: Now add GC and assume the patient has a penicillin allergy (i.e., treat `penicillin_allergy` as `true` at the root, meaning GB and GC together force a conflict). Are GB and GC jointly consistent in KD when the allergy is present?

$(Markdown.MD(Markdown.Admonition("hint", "Reveal answer", [md"When penicillin_allergy is true, GC simplifies to □(¬antibiotics) — antibiotics must not be given in any successor. But GB = ◇(antibiotics) requires antibiotics in at least one successor. These directly conflict: no successor can simultaneously satisfy antibiotics and ¬antibiotics. `tableau_consistent(TABLEAU_KD, [Diamond(antibiotics), Box(Not(antibiotics))])` returns **false**. This is a conditional conflict: GA, GB, GC are mutually consistent for non-allergic patients, but inconsistent for penicillin-allergic patients."])))

**Question 3**: What does this conflict imply for EHR implementation of the guideline set?

$(Markdown.MD(Markdown.Admonition("hint", "Reveal answer", [md"The EHR must stratify by allergy status: the antibiotic guideline (GB) should be annotated with a pre-condition ¬penicillin_allergy, or an alternative antibiotic guideline must be added for allergic patients. The conflict is not a flaw in the checker — it correctly identified a real gap in the protocol. The fix is in the clinical content, not the logic."])))
"""

# ╔═╡ 9a1b3c4d-0011-0011-0011-000000000011
md"""
## Interactive Example: Guideline Conflict Checker

Select which clinical guidelines to include, then run the tableau to check consistency. If the guidelines are consistent, we extract and display the countermodel.
"""

# ╔═╡ 9a1b3c4d-0012-0012-0012-000000000012
begin
	guideline_options = [
		"Box(consent)" => "G1: Informed consent must be obtained -- Box(consent)",
		"Diamond(thrombolytic)" => "G2: Thrombolytic therapy may be given -- Diamond(thrombolytic)",
		"Box(thrombolytic)" => "G3: Thrombolytics must be given -- Box(thrombolytic)",
		"Box(Not(thrombolytic))" => "G4: Thrombolytics must not be given -- Box(Not(thrombolytic))",
		"Box(blood_cultures)" => "G5: Blood cultures must be drawn -- Box(blood_cultures)",
		"Diamond(discharge_plan)" => "G6: Discharge planning may begin -- Diamond(discharge_plan)",
		"Implies(active_bleeding, Box(Not(thrombolytic)))" => "G7: If bleeding, thrombolytics prohibited -- active_bleeding -> Box(Not(thrombolytic))",
	]
	md"**Select guidelines** (hold Ctrl/Cmd for multiple):"
end

# ╔═╡ 9a1b3c4d-0013-0013-0013-000000000013
@bind selected_keys MultiSelect(guideline_options, default=["Box(consent)", "Diamond(thrombolytic)"])

# ╔═╡ 9a1b3c4d-0014-0014-0014-000000000014
md"**Select the logic** for consistency checking:"

# ╔═╡ 9a1b3c4d-0015-0015-0015-000000000015
@bind selected_logic Select([
	"K" => "K -- basic modal logic (no frame conditions)",
	"KD" => "KD -- deontic logic (serial frames: obligations must be achievable)",
], default="KD")

# ╔═╡ 9a1b3c4d-0016-0016-0016-000000000016
begin
	# Map string keys to actual formulas
	key_to_formula = Dict(
		"Box(consent)" => g1,
		"Diamond(thrombolytic)" => g2,
		"Box(thrombolytic)" => g3,
		"Box(Not(thrombolytic))" => g4,
		"Box(blood_cultures)" => Box(blood_cultures),
		"Diamond(discharge_plan)" => Diamond(discharge_plan),
		"Implies(active_bleeding, Box(Not(thrombolytic)))" => Implies(active_bleeding, Box(Not(thrombolytic))),
	)

	system = selected_logic == "KD" ? TABLEAU_KD : TABLEAU_K

	chosen_formulas = Formula[key_to_formula[k] for k in selected_keys]

	if isempty(chosen_formulas)
		md"*Select at least one guideline above.*"
	else
		# Build the tableau
		pf_assumptions = [pf_true(root, f) for f in chosen_formulas]
		t_interactive = build_tableau(pf_assumptions, system)

		if is_closed(t_interactive)
			md"""
			### Result: CONFLICT DETECTED

			The tableau **closed** -- the selected guidelines are **inconsistent** in $(selected_logic). There is no possible clinical scenario where all of them can be simultaneously satisfied.

			This means:
			- A genuine logical contradiction exists among the selected directives
			- No implementation can faithfully follow all of them at once
			- The conflict must be resolved (e.g., by prioritizing one guideline, adding conditions, or revising)

			Tableau: $(t_interactive)
			"""
		else
			open_br = first(b for b in t_interactive.branches if !is_closed(b))
			countermodel = extract_countermodel(open_br)
			md"""
			### Result: NO CONFLICT

			The tableau **remained open** -- the selected guidelines are **consistent** in $(selected_logic).

			**Countermodel** (a concrete scenario where all guidelines hold):

			$(countermodel)

			By completeness, this is a reliable result: there genuinely exists a way to follow all selected guidelines simultaneously.
			"""
		end
	end
end

# ╔═╡ 9a1b3c4d-0017-0017-0017-000000000017
md"""
## What Completeness Does NOT Guarantee

Completeness is powerful but has clear limits:

1. **Garbage in, garbage out.** Completeness guarantees the checker is faithful to the *logic*, not to the *formalization*. If a guideline is formalized incorrectly (e.g., encoding "should" as Diamond when it should be Box), the checker will faithfully reason about the wrong formulas. Formal verification of the encoding itself remains a human task.

2. **No defeasible reasoning.** Standard modal logic is monotonic: adding more guidelines can only create new conflicts, never resolve existing ones. Real clinical reasoning is often defeasible -- a general rule can be overridden by a more specific one ("give thrombolytics, unless active bleeding"). Nonmonotonic extensions exist but are beyond the scope of basic modal logic.

3. **No probabilities.** The logic deals with *necessity* and *possibility*, not with likelihood. "Thrombolytics reduce 30-day mortality by 2%" cannot be expressed. For probabilistic reasoning about treatment outcomes, different formalisms (decision theory, Bayesian networks) are needed.

4. **Finite model property required.** The completeness result for tableaux relies on the finite model property (Chapter 5). For logics without this property, the tableau procedure may not terminate. The standard systems (K, KD, KT, S4, S5) all have it.
"""

# ╔═╡ 9a1b3c4d-0018-0018-0018-000000000018
md"""
## Comparing K and KD

The choice of logic matters. KD (deontic logic) adds seriality: every world must have at least one accessible successor. This means every obligation must be achievable -- there is always some acceptable scenario.

Let's see how the logic choice affects consistency:
"""

# ╔═╡ 9a1b3c4d-0019-0019-0019-000000000019
begin
	# Box(p) ∧ Box(Not(p)) -- obligatory that p AND obligatory that not-p
	p = Atom(:p)
	absurd_pair = [Box(p), Box(Not(p))]

	k_result = tableau_consistent(TABLEAU_K, absurd_pair)
	kd_result = tableau_consistent(TABLEAU_KD, absurd_pair)

	md"""
	**Box(p) and Box(Not(p))** -- "p is obligatory" and "not-p is obligatory":

	| Logic | Consistent? | Explanation |
	|:------|:------------|:------------|
	| K | **$(k_result)** | In K, a world with no successors vacuously satisfies both -- but that's a dead-end world with no achievable obligations |
	| KD | **$(kd_result)** | In KD, every world must have a successor, so some world must make both p and not-p true -- impossible |

	KD is the appropriate logic for clinical guidelines because it rules out vacuous satisfaction. An obligation is only meaningful if there is some achievable scenario where it holds.
	"""
end

# ╔═╡ 9a1b3c4d-0024-0024-0024-000000000024
md"""
### Exercise: Why K Is Not Enough for Clinical Obligations

In system K, `tableau_consistent(TABLEAU_K, [Box(p), Box(Not(p))])` returns `true`.

**Question 1**: Describe in plain language the Kripke model that witnesses this consistency. What does it look like, and why does it satisfy both □p and □(¬p)?

$(Markdown.MD(Markdown.Admonition("hint", "Reveal answer", [md"The model has a single world w with **no successors** (no accessible worlds). Since □p is vacuously true when there are no successors (there is no counterexample), and □(¬p) is also vacuously true for the same reason, both formulas hold at w. The K-consistent 'model' is a dead-end: no care pathways exist at all."])))

**Question 2**: Why is this witness model clinically unacceptable for guideline reasoning?

$(Markdown.MD(Markdown.Admonition("hint", "Reveal answer", [md"A dead-end world represents a clinical state with no possible next steps — no achievable care pathways. If both 'must give medication X' and 'must not give medication X' are 'satisfied' only because the patient has no possible future states, that is not a resolution of the conflict — it is the absence of any clinical context. Guidelines are meant to direct action toward achievable states. A logic that allows obligations to be vacuously 'satisfied' in dead ends cannot model that purpose. The D axiom (seriality in KD) rules this out by requiring that every clinical state has at least one reachable successor."])))

**Question 3**: The D axiom states □p → ◇p (every obligation implies a corresponding permission — there is always a way to comply). How does this connect to the intuition that 'ought implies can'?

$(Markdown.MD(Markdown.Admonition("hint", "Reveal answer", [md"'Ought implies can' (Kant) says that you are only obligated to do something if it is actually possible to do it. The D axiom encodes exactly this: if □p (you must bring about p), then ◇p (it is possible to bring about p). Seriality guarantees the existence of at least one accessible world, so the obligation is not vacuous. In clinical terms: it is only meaningful to require a clinician to perform an action if that action is actually achievable for the patient. A guideline obligation in KD always has an achievable scenario — it cannot be satisfied in a dead-end world."])))
"""

# ╔═╡ 9a1b3c4d-0020-0020-0020-000000000020
md"""
## Summary

The completeness theorem (B&D Chapter 4, Corollary 4.15 and Theorem 4.16) provides the theoretical foundation for automated guideline validation:

| Concept | Technical meaning | Clinical significance |
|:--------|:-----------------|:---------------------|
| **Soundness** | Closed tableau implies unsatisfiability | No false conflict reports |
| **Completeness** | Unsatisfiable formulas always produce a closed tableau | No missed conflicts |
| **Countermodel extraction** | Open branches yield concrete satisfying models | "Here is how the guidelines can all be followed" |
| **Frame completeness** | Canonical model inherits frame properties from axioms | KD completeness ensures deontic reasoning is reliable |

When we combine soundness and completeness, automated guideline checking becomes a *decision procedure*: given a set of formalized guidelines and a choice of logic, the tableau either closes (conflict) or remains open (consistent, with a witnessing model). The answer is always correct and always terminates (for systems with the finite model property — see Chapter 5 for why KD has this property and Chapter 6 for the full tableau algorithm applied to clinical guideline pairs).

This does not replace clinical judgment -- it augments it. The formalization step requires human expertise, and the logic captures only the structural relationships between guidelines, not resource constraints or patient preferences. But for what it does capture, the completeness theorem guarantees it captures it perfectly.
"""

# ╔═╡ 9a1b3c4d-0025-0025-0025-000000000025
md"""
$(Markdown.MD(Markdown.Admonition("note", "Knowledge Representation Lens", [md"Davis, Shrobe & Szolovits (1993) identify five roles a knowledge representation must play. Role 3 is a **theory of reasoning** — the representation defines which inferences are *sanctioned* (guaranteed correct) versus merely *recommended* (tractable but possibly incomplete). This is precisely what the completeness theorem establishes for modal tableaux. Soundness says the proof procedure sanctions only valid inferences — it never proves a false conflict. Completeness says the sanctioned inferences are *also* the only ones needed — no conflict goes undetected. Together, soundness and completeness mean the tableau is not just a useful heuristic but a *complete theory of reasoning* for the logic: every provable consequence is proved, and nothing unprovable is proved. For clinical guideline validation, this matters because it turns 'no conflict found' from a heuristic observation ('we did not find one') into a logical guarantee ('none exists'). Buchanan (2006) observes that 'making assumptions explicit is valuable, whether or not the system is correct.' Completeness goes further: it guarantees that the explicit assumptions are not just visible but *exhaustively reasoned about*."])))
"""

# ╔═╡ Cell order:
# ╟─9a1b3c4d-0001-0001-0001-000000000001
# ╟─9a1b3c4d-0002-0002-0002-000000000002
# ╟─9a1b3c4d-0003-0003-0003-000000000003
# ╟─9a1b3c4d-0004-0004-0004-000000000004
# ╟─9a1b3c4d-0005-0005-0005-000000000005
# ╟─9a1b3c4d-0006-0006-0006-000000000006
# ╟─9a1b3c4d-0021-0021-0021-000000000021
# ╟─9a1b3c4d-0007-0007-0007-000000000007
# ╟─9a1b3c4d-0022-0022-0022-000000000022
# ╟─9a1b3c4d-0008-0008-0008-000000000008
# ╟─9a1b3c4d-0009-0009-0009-000000000009
# ╟─9a1b3c4d-0010-0010-0010-000000000010
# ╟─9a1b3c4d-0023-0023-0023-000000000023
# ╟─9a1b3c4d-0011-0011-0011-000000000011
# ╟─9a1b3c4d-0012-0012-0012-000000000012
# ╟─9a1b3c4d-0013-0013-0013-000000000013
# ╟─9a1b3c4d-0014-0014-0014-000000000014
# ╟─9a1b3c4d-0015-0015-0015-000000000015
# ╟─9a1b3c4d-0016-0016-0016-000000000016
# ╟─9a1b3c4d-0017-0017-0017-000000000017
# ╟─9a1b3c4d-0018-0018-0018-000000000018
# ╟─9a1b3c4d-0019-0019-0019-000000000019
# ╟─9a1b3c4d-0024-0024-0024-000000000024
# ╟─9a1b3c4d-0020-0020-0020-000000000020
# ╟─9a1b3c4d-0025-0025-0025-000000000025
