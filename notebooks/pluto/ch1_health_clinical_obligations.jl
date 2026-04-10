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

# ╔═╡ 2a1b3c4d-0002-0002-0002-000000000002
begin
	using Pkg
	Pkg.activate(joinpath(@__DIR__, ".."))
	using Gamen
	using PlutoUI
end

# ╔═╡ 2a1b3c4d-0001-0001-0001-000000000001
md"""
# Clinical Obligations and Modal Logic

This notebook parallels [Chapter 1 of Boxes and Diamonds](https://bd.openlogicproject.org) but uses **clinical guideline examples** instead of abstract propositions. It shows how the same modal logic concepts -- formulas, Kripke models, truth, and entailment -- formalize the deontic language of clinical practice guidelines.

**Key insight**: When a guideline says "must," "should," or "may," it is making a *modal* claim about what is obligatory, recommended, or permitted across possible clinical scenarios. Modal logic makes these claims precise.

### Background

Lomotan et al. (2010) found that clinicians interpret deontic terms ("must," "should," "may") with widely varying obligation levels. When EHR systems implement guidelines as clinical decision support, this ambiguity produces inconsistent behavior -- one vendor implements "should" as a hard stop, another as a soft reminder.

Formalizing guidelines in deontic logic resolves this ambiguity.
"""

# ╔═╡ 2a1b3c4d-0003-0003-0003-000000000003
md"""
## From Clinical Language to Modal Logic

Clinical guidelines use three levels of deontic strength:

| Clinical Term | Deontic Meaning | Modal Operator | Gamen.jl |
|:-------------|:----------------|:---------------|:---------|
| "must," "is required" | **Obligation** | $\square p$ (in all acceptable scenarios, $p$ holds) | `Box(p)` |
| "may," "is acceptable" | **Permission** | $\diamond p$ (in some acceptable scenario, $p$ holds) | `Diamond(p)` |
| "must not," "is contraindicated" | **Prohibition** | $\square \lnot p$ (in all acceptable scenarios, $p$ does not hold) | `Box(Not(p))` |

The "worlds" in a Kripke model represent possible clinical scenarios -- different patient states, different treatment decisions, different outcomes. The accessibility relation connects the current state to states that are **deontically acceptable** (compliant with guidelines).
"""

# ╔═╡ 2a1b3c4d-0004-0004-0004-000000000004
md"""
## Formalizing Guidelines as Formulas

Let's formalize five real clinical guidelines. Select a guideline to see its formalization:
"""

# ╔═╡ 2a1b3c4d-0005-0005-0005-000000000005
@bind selected_guideline Select([
	"G1" => "G1: Informed consent must be obtained before any procedure",
	"G2" => "G2: Patients with bacteremia should receive blood cultures before antibiotics",
	"G3" => "G3: Clinicians may use clinical judgment to adjust antibiotic duration",
	"G4" => "G4: Thrombolytics must not be given if the patient has active bleeding",
	"G5" => "G5: Discharge planning should begin within 24 hours of admission",
])

