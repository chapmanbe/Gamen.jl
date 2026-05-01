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

# ╔═╡ 11a1b3c4d-0001-0001-0001-000000000001
md"""
# Tableaux for Clinical Guideline Conflict Detection

## The Problem: When CDS Alerts Go Wrong

In 2005 a systematic review found that clinical decision support (CDS) systems contradict
themselves at rates high enough to cause *alert fatigue*: clinicians override 49–96% of
all drug–drug interaction alerts because so many are spurious or inconsistent with each
other (van der Sijs et al., 2006). More recently, Braithwaite et al. (2020) described the
60–30–10 challenge: only 60% of care is evidence-based, 30% is waste, and 10% is
outright harm — much of it caused by guidelines that conflict when applied to the same
patient.

**Scenario**: A STEMI patient arrives in the emergency department. Two active CDS rules fire:
- *Rule A*: "Patients with STEMI must receive thrombolytics." (ACC/AHA)
- *Rule B*: "If the patient has active bleeding, thrombolytics must NOT be given." (ACEP)

The patient's chart shows active bleeding from a recent procedure. The rules contradict.
Which one should the clinician follow? The EHR fires both alerts and leaves the decision
to the clinician — who is already under cognitive load.

**What formal logic adds**: We can *prove* this conflict exists before the patient arrives,
by checking the logical consistency of the rule set. The tableau method is the automated
proof procedure that makes this check tractable.

This notebook parallels [Chapter 6 of Boxes and Diamonds](https://bd.openlogicproject.org)
(Modal Tableaux) but applies it to guideline conflict detection. By the end you will be
able to:
- Translate clinical rules into modal formulas
- Use `tableau_consistent` to detect conflicts automatically
- Extract a countermodel showing how compatible guidelines coexist
- Understand why pairwise checking is insufficient

See the [Chapter 6 B&D notebook](../../../theory/pluto/ch6_tableaux.jl) for the full
technical treatment. This notebook focuses on the clinical application.
"""

# ╔═╡ 11a1b3c4d-0002-0002-0002-000000000002
begin
	using Gamen
	using PlutoUI
	import CairoMakie, GraphMakie, Graphs
end

# ╔═╡ 11a1b3c4d-0003-0003-0003-000000000003
md"""
## How Tableaux Work (Brief Recap)

A modal tableau is a tree of **signed prefixed formulas**. Each formula carries:
- A **prefix** (e.g., `1`, `1.1`, `1.2`) naming a world
- A **sign**: T (true) or F (false)

A branch **closes** when it contains both `σ T A` and `σ F A` for some prefix σ and formula A -- a contradiction. A tableau is **closed** (a proof of unsatisfiability) when *every* branch closes.

For consistency checking:
- Start with `{1 T G₁, 1 T G₂, ...}` -- assume all guidelines are true at the root world
- Expand the tableau by applying rules
- If the tableau closes: the guidelines are **inconsistent** (conflict detected)
- If any branch stays open: the guidelines are **consistent**, and the open branch defines a model where all guidelines hold simultaneously
"""

# ╔═╡ 11a1b3c4d-0035-0035-0035-000000000035
md"""
$(Markdown.MD(Markdown.Admonition("note", "Knowledge Representation Lens", [md"Davis, Shrobe & Szolovits (1993) identify five roles a knowledge representation must play. For Ch6, two are central. **Role 4 — Medium for efficient computation**: a representation is only useful if reasoning over it is tractable. The tableau method makes consistency checking *automated* — we do not need a human expert to spot conflicts. Fitting (1999) shows that prefixed tableaux for modal logic are both sound and complete, so we are guaranteed to find every conflict that exists. **Role 3 — Theory of reasoning**: the tableau rules specify exactly which inferences are *sanctioned*: T□A at σ licenses T A at any σ.n accessible from σ; F□A licenses F A at a fresh prefix. These are not heuristics — they are the licensed moves. Together these roles explain why formal logic is not just academic: it gives us a computation we can run and a guarantee about what it finds."])))
"""

# ╔═╡ 11a1b3c4d-0004-0004-0004-000000000004
md"""
## Clinical Guidelines as Modal Formulas

We use five guidelines from clinical practice, formalized in the [Chapter 1 health notebook](ch1_health_clinical_obligations.jl):
"""

