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

# ╔═╡ 6a1b3c4d-0001-0001-0001-000000000001
begin
	using Pkg
	Pkg.activate(joinpath(@__DIR__, ".."))
	using Gamen
	using PlutoUI
end

# ╔═╡ 6a1b3c4d-0002-0002-0002-000000000002
md"""
# Automated Clinical Guideline Conflict Detection

This notebook is the culmination of the teaching sequence. It brings together everything from:

- **Ch 1** — formulas, Kripke models, truth at a world
- **Ch 6** — tableau-based automated proving and consistency checking
- **Ch 14** — temporal operators (G, F) for "always" and "eventually"
- **Deontic-temporal logic** — the combined system TABLEAU\_KDt

We apply the combined deontic-temporal tableau system to a problem of real clinical significance: **automated detection of conflicts between clinical practice guidelines**.

### The Problem

When multiple clinical guidelines apply to the same patient, they may issue contradictory directives. A patient presenting with both **STEMI and active bleeding** faces contradictory obligations about thrombolytics: one guideline mandates them, another prohibits them. A patient needing **discharge planning** may face temporal conflicts about when to begin. These conflicts are not hypothetical — they arise routinely in complex patients and can cause harm when embedded in clinical decision support systems without formal checking.

### Why Formal Logic?

Lomotan et al. (2010) found that clinicians interpret deontic terms ("must," "should," "may") with widely varying obligation levels. When EHR systems implement guidelines as clinical decision support, this ambiguity produces inconsistent behavior. One vendor implements "should" as a hard stop, another as a soft reminder.

Formalizing guidelines in deontic-temporal logic and running automated consistency checks resolves this ambiguity and detects conflicts *before* they reach patient care.
"""

# ╔═╡ 6a1b3c4d-0003-0003-0003-000000000003
md"""
## 1. Formalizing Real Guidelines

We draw on five guidelines from our guideline-validation dataset. Each is a real clinical directive translated step by step into modal logic.

The key mapping:
- **"must" / "is required"** --> obligation --> `Box(p)` (in all acceptable scenarios, p holds)
- **"must not" / "is contraindicated"** --> prohibition --> `Box(Not(p))`
- **"always"** --> temporal persistence --> `FutureBox(p)` (at every future time)
- **"eventually"** --> temporal liveness --> `FutureDiamond(p)` (at some future time)

Combined deontic-temporal formulas nest these: "must always reassess" becomes `FutureBox(Box(p))` -- at every future time, it is obligatory to reassess.
"""

# ╔═╡ 6a1b3c4d-0004-0004-0004-000000000004
begin
	# ── G1: "Informed consent must be obtained" ──
	# "must" → obligation → □(consent)
	# In all deontically acceptable scenarios, consent is obtained.
	g1 = Box(Atom(:consent))

	# ── G4: "Thrombolytics must not be given if active bleeding" ──
	# "must not ... if" → conditional prohibition → bleeding → □(¬thrombolytic)
	# The prohibition scopes inside the condition.
	g4 = Implies(Atom(:active_bleeding), Box(Not(Atom(:thrombolytic))))

	# ── G7: "STEMI patients must receive thrombolytics" ──
	# "must" → obligation → □(thrombolytic)
	g7 = Box(Atom(:thrombolytic))

	# ── T1: "Statin therapy must always be reassessed" ──
	# "must always" → temporal-deontic → 𝐆(□(statin_reassessment))
	# At every future time, reassessment is obligatory.
	t1 = FutureBox(Box(Atom(:statin_reassessment)))

	# ── T2: "Antibiotics must eventually be de-escalated" ──
	# "must eventually" → deontic-temporal → □(𝐅(deescalate_antibiotics))
	# It is obligatory that de-escalation eventually happens.
	t2 = Box(FutureDiamond(Atom(:deescalate_antibiotics)))

	md"""
	### The Five Guidelines

	| ID | Clinical Text | Formal Encoding |
	|:---|:-------------|:----------------|
	| G1 | Informed consent must be obtained | `Box(Atom(:consent))` |
	| G4 | Thrombolytics must not be given if active bleeding | `Implies(active_bleeding, Box(Not(thrombolytic)))` |
	| G7 | STEMI patients must receive thrombolytics | `Box(Atom(:thrombolytic))` |
	| T1 | Statin therapy must always be reassessed | `FutureBox(Box(Atom(:statin_reassessment)))` |
	| T2 | Antibiotics must eventually be de-escalated | `Box(FutureDiamond(Atom(:deescalate_antibiotics)))` |
	"""