# ╔═╡ 2a1b3c4d-0006-0006-0006-000000000006
begin
	# Define the atomic propositions
	consent = Atom(:consent)
	blood_cultures = Atom(:blood_cultures)
	adjust_duration = Atom(:adjust_duration)
	thrombolytic = Atom(:thrombolytic)
	active_bleeding = Atom(:active_bleeding)
	discharge_plan = Atom(:discharge_plan)

	# Formalize each guideline
	guidelines = Dict(
		"G1" => (
			text = "Informed consent must be obtained before any procedure",
			term = "must",
			type = "obligation",
			formula = Box(consent),
			explanation = """**G1**: "must" → obligation → □(consent)

In all deontically acceptable scenarios, informed consent is obtained.
`Box(consent)` means there is no acceptable world where consent is absent."""
		),
		"G2" => (
			text = "Patients with bacteremia should receive blood cultures before antibiotics",
			term = "should",
			type = "obligation",
			formula = Box(blood_cultures),
			explanation = """**G2**: "should" → obligation → □(blood_cultures)

"Should" is weaker than "must" in clinical language, but both map to obligation (□) in standard deontic logic. The difference in strength could be captured by graded modalities or certainty factors — but in basic modal logic, both are □."""
		),
		"G3" => (
			text = "Clinicians may use clinical judgment to adjust antibiotic duration",
			term = "may",
			type = "permission",
			formula = Diamond(adjust_duration),
			explanation = """**G3**: "may" → permission → ◇(adjust_duration)

In some acceptable scenario, antibiotic duration is adjusted.
`Diamond(adjust_duration)` means adjusting is *permitted* — there exists at least one acceptable world where it happens. It is neither required nor prohibited."""
		),
		"G4" => (
			text = "Thrombolytics must not be given if the patient has active bleeding",
			term = "must not",
			type = "conditional prohibition",
			formula = Implies(active_bleeding, Box(Not(thrombolytic))),
			explanation = """**G4**: "must not ... if" → conditional prohibition → active_bleeding → □(¬thrombolytic)

This is an *implication*: IF active bleeding THEN it is obligatory that thrombolytics are not given. If there is no active bleeding, the prohibition does not apply.

Note: this is `Implies(active_bleeding, Box(Not(thrombolytic)))` — the condition scopes outside the modal operator."""
		),
		"G5" => (
			text = "Discharge planning should begin within 24 hours of admission",
			term = "should",
			type = "obligation",
			formula = Box(discharge_plan),
			explanation = """**G5**: "should" → obligation → □(discharge_plan)

The temporal constraint ("within 24 hours") cannot be captured in basic modal logic — it requires temporal operators (Chapter 14). For now, we formalize just the deontic content: discharge planning is obligatory."""
		),
	)

	g = guidelines[selected_guideline]
	Markdown.parse(g.explanation)
end

# ╔═╡ 2a1b3c4d-0007-0007-0007-000000000007
md"""
### The Formula

Here is the formal representation:
"""

# ╔═╡ 2a1b3c4d-0008-0008-0008-000000000008
g.formula

# ╔═╡ 2a1b3c4d-0009-0009-0009-000000000009
md"""
## A Clinical Kripke Model

Let's build a Kripke model for a clinical scenario. The **worlds** represent possible states of a patient encounter, and the **accessibility relation** connects the current state to deontically acceptable next states.

### Scenario: Emergency Department patient with chest pain

- **w1**: Patient arrives with chest pain (current state)
- **w2**: Acceptable pathway — consent obtained, blood cultures drawn, discharge planned
- **w3**: Acceptable pathway — consent obtained, thrombolytics given (no active bleeding)
- **w4**: Unacceptable state — thrombolytics given despite active bleeding
"""

# ╔═╡ 2a1b3c4d-0010-0010-0010-000000000010
begin
	clinical_frame = KripkeFrame(
		[:w1, :w2, :w3, :w4],
		[
			:w1 => :w2,  # w1 can reach w2 (acceptable)
			:w1 => :w3,  # w1 can reach w3 (acceptable)
			# w4 is NOT accessible from w1 — it's not an acceptable scenario
		]
	)

	clinical_model = KripkeModel(clinical_frame, [
		:consent         => [:w2, :w3],      # consent obtained in acceptable worlds
		:blood_cultures  => [:w2],            # blood cultures in w2
		:thrombolytic    => [:w3, :w4],       # thrombolytics given in w3 and w4
		:active_bleeding => [:w4],            # active bleeding only in w4
		:discharge_plan  => [:w2],            # discharge plan in w2
	])
end

# ╔═╡ 2a1b3c4d-0011-0011-0011-000000000011
md"""
### Evaluating Guidelines in the Model

Let's check which guidelines are satisfied at the current state (w1):
"""

# ╔═╡ 2a1b3c4d-0012-0012-0012-000000000012
begin
	eval_results = [
		"G1: □(consent) — must obtain consent" =>
			satisfies(clinical_model, :w1, Box(consent)),
		"G2: □(blood_cultures) — should draw cultures" =>
			satisfies(clinical_model, :w1, Box(blood_cultures)),
		"G3: ◇(adjust_duration) — may adjust" =>
			satisfies(clinical_model, :w1, Diamond(adjust_duration)),
		"G4: bleeding → □(¬thrombolytic)" =>
			satisfies(clinical_model, :w1,
				Implies(active_bleeding, Box(Not(thrombolytic)))),
		"G5: □(discharge_plan) — should plan discharge" =>
			satisfies(clinical_model, :w1, Box(discharge_plan)),
	]
end