# ╔═╡ 11a1b3c4d-0005-0005-0005-000000000005
begin
	# Atomic propositions
	consent = Atom(:consent)
	thrombolytic = Atom(:thrombolytic)
	active_bleeding = Atom(:active_bleeding)
	discharge_plan = Atom(:discharge_plan)

	# Formalized guidelines
	g1 = Box(consent)                                        # G1: consent must be obtained
	g4 = Implies(active_bleeding, Box(Not(thrombolytic)))    # G4: if bleeding, no thrombolytics
	g5 = Box(discharge_plan)                                 # G5: discharge planning is obligatory
	g6 = Box(Not(discharge_plan))                            # G6: discharge planning is prohibited
	g7 = Box(thrombolytic)                                   # G7: thrombolytics are obligatory

	md"""
	| Label | Clinical Guideline | Formula |
	|:------|:-------------------|:--------|
	| G1 | Informed consent must be obtained | $(g1) |
	| G4 | If active bleeding, thrombolytics must not be given | $(g4) |
	| G5 | Discharge planning should begin promptly | $(g5) |
	| G6 | Discharge planning must not begin until cultures finalized | $(g6) |
	| G7 | Patients with STEMI must receive thrombolytics | $(g7) |
	"""
end

# ╔═╡ 11a1b3c4d-0036-0036-0036-000000000036
md"""
### Exercise 1: Identify the Potential Conflict

Looking at guidelines G1–G7 in the table above, which pair would you expect to conflict
when a patient has both a STEMI diagnosis AND active bleeding? Which single additional
fact creates the conflict?

$(Markdown.MD(Markdown.Admonition("hint", "Reveal answer", [md"G4 and G7 conflict when `active_bleeding` is asserted as a fact. G7 = □(thrombolytic) requires thrombolytics in every accessible world. G4 = active_bleeding → □(¬thrombolytic) — when active_bleeding is true at the root, it expands to □(¬thrombolytic). A successor world must then have both thrombolytic and ¬thrombolytic true — a contradiction. Without active_bleeding, the antecedent of G4 is vacuously false and no conflict arises."])))
"""

# ╔═╡ 11a1b3c4d-0006-0006-0006-000000000006
md"""
## Checking Guideline Consistency

`tableau_consistent(system, formulas)` builds a tableau starting from `{1 T A₁, ..., 1 T Aₙ}` and returns `true` if any branch stays open (consistent) or `false` if all branches close (conflict).

We use **KD** (serial frames) as our base system, since deontic logic requires seriality: every world must have at least one accessible successor (obligations must be achievable).

"""

# ╔═╡ 11a1b3c4d-0007-0007-0007-000000000007
begin
	# Consistent pair: consent + conditional prohibition
	r_g1_g4 = tableau_consistent(TABLEAU_KD, Formula[g1, g4])
	println("G1 + G4 (consent + conditional prohibition): consistent = ", r_g1_g4)

	# Inconsistent pair: obligatory discharge vs prohibited discharge
	r_g5_g6 = tableau_consistent(TABLEAU_KD, Formula[g5, g6])
	println("G5 + G6 (obligatory vs prohibited discharge): consistent = ", r_g5_g6)
end

# ╔═╡ 11a1b3c4d-0008-0008-0008-000000000008
md"""
G5 and G6 directly contradict: one requires discharge planning in every accessible world, the other forbids it. No model can satisfy both.

Now consider the subtler case — G4 (if bleeding, no thrombolytics) and G7 (thrombolytics are obligatory):
"""

# ╔═╡ 11a1b3c4d-0009-0009-0009-000000000009
begin
	# Conditional conflict: depends on whether bleeding is assumed
	r_no_bleed = tableau_consistent(TABLEAU_KD, Formula[g4, g7])
	r_with_bleed = tableau_consistent(TABLEAU_KD, Formula[g4, g7, active_bleeding])

	println("G4 + G7 (no bleeding assumed): consistent = ", r_no_bleed)
	println("G4 + G7 + active_bleeding:     consistent = ", r_with_bleed)
end

# ╔═╡ 11a1b3c4d-0010-0010-0010-000000000010
md"""
Without assuming active bleeding, G4 and G7 are compatible — the conditional prohibition is vacuously satisfied. But when active bleeding is asserted as a fact, a genuine conflict emerges: G4 demands no thrombolytics in all accessible worlds, while G7 demands thrombolytics in all accessible worlds.

This is exactly the kind of **conditional conflict** that informal guideline review often misses.
"""