end

# ╔═╡ 6a1b3c4d-0005-0005-0005-000000000005
md"""
### Inspecting the Formulas

Each formula is a first-class Julia object in Gamen.jl:
"""

# ╔═╡ 6a1b3c4d-0006-0006-0006-000000000006
(g1, g4, g7, t1, t2)

# ╔═╡ 6a1b3c4d-0007-0007-0007-000000000007
md"""
## 2. Pairwise Consistency Checking

The function `tableau_consistent(system, formulas)` returns `true` if there exists a model of the given system that satisfies all formulas simultaneously. If it returns `false`, the formulas are **jointly unsatisfiable** -- no matter what Kripke structure you build, you cannot make them all true at once.

We start by checking every pair of our five guidelines.
"""

# ╔═╡ 6a1b3c4d-0008-0008-0008-000000000008
begin
	# All guidelines in a named collection
	all_guidelines = [
		("G1", g1), ("G4", g4), ("G7", g7), ("T1", t1), ("T2", t2)
	]

	# Pairwise consistency matrix
	n_guidelines = length(all_guidelines)
	pairwise_results = []

	for i in 1:n_guidelines
		for j in (i+1):n_guidelines
			id_i, f_i = all_guidelines[i]
			id_j, f_j = all_guidelines[j]
			result = tableau_consistent(TABLEAU_KDt, Formula[f_i, f_j])
			push!(pairwise_results, (pair="$id_i + $id_j", consistent=result))
		end
	end

	md"""
	### Pairwise Results

	| Guideline Pair | Consistent? |
	|:---------------|:------------|
	$(join(["| $(r.pair) | **$(r.consistent ? "yes" : "CONFLICT")** |" for r in pairwise_results], "\n"))

	All pairs are consistent in isolation. This is expected: G4 is a *conditional* prohibition (it only fires when active bleeding is present), and the temporal guidelines operate on different atoms.

	But what happens when we add **patient conditions** as facts?
	"""
end

# ╔═╡ 6a1b3c4d-0009-0009-0009-000000000009
md"""
### Adding Patient Conditions

G4 says thrombolytics are prohibited *if* active bleeding. G7 says thrombolytics are obligatory. These are consistent when the patient has no active bleeding -- the conditional prohibition is vacuously satisfied.

But if the patient *does* have active bleeding:
"""

# ╔═╡ 6a1b3c4d-0010-0010-0010-000000000010
begin
	# G4 + G7 without active bleeding: consistent
	no_bleeding = tableau_consistent(TABLEAU_KDt, Formula[g4, g7])

	# G4 + G7 WITH active bleeding as a fact: conflict!
	with_bleeding = tableau_consistent(TABLEAU_KDt,
		Formula[g4, g7, Atom(:active_bleeding)])

	md"""
	| Scenario | Formulas | Consistent? |
	|:---------|:---------|:------------|
	| No bleeding | G4 + G7 | **$(no_bleeding)** |
	| Active bleeding | G4 + G7 + active\_bleeding | **$(with_bleeding ? "yes" : "CONFLICT")** |

	Adding `Atom(:active_bleeding)` as a fact triggers the conditional prohibition in G4, which now contradicts the obligation in G7. The tableau closes -- there is no model of KDt satisfying all three formulas.

	This is a **conditional conflict**: the guidelines are compatible in general but incompatible for patients with active bleeding. This distinction -- conditional vs. unconditional conflict -- is clinically crucial.
	"""
end

# ╔═╡ 6a1b3c4d-0011-0011-0011-000000000011
md"""
## 3. Temporal Conflicts

Temporal obligations can conflict when "always" clashes with "eventually not." Consider a therapy that must always continue versus a requirement that it must eventually stop:
"""

