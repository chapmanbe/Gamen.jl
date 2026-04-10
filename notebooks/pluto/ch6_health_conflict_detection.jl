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

This notebook parallels [Chapter 6 of Boxes and Diamonds](https://bd.openlogicproject.org) (Modal Tableaux) but applies the tableau method to a practical problem: **automated detection of conflicts between clinical practice guidelines**.

**Key insight**: The tableau method is an automated proof procedure. For clinical guideline validation, it lets us check whether a set of guidelines is *consistent* -- can they all be followed simultaneously? If the tableau closes, there is a conflict. If it stays open, the guidelines are compatible, and we can extract a model showing how they can coexist.

See the [Chapter 6 B&D notebook](ch6_tableaux.jl) for the full technical treatment of tableaux. This notebook focuses on the clinical application.
"""

# ╔═╡ 11a1b3c4d-0002-0002-0002-000000000002
begin
	using Pkg
	Pkg.activate(joinpath(@__DIR__, ".."))
	using Gamen
	using PlutoUI
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

Now consider the subtler case -- G4 (if bleeding, no thrombolytics) and G7 (thrombolytics are obligatory):
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
Without assuming active bleeding, G4 and G7 are compatible -- the conditional prohibition is vacuously satisfied. But when active bleeding is asserted as a fact, a genuine conflict emerges: G4 demands no thrombolytics in all accessible worlds, while G7 demands thrombolytics in all accessible worlds.

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

When guidelines are consistent, the open branch defines a **countermodel** -- a Kripke model showing how the guidelines can all be satisfied simultaneously. This is the completeness result from B&D Theorem 6.19.
"""

# ╔═╡ 11a1b3c4d-0016-0016-0016-000000000016
begin
	# Build tableau for G4 + G7 (no bleeding) -- should be open
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
The countermodel shows a scenario where both guidelines hold: thrombolytics are given in every accessible world (satisfying G7), and active bleeding is false at the root (making G4 vacuously true). This is precisely the clinical scenario where these guidelines coexist -- a STEMI patient without active bleeding.
"""

# ╔═╡ 11a1b3c4d-0018-0018-0018-000000000018
md"""
## Choosing the Right Tableau System

Different modal logics make different assumptions about the accessibility relation. For clinical guidelines, the choice of system affects what counts as a conflict:

| System | Frame Property | Clinical Interpretation |
|:-------|:---------------|:-----------------------|
| K | None | Minimal -- no assumptions about clinical scenarios |
| KD | Serial | Every state has an acceptable successor (obligations are achievable) |
| KDt | Serial + transitive | Obligations persist across chains of clinical decisions |
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
KD is the standard choice for deontic reasoning: the seriality axiom (D: □p -> ◇p) ensures that if something is obligatory, it is also permitted -- there must be at least one acceptable scenario. Without seriality (system K), dead-end worlds make every obligation vacuously true, which is clinically meaningless.

KDt adds transitivity, meaning obligations propagate: if thrombolytics are obligatory, and the obligation persists through follow-up decisions, then thrombolytics remain obligatory at every reachable state. This is appropriate when guidelines apply throughout a care episode rather than at a single decision point.
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

For clinical decision support systems, this means we need full-set consistency checking, not just pairwise comparison. The tableau method handles this naturally -- we simply add all formulas as assumptions and check whether the tableau closes.

For N guidelines, full-set checking requires only one tableau construction, while pairwise checking requires N(N-1)/2. Full-set checking is both more thorough and (for detecting interactions) more efficient.
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

# ╔═╡ Cell order:
# ╟─11a1b3c4d-0001-0001-0001-000000000001
# ╠═11a1b3c4d-0002-0002-0002-000000000002
# ╟─11a1b3c4d-0003-0003-0003-000000000003
# ╟─11a1b3c4d-0004-0004-0004-000000000004
# ╠═11a1b3c4d-0005-0005-0005-000000000005
# ╟─11a1b3c4d-0006-0006-0006-000000000006
# ╠═11a1b3c4d-0007-0007-0007-000000000007
# ╟─11a1b3c4d-0008-0008-0008-000000000008
# ╠═11a1b3c4d-0009-0009-0009-000000000009
# ╟─11a1b3c4d-0010-0010-0010-000000000010
# ╟─11a1b3c4d-0011-0011-0011-000000000011
# ╠═11a1b3c4d-0012-0012-0012-000000000012
# ╠═11a1b3c4d-0013-0013-0013-000000000013
# ╟─11a1b3c4d-0014-0014-0014-000000000014
# ╟─11a1b3c4d-0015-0015-0015-000000000015
# ╠═11a1b3c4d-0016-0016-0016-000000000016
# ╟─11a1b3c4d-0017-0017-0017-000000000017
# ╟─11a1b3c4d-0018-0018-0018-000000000018
# ╠═11a1b3c4d-0019-0019-0019-000000000019
# ╟─11a1b3c4d-0020-0020-0020-000000000020
# ╟─11a1b3c4d-0021-0021-0021-000000000021
# ╠═11a1b3c4d-0022-0022-0022-000000000022
# ╠═11a1b3c4d-0023-0023-0023-000000000023
# ╠═11a1b3c4d-0024-0024-0024-000000000024
# ╠═11a1b3c4d-0025-0025-0025-000000000025
# ╟─11a1b3c4d-0026-0026-0026-000000000026
# ╟─11a1b3c4d-0027-0027-0027-000000000027
# ╠═11a1b3c4d-0028-0028-0028-000000000028
# ╟─11a1b3c4d-0029-0029-0029-000000000029
# ╠═11a1b3c4d-0030-0030-0030-000000000030
# ╟─11a1b3c4d-0031-0031-0031-000000000031
# ╟─11a1b3c4d-0032-0032-0032-000000000032
# ╠═11a1b3c4d-0033-0033-0033-000000000033
# ╟─11a1b3c4d-0034-0034-0034-000000000034
