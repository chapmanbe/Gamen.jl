### A Pluto.jl notebook ###
# v0.20.4

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

# ╔═╡ 10a1b3c4d-0001-0001-0001-000000000001
md"""
# Decidability of Guideline Checking

Can a computer *always* determine whether a set of clinical guidelines is consistent? The answer is **yes** -- for the modal logics we use, the problem is **decidable**. There is an algorithm that is guaranteed to terminate with the correct answer for any finite set of guidelines.

This notebook parallels [Chapter 5 of Boxes and Diamonds](https://bd.openlogicproject.org) (Filtrations and Decidability), applied to automated guideline checking. We cover:

1. The **finite model property** -- why a finite search always suffices
2. **Decidability** -- the existence of a terminating algorithm
3. The **computational cost** -- why brute force is expensive and what that means in practice
4. **Filtrations** -- the theoretical tool that collapses irrelevant clinical scenarios
5. **Tableaux** as the practical decision procedure
"""

# ╔═╡ 10a1b3c4d-0002-0002-0002-000000000002
begin
	using Pkg
	Pkg.activate(joinpath(@__DIR__, ".."))
	using Gamen
	using PlutoUI
end

# ╔═╡ 10a1b3c4d-0003-0003-0003-000000000003
begin
	consent = Atom(:consent)
	cultures = Atom(:blood_cultures)
	antibiotics = Atom(:antibiotics)
	thrombolytic = Atom(:thrombolytic)
	bleeding = Atom(:active_bleeding)
	discharge = Atom(:discharge_plan)
	p = Atom(:p)
	q = Atom(:q)
end;

# ╔═╡ 10a1b3c4d-0004-0004-0004-000000000004
md"""
## The Finite Model Property

A logic has the **finite model property** (FMP) if every satisfiable formula is satisfiable in a *finite* model. Both K and KD (the logic of clinical guidelines) have this property.

**Clinical meaning**: when checking whether a set of guidelines is consistent, we never need to consider infinitely many clinical scenarios. A finite search through finite models always suffices. If there is any way to satisfy the guidelines simultaneously, there is a *finite* model that demonstrates it.
"""

# ╔═╡ 10a1b3c4d-0005-0005-0005-000000000005
md"""
### Example: Finite Countermodels

The formula `Box(consent) -> consent` ("if consent is obligatory, then consent is actually obtained") is not valid in K -- it requires reflexivity. The FMP guarantees a finite countermodel exists:
"""

# ╔═╡ 10a1b3c4d-0006-0006-0006-000000000006
begin
	fmp_k = has_finite_model_property(SYSTEM_K, Implies(Box(consent), consent))
	fmp_s5 = has_finite_model_property(SYSTEM_S5, Implies(Box(consent), consent))
	(K_has_FMP = fmp_k, S5_has_FMP = fmp_s5)
end

# ╔═╡ 10a1b3c4d-0007-0007-0007-000000000007
md"""
Both return `true`: K has the FMP because it imposes no frame conditions (Proposition 5.14, B&D), and S5 has it because filtrations preserve the equivalence-relation structure (Corollary 5.16).
"""

# ╔═╡ 10a1b3c4d-0008-0008-0008-000000000008
md"""
## Decidability

The FMP gives us decidability directly: given a formula A with n subformulas, any filtration has at most 2^n worlds (Proposition 5.12, B&D). So we can check all models up to that size. If A is satisfiable, we find a model; if not, we exhaustively confirm there is none. Either way, the algorithm **terminates**.

This is a remarkable guarantee. First-order logic, by contrast, is *undecidable* -- there is no algorithm that can always determine whether a first-order sentence is valid. Modal logic's decidability is one reason it is well-suited to automated guideline checking.
"""

# ╔═╡ 10a1b3c4d-0009-0009-0009-000000000009
md"""
### Decidability in Action

The function `is_decidable_within` checks validity by exhaustive search over finite models up to the bound implied by the subformula count:
"""

# ╔═╡ 10a1b3c4d-0010-0010-0010-000000000010
begin
	# The K axiom: □(p -> q) -> (□p -> □q) -- valid in K
	k_axiom = Implies(Box(Implies(p, q)), Implies(Box(p), Box(q)))
	result_k = is_decidable_within(SYSTEM_K, k_axiom)
	(formula = "K axiom", valid = result_k.valid,
	 subformulas = result_k.subformula_count, bound = result_k.bound)
end