# ╔═╡ 6a1b3c4d-0012-0012-0012-000000000012
begin
	# "Therapy must always be maintained" → 𝐆(□(therapy))
	always_therapy = FutureBox(Box(Atom(:therapy)))

	# "Therapy must eventually be discontinued" → □(𝐅(¬therapy))
	eventually_stop = Box(FutureDiamond(Not(Atom(:therapy))))

	temporal_conflict = tableau_consistent(TABLEAU_KDt,
		Formula[always_therapy, eventually_stop])

	md"""
	| Guideline | Formula | Meaning |
	|:----------|:--------|:--------|
	| "Always maintain therapy" | `FutureBox(Box(Atom(:therapy)))` | At every future time, therapy is obligatory |
	| "Eventually discontinue therapy" | `Box(FutureDiamond(Not(Atom(:therapy))))` | It is obligatory that therapy eventually stops |

	**Consistent?** $(temporal_conflict ? "yes" : "CONFLICT")

	These conflict because if therapy is obligatory at *every* future time, there is no future time at which it can be absent. The temporal G operator (reflexive and transitive) covers all future moments, leaving no room for F(not therapy).

	This pattern appears clinically when one guideline mandates indefinite therapy (e.g., lifelong anticoagulation) while another requires periodic reassessment with possible discontinuation.
	"""
end

# ╔═╡ 6a1b3c4d-0013-0013-0013-000000000013
md"""
### A Subtler Temporal Interaction

Now consider T1 ("always reassess statins") and T2 ("eventually de-escalate antibiotics"). These operate on *different* atoms:
"""

# ╔═╡ 6a1b3c4d-0014-0014-0014-000000000014
begin
	t1_t2_result = tableau_consistent(TABLEAU_KDt, Formula[t1, t2])

	md"""
	T1 + T2 consistent? **$(t1_t2_result)**

	These are consistent because they govern *different treatments*. Reassessing statins at every time point does not interfere with eventually de-escalating antibiotics. The tableau finds a model satisfying both.

	Conflict detection is not just about finding *any* inconsistency -- it tells you precisely *which* guideline combinations are safe and which are not.
	"""
end

# ╔═╡ 6a1b3c4d-0015-0015-0015-000000000015
md"""
## 4. Interactive Conflict Explorer

Select guidelines, choose a tableau system, and add patient conditions to explore conflicts interactively.
"""

# ╔═╡ 6a1b3c4d-0016-0016-0016-000000000016
md"""
**Select guidelines to check:**
"""

# ╔═╡ 6a1b3c4d-0017-0017-0017-000000000017
begin
	guideline_options = [
		"G1" => "G1: Informed consent must be obtained",
		"G4" => "G4: Thrombolytics must not be given if active bleeding",
		"G7" => "G7: STEMI patients must receive thrombolytics",
		"T1" => "T1: Statin therapy must always be reassessed",
		"T2" => "T2: Antibiotics must eventually be de-escalated",
	]
	@bind selected_guidelines MultiCheckBox(guideline_options, default=["G4", "G7"])
end

# ╔═╡ 6a1b3c4d-0018-0018-0018-000000000018
md"""
**Select tableau system:**
"""

# ╔═╡ 6a1b3c4d-0019-0019-0019-000000000019
@bind selected_system Select([
	"TABLEAU_K" => "K (basic modal logic -- no frame conditions)",
	"TABLEAU_KD" => "KD (deontic -- seriality: obligations must be achievable)",
	"TABLEAU_KDt" => "KDt (deontic-temporal -- seriality + reflexivity + transitivity)",
])

# ╔═╡ 6a1b3c4d-0020-0020-0020-000000000020
md"""
**Patient conditions (added as propositional facts):**
"""

# ╔═╡ 6a1b3c4d-0021-0021-0021-000000000021
begin
	condition_options = [
		"active_bleeding" => "Active bleeding",
		"sepsis" => "Sepsis diagnosed",
		"heart_failure" => "Heart failure",
		"stemi" => "STEMI",
		"immunocompromised" => "Immunocompromised",
	]
	@bind selected_conditions MultiCheckBox(condition_options, default=String[])
end