# ╔═╡ 2a1b3c4d-0013-0013-0013-000000000013
md"""
### Interpreting the Results

- **G1 (consent): true** — consent is obtained in both accessible worlds (w2, w3)
- **G2 (blood cultures): false** — blood cultures are drawn in w2 but not w3. Since □ requires truth in *all* accessible worlds, the obligation is violated.
- **G3 (adjust duration): false** — adjusting duration doesn't happen in any accessible world. Permission (◇) requires truth in *at least one* accessible world.
- **G4 (conditional prohibition): true** — at w1, active bleeding is false, so the implication is vacuously true. The prohibition only applies when the condition holds.
- **G5 (discharge plan): false** — discharge planning happens in w2 but not w3.

This illustrates a key insight: **a model satisfying all guidelines simultaneously requires every accessible world to comply with every obligation**. Clinical reality is that different pathways satisfy different guidelines — which is why consistency checking matters.
"""

# ╔═╡ 2a1b3c4d-0014-0014-0014-000000000014
md"""
## Exploring Deontic Concepts

### Obligation vs Permission (□ vs ◇)

A core concept from B&D Chapter 1: □ and ◇ are *duals*.

In clinical terms:
- "It is obligatory to obtain consent" = "It is not permitted to skip consent"
- □(consent) ≡ ¬◇(¬consent)

Let's verify this duality holds at every world:
"""

# ╔═╡ 2a1b3c4d-0015-0015-0015-000000000015
begin
	duality_check = []
	for w in [:w1, :w2, :w3, :w4]
		box_way = satisfies(clinical_model, w, Box(consent))
		diamond_way = !satisfies(clinical_model, w, Diamond(Not(consent)))
		push!(duality_check,
			"$w: □(consent)=$box_way, ¬◇(¬consent)=$diamond_way, equal=$(box_way == diamond_way)")
	end
	duality_check
end

# ╔═╡ 2a1b3c4d-0016-0016-0016-000000000016
md"""
### Vacuous Truth and Dead-End Worlds

At worlds with no accessible successors (w2, w3, w4 in our model), **every obligation is vacuously true**:
"""

# ╔═╡ 2a1b3c4d-0017-0017-0017-000000000017
begin
	# An absurd obligation — vacuously true at dead-end worlds
	absurd = Box(And(consent, Not(consent)))  # □(consent ∧ ¬consent)

	vacuous_results = [
		"w1 (has successors): □(consent ∧ ¬consent) = " *
			string(satisfies(clinical_model, :w1, absurd)),
		"w2 (dead end): □(consent ∧ ¬consent) = " *
			string(satisfies(clinical_model, :w2, absurd)),
		"w3 (dead end): □(consent ∧ ¬consent) = " *
			string(satisfies(clinical_model, :w3, absurd)),
	]
end

# ╔═╡ 2a1b3c4d-0018-0018-0018-000000000018
md"""
This is a well-known feature of standard deontic logic: at a world with no acceptable alternatives, *everything* is obligatory (even contradictions). This is related to the problem of **moral dilemmas** and is one reason why the **D axiom** (□p → ◇p: if something is obligatory, it must be permitted) is important for deontic reasoning — it rules out dead-end worlds. We'll explore this in Chapter 3.
"""

# ╔═╡ 2a1b3c4d-0019-0019-0019-000000000019
md"""
## Interactive Exploration: Build Your Own Scenario

### Choose which clinical facts hold at each world:
"""

# ╔═╡ 2a1b3c4d-0020-0020-0020-000000000020
md"""
**World w2 (acceptable pathway A):**
"""

# ╔═╡ 2a1b3c4d-0021-0021-0021-000000000021
begin
	@bind w2_consent CheckBox(default=true)
	md"Consent obtained: $(@bind w2_consent CheckBox(default=true))"
end

# ╔═╡ 2a1b3c4d-0022-0022-0022-000000000022
md"Blood cultures drawn: $(@bind w2_cultures CheckBox(default=true))"

# ╔═╡ 2a1b3c4d-0023-0023-0023-000000000023
md"Thrombolytics given: $(@bind w2_thrombo CheckBox(default=false))"

# ╔═╡ 2a1b3c4d-0024-0024-0024-000000000024
md"""
**World w3 (acceptable pathway B):**
"""

# ╔═╡ 2a1b3c4d-0025-0025-0025-000000000025
md"Consent obtained: $(@bind w3_consent CheckBox(default=true))"

# ╔═╡ 2a1b3c4d-0026-0026-0026-000000000026
md"Blood cultures drawn: $(@bind w3_cultures CheckBox(default=false))"