# ╔═╡ 10a1b3c4d-0011-0011-0011-000000000011
begin
	# □(consent) -> consent -- NOT valid in K (needs reflexivity)
	t_schema = Implies(Box(consent), consent)
	result_t = is_decidable_within(SYSTEM_K, t_schema)
	(formula = "T schema", valid_in_K = result_t.valid,
	 subformulas = result_t.subformula_count, bound = result_t.bound)
end

# ╔═╡ 10a1b3c4d-0012-0012-0012-000000000012
begin
	# Same formula IS valid in KT (which has reflexivity)
	result_kt = is_decidable_within(SYSTEM_KT, t_schema)
	(formula = "T schema in KT", valid_in_KT = result_kt.valid)
end

# ╔═╡ 10a1b3c4d-0013-0013-0013-000000000013
md"""
## The Cost of Decidability

Decidability is a *theoretical* guarantee -- it says an algorithm exists. It says nothing about how fast that algorithm runs. The brute-force approach (enumerate all frames and valuations) is **O(2^(n^2))** where n is the number of worlds, because the accessibility relation is a binary relation on n worlds (n^2 possible edges, each present or absent).

The table below shows why this matters:

| max\_worlds | Frames enumerated | Time estimate |
|:-----------|:-----------------|:-------------|
| 4 | 2^16 = 65,536 | seconds |
| 5 | 2^25 = 33,554,432 | minutes to hours |
| 6 | 2^36 ~ 69 billion | days |
| 16 | 2^256 | more than atoms in the universe |

Gamen.jl caps `max_worlds` at 4 for brute-force search. This is not a bug -- it is a fundamental complexity bound.
"""

# ╔═╡ 10a1b3c4d-0014-0014-0014-000000000014
md"""
### Interactive: Exponential Blowup

Use the slider to see how quickly frame counts explode:
"""

# ╔═╡ 10a1b3c4d-0015-0015-0015-000000000015
@bind n_worlds Slider(1:10, default=4, show_value=true)

# ╔═╡ 10a1b3c4d-0016-0016-0016-000000000016
begin
	n_edges = n_worlds^2
	n_frames = BigInt(2)^n_edges
	md"""
	**$(n_worlds) worlds** --> $(n_edges) possible edges --> **$(n_frames) frames** to enumerate

	$(n_worlds <= 4 ? "Feasible for brute-force search." : n_worlds <= 5 ? "Borderline -- will take minutes." : "Infeasible for brute-force enumeration. Tableaux required.")
	"""
end

# ╔═╡ 10a1b3c4d-0017-0017-0017-000000000017
md"""
## Consistency Checking for Guidelines

The `is_consistent` function checks whether a set of formulas can all be satisfied simultaneously in a model of the given system. For clinical guidelines, this is the core question: **can all the guidelines be followed at once?**
"""

# ╔═╡ 10a1b3c4d-0018-0018-0018-000000000018
begin
	# Two compatible guidelines
	g1 = Box(consent)                          # must obtain consent
	g2 = Diamond(antibiotics)                  # may give antibiotics
	compatible = is_consistent(SYSTEM_KD, [g1, g2])

	# Two conflicting guidelines
	g3 = Box(discharge)                        # must plan discharge
	g4 = Box(Not(discharge))                   # must NOT plan discharge
	conflicting = is_consistent(SYSTEM_KD, [g3, g4])

	(compatible_guidelines = compatible, conflicting_guidelines = conflicting)
end

# ╔═╡ 10a1b3c4d-0019-0019-0019-000000000019
md"""
The first pair is consistent -- there exists a model where consent is obligatory and antibiotics are permitted. The second pair is inconsistent -- no model can make both `Box(discharge)` and `Box(Not(discharge))` true at the same world (assuming at least one accessible world, which KD guarantees via the D axiom).
"""

# ╔═╡ 10a1b3c4d-0020-0020-0020-000000000020
md"""
### Interactive: Pick Guidelines to Check

Select which guidelines to include and see whether they are jointly consistent:
"""

# ╔═╡ 10a1b3c4d-0021-0021-0021-000000000021
begin
	md"""
	Include G1 -- "must obtain consent" (Box(consent)): $(@bind inc_g1 CheckBox(default=true))

	Include G2 -- "may give antibiotics" (Diamond(antibiotics)): $(@bind inc_g2 CheckBox(default=true))

	Include G3 -- "must plan discharge" (Box(discharge)): $(@bind inc_g3 CheckBox(default=false))

	Include G4 -- "must NOT plan discharge" (Box(Not(discharge))): $(@bind inc_g4 CheckBox(default=false))

	Include G5 -- "if bleeding, must not give thrombolytics": $(@bind inc_g5 CheckBox(default=false))
	"""