# ╔═╡ 6a1b3c4d-0022-0022-0022-000000000022
begin
	# Map IDs to formula objects
	guideline_map = Dict(
		"G1" => g1, "G4" => g4, "G7" => g7, "T1" => t1, "T2" => t2
	)

	# Map system names to objects
	system_map = Dict(
		"TABLEAU_K" => TABLEAU_K,
		"TABLEAU_KD" => TABLEAU_KD,
		"TABLEAU_KDt" => TABLEAU_KDt,
	)

	# Build formula set
	explorer_formulas = Formula[]
	for gid in selected_guidelines
		push!(explorer_formulas, guideline_map[gid])
	end
	for cond in selected_conditions
		push!(explorer_formulas, Atom(Symbol(cond)))
	end

	chosen_system = system_map[selected_system]

	if length(explorer_formulas) < 2
		md"""
		!!! warning "Select at least two guidelines"
		    Consistency checking requires at least two formulas. Select more guidelines above.
		"""
	else
		explorer_result = tableau_consistent(chosen_system, explorer_formulas)

		guidelines_str = join(selected_guidelines, ", ")
		conditions_str = isempty(selected_conditions) ? "none" : join(selected_conditions, ", ")

		md"""
		### Result

		| | |
		|:--|:--|
		| **Guidelines** | $(guidelines_str) |
		| **Patient conditions** | $(conditions_str) |
		| **Tableau system** | $(selected_system) |
		| **Consistent?** | **$(explorer_result ? "YES -- no conflict detected" : "CONFLICT DETECTED")** |

		$(explorer_result ?
			"The tableau did not close. A model exists in which all selected guidelines and patient conditions are simultaneously satisfiable." :
			"The tableau closed on all branches. There is **no model** of $(selected_system) satisfying these guidelines together. This is a genuine logical conflict that would require clinical adjudication.")
		"""
	end
end

# ╔═╡ 6a1b3c4d-0023-0023-0023-000000000023
md"""
!!! tip "Try it"
    - Select G4 + G7, then check "Active bleeding" -- watch the conflict appear
    - Select G4 + G7 with no conditions -- they're consistent
    - Compare TABLEAU\_K vs TABLEAU\_KD vs TABLEAU\_KDt -- the D axiom (seriality) can change results because it forces at least one accessible world to exist
"""

# ╔═╡ 6a1b3c4d-0024-0024-0024-000000000024
md"""
## 5. The Complex Patient

Real patients don't have just one condition. Consider a patient presenting with:

- **STEMI** (ST-elevation myocardial infarction)
- **Active bleeding** (GI hemorrhage)
- **Sepsis**

All of our guidelines potentially apply. What happens when we check the full set?
"""

# ╔═╡ 6a1b3c4d-0025-0025-0025-000000000025
begin
	# The complex patient's conditions
	patient_conditions = Formula[
		Atom(:active_bleeding),
		Atom(:stemi),
		Atom(:sepsis),
	]

	# All guidelines that might apply
	complex_guidelines = Formula[g1, g4, g7, t1, t2]

	# Full check
	complex_result = tableau_consistent(TABLEAU_KDt,
		vcat(complex_guidelines, patient_conditions))

	md"""
	### Full Guideline Set + Complex Patient

	**Patient**: STEMI + active bleeding + sepsis

	**Guidelines applied**: G1, G4, G7, T1, T2

	**Consistent?** $(complex_result ? "yes" : "**CONFLICT DETECTED**")

	The full set is inconsistent. But *which* guidelines conflict? Let's isolate the minimal conflicting subset:
	"""
end

# ╔═╡ 6a1b3c4d-0026-0026-0026-000000000026
begin
	# Test subsets to find minimal conflicts
	subset_tests = [
		("G1 only",       Formula[g1]),
		("G4 only",       Formula[g4]),
		("G7 only",       Formula[g7]),
		("T1 only",       Formula[t1]),
		("T2 only",       Formula[t2]),
		("G4 + G7",       Formula[g4, g7]),
		("G1 + G4 + G7",  Formula[g1, g4, g7]),
		("G4 + G7 + T1",  Formula[g4, g7, t1]),
		("G1 + T1 + T2",  Formula[g1, t1, t2]),
	]

	subset_results = []
	for (label, gs) in subset_tests
		formulas = vcat(gs, patient_conditions)
		result = tableau_consistent(TABLEAU_KDt, formulas)
		push!(subset_results, (label=label, consistent=result))
	end

	md"""
	### Isolating the Conflict

	All subsets tested with patient conditions (active\_bleeding, stemi, sepsis):

	| Guideline Subset | Consistent? |
	|:-----------------|:------------|
	$(join(["| $(r.label) | **$(r.consistent ? "yes" : "CONFLICT")** |" for r in subset_results], "\n"))

	The minimal conflicting subset is **G4 + G7** in the presence of active bleeding. G4 prohibits thrombolytics (because of bleeding), G7 mandates them (because of STEMI). The other guidelines (G1, T1, T2) do not contribute to this conflict.

	**Clinical interpretation**: This patient needs a **clinical decision** that logic alone cannot make. The cardiologist and emergency physician must weigh the risk of hemorrhagic extension (favoring G4) against the risk of infarct progression (favoring G7). The logic tells us the conflict exists and exactly where it is -- the clinical judgment resolves it.
	"""