# ╔═╡ 2a1b3c4d-0027-0027-0027-000000000027
md"Thrombolytics given: $(@bind w3_thrombo CheckBox(default=true))"

# ╔═╡ 2a1b3c4d-0028-0028-0028-000000000028
begin
	# Build the interactive model from checkbox states
	interactive_frame = KripkeFrame([:w1, :w2, :w3], [:w1 => :w2, :w1 => :w3])

	val_consent = Symbol[]
	val_cultures = Symbol[]
	val_thrombo = Symbol[]

	w2_consent   && push!(val_consent, :w2)
	w3_consent   && push!(val_consent, :w3)
	w2_cultures  && push!(val_cultures, :w2)
	w3_cultures  && push!(val_cultures, :w3)
	w2_thrombo   && push!(val_thrombo, :w2)
	w3_thrombo   && push!(val_thrombo, :w3)

	interactive_model = KripkeModel(interactive_frame, [
		:consent        => val_consent,
		:blood_cultures => val_cultures,
		:thrombolytic   => val_thrombo,
	])

	md"""
	### Guideline Compliance at w1

	| Guideline | Formula | Satisfied? |
	|:----------|:--------|:-----------|
	| G1: Must obtain consent | □(consent) | **$(satisfies(interactive_model, :w1, Box(consent)))** |
	| G2: Should draw cultures | □(blood\_cultures) | **$(satisfies(interactive_model, :w1, Box(blood_cultures)))** |
	| G3: May give thrombolytics | ◇(thrombolytic) | **$(satisfies(interactive_model, :w1, Diamond(thrombolytic)))** |
	| All obligations met | □(consent) ∧ □(blood\_cultures) | **$(satisfies(interactive_model, :w1, And(Box(consent), Box(blood_cultures))))** |

	Toggle the checkboxes above and watch the results update. Notice:
	- **Obligations (□)** require the fact to hold in *both* w2 and w3
	- **Permissions (◇)** only need the fact in *at least one* world
	- To satisfy all obligations, every acceptable pathway must comply
	"""
end

# ╔═╡ 2a1b3c4d-0029-0029-0029-000000000029
md"""
## Guideline Conflicts

When two guidelines apply to the same patient, they may **conflict**. Consider:

- **G5**: "Discharge planning should begin within 24 hours" → □(discharge\_plan)
- **G6**: "Discharge planning must not begin until cultures are finalized" → □(¬discharge\_plan)

These are jointly unsatisfiable: no world can have both discharge\_plan and ¬discharge\_plan.
"""

# ╔═╡ 2a1b3c4d-0030-0030-0030-000000000030
begin
	g5 = Box(discharge_plan)
	g6 = Box(Not(discharge_plan))

	# Can any model satisfy both at the same world?
	# Build a model and check:
	conflict_frame = KripkeFrame([:w1, :w2], [:w1 => :w2])

	# Try with discharge_plan true at w2:
	model_dp_true = KripkeModel(conflict_frame, [:discharge_plan => [:w2]])
	# Try with discharge_plan false at w2:
	model_dp_false = KripkeModel(conflict_frame, [:discharge_plan => Symbol[]])

	md"""
	### Testing both valuations:

	**If discharge\_plan is true at w2:**
	- G5: □(discharge\_plan) = $(satisfies(model_dp_true, :w1, g5))
	- G6: □(¬discharge\_plan) = $(satisfies(model_dp_true, :w1, g6))

	**If discharge\_plan is false at w2:**
	- G5: □(discharge\_plan) = $(satisfies(model_dp_false, :w1, g5))
	- G6: □(¬discharge\_plan) = $(satisfies(model_dp_false, :w1, g6))

	No matter what, one guideline is violated. This is a **genuine conflict** — the guidelines cannot both be followed. In Chapter 6, we'll see how the tableau prover detects this automatically.
	"""
end

# ╔═╡ 2a1b3c4d-0031-0031-0031-000000000031
md"""
### Conditional Conflicts are Subtler

Now consider G4 + G7:

- **G4**: "Thrombolytics must not be given if active bleeding" → active\_bleeding → □(¬thrombolytic)
- **G7**: "Patients with STEMI must receive thrombolytics" → □(thrombolytic)

Are these inconsistent?
"""

