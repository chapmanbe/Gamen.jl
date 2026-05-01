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

# ╔═╡ 00000000-0000-0000-0000-000000000001
PLUTO_PROJECT_TOML_CONTENTS = """
[deps]
Gamen = "d58aead4-12fe-4bc4-9bd9-a7dede724567"
PlutoUI = "7f904dfe-b85e-4ff6-b463-dae2292396a8"

[compat]
Gamen = "~0.1.0"
PlutoUI = "~0.7.80"
"""

# ╔═╡ 00000000-0000-0000-0000-000000000002
PLUTO_MANIFEST_TOML_CONTENTS = """
# This file is machine-generated - editing it directly is not advised

julia_version = "1.12.4"
manifest_format = "2.0"
project_hash = "6a4c9e740b5c926909fc9b90cccb5fb962b93203"

[[deps.AbstractPlutoDingetjes]]
deps = ["Pkg"]
git-tree-sha1 = "6e1d2a35f2f90a4bc7c2ed98079b2ba09c35b83a"
uuid = "6e696c72-6542-2067-7265-42206c756150"
version = "1.3.2"

[[deps.ArgTools]]
uuid = "0dad84c5-d112-42e6-8d28-ef12dabb789f"
version = "1.1.2"

[[deps.Artifacts]]
uuid = "56f22d72-fd6d-98f1-02f0-08ddc0907c33"
version = "1.11.0"

[[deps.Base64]]
uuid = "2a0f44e3-6c83-55bd-87e4-b1978d98bd5f"
version = "1.11.0"

[[deps.ColorTypes]]
deps = ["FixedPointNumbers", "Random"]
git-tree-sha1 = "67e11ee83a43eb71ddc950302c53bf33f0690dfe"
uuid = "3da002f7-5984-5a60-b8a6-cbb66c0b333f"
version = "0.12.1"
weakdeps = ["StyledStrings"]

    [deps.ColorTypes.extensions]
    StyledStringsExt = "StyledStrings"

[[deps.CompilerSupportLibraries_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "e66e0078-7015-5450-92f7-15fbd957f2ae"
version = "1.3.0+1"

[[deps.Dates]]
deps = ["Printf"]
uuid = "ade2ca70-3891-5945-98fb-dc099432e06a"
version = "1.11.0"

[[deps.Downloads]]
deps = ["ArgTools", "FileWatching", "LibCURL", "NetworkOptions"]
uuid = "f43a241f-c20a-4ad4-852c-f6b1247861c6"
version = "1.7.0"

[[deps.FileWatching]]
uuid = "7b1f6079-737a-58dc-b8bc-7a2ca5c1b5ee"
version = "1.11.0"

[[deps.FixedPointNumbers]]
deps = ["Statistics"]
git-tree-sha1 = "05882d6995ae5c12bb5f36dd2ed3f61c98cbb172"
uuid = "53c48c17-4a7d-5ca2-90c5-79b7896eea93"
version = "0.8.5"

[[deps.Gamen]]
git-tree-sha1 = "774cbe7d92f726eeea0195227ee7d917d5e3907d"
uuid = "d58aead4-12fe-4bc4-9bd9-a7dede724567"
version = "0.1.0"

    [deps.Gamen.extensions]
    GamenMakieExt = ["CairoMakie", "GraphMakie", "Graphs"]

    [deps.Gamen.weakdeps]
    CairoMakie = "13f3f980-e62b-5c42-98c6-ff1f3baf88f0"
    GraphMakie = "1ecd5474-83a3-4783-bb4f-06765db800d2"
    Graphs = "86223c79-3864-5bf0-83f7-82e725a168b6"

[[deps.Hyperscript]]
deps = ["Test"]
git-tree-sha1 = "179267cfa5e712760cd43dcae385d7ea90cc25a4"
uuid = "47d2ed2b-36de-50cf-bf87-49c2cf4b8b91"
version = "0.0.5"

[[deps.HypertextLiteral]]
deps = ["Tricks"]
git-tree-sha1 = "d1a86724f81bcd184a38fd284ce183ec067d71a0"
uuid = "ac1192a8-f4b3-4bfe-ba22-af5b92cd3ab2"
version = "1.0.0"

[[deps.IOCapture]]
deps = ["Logging", "Random"]
git-tree-sha1 = "0ee181ec08df7d7c911901ea38baf16f755114dc"
uuid = "b5f81e59-6552-4d32-b1f0-c071b021bf89"
version = "1.0.0"

[[deps.InteractiveUtils]]
deps = ["Markdown"]
uuid = "b77e0a4c-d291-57a0-90e8-8db25a27a240"
version = "1.11.0"

[[deps.JuliaSyntaxHighlighting]]
deps = ["StyledStrings"]
uuid = "ac6e5ff7-fb65-4e79-a425-ec3bc9c03011"
version = "1.12.0"

[[deps.LibCURL]]
deps = ["LibCURL_jll", "MozillaCACerts_jll"]
uuid = "b27032c2-a3e7-50c8-80cd-2d36dbcbfd21"
version = "0.6.4"

[[deps.LibCURL_jll]]
deps = ["Artifacts", "LibSSH2_jll", "Libdl", "OpenSSL_jll", "Zlib_jll", "nghttp2_jll"]
uuid = "deac9b47-8bc7-5906-a0fe-35ac56dc84c0"
version = "8.15.0+0"

[[deps.LibGit2]]
deps = ["LibGit2_jll", "NetworkOptions", "Printf", "SHA"]
uuid = "76f85450-5226-5b5a-8eaa-529ad045b433"
version = "1.11.0"

[[deps.LibGit2_jll]]
deps = ["Artifacts", "LibSSH2_jll", "Libdl", "OpenSSL_jll"]
uuid = "e37daf67-58a4-590a-8e99-b0245dd2ffc5"
version = "1.9.0+0"

[[deps.LibSSH2_jll]]
deps = ["Artifacts", "Libdl", "OpenSSL_jll"]
uuid = "29816b5a-b9ab-546f-933c-edad1886dfa8"
version = "1.11.3+1"

[[deps.Libdl]]
uuid = "8f399da3-3557-5675-b5ff-fb832c97cbdb"
version = "1.11.0"

[[deps.LinearAlgebra]]
deps = ["Libdl", "OpenBLAS_jll", "libblastrampoline_jll"]
uuid = "37e2e46d-f89d-539d-b4ee-838fcccc9c8e"
version = "1.12.0"

[[deps.Logging]]
uuid = "56ddb016-857b-54e1-b83d-db4d58db5568"
version = "1.11.0"

[[deps.MIMEs]]
git-tree-sha1 = "c64d943587f7187e751162b3b84445bbbd79f691"
uuid = "6c6e2e6c-3030-632d-7369-2d6c69616d65"
version = "1.1.0"

[[deps.Markdown]]
deps = ["Base64", "JuliaSyntaxHighlighting", "StyledStrings"]
uuid = "d6f4376e-aef5-505a-96c1-9c027394607a"
version = "1.11.0"

[[deps.MozillaCACerts_jll]]
uuid = "14a3606d-f60d-562e-9121-12d972cd8159"
version = "2025.11.4"

[[deps.NetworkOptions]]
uuid = "ca575930-c2e3-43a9-ace4-1e988b2c1908"
version = "1.3.0"

[[deps.OpenBLAS_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "Libdl"]
uuid = "4536629a-c528-5b80-bd46-f80d51c5b363"
version = "0.3.29+0"

[[deps.OpenSSL_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "458c3c95-2e84-50aa-8efc-19380b2a3a95"
version = "3.5.4+0"

[[deps.Pkg]]
deps = ["Artifacts", "Dates", "Downloads", "FileWatching", "LibGit2", "Libdl", "Logging", "Markdown", "Printf", "Random", "SHA", "TOML", "Tar", "UUIDs", "p7zip_jll"]
uuid = "44cfe95a-1eb2-52ea-b672-e2afdf69b78f"
version = "1.12.1"

    [deps.Pkg.extensions]
    REPLExt = "REPL"

    [deps.Pkg.weakdeps]
    REPL = "3fa0cd96-eef1-5676-8a61-b3b8758bbffb"

[[deps.PlutoUI]]
deps = ["AbstractPlutoDingetjes", "Base64", "ColorTypes", "Dates", "Downloads", "FixedPointNumbers", "Hyperscript", "HypertextLiteral", "IOCapture", "InteractiveUtils", "Logging", "MIMEs", "Markdown", "Random", "Reexport", "URIs", "UUIDs"]
git-tree-sha1 = "fbc875044d82c113a9dee6fc14e16cf01fd48872"
uuid = "7f904dfe-b85e-4ff6-b463-dae2292396a8"
version = "0.7.80"

[[deps.Printf]]
deps = ["Unicode"]
uuid = "de0858da-6303-5e67-8744-51eddeeeb8d7"
version = "1.11.0"

[[deps.Random]]
deps = ["SHA"]
uuid = "9a3f8284-a2c9-5f02-9a11-845980a1fd5c"
version = "1.11.0"

[[deps.Reexport]]
git-tree-sha1 = "45e428421666073eab6f2da5c9d310d99bb12f9b"
uuid = "189a3867-3050-52da-a836-e630ba90ab69"
version = "1.2.2"

[[deps.SHA]]
uuid = "ea8e919c-243c-51af-8825-aaa63cd721ce"
version = "0.7.0"

[[deps.Serialization]]
uuid = "9e88b42a-f829-5b0c-bbe9-9e923198166b"
version = "1.11.0"

[[deps.Statistics]]
deps = ["LinearAlgebra"]
git-tree-sha1 = "ae3bb1eb3bba077cd276bc5cfc337cc65c3075c0"
uuid = "10745b16-79ce-11e8-11f9-7d13ad32a3b2"
version = "1.11.1"

    [deps.Statistics.extensions]
    SparseArraysExt = ["SparseArrays"]

    [deps.Statistics.weakdeps]
    SparseArrays = "2f01184e-e22b-5df5-ae63-d93ebab69eaf"

[[deps.StyledStrings]]
uuid = "f489334b-da3d-4c2e-b8f0-e476e12c162b"
version = "1.11.0"

[[deps.TOML]]
deps = ["Dates"]
uuid = "fa267f1f-6049-4f14-aa54-33bafae1ed76"
version = "1.0.3"

[[deps.Tar]]
deps = ["ArgTools", "SHA"]
uuid = "a4e569a6-e804-4fa4-b0f3-eef7a1d5b13e"
version = "1.10.0"

[[deps.Test]]
deps = ["InteractiveUtils", "Logging", "Random", "Serialization"]
uuid = "8dfed614-e22c-5e08-85e1-65c5234f0b40"
version = "1.11.0"

[[deps.Tricks]]
git-tree-sha1 = "311349fd1c93a31f783f977a71e8b062a57d4101"
uuid = "410a4b4d-49e4-4fbc-ab6d-cb71b17b3775"
version = "0.1.13"

[[deps.URIs]]
git-tree-sha1 = "bef26fb046d031353ef97a82e3fdb6afe7f21b1a"
uuid = "5c2747f8-b7ea-4ff2-ba2e-563bfd36b1d4"
version = "1.6.1"

[[deps.UUIDs]]
deps = ["Random", "SHA"]
uuid = "cf7118a7-6976-5b1a-9a39-7adc72f591a4"
version = "1.11.0"

[[deps.Unicode]]
uuid = "4ec0a83e-493e-50e2-b9ac-8f72acf5a8f5"
version = "1.11.0"

[[deps.Zlib_jll]]
deps = ["Libdl"]
uuid = "83775a58-1f1d-513f-b197-d71354ab007a"
version = "1.3.1+2"

[[deps.libblastrampoline_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "8e850b90-86db-534c-a0d3-1478176c7d93"
version = "5.15.0+0"

[[deps.nghttp2_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "8e850ede-7688-5339-a07c-302acd2aaf8d"
version = "1.64.0+1"

[[deps.p7zip_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "Libdl"]
uuid = "3f19e933-33d8-53b3-aaab-bd5110c3b7a0"
version = "17.7.0+0"
"""