end

# ╔═╡ 6a1b3c4d-0027-0027-0027-000000000027
md"""
## 6. Conditional vs. Unconditional Conflicts

Not all conflicts are created equal. Some guideline pairs are *always* inconsistent (unconditional conflict), while others conflict only when specific patient conditions are present (conditional conflict). This distinction matters enormously for clinical decision support design.
"""

# ╔═╡ 6a1b3c4d-0028-0028-0028-000000000028
begin
	# ── Unconditional conflict: □(p) ∧ □(¬p) ──
	# "Must administer drug X" + "Must not administer drug X"
	# These conflict regardless of patient state.
	unconditional_a = Box(Atom(:drug_x))
	unconditional_b = Box(Not(Atom(:drug_x)))

	uc_result = tableau_consistent(TABLEAU_KDt,
		Formula[unconditional_a, unconditional_b])

	# ── Conditional conflict: (a → □(¬p)) ∧ □(p) ──
	# "If condition a, must not give p" + "Must give p"
	# Only conflicts when a is true.
	conditional_a = Implies(Atom(:condition_a), Box(Not(Atom(:drug_x))))
	conditional_b = Box(Atom(:drug_x))

	cc_without = tableau_consistent(TABLEAU_KDt,
		Formula[conditional_a, conditional_b])
	cc_with = tableau_consistent(TABLEAU_KDt,
		Formula[conditional_a, conditional_b, Atom(:condition_a)])

	md"""
	### Unconditional Conflict

	- □(drug\_x): "Drug X must be administered"
	- □(not drug\_x): "Drug X must not be administered"

	Consistent? **$(uc_result ? "yes" : "CONFLICT")** -- always, regardless of patient state.

	### Conditional Conflict

	- (condition\_a -> □(not drug\_x)): "If condition A, drug X must not be given"
	- □(drug\_x): "Drug X must be given"

	| Patient State | Consistent? |
	|:-------------|:------------|
	| condition\_a absent | **$(cc_without ? "yes" : "CONFLICT")** |
	| condition\_a present | **$(cc_with ? "yes" : "CONFLICT")** |

	### Clinical Significance

	**Unconditional conflicts** indicate a fundamental disagreement between guidelines -- they can never be jointly followed. These should trigger **hard stops** in clinical decision support: the EHR should prevent order entry and require explicit override with documentation.

	**Conditional conflicts** are context-dependent. They should trigger **soft alerts**: "Guideline X prohibits this intervention for patients with condition A. The patient has condition A. Do you wish to proceed?" The clinician can then evaluate which guideline takes precedence for this specific patient.
	"""
end

# ╔═╡ 6a1b3c4d-0029-0029-0029-000000000029
md"""
## 7. Temporal Conflict Patterns

Temporal conflicts arise when guidelines make incompatible claims about the *timing* of clinical actions. Here are the key patterns:
"""