# ╔═╡ 2a1b3c4d-0032-0032-0032-000000000032
begin
	g4_formula = Implies(active_bleeding, Box(Not(thrombolytic)))
	g7_formula = Box(thrombolytic)

	# Model where active_bleeding is FALSE — both can be satisfied
	ok_frame = KripkeFrame([:w1, :w2], [:w1 => :w2])
	ok_model = KripkeModel(ok_frame, [
		:thrombolytic    => [:w2],
		:active_bleeding => Symbol[],  # no active bleeding
	])

	md"""
	**When active\_bleeding is false** (patient has STEMI but no bleeding):
	- G4: $(satisfies(ok_model, :w1, g4_formula)) — the condition is false, so the implication holds
	- G7: $(satisfies(ok_model, :w1, g7_formula)) — thrombolytics are given

	**Both satisfied!** The guidelines are **consistent** — they only conflict for patients who have *both* STEMI and active bleeding. This is exactly the kind of conditional consistency that formal logic can detect and that informal review often misses.
	"""
end

# ╔═╡ 2a1b3c4d-0033-0033-0033-000000000033
md"""
## Summary

| B&D Concept | Clinical Interpretation |
|:-----------|:----------------------|
| Formula | A clinical recommendation or condition |
| □A (Box) | "A is obligatory" / "must" / "is required" |
| ◇A (Diamond) | "A is permitted" / "may" / "is acceptable" |
| □¬A | "A is prohibited" / "must not" |
| A → □B | "If condition A, then B is obligatory" |
| Kripke world | A possible clinical scenario |
| Accessibility relation | "deontically acceptable" transitions |
| M, w ⊩ A | Guideline A is satisfied in scenario w |
| M ⊩ A | Guideline A is satisfied in all scenarios |

### What's Next

- **Chapter 2** (Frame Definability): Why frame properties like *seriality* matter — the D axiom (□p → ◇p) ensures obligations are achievable
- **Chapter 3** (Axiomatic Derivations): KD as the logic of clinical guidelines
- **Chapter 6** (Tableaux): Automated conflict detection — let the computer find guideline inconsistencies
- **Chapter 14** (Temporal Logic): Formalizing "before," "after," "within 7 days"
"""

# ╔═╡ Cell order:
# ╟─2a1b3c4d-0001-0001-0001-000000000001
# ╠═2a1b3c4d-0002-0002-0002-000000000002
# ╟─2a1b3c4d-0003-0003-0003-000000000003
# ╟─2a1b3c4d-0004-0004-0004-000000000004
# ╠═2a1b3c4d-0005-0005-0005-000000000005
# ╠═2a1b3c4d-0006-0006-0006-000000000006
# ╟─2a1b3c4d-0007-0007-0007-000000000007
# ╠═2a1b3c4d-0008-0008-0008-000000000008
# ╟─2a1b3c4d-0009-0009-0009-000000000009
# ╠═2a1b3c4d-0010-0010-0010-000000000010
# ╟─2a1b3c4d-0011-0011-0011-000000000011
# ╠═2a1b3c4d-0012-0012-0012-000000000012
# ╟─2a1b3c4d-0013-0013-0013-000000000013
# ╟─2a1b3c4d-0014-0014-0014-000000000014
# ╠═2a1b3c4d-0015-0015-0015-000000000015
# ╟─2a1b3c4d-0016-0016-0016-000000000016
# ╠═2a1b3c4d-0017-0017-0017-000000000017
# ╟─2a1b3c4d-0018-0018-0018-000000000018
# ╟─2a1b3c4d-0019-0019-0019-000000000019
# ╟─2a1b3c4d-0020-0020-0020-000000000020
# ╠═2a1b3c4d-0021-0021-0021-000000000021
# ╠═2a1b3c4d-0022-0022-0022-000000000022
# ╠═2a1b3c4d-0023-0023-0023-000000000023
# ╟─2a1b3c4d-0024-0024-0024-000000000024
# ╠═2a1b3c4d-0025-0025-0025-000000000025
# ╠═2a1b3c4d-0026-0026-0026-000000000026
# ╠═2a1b3c4d-0027-0027-0027-000000000027
# ╠═2a1b3c4d-0028-0028-0028-000000000028
# ╟─2a1b3c4d-0029-0029-0029-000000000029
# ╠═2a1b3c4d-0030-0030-0030-000000000030
# ╟─2a1b3c4d-0031-0031-0031-000000000031
# ╠═2a1b3c4d-0032-0032-0032-000000000032
# ╟─2a1b3c4d-0033-0033-0033-000000000033