# ╔═╡ Cell order:
# ╟─2a1b3c4d-0001-0001-0001-000000000001
# ╟─2a1b3c4d-0002-0002-0002-000000000002
# ╟─2a1b3c4d-0003-0003-0003-000000000003
# ╟─2a1b3c4d-0004-0004-0004-000000000004
# ╟─2a1b3c4d-0005-0005-0005-000000000005
# ╟─2a1b3c4d-0006-0006-0006-000000000006
# ╟─2a1b3c4d-0007-0007-0007-000000000007
# ╟─2a1b3c4d-0008-0008-0008-000000000008
# ╟─2a1b3c4d-0009-0009-0009-000000000009
# ╟─2a1b3c4d-0010-0010-0010-000000000010
# ╟─2a1b3c4d-0011-0011-0011-000000000011
# ╟─2a1b3c4d-0012-0012-0012-000000000012
# ╟─2a1b3c4d-0013-0013-0013-000000000013
# ╟─2a1b3c4d-0014-0014-0014-000000000014
# ╟─2a1b3c4d-0015-0015-0015-000000000015
# ╟─2a1b3c4d-0016-0016-0016-000000000016
# ╟─2a1b3c4d-0017-0017-0017-000000000017
# ╟─2a1b3c4d-0018-0018-0018-000000000018
# ╟─2a1b3c4d-0019-0019-0019-000000000019
# ╟─2a1b3c4d-0020-0020-0020-000000000020
# ╟─2a1b3c4d-0021-0021-0021-000000000021
# ╟─2a1b3c4d-0022-0022-0022-000000000022
# ╟─2a1b3c4d-0023-0023-0023-000000000023
# ╟─2a1b3c4d-0024-0024-0024-000000000024
# ╟─2a1b3c4d-0025-0025-0025-000000000025
# ╟─2a1b3c4d-0026-0026-0026-000000000026
# ╟─2a1b3c4d-0027-0027-0027-000000000027
# ╟─2a1b3c4d-0028-0028-0028-000000000028
# ╟─2a1b3c4d-0029-0029-0029-000000000029
# ╟─2a1b3c4d-0030-0030-0030-000000000030
# ╟─2a1b3c4d-0031-0031-0031-000000000031
# ╟─2a1b3c4d-0032-0032-0032-000000000032
# ╟─2a1b3c4d-0033-0033-0033-000000000033
# ╟─00000000-0000-0000-0000-000000000001
# ╟─00000000-0000-0000-0000-000000000002