# ╔═╡ 6a1b3c4d-0030-0030-0030-000000000030
begin
	# Pattern 1: "Always do X" vs "Eventually stop X"
	# 𝐆(□(X)) vs □(𝐅(¬X))
	pat1_always = FutureBox(Box(Atom(:treatment)))
	pat1_stop = Box(FutureDiamond(Not(Atom(:treatment))))
	pat1_result = tableau_consistent(TABLEAU_KDt, Formula[pat1_always, pat1_stop])

	# Pattern 2: "Always do X" vs "Always do Y" (independent atoms — no conflict)
	pat2_a = FutureBox(Box(Atom(:monitor_bp)))
	pat2_b = FutureBox(Box(Atom(:monitor_hr)))
	pat2_result = tableau_consistent(TABLEAU_KDt, Formula[pat2_a, pat2_b])

	# Pattern 3: "Eventually do X" vs "Eventually do Y" (both achievable — no conflict)
	pat3_a = Box(FutureDiamond(Atom(:start_physio)))
	pat3_b = Box(FutureDiamond(Atom(:start_diet)))
	pat3_result = tableau_consistent(TABLEAU_KDt, Formula[pat3_a, pat3_b])

	# Pattern 4: "Never do X" vs "Eventually do X"
	# 𝐆(□(¬X)) vs □(𝐅(X))
	pat4_never = FutureBox(Box(Not(Atom(:procedure))))
	pat4_eventually = Box(FutureDiamond(Atom(:procedure)))
	pat4_result = tableau_consistent(TABLEAU_KDt, Formula[pat4_never, pat4_eventually])

	md"""
	| Pattern | Formula A | Formula B | Consistent? | Clinical Example |
	|:--------|:----------|:----------|:------------|:-----------------|
	| Always X vs Eventually not X | G(□(treatment)) | □(F(not treatment)) | **$(pat1_result ? "yes" : "CONFLICT")** | Lifelong anticoagulation vs eventual discontinuation |
	| Always X vs Always Y | G(□(monitor\_bp)) | G(□(monitor\_hr)) | **$(pat2_result ? "yes" : "CONFLICT")** | Concurrent monitoring obligations |
	| Eventually X vs Eventually Y | □(F(start\_physio)) | □(F(start\_diet)) | **$(pat3_result ? "yes" : "CONFLICT")** | Multiple eventual care goals |
	| Never X vs Eventually X | G(□(not procedure)) | □(F(procedure)) | **$(pat4_result ? "yes" : "CONFLICT")** | Contraindicated procedure vs required procedure |

	The conflicting patterns share a common structure: one guideline asserts something holds at *all* future times, while the other requires a future time where it does *not* hold. Independent atoms (different treatments, different monitoring targets) never conflict because they don't constrain each other.
	"""
end

# ╔═╡ 6a1b3c4d-0031-0031-0031-000000000031
md"""
## 8. From Conflict Detection to Clinical Decision Support

Automated consistency checking with `tableau_consistent` provides the foundation for a clinical decision support (CDS) system. Here is how the logical results map to CDS design:

### Alert Tiers Based on Conflict Type

| Conflict Type | Logic Pattern | CDS Response |
|:-------------|:-------------|:-------------|
| Unconditional | □(p) and □(not p) | **Hard stop** -- cannot proceed without override and documentation |
| Conditional (triggered) | (a -> □(not p)) and □(p) with a true | **Interruptive alert** -- "Patient has condition A; guideline X contraindicates this action" |
| Conditional (untriggered) | (a -> □(not p)) and □(p) with a absent | **Informational** -- "Note: if patient develops A, this order would conflict with guideline X" |
| Temporal | G(□(p)) vs □(F(not p)) | **Planning alert** -- "Long-term management plan contains conflicting temporal requirements" |

### Open Questions

**Which guideline takes precedence?** Standard deontic-temporal logic treats all obligations equally. In practice, guidelines have different evidence levels, recommendation strengths, and clinical contexts. Resolving conflicts requires **defeasible reasoning** -- a form of non-monotonic logic where specific conditions can override general rules. This is an active research area and a natural extension of this work.

**What about probability?** A guideline saying "thrombolytics reduce mortality by 25% in STEMI" and one saying "thrombolytics increase hemorrhagic stroke risk by 3% in bleeding patients" are not logically contradictory -- they are *competing risk-benefit tradeoffs*. Formal logic detects *normative* conflicts (obligations vs prohibitions), not empirical tradeoffs. Both tools are needed.

**The role of clinical judgment.** When the tableau closes, it tells us that no model simultaneously satisfies all guidelines. It does *not* tell us which guideline to follow. That decision requires clinical expertise, patient preferences, and contextual factors that formal logic cannot capture. The logic's role is to make the conflict *explicit* so the clinician can make an informed decision rather than unknowingly violating one guideline while following another.
"""