# ╔═╡ 11a1b3c4d-0011-0011-0011-000000000011
md"""
## Building and Inspecting Tableaux

To see *why* a conflict exists, we can build the tableau and inspect its branches:
"""

# ╔═╡ 11a1b3c4d-0012-0012-0012-000000000012
begin
	root = Prefix([1])

	# Build tableau for the direct conflict: G5 vs G6
	assumptions_conflict = [pf_true(root, g5), pf_true(root, g6)]
	t_conflict = build_tableau(assumptions_conflict, TABLEAU_KD)

	println("Tableau for G5 + G6:")
	println("  Closed: ", is_closed(t_conflict))
	println("  Branches: ", length(t_conflict.branches))
	for (i, b) in enumerate(t_conflict.branches)
		println("  Branch $i: ", is_closed(b) ? "closed" : "open",
			" ($(length(b.formulas)) formulas)")
	end
end

# ╔═╡ 11a1b3c4d-0013-0013-0013-000000000013
begin
	# Show the formulas on the first branch to see the contradiction
	println("Formulas on branch 1:")
	for pf in t_conflict.branches[1].formulas
		println("  ", pf)
	end
end

# ╔═╡ 11a1b3c4d-0014-0014-0014-000000000014
md"""
The branch contains both a T (true) and F (false) assignment for the same formula at the same prefix -- a contradiction. The tableau engine finds this automatically.
"""

# ╔═╡ 11a1b3c4d-0015-0015-0015-000000000015
md"""
## Countermodel Extraction

When guidelines are consistent, the open branch defines a **countermodel** — a Kripke model showing how the guidelines can all be satisfied simultaneously. This is the completeness result from B&D Theorem 6.19.
"""

# ╔═╡ 11a1b3c4d-0016-0016-0016-000000000016
begin
	# Build tableau for G4 + G7 (no bleeding) — should be open
	assumptions_compat = [pf_true(root, g4), pf_true(root, g7)]
	t_compat = build_tableau(assumptions_compat, TABLEAU_KD)

	println("Tableau for G4 + G7 (no bleeding):")
	println("  Closed: ", is_closed(t_compat))

	# Find the first open branch
	open_idx = findfirst(b -> !is_closed(b), t_compat.branches)
	if open_idx !== nothing
		branch = t_compat.branches[open_idx]
		cm = extract_countermodel(branch)
		println("\nCountermodel extracted:")
		println("  Worlds: ", cm.frame.worlds)
		println("  Relations: ", cm.frame.relations)
		println("  Valuation: ", cm.valuation)
	end
end

# ╔═╡ 11a1b3c4d-0017-0017-0017-000000000017
md"""
The countermodel shows a scenario where both guidelines hold: thrombolytics are given in every accessible world (satisfying G7), and active bleeding is false at the root (making G4 vacuously true). This is precisely the clinical scenario where these guidelines coexist — a STEMI patient without active bleeding.
"""

# ╔═╡ 11a1b3c4d-0039-0039-0039-000000000039
begin
	# Visualize the countermodel extracted from the G4 + G7 (no bleeding) open branch
	open_idx_vis = findfirst(b -> !is_closed(b), t_compat.branches)
	if open_idx_vis !== nothing
		cm_vis = extract_countermodel(t_compat.branches[open_idx_vis])
		visualize_model(cm_vis)
	end
end

# ╔═╡ 11a1b3c4d-0018-0018-0018-000000000018
md"""
## Choosing the Right Tableau System

Different modal logics make different assumptions about the accessibility relation. For clinical guidelines, the choice of system affects what counts as a conflict:

| System | Frame Property | Clinical Interpretation |
|:-------|:---------------|:-----------------------|
| K | None | Minimal — no assumptions about clinical scenarios |
| KD | Serial | Every state has an acceptable successor (obligations are achievable) |
| KDt | Deontic-serial + temporal (reflexive, transitive) | Obligations are achievable; temporal operators 𝐆/𝐅 track care episode sequencing |
"""

# ╔═╡ 11a1b3c4d-0019-0019-0019-000000000019
begin
	formulas_compare = Formula[g4, g7]
	r_K   = tableau_consistent(TABLEAU_K,   formulas_compare)
	r_KD  = tableau_consistent(TABLEAU_KD,  formulas_compare)
	r_KDt = tableau_consistent(TABLEAU_KDt, formulas_compare)

	println("G4 + G7 consistency across systems:")
	println("  K:   ", r_K)
	println("  KD:  ", r_KD)
	println("  KDt: ", r_KDt)