end

# ╔═╡ 10a1b3c4d-0022-0022-0022-000000000022
begin
	selected_formulas = Formula[]
	selected_names = String[]
	if inc_g1
		push!(selected_formulas, Box(consent))
		push!(selected_names, "Box(consent)")
	end
	if inc_g2
		push!(selected_formulas, Diamond(antibiotics))
		push!(selected_names, "Diamond(antibiotics)")
	end
	if inc_g3
		push!(selected_formulas, Box(discharge))
		push!(selected_names, "Box(discharge)")
	end
	if inc_g4
		push!(selected_formulas, Box(Not(discharge)))
		push!(selected_names, "Box(Not(discharge))")
	end
	if inc_g5
		push!(selected_formulas, Implies(bleeding, Box(Not(thrombolytic))))
		push!(selected_names, "bleeding -> Box(Not(thrombolytic))")
	end

	if isempty(selected_formulas)
		md"*Select at least one guideline above.*"
	else
		consistent = is_consistent(SYSTEM_KD, selected_formulas)
		status = consistent ? "**Consistent** -- these guidelines can all be satisfied simultaneously." : "**Inconsistent** -- no model in KD satisfies all of these guidelines at once."
		md"""
		### Checking $(length(selected_formulas)) guideline(s):
		$(join(["- " * n for n in selected_names], "\n"))

		Result: $(status)
		"""
	end
end

# ╔═╡ 10a1b3c4d-0023-0023-0023-000000000023
md"""
## Practical Implications

For clinical guidelines involving a handful of propositions (3-5 atomic facts), decidability is not a practical problem. The brute-force search terminates in seconds for models with up to 4 worlds.

But real guideline sets can involve dozens of recommendations, each mentioning several clinical variables. With 20 atomic propositions, the subformula closure of a complex guideline formula could have 50+ elements, requiring models with up to 2^50 worlds -- far beyond brute force.

This is why we need smarter algorithms.
"""

# ╔═╡ 10a1b3c4d-0024-0024-0024-000000000024
md"""
## Tableaux as a Practical Decision Procedure

The **tableau method** (Chapter 6) implements decidability without enumerating all frames. Instead of asking "is there *any* model that satisfies these formulas?", a tableau asks "can I derive a contradiction from assuming they are all true?"

The tableau:
1. Assumes all guidelines hold at some world
2. Applies decomposition rules (breaking formulas into subformulas)
3. Applies modal rules (creating new worlds as needed)
4. Checks for contradictions (a proposition and its negation at the same world)

If every branch closes (contradiction found), the guidelines are **inconsistent**. If some branch stays open, the open branch *describes* a satisfying model.

**Key advantage**: the tableau often terminates much faster than brute force because it prunes branches early. It does not enumerate all possible frames -- it builds only the structure it needs.

See the [Chapter 6 notebook](ch6_tableaux.jl) for the full tableau treatment.
"""

# ╔═╡ 10a1b3c4d-0025-0025-0025-000000000025
md"""
## Filtrations: The Theoretical Engine

The decidability proof relies on **filtrations** -- a technique for collapsing a potentially infinite model into a finite one while preserving truth of all relevant formulas.

### The Idea

Given a model M and a finite set of formulas Gamma (typically the subformulas of the formula we are checking), a filtration identifies ("collapses") worlds that agree on every formula in Gamma. If two worlds make exactly the same formulas from Gamma true, they are **Gamma-equivalent** and get merged into a single equivalence class.

### The Clinical Analogy

Consider a hospital with thousands of patients. For a guideline about anticoagulation, only a few clinical facts matter: is the patient on warfarin? Is the INR above 3? Is there active bleeding? Two patients who agree on these facts are *equivalent with respect to this guideline*, even if they differ in age, weight, diagnosis, and a thousand other variables.

Filtration captures exactly this: irrelevant clinical details are collapsed away, leaving only the distinctions that matter for the formulas in question.
"""

# ╔═╡ 10a1b3c4d-0026-0026-0026-000000000026
begin
	# Demonstrate filtration collapsing equivalent worlds
	frame_big = KripkeFrame(
		[:s1, :s2, :s3, :s4],
		[:s1 => :s2, :s1 => :s3, :s1 => :s4]
	)
	# s2 and s3 agree on consent (both true); s4 differs
	model_big = KripkeModel(frame_big, [:consent => [:s1, :s2, :s3]])

	gamma = subformula_closure(Box(consent))
	classes = equivalence_classes(model_big, gamma)
	filt = finest_filtration(model_big, gamma)

	(original_worlds = length(model_big.frame.worlds),
	 equivalence_classes = length(classes),
	 filtration_preserves_truth = filtration_lemma_holds(filt))