# ╔═╡ 6a1b3c4d-0032-0032-0032-000000000032
md"""
## 9. Summary

### What Automated Consistency Checking Can Do

- **Detect logical conflicts** between guidelines before they reach patient care
- **Distinguish conditional from unconditional conflicts** -- identifying exactly which patient conditions trigger the inconsistency
- **Identify temporal conflicts** -- obligations that are incompatible over time even if compatible at any single moment
- **Scale to guideline databases** -- checking all pairwise (and higher-order) combinations systematically, which manual review cannot do reliably

### What It Cannot Do

- **Resolve conflicts** -- detection is not resolution; clinical judgment and guideline hierarchy are needed
- **Capture risk-benefit tradeoffs** -- logic detects normative inconsistency, not empirical disagreement
- **Replace clinical expertise** -- the goal is to make conflicts visible, not to automate clinical decisions
- **Handle natural language directly** -- formalization from clinical text to modal logic requires expert translation (though NLP-assisted formalization is an active research area)

### The Technical Foundation

Everything in this notebook rests on:

1. **Kripke semantics** (Ch 1) -- guidelines interpreted as modal claims about acceptable clinical states
2. **Tableau methods** (Ch 6) -- automated satisfiability checking via systematic branch exploration
3. **Temporal operators** (Ch 14) -- "always," "eventually," "before," "after" as first-class logical constructs
4. **Combined deontic-temporal frames** (TABLEAU\_KDt) -- seriality ensures obligations are achievable; reflexivity and transitivity govern temporal reasoning

The tableau prover does not enumerate models (which would be intractable for complex formulas). Instead, it systematically searches for a satisfying assignment and reports either success (consistent) or closure of all branches (inconsistent). This is sound and complete for the logics we consider.
"""

# ╔═╡ Cell order:
# ╟─6a1b3c4d-0002-0002-0002-000000000002
# ╠═6a1b3c4d-0001-0001-0001-000000000001
# ╟─6a1b3c4d-0003-0003-0003-000000000003
# ╠═6a1b3c4d-0004-0004-0004-000000000004
# ╟─6a1b3c4d-0005-0005-0005-000000000005
# ╠═6a1b3c4d-0006-0006-0006-000000000006
# ╟─6a1b3c4d-0007-0007-0007-000000000007
# ╠═6a1b3c4d-0008-0008-0008-000000000008
# ╟─6a1b3c4d-0009-0009-0009-000000000009
# ╠═6a1b3c4d-0010-0010-0010-000000000010
# ╟─6a1b3c4d-0011-0011-0011-000000000011
# ╠═6a1b3c4d-0012-0012-0012-000000000012
# ╟─6a1b3c4d-0013-0013-0013-000000000013
# ╠═6a1b3c4d-0014-0014-0014-000000000014
# ╟─6a1b3c4d-0015-0015-0015-000000000015
# ╟─6a1b3c4d-0016-0016-0016-000000000016
# ╠═6a1b3c4d-0017-0017-0017-000000000017
# ╟─6a1b3c4d-0018-0018-0018-000000000018
# ╠═6a1b3c4d-0019-0019-0019-000000000019
# ╟─6a1b3c4d-0020-0020-0020-000000000020
# ╠═6a1b3c4d-0021-0021-0021-000000000021
# ╠═6a1b3c4d-0022-0022-0022-000000000022
# ╟─6a1b3c4d-0023-0023-0023-000000000023
# ╟─6a1b3c4d-0024-0024-0024-000000000024
# ╠═6a1b3c4d-0025-0025-0025-000000000025
# ╠═6a1b3c4d-0026-0026-0026-000000000026
# ╟─6a1b3c4d-0027-0027-0027-000000000027
# ╠═6a1b3c4d-0028-0028-0028-000000000028
# ╟─6a1b3c4d-0029-0029-0029-000000000029
# ╠═6a1b3c4d-0030-0030-0030-000000000030
# ╟─6a1b3c4d-0031-0031-0031-000000000031
# ╟─6a1b3c4d-0032-0032-0032-000000000032