end

# ╔═╡ 11a1b3c4d-0020-0020-0020-000000000020
md"""
KD is the standard choice for deontic reasoning: the seriality axiom (D: □p → ◇p) ensures that if something is obligatory, it is also permitted — there must be at least one acceptable scenario. Without seriality (system K), dead-end worlds make every obligation vacuously true, which is clinically meaningless.

KDt combines KD's seriality with reflexive and transitive temporal operators (𝐆/𝐅), meaning temporal statements like "thrombolytics should always be given during the care episode" can be expressed and checked alongside deontic obligations. This is appropriate when guidelines apply throughout a care episode rather than at a single decision point.
"""

# ╔═╡ 11a1b3c4d-0021-0021-0021-000000000021
md"""
## Interactive Conflict Checker

Select guidelines and a tableau system to check for conflicts:
"""

# ╔═╡ 11a1b3c4d-0022-0022-0022-000000000022
@bind selected_guidelines MultiSelect([
	"G1" => "G1: Informed consent must be obtained",
	"G4" => "G4: If bleeding, no thrombolytics",
	"G5" => "G5: Discharge planning is obligatory",
	"G6" => "G6: Discharge planning is prohibited",
	"G7" => "G7: Thrombolytics are obligatory",
], default=["G5", "G6"])

# ╔═╡ 11a1b3c4d-0023-0023-0023-000000000023
@bind selected_system Select([
	"K"   => "K (no frame conditions)",
	"KD"  => "KD (serial -- deontic)",
	"KDt" => "KDt (serial + transitive)",
], default="KD")

# ╔═╡ 11a1b3c4d-0024-0024-0024-000000000024
md"Include `active_bleeding` as a fact: $(@bind include_bleeding CheckBox(default=false))"

# ╔═╡ 11a1b3c4d-0025-0025-0025-000000000025
begin
	guideline_map = Dict("G1" => g1, "G4" => g4, "G5" => g5, "G6" => g6, "G7" => g7)
	system_map = Dict("K" => TABLEAU_K, "KD" => TABLEAU_KD, "KDt" => TABLEAU_KDt)

	chosen = Formula[guideline_map[k] for k in selected_guidelines]
	if include_bleeding
		push!(chosen, active_bleeding)
	end

	sys = system_map[selected_system]

	if length(chosen) == 0
		md"*Select at least one guideline above.*"
	else
		is_consistent = tableau_consistent(sys, chosen)

		# Build the tableau for detail
		detail_assumptions = [pf_true(root, f) for f in chosen]
		detail_tab = build_tableau(detail_assumptions, sys)

		result_text = is_consistent ? "**Consistent** -- guidelines can all be followed simultaneously." : "**Inconsistent** -- conflict detected! The tableau closes on all branches."

		branch_info = join([
			"Branch $i: $(is_closed(b) ? "closed" : "OPEN") ($(length(b.formulas)) formulas)"
			for (i, b) in enumerate(detail_tab.branches)
		], "\n")

		bleeding_note = include_bleeding ? " + active\\_bleeding" : ""

		md"""
		### Result for {$(join(selected_guidelines, ", "))}$bleeding_note in $(selected_system)

		$(result_text)

		**Tableau detail** ($(length(detail_tab.branches)) branches):

		```
		$(branch_info)
		```
		"""
	end
end

# ╔═╡ 11a1b3c4d-0026-0026-0026-000000000026
md"""
*(Use the "include bleeding" checkbox above the result cell to add `active_bleeding` as an assumed fact. Try selecting G4 + G7 with and without it.)*
"""

# ╔═╡ 11a1b3c4d-0037-0037-0037-000000000037
md"""
### Exercise 2: Use the Interactive Checker

Using the MultiSelect widget above, select **G1 + G5 + G6** with system **KD** (no bleeding).
Predict the result before running it. Then try **G4 + G7** with and without the bleeding checkbox.

$(Markdown.MD(Markdown.Admonition("hint", "Reveal answer", [md"G1 + G5 + G6 in KD: **Inconsistent**. G5 = □(discharge_plan) and G6 = □(¬discharge_plan) directly conflict regardless of G1. The tableau closes on any branch that tries to satisfy both in a successor world. G4 + G7 without bleeding: **Consistent** — the conditional is vacuously satisfied. G4 + G7 with active_bleeding: **Inconsistent** — the conditional fires, producing □(¬thrombolytic) which contradicts G7."])))
"""