end

# ╔═╡ 10a1b3c4d-0027-0027-0027-000000000027
md"""
Four clinical scenarios collapsed to $(length(classes)) equivalence classes. Worlds s2 and s3 were equivalent with respect to `{consent, Box(consent)}` -- they agreed on all relevant formulas -- so the filtration merged them. The **Filtration Lemma** (Theorem 5.5, B&D) guarantees that truth is preserved: `Box(consent)` is true at s1 in the original model if and only if it is true at the corresponding class in the filtration.
"""

# ╔═╡ 10a1b3c4d-0028-0028-0028-000000000028
md"""
### The Finiteness Bound

If Gamma has n formulas, the filtration has at most **2^n** equivalence classes -- one for each possible truth-value assignment to the n formulas. For a guideline formula with 5 subformulas, that means at most 32 worlds in the filtrated model, regardless of how many patients (worlds) the original model had.
"""

# ╔═╡ 10a1b3c4d-0029-0029-0029-000000000029
begin
	phi = And(Box(consent), Diamond(antibiotics))
	gamma2 = subformula_closure(phi)
	n_sub = length(gamma2)
	(formula_subformulas = n_sub, max_filtration_worlds = 2^n_sub)
end

# ╔═╡ 10a1b3c4d-0030-0030-0030-000000000030
md"""
## Summary

| Concept | Meaning for Guideline Checking |
|:--------|:-------------------------------|
| Finite model property | If guidelines are satisfiable at all, they are satisfiable in a finite model |
| Decidability | An algorithm always terminates with the correct consistency verdict |
| 2^n bound | The maximum model size needed, where n = number of subformulas |
| O(2^(n^2)) brute force | Enumerating all frames is feasible only for tiny problems (max 4 worlds) |
| Filtration | Collapses irrelevant clinical distinctions, reducing model size |
| Tableau method | The practical decision procedure -- prunes early, avoids exhaustive enumeration |

**The bottom line**: decidability guarantees that automated guideline checking always terminates. The finite model property is the theoretical foundation. For practical performance on real guideline sets, the tableau method (Chapter 6) is essential -- it delivers the same guarantee without the exponential cost of brute-force enumeration.
"""

# ╔═╡ Cell order:
# ╟─10a1b3c4d-0001-0001-0001-000000000001
# ╠═10a1b3c4d-0002-0002-0002-000000000002
# ╠═10a1b3c4d-0003-0003-0003-000000000003
# ╟─10a1b3c4d-0004-0004-0004-000000000004
# ╟─10a1b3c4d-0005-0005-0005-000000000005
# ╠═10a1b3c4d-0006-0006-0006-000000000006
# ╟─10a1b3c4d-0007-0007-0007-000000000007
# ╟─10a1b3c4d-0008-0008-0008-000000000008
# ╟─10a1b3c4d-0009-0009-0009-000000000009
# ╠═10a1b3c4d-0010-0010-0010-000000000010
# ╠═10a1b3c4d-0011-0011-0011-000000000011
# ╠═10a1b3c4d-0012-0012-0012-000000000012
# ╟─10a1b3c4d-0013-0013-0013-000000000013
# ╟─10a1b3c4d-0014-0014-0014-000000000014
# ╠═10a1b3c4d-0015-0015-0015-000000000015
# ╠═10a1b3c4d-0016-0016-0016-000000000016
# ╟─10a1b3c4d-0017-0017-0017-000000000017
# ╠═10a1b3c4d-0018-0018-0018-000000000018
# ╟─10a1b3c4d-0019-0019-0019-000000000019
# ╟─10a1b3c4d-0020-0020-0020-000000000020
# ╠═10a1b3c4d-0021-0021-0021-000000000021
# ╠═10a1b3c4d-0022-0022-0022-000000000022
# ╟─10a1b3c4d-0023-0023-0023-000000000023
# ╟─10a1b3c4d-0024-0024-0024-000000000024
# ╟─10a1b3c4d-0025-0025-0025-000000000025
# ╠═10a1b3c4d-0026-0026-0026-000000000026
# ╟─10a1b3c4d-0027-0027-0027-000000000027
# ╟─10a1b3c4d-0028-0028-0028-000000000028
# ╠═10a1b3c4d-0029-0029-0029-000000000029
# ╟─10a1b3c4d-0030-0030-0030-000000000030