# ╔═╡ 11a1b3c4d-0027-0027-0027-000000000027
md"""
## Pairwise Conflict Matrix

For a guideline set, we can check every pair for conflicts. This gives a quick overview of which guidelines are incompatible:
"""

# ╔═╡ 11a1b3c4d-0028-0028-0028-000000000028
begin
	all_guidelines = [("G1", g1), ("G4", g4), ("G5", g5), ("G6", g6), ("G7", g7)]
	n = length(all_guidelines)
	labels = [name for (name, _) in all_guidelines]

	# Build pairwise consistency matrix
	matrix_rows = []
	for i in 1:n
		row = []
		for j in 1:n
			if i == j
				push!(row, "-")
			elseif i < j
				pair = Formula[all_guidelines[i][2], all_guidelines[j][2]]
				result = tableau_consistent(TABLEAU_KD, pair)
				push!(row, result ? "ok" : "CONFLICT")
			else
				# Mirror the upper triangle
				pair = Formula[all_guidelines[j][2], all_guidelines[i][2]]
				result = tableau_consistent(TABLEAU_KD, pair)
				push!(row, result ? "ok" : "CONFLICT")
			end
		end
		push!(matrix_rows, row)
	end

	# Display as a table
	header = "| | " * join(labels, " | ") * " |"
	separator = "|:--|" * join(fill(":--:", n), "|") * "|"
	body = join([
		"| **$(labels[i])** | " * join(matrix_rows[i], " | ") * " |"
		for i in 1:n
	], "\n")

	Markdown.parse("""
	### Pairwise Consistency (KD)

	$header
	$separator
	$body

	Only one pair shows a direct conflict: **G5 vs G6** (obligatory vs prohibited discharge planning). The conditional conflict between G4 and G7 does not appear in pairwise checking because `active_bleeding` is not assumed.
	""")
end

# ╔═╡ 11a1b3c4d-0029-0029-0029-000000000029
md"""
## Scaling Considerations

Pairwise checking is O(N^2) in the number of guidelines. It catches direct binary conflicts but can miss **interaction effects** -- situations where guidelines are pairwise consistent but collectively inconsistent.

### Pairwise vs Full-Set Checking

Consider three guidelines that are pairwise consistent but collectively inconsistent when a triggering condition is present:
"""

# ╔═╡ 11a1b3c4d-0030-0030-0030-000000000030
begin
	# G4: active_bleeding -> Box(Not(thrombolytic))
	# G7: Box(thrombolytic)
	# active_bleeding (as a fact)
	#
	# Pairwise:
	#   G4 + G7:              consistent (no bleeding assumed)
	#   G4 + active_bleeding: consistent (just says: if bleeding, no thrombolytics)
	#   G7 + active_bleeding: consistent (bleeding + obligatory thrombolytics -- no direct contradiction)
	# Triple:
	#   G4 + G7 + active_bleeding: INCONSISTENT

	pair_4_7  = tableau_consistent(TABLEAU_KD, Formula[g4, g7])
	pair_4_ab = tableau_consistent(TABLEAU_KD, Formula[g4, active_bleeding])
	pair_7_ab = tableau_consistent(TABLEAU_KD, Formula[g7, active_bleeding])
	triple    = tableau_consistent(TABLEAU_KD, Formula[g4, g7, active_bleeding])

	println("Pairwise checks:")
	println("  G4 + G7:              consistent = ", pair_4_7)
	println("  G4 + active_bleeding: consistent = ", pair_4_ab)
	println("  G7 + active_bleeding: consistent = ", pair_7_ab)
	println("\nFull-set check:")
	println("  G4 + G7 + active_bleeding: consistent = ", triple)
end

# ╔═╡ 11a1b3c4d-0031-0031-0031-000000000031
md"""
Every pair is consistent, but the triple is not. This is a classic case where **pairwise checking is insufficient**: the conflict only emerges when a conditional prohibition (G4), a positive obligation (G7), and a triggering condition (active bleeding) are all present simultaneously.

For clinical decision support systems, this means we need full-set consistency checking, not just pairwise comparison. The tableau method handles this naturally — we simply add all formulas as assumptions and check whether the tableau closes.

For N guidelines, full-set checking requires only one tableau construction, while pairwise checking requires N(N-1)/2. Full-set checking is both more thorough and (for detecting interactions) more efficient.
"""

# ╔═╡ 11a1b3c4d-0038-0038-0038-000000000038
md"""
### Exercise 3: Why Pairwise Checking Is Insufficient

Suppose a hospital has three guidelines about IV fluids in sepsis:
- **H1**: "Patients in septic shock must receive IV fluids." → □(iv_fluids)
- **H2**: "If the patient has acute pulmonary edema, IV fluids are contraindicated." → pulmonary_edema → □(¬iv_fluids)
- **H3**: "Patients with septic shock and pulmonary edema must be admitted to the ICU." → (propositional fact: pulmonary_edema = true)

Do any two of H1, H2, H3 conflict on their own? What about all three together?

$(Markdown.MD(Markdown.Admonition("hint", "Reveal answer", [md"Pairwise: H1 + H2 consistent (conditional vacuous without pulmonary_edema); H1 + H3 consistent (fluids + edema fact, no contradiction yet); H2 + H3 consistent (edema + conditional, still no direct clash). Full set H1 + H2 + H3: **inconsistent**. H3 makes pulmonary_edema true at the root world. H2 then expands to □(¬iv_fluids). H1 requires □(iv_fluids). Any successor world needs both iv_fluids and ¬iv_fluids — contradiction. Pairwise checking would miss this; full-set tableau catches it."])))
"""

# ╔═╡ 11a1b3c4d-0032-0032-0032-000000000032
md"""
## Using `tableau_proves` for Entailment

Beyond consistency, tableaux can check whether one guideline **entails** another -- whether following one set of guidelines logically requires following another:
"""

# ╔═╡ 11a1b3c4d-0033-0033-0033-000000000033
begin
	# Does G7 (Box(thrombolytic)) entail Diamond(thrombolytic)?
	# In KD: Box(p) -> Diamond(p) is the D axiom, so yes.
	r_entail = tableau_proves(TABLEAU_KD, Formula[g7], Diamond(thrombolytic))
	println("KD: G7 entails Diamond(thrombolytic): ", r_entail)

	# Does G1 (Box(consent)) entail consent at the current world?
	# In K: no (no reflexivity). In KT: yes.
	r_k  = tableau_proves(TABLEAU_K,  Formula[g1], consent)
	r_kd = tableau_proves(TABLEAU_KD, Formula[g1], consent)
	println("K:  G1 entails consent: ", r_k)
	println("KD: G1 entails consent: ", r_kd)
end

# ╔═╡ 11a1b3c4d-0040-0040-0040-000000000040
md"""
## What Comes Next

The conflict detection toolkit built here handles *static* guideline sets — a snapshot of obligations at a single decision point. Clinical care unfolds over time: consent must occur *before* treatment; discharge planning must follow *after* cultures finalize. The next step is **temporal logic**, where operators 𝐆 ("always"), 𝐅 ("eventually"), 𝐇 ("historically"), and 𝐏 ("previously") let us express and check temporal sequencing requirements.

See the [Ch14 health notebook](ch14_health_temporal_clinical.jl) for temporal conflict detection — where G4 might become "if bleeding develops *after* thrombolytic administration, escalate to reversal agent" and we can check whether that temporal obligation is consistent with the rest of the care protocol.

Epistemic extensions (Ch15) add another layer: what if the attending and the covering nurse have *different* information about the patient's bleeding status? The [Ch15 health notebook](ch15_health_epistemic_clinical.jl) addresses information asymmetry in CDS.
"""

# ╔═╡ 11a1b3c4d-0034-0034-0034-000000000034
md"""
## Summary

| Task | Method | Result |
|:-----|:-------|:-------|
| Are guidelines consistent? | `tableau_consistent(system, formulas)` | `true` = compatible, `false` = conflict |
| Why is there a conflict? | `build_tableau(assumptions, system)` | Inspect closed branches for contradictions |
| How can guidelines coexist? | `extract_countermodel(open_branch)` | A Kripke model satisfying all guidelines |
| Does one guideline follow from others? | `tableau_proves(system, premises, conclusion)` | `true` = entailed |
| Which system to use? | KD for standard deontic, KDt for persistent obligations | Seriality ensures obligations are achievable |

Tableaux give us a **sound and complete** method for automated guideline conflict detection: if a conflict exists, the tableau will find it. If no conflict exists, we get a constructive model demonstrating compatibility.
"""

# ╔═╡ 00000000-0000-0000-0000-000000000001
PLUTO_PROJECT_TOML_CONTENTS = """
[deps]
CairoMakie = "13f3f980-e62b-5c42-98c6-ff1f3baf88f0"
Gamen = "d58aead4-12fe-4bc4-9bd9-a7dede724567"
GraphMakie = "1ecd5474-83a3-4783-bb4f-06765db800d2"
Graphs = "86223c79-3864-5bf0-83f7-82e725a168b6"
PlutoUI = "7f904dfe-b85e-4ff6-b463-dae2292396a8"

[compat]
CairoMakie = "0.15"
Gamen = "~0.2"
GraphMakie = "0.6"
Graphs = "1"
PlutoUI = "~0.7.80"
"""

# ╔═╡ 00000000-0000-0000-0000-000000000002
PLUTO_MANIFEST_TOML_CONTENTS = """
# This file is machine-generated - editing it directly is not advised

julia_version = "1.12.4"
manifest_format = "2.0"
project_hash = "placeholder-ch6-health-conflict-detection"

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
version = "0.2.0"

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
# ╟─11a1b3c4d-0001-0001-0001-000000000001
# ╟─11a1b3c4d-0002-0002-0002-000000000002
# ╟─11a1b3c4d-0003-0003-0003-000000000003
# ╟─11a1b3c4d-0035-0035-0035-000000000035
# ╟─11a1b3c4d-0004-0004-0004-000000000004
# ╟─11a1b3c4d-0005-0005-0005-000000000005
# ╟─11a1b3c4d-0036-0036-0036-000000000036
# ╟─11a1b3c4d-0006-0006-0006-000000000006
# ╟─11a1b3c4d-0007-0007-0007-000000000007
# ╟─11a1b3c4d-0008-0008-0008-000000000008
# ╟─11a1b3c4d-0009-0009-0009-000000000009
# ╟─11a1b3c4d-0010-0010-0010-000000000010
# ╟─11a1b3c4d-0011-0011-0011-000000000011
# ╟─11a1b3c4d-0012-0012-0012-000000000012
# ╟─11a1b3c4d-0013-0013-0013-000000000013
# ╟─11a1b3c4d-0014-0014-0014-000000000014
# ╟─11a1b3c4d-0015-0015-0015-000000000015
# ╟─11a1b3c4d-0016-0016-0016-000000000016
# ╟─11a1b3c4d-0017-0017-0017-000000000017
# ╟─11a1b3c4d-0039-0039-0039-000000000039
# ╟─11a1b3c4d-0018-0018-0018-000000000018
# ╟─11a1b3c4d-0019-0019-0019-000000000019
# ╟─11a1b3c4d-0020-0020-0020-000000000020
# ╟─11a1b3c4d-0021-0021-0021-000000000021
# ╟─11a1b3c4d-0022-0022-0022-000000000022
# ╟─11a1b3c4d-0023-0023-0023-000000000023
# ╟─11a1b3c4d-0024-0024-0024-000000000024
# ╟─11a1b3c4d-0025-0025-0025-000000000025
# ╟─11a1b3c4d-0026-0026-0026-000000000026
# ╟─11a1b3c4d-0037-0037-0037-000000000037
# ╟─11a1b3c4d-0027-0027-0027-000000000027
# ╟─11a1b3c4d-0028-0028-0028-000000000028
# ╟─11a1b3c4d-0029-0029-0029-000000000029
# ╟─11a1b3c4d-0030-0030-0030-000000000030
# ╟─11a1b3c4d-0031-0031-0031-000000000031
# ╟─11a1b3c4d-0038-0038-0038-000000000038
# ╟─11a1b3c4d-0032-0032-0032-000000000032
# ╟─11a1b3c4d-0033-0033-0033-000000000033
# ╟─11a1b3c4d-0040-0040-0040-000000000040
# ╟─11a1b3c4d-0034-0034-0034-000000000034
# ╟─00000000-0000-0000-0000-000000000001
# ╟─00000000-0000-0000-0000-000000000002
