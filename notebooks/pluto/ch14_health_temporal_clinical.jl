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

# ╔═╡ 3a1b3c4d-0001-0001-0001-000000000001
begin
	using Pkg
	Pkg.activate(joinpath(@__DIR__, ".."))
	using Gamen
	using PlutoUI
end

# ╔═╡ 3a1b3c4d-0002-0002-0002-000000000002
md"""
# Temporal Logic for Clinical Care Sequencing

This notebook parallels [Chapter 14 of Boxes and Diamonds](https://bd.openlogicproject.org) (Temporal Logics) but applies temporal operators to **clinical care sequencing** -- the ordering of treatments, assessments, and decisions over the course of a patient encounter.

**Key insight**: Clinical care has inherent temporal structure. Treatments must happen in order ("draw cultures *before* starting antibiotics"), conditions must be monitored over time ("*always* reassess statin therapy"), and outcomes must eventually occur ("discharge planning must *eventually* happen"). Temporal logic formalizes "always," "eventually," "before," and "after" -- exactly the temporal language clinicians already use.

### Why temporal logic matters for clinical informatics

When clinical decision support (CDS) systems encode guidelines, they typically represent *what* should happen but not *when*. A rule that fires once ("draw blood cultures") cannot express "blood cultures must be drawn *before* antibiotics are started." Temporal logic gives us a formal language for these sequencing constraints, making them amenable to automated verification.
"""

# ╔═╡ 3a1b3c4d-0003-0003-0003-000000000003
md"""
## Temporal Operators in Clinical Context

Chapter 14 of B&D introduces four unary temporal operators. Each has a natural clinical reading:

| Operator | B&D Name | Gamen.jl | Clinical Reading | Example |
|:---------|:---------|:---------|:-----------------|:--------|
| **G**(p) | "always" (future necessity) | `FutureBox(p)` | "from now on, p must hold at every future time" | "Statin therapy must always be reassessed" |
| **F**(p) | "eventually" (future possibility) | `FutureDiamond(p)` | "at some future time, p will hold" | "Antibiotics must eventually be de-escalated" |
| **H**(p) | "historically" (past necessity) | `PastBox(p)` | "at every past time, p held" | "The patient has always been on this medication" |
| **P**(p) | "previously" (past possibility) | `PastDiamond(p)` | "at some past time, p held" | "Blood cultures were drawn at some prior time" |

These come in dual pairs, just like Box/Diamond:
- **G**(p) = not **F**(not p) -- "p always holds" means "it is never the case that p fails"
- **H**(p) = not **P**(not p) -- "p has always held" means "there was never a time when p failed"
"""

# ╔═╡ 3a1b3c4d-0004-0004-0004-000000000004
md"""
## Building a Temporal Clinical Model

A temporal model M = (T, <, V) consists of:
- **T**: a set of *time points* (moments in the patient encounter)
- **<**: a *precedence relation* (t1 < t2 means t1 comes before t2)
- **V**: a *valuation* assigning clinical facts to time points

In Gamen.jl, `TemporalModel` is simply `KripkeModel` with a temporal reading -- the "worlds" are time points and the "accessibility relation" is temporal precedence.

### Scenario: Inpatient sepsis management

A patient is admitted with suspected sepsis. We model four time points:

- **t1** (admission): initial assessment, blood cultures drawn
- **t2** (day 1): broad-spectrum antibiotics started, labs reviewed
- **t3** (day 3): therapy reassessed based on culture results
- **t4** (discharge): discharge planning complete, antibiotics de-escalated
"""

# ╔═╡ 3a1b3c4d-0005-0005-0005-000000000005
begin
	# Define clinical atoms
	blood_cultures = Atom(:blood_cultures)
	antibiotics = Atom(:antibiotics)
	reassess_therapy = Atom(:reassess_therapy)
	discharge_plan = Atom(:discharge_plan)
	deescalate = Atom(:deescalate)
	labs_reviewed = Atom(:labs_reviewed)
end;

# ╔═╡ 3a1b3c4d-0006-0006-0006-000000000006
begin
	# Build a linear temporal model: t1 → t2 → t3 → t4
	# The precedence relation is: t1 < t2, t2 < t3, t3 < t4
	# (direct successors only -- not transitive closure)
	sepsis_frame = KripkeFrame(
		[:t1, :t2, :t3, :t4],
		[:t1 => :t2, :t2 => :t3, :t3 => :t4]
	)

	sepsis_model = KripkeModel(sepsis_frame, [
		:blood_cultures   => [:t1],            # cultures drawn at admission
		:antibiotics      => [:t2, :t3, :t4],  # antibiotics from day 1 onward
		:reassess_therapy => [:t3],             # therapy reassessed on day 3
		:labs_reviewed    => [:t2, :t3],        # labs reviewed on day 1 and day 3
		:discharge_plan   => [:t4],             # discharge planning at discharge
		:deescalate       => [:t4],             # de-escalation at discharge
	])
end

# ╔═╡ 3a1b3c4d-0007-0007-0007-000000000007
md"""
### The Model Structure

```
t1 (admission)  →  t2 (day 1)  →  t3 (day 3)  →  t4 (discharge)
  cultures           abx             abx, reassess    abx, discharge,
                     labs             labs              de-escalate
```

Note: the precedence relation here has *direct* edges only (t1 to t2, t2 to t3, t3 to t4). This means `FutureDiamond(p)` at t1 only looks at t2 (the direct successor), not t3 or t4. To reason about "eventually in the future" across multiple steps, we would need a *transitive* frame -- we'll explore this below.
"""

# ╔═╡ 3a1b3c4d-0008-0008-0008-000000000008
md"""
## Evaluating Temporal Formulas

Let's check temporal formulas that express real clinical sequencing requirements.
"""

# ╔═╡ 3a1b3c4d-0009-0009-0009-000000000009
begin
	# FutureBox: "always going forward"
	# At t1, is therapy always reassessed in all future time points?
	r1 = satisfies(sepsis_model, :t1, FutureBox(reassess_therapy))

	# FutureDiamond: "eventually"
	# At t1, does discharge planning eventually happen (at a direct successor)?
	r2 = satisfies(sepsis_model, :t1, FutureDiamond(discharge_plan))

	# At t3, does discharge planning eventually happen?
	r3 = satisfies(sepsis_model, :t3, FutureDiamond(discharge_plan))

	md"""
	### Future operators at different time points

	| Formula | Time | Result | Interpretation |
	|:--------|:-----|:-------|:---------------|
	| G(reassess\_therapy) | t1 | **$(r1)** | "Therapy is reassessed at every future time" -- false because t2 has no reassessment |
	| F(discharge\_plan) | t1 | **$(r2)** | "Discharge planning happens at some direct successor of t1" -- false, only t2 is a direct successor and it has no discharge plan |
	| F(discharge\_plan) | t3 | **$(r3)** | "Discharge planning happens at some direct successor of t3" -- true, t4 has discharge planning |

	Notice that F(discharge\_plan) is false at t1 even though discharge planning *does* happen at t4. This is because in a non-transitive frame, F only looks at *direct* successors. The clinical lesson: if we want "eventually" to mean "at some point in the future," we need transitivity.
	"""
end

# ╔═╡ 3a1b3c4d-0010-0010-0010-000000000010
begin
	# PastDiamond: "at some point in the past"
	# At t4 (discharge), were blood cultures drawn at some prior time?
	r4 = satisfies(sepsis_model, :t4, PastDiamond(blood_cultures))

	# At t2, were blood cultures drawn previously?
	r5 = satisfies(sepsis_model, :t2, PastDiamond(blood_cultures))

	# PastBox: "at all past times"
	# At t4, were antibiotics given at every prior time point?
	r6 = satisfies(sepsis_model, :t4, PastBox(antibiotics))

	md"""
	### Past operators

	| Formula | Time | Result | Interpretation |
	|:--------|:-----|:-------|:---------------|
	| P(blood\_cultures) | t4 | **$(r4)** | "Cultures were drawn at some time before discharge" -- only checks direct predecessors (t3); cultures are at t1, not t3, so **false** |
	| P(blood\_cultures) | t2 | **$(r5)** | "Cultures were drawn before day 1" -- t1 is a direct predecessor of t2, and cultures are at t1, so **true** |
	| H(antibiotics) | t4 | **$(r6)** | "Antibiotics were given at every prior time" -- only checks t3 (direct predecessor), and t3 has antibiotics, so **true** |

	Again, the non-transitive frame limits P and H to direct predecessors. In a transitive frame, P(blood\_cultures) at t4 would be true because t1 (with cultures) would be a predecessor of t4.
	"""
end

# ╔═╡ 3a1b3c4d-0011-0011-0011-000000000011
md"""
## Transitive Frames: "Eventually" Means Eventually

Clinical time is naturally transitive: if Monday precedes Tuesday and Tuesday precedes Wednesday, then Monday precedes Wednesday. Let's rebuild our model with a transitive precedence relation.
"""

# ╔═╡ 3a1b3c4d-0012-0012-0012-000000000012
begin
	# Transitive frame: add all transitive edges
	# t1→t2, t1→t3, t1→t4, t2→t3, t2→t4, t3→t4
	sepsis_trans_frame = KripkeFrame(
		[:t1, :t2, :t3, :t4],
		[
			:t1 => :t2, :t1 => :t3, :t1 => :t4,
			:t2 => :t3, :t2 => :t4,
			:t3 => :t4,
		]
	)

	sepsis_trans = KripkeModel(sepsis_trans_frame, [
		:blood_cultures   => [:t1],
		:antibiotics      => [:t2, :t3, :t4],
		:reassess_therapy => [:t3],
		:labs_reviewed    => [:t2, :t3],
		:discharge_plan   => [:t4],
		:deescalate       => [:t4],
	])
end

# ╔═╡ 3a1b3c4d-0013-0013-0013-000000000013
begin
	# Now re-evaluate with the transitive frame
	rt1 = satisfies(sepsis_trans, :t1, FutureDiamond(discharge_plan))
	rt2 = satisfies(sepsis_trans, :t4, PastDiamond(blood_cultures))
	rt3 = satisfies(sepsis_trans, :t1, FutureDiamond(reassess_therapy))
	rt4 = satisfies(sepsis_trans, :t1, FutureBox(antibiotics))

	md"""
	### With transitive precedence

	| Formula | Time | Non-transitive | Transitive | Clinical reading |
	|:--------|:-----|:---------------|:-----------|:-----------------|
	| F(discharge\_plan) | t1 | false | **$(rt1)** | "Discharge planning eventually happens" |
	| P(blood\_cultures) | t4 | false | **$(rt2)** | "Cultures were drawn at some point before discharge" |
	| F(reassess\_therapy) | t1 | false | **$(rt3)** | "Therapy will eventually be reassessed" |
	| G(antibiotics) | t1 | false | **$(rt4)** | "Antibiotics are given at all future times" |

	With transitivity, "eventually" (F) and "previously" (P) work as clinicians expect -- they can see across multiple time steps, not just the immediate next/previous one. This is why **transitivity is the default assumption for clinical temporal reasoning**.
	"""
end

# ╔═╡ 3a1b3c4d-0014-0014-0014-000000000014
md"""
## "Before" as a Temporal Pattern

One of the most common temporal constraints in clinical guidelines is **ordering**: "X must happen before Y." For example:

> *Blood cultures must be drawn before antibiotics are started.*

This cannot be expressed with a single temporal operator. Instead, we encode it as a *pattern*: **at any time point where antibiotics is true, PastDiamond(blood\_cultures) must also be true.**

In other words: whenever we observe antibiotics, there must have been a prior time where cultures were drawn.

Formally: for every time t, if M,t satisfies `antibiotics`, then M,t must also satisfy `P(blood_cultures)`.
"""

# ╔═╡ 3a1b3c4d-0015-0015-0015-000000000015
begin
	# Check the "before" pattern at every time point in the transitive model
	before_results = []
	for t in [:t1, :t2, :t3, :t4]
		has_abx = satisfies(sepsis_trans, t, antibiotics)
		has_prior_cultures = satisfies(sepsis_trans, t, PastDiamond(blood_cultures))
		pattern_holds = !has_abx || has_prior_cultures  # abx → P(cultures)
		push!(before_results,
			(time=t, antibiotics=has_abx,
			 prior_cultures=has_prior_cultures, pattern=pattern_holds))
	end

	md"""
	### "Cultures before antibiotics" check (transitive frame)

	| Time | antibiotics? | P(blood\_cultures)? | abx $\to$ P(cultures) |
	|:-----|:-------------|:--------------------|:----------------------|
	| t1 | $(before_results[1].antibiotics) | $(before_results[1].prior_cultures) | **$(before_results[1].pattern)** (vacuously -- no abx) |
	| t2 | $(before_results[2].antibiotics) | $(before_results[2].prior_cultures) | **$(before_results[2].pattern)** |
	| t3 | $(before_results[3].antibiotics) | $(before_results[3].prior_cultures) | **$(before_results[3].pattern)** |
	| t4 | $(before_results[4].antibiotics) | $(before_results[4].prior_cultures) | **$(before_results[4].pattern)** |

	The pattern holds at every time point: whenever antibiotics are being given, cultures were drawn at a prior time. The ordering constraint is satisfied.

	This is the temporal logic formalization of the Surviving Sepsis Campaign's recommendation: "Obtain blood cultures before starting antimicrobial therapy" (Rhodes et al. 2017).
	"""
end

# ╔═╡ 3a1b3c4d-0016-0016-0016-000000000016
md"""
### What happens when the ordering is violated?

Let's build a model where antibiotics are started *without* prior cultures:
"""

# ╔═╡ 3a1b3c4d-0017-0017-0017-000000000017
begin
	# Violation model: antibiotics at t1, cultures at t2
	# (cultures drawn AFTER antibiotics -- wrong order)
	violation_model = KripkeModel(
		KripkeFrame([:t1, :t2, :t3], [:t1 => :t2, :t1 => :t3, :t2 => :t3]),
		[
			:blood_cultures => [:t2],       # cultures drawn on day 1 (too late)
			:antibiotics    => [:t1, :t2],   # antibiotics started at admission
		]
	)

	# Check the pattern at t1 (where antibiotics are given)
	v_abx = satisfies(violation_model, :t1, antibiotics)
	v_prior = satisfies(violation_model, :t1, PastDiamond(blood_cultures))
	v_pattern = !v_abx || v_prior

	md"""
	At **t1** (admission):
	- antibiotics = **$(v_abx)** (antibiotics started)
	- P(blood\_cultures) = **$(v_prior)** (no prior time with cultures -- t1 has no predecessors)
	- Pattern (abx $\to$ P(cultures)) = **$(v_pattern)**

	The temporal ordering violation is detected: antibiotics were started at a time when no cultures had previously been drawn. This is exactly the kind of sequencing error that temporal logic can catch in clinical decision support systems.
	"""
end

# ╔═╡ 3a1b3c4d-0018-0018-0018-000000000018
md"""
## Interactive Exploration: Clinical Timeline Builder

Use the checkboxes below to toggle which clinical actions happen at each time point. The temporal formula evaluations update automatically.
"""

# ╔═╡ 3a1b3c4d-0019-0019-0019-000000000019
md"""
**t1 (Admission):**
"""

# ╔═╡ 3a1b3c4d-0020-0020-0020-000000000020
md"Blood cultures drawn: $(@bind t1_cultures CheckBox(default=true)) | Antibiotics started: $(@bind t1_abx CheckBox(default=false)) | Reassess therapy: $(@bind t1_reassess CheckBox(default=false)) | Discharge plan: $(@bind t1_discharge CheckBox(default=false))"

# ╔═╡ 3a1b3c4d-0021-0021-0021-000000000021
md"""
**t2 (Day 1):**
"""

# ╔═╡ 3a1b3c4d-0022-0022-0022-000000000022
md"Blood cultures drawn: $(@bind t2_cultures CheckBox(default=false)) | Antibiotics started: $(@bind t2_abx CheckBox(default=true)) | Reassess therapy: $(@bind t2_reassess CheckBox(default=false)) | Discharge plan: $(@bind t2_discharge CheckBox(default=false))"

# ╔═╡ 3a1b3c4d-0023-0023-0023-000000000023
md"""
**t3 (Day 3):**
"""

# ╔═╡ 3a1b3c4d-0024-0024-0024-000000000024
md"Blood cultures drawn: $(@bind t3_cultures CheckBox(default=false)) | Antibiotics started: $(@bind t3_abx CheckBox(default=true)) | Reassess therapy: $(@bind t3_reassess CheckBox(default=true)) | Discharge plan: $(@bind t3_discharge CheckBox(default=false))"

# ╔═╡ 3a1b3c4d-0025-0025-0025-000000000025
md"""
**t4 (Discharge):**
"""

# ╔═╡ 3a1b3c4d-0026-0026-0026-000000000026
md"Blood cultures drawn: $(@bind t4_cultures CheckBox(default=false)) | Antibiotics started: $(@bind t4_abx CheckBox(default=false)) | Reassess therapy: $(@bind t4_reassess CheckBox(default=false)) | Discharge plan: $(@bind t4_discharge CheckBox(default=true))"

# ╔═╡ 3a1b3c4d-0027-0027-0027-000000000027
begin
	# Build the interactive model from checkbox state (transitive frame)
	interactive_frame = KripkeFrame(
		[:t1, :t2, :t3, :t4],
		[:t1 => :t2, :t1 => :t3, :t1 => :t4,
		 :t2 => :t3, :t2 => :t4,
		 :t3 => :t4]
	)

	# Collect valuations from checkboxes
	v_cultures = Symbol[]
	v_abx = Symbol[]
	v_reassess = Symbol[]
	v_discharge = Symbol[]

	t1_cultures  && push!(v_cultures, :t1)
	t2_cultures  && push!(v_cultures, :t2)
	t3_cultures  && push!(v_cultures, :t3)
	t4_cultures  && push!(v_cultures, :t4)

	t1_abx       && push!(v_abx, :t1)
	t2_abx       && push!(v_abx, :t2)
	t3_abx       && push!(v_abx, :t3)
	t4_abx       && push!(v_abx, :t4)

	t1_reassess  && push!(v_reassess, :t1)
	t2_reassess  && push!(v_reassess, :t2)
	t3_reassess  && push!(v_reassess, :t3)
	t4_reassess  && push!(v_reassess, :t4)

	t1_discharge && push!(v_discharge, :t1)
	t2_discharge && push!(v_discharge, :t2)
	t3_discharge && push!(v_discharge, :t3)
	t4_discharge && push!(v_discharge, :t4)

	interactive_model = KripkeModel(interactive_frame, [
		:blood_cultures   => v_cultures,
		:antibiotics      => v_abx,
		:reassess_therapy => v_reassess,
		:discharge_plan   => v_discharge,
	])

	# Evaluate temporal formulas
	i_f_discharge = satisfies(interactive_model, :t1, FutureDiamond(discharge_plan))
	i_g_reassess = satisfies(interactive_model, :t1, FutureBox(reassess_therapy))
	i_f_reassess = satisfies(interactive_model, :t1, FutureDiamond(reassess_therapy))
	i_p_cultures_t4 = satisfies(interactive_model, :t4, PastDiamond(blood_cultures))

	# Check "cultures before antibiotics" pattern at every time
	i_before_ok = all([:t1, :t2, :t3, :t4]) do t
		has_abx = satisfies(interactive_model, t, antibiotics)
		has_prior = satisfies(interactive_model, t, PastDiamond(blood_cultures))
		!has_abx || has_prior
	end

	md"""
	### Temporal Formula Evaluations

	| Formula | Evaluation | Clinical Meaning |
	|:--------|:-----------|:-----------------|
	| F(discharge\_plan) at t1 | **$(i_f_discharge)** | Discharge planning eventually happens |
	| G(reassess\_therapy) at t1 | **$(i_g_reassess)** | Therapy is reassessed at *every* future time |
	| F(reassess\_therapy) at t1 | **$(i_f_reassess)** | Therapy is reassessed at *some* future time |
	| P(blood\_cultures) at t4 | **$(i_p_cultures_t4)** | Cultures were drawn at some time before discharge |
	| cultures before abx (all times) | **$(i_before_ok)** | Whenever abx are given, cultures were previously drawn |

	Toggle the checkboxes to explore:
	- What happens if you start antibiotics at t1 without cultures? (The "before" pattern fails.)
	- What if you never reassess therapy? (F(reassess\_therapy) becomes false.)
	- What if discharge planning happens at t2 instead of t4? (F(discharge\_plan) still holds.)
	"""
end

# ╔═╡ 3a1b3c4d-0028-0028-0028-000000000028
md"""
## Frame Properties for Clinical Time

Chapter 14 (Table 14.1) catalogs frame properties that constrain the precedence relation. Several are directly relevant to clinical time.
"""

# ╔═╡ 3a1b3c4d-0029-0029-0029-000000000029
begin
	# Demonstrate frame properties
	linear_trans_frame = KripkeFrame(
		[:t1, :t2, :t3],
		[:t1 => :t2, :t1 => :t3, :t2 => :t3]
	)

	branching_frame = KripkeFrame(
		[:t1, :t2, :t3],
		[:t1 => :t2, :t1 => :t3]  # t2 and t3 are incomparable
	)

	non_trans_frame = KripkeFrame(
		[:t1, :t2, :t3],
		[:t1 => :t2, :t2 => :t3]
	)

	md"""
	### Transitivity

	If t1 precedes t2 and t2 precedes t3, then t1 precedes t3. This is the most fundamental property for clinical time -- if the admission comes before day 1 and day 1 comes before day 3, then the admission comes before day 3.

	- Linear transitive frame: `is_transitive_frame` = **$(is_transitive_frame(linear_trans_frame))**
	- Non-transitive frame (t1 to t2 to t3, but no t1 to t3): `is_transitive_frame` = **$(is_transitive_frame(non_trans_frame))**

	Transitivity validates the formula FFp $\to$ Fp: if p will hold in the future's future, then (with transitivity) p holds in the future directly.

	### Linearity

	For any two distinct time points, one precedes the other. Clinical time within a single patient encounter is linear -- events don't happen on parallel timelines.

	- Linear frame (t1 < t2 < t3): `is_linear_frame` = **$(is_linear_frame(linear_trans_frame))**
	- Branching frame (t1 < t2 and t1 < t3, but t2 and t3 incomparable): `is_linear_frame` = **$(is_linear_frame(branching_frame))**

	Branching time arises in *treatment decision modeling* -- when we consider alternative treatment paths that could be taken. But once a treatment is chosen, the actual clinical timeline is linear.
	"""
end

# ╔═╡ 3a1b3c4d-0030-0030-0030-000000000030
begin
	# Dense and unbounded frames
	dense_f = KripkeFrame([:t1, :t2, :t3],
		[:t1 => :t2, :t2 => :t3, :t1 => :t3, :t2 => :t2])
	sparse_f = KripkeFrame([:t1, :t2], [:t1 => :t2])

	cyclic_f = KripkeFrame([:t1, :t2, :t3],
		[:t1 => :t2, :t2 => :t3, :t3 => :t1,
		 :t1 => :t3, :t2 => :t1, :t3 => :t2])

	md"""
	### Density and Boundedness

	**Density** (between any two related points, there is another):
	- Dense frame: `is_dense_frame` = **$(is_dense_frame(dense_f))**
	- Sparse (discrete) frame: `is_dense_frame` = **$(is_dense_frame(sparse_f))**

	Clinical time is typically *discrete* (measured in days, hours, shifts) rather than dense. Density validates Fp $\to$ FFp.

	**Unbounded future** (every time has a successor):
	- Bounded frame: `is_unbounded_future` = **$(is_unbounded_future(sparse_f))**
	- Cyclic frame: `is_unbounded_future` = **$(is_unbounded_future(cyclic_f))**

	A bounded future is natural for patient encounters -- there is a final time point (discharge or death). At that endpoint, G(p) is vacuously true (no future to check) but F(p) is false for any p (no future exists).

	**Unbounded past** (every time has a predecessor):
	- Bounded frame: `is_unbounded_past` = **$(is_unbounded_past(sparse_f))**

	Similarly, there is an earliest time (admission), so clinical frames have bounded past.
	"""
end

# ╔═╡ 3a1b3c4d-0031-0031-0031-000000000031
md"""
### Frame Properties Summary for Clinical Time

| Property | Clinical time? | Why |
|:---------|:---------------|:----|
| Transitive | Yes | If t1 < t2 and t2 < t3, then t1 < t3 |
| Linear | Yes (single encounter) | Events are totally ordered within one patient timeline |
| Dense | No (usually) | Clinical time is discrete (days, hours, shifts) |
| Unbounded future | No | Patient encounters end (discharge) |
| Unbounded past | No | Patient encounters begin (admission) |

This means clinical temporal frames are typically **finite linear orders** -- transitive, linear, with a first and last element. This is a strong structural constraint that simplifies reasoning.
"""

# ╔═╡ 3a1b3c4d-0032-0032-0032-000000000032
md"""
## Duality in Clinical Context

The temporal duality G(p) = not F(not p) has a direct clinical reading:

- "Therapy is **always** reassessed" = "There is **never** a time when therapy is **not** reassessed"
- G(reassess) = not F(not reassess)

Let's verify duality holds across our transitive model:
"""

# ╔═╡ 3a1b3c4d-0033-0033-0033-000000000033
begin
	duality_checks = []
	for t in [:t1, :t2, :t3, :t4]
		ga = satisfies(sepsis_trans, t, FutureBox(reassess_therapy))
		dual = !satisfies(sepsis_trans, t, FutureDiamond(Not(reassess_therapy)))
		push!(duality_checks,
			(time=t, G_reassess=ga, not_F_not_reassess=dual, match=(ga == dual)))
	end

	md"""
	| Time | G(reassess) | not F(not reassess) | Match? |
	|:-----|:------------|:--------------------|:-------|
	| t1 | $(duality_checks[1].G_reassess) | $(duality_checks[1].not_F_not_reassess) | $(duality_checks[1].match) |
	| t2 | $(duality_checks[2].G_reassess) | $(duality_checks[2].not_F_not_reassess) | $(duality_checks[2].match) |
	| t3 | $(duality_checks[3].G_reassess) | $(duality_checks[3].not_F_not_reassess) | $(duality_checks[3].match) |
	| t4 | $(duality_checks[4].G_reassess) | $(duality_checks[4].not_F_not_reassess) | $(duality_checks[4].match) |

	Duality holds at every time point. Note that at t4 (discharge, no successors), G(reassess) is vacuously true -- there are no future times to check.
	"""
end

# ╔═╡ 3a1b3c4d-0034-0034-0034-000000000034
md"""
## Summary: B&D Temporal Concepts in Clinical Interpretation

| B&D Concept (Ch 14) | Gamen.jl | Clinical Interpretation |
|:---------------------|:---------|:-----------------------|
| Time point t | World in `KripkeModel` | A moment in the patient encounter (admission, day 1, discharge) |
| Precedence t1 < t2 | `t1 => t2` in frame | t1 comes before t2 in the clinical timeline |
| G(p) -- "always" | `FutureBox(p)` | "p holds at every future time" -- e.g., "always reassess therapy" |
| F(p) -- "eventually" | `FutureDiamond(p)` | "p holds at some future time" -- e.g., "eventually de-escalate" |
| H(p) -- "historically" | `PastBox(p)` | "p held at every past time" -- e.g., "patient has always been on this med" |
| P(p) -- "previously" | `PastDiamond(p)` | "p held at some past time" -- e.g., "cultures were drawn before now" |
| Transitivity | `is_transitive_frame` | Natural for clinical time -- past of the past is still in the past |
| Linearity | `is_linear_frame` | Clinical encounters follow a single timeline |
| "X before Y" pattern | abx $\to$ P(cultures) | At every time with Y, X was previously true |
| Vacuous truth at endpoints | G(p) true at discharge | No future times to violate -- important edge case for CDS |
"""

# ╔═╡ 3a1b3c4d-0035-0035-0035-000000000035
md"""
## What's Next

- **Combined deontic-temporal reasoning**: Clinical guidelines involve both obligation ("must") and time ("before," "within 24 hours"). The notebook `ext_deontic_temporal.jl` combines deontic operators (Chapter 1) with temporal operators (Chapter 14) to formalize guidelines like "blood cultures *must* be drawn *before* antibiotics are started" -- where "must" is a deontic obligation and "before" is a temporal constraint.
- **Epistemic logic** (Chapter 15 health parallel): What does the clinician *know* at each time point? Information changes over time -- culture results arrive, labs are reviewed. Combining temporal and epistemic logic models how clinical knowledge evolves.
"""

# ╔═╡ Cell order:
# ╟─3a1b3c4d-0002-0002-0002-000000000002
# ╠═3a1b3c4d-0001-0001-0001-000000000001
# ╟─3a1b3c4d-0003-0003-0003-000000000003
# ╟─3a1b3c4d-0004-0004-0004-000000000004
# ╠═3a1b3c4d-0005-0005-0005-000000000005
# ╠═3a1b3c4d-0006-0006-0006-000000000006
# ╟─3a1b3c4d-0007-0007-0007-000000000007
# ╟─3a1b3c4d-0008-0008-0008-000000000008
# ╠═3a1b3c4d-0009-0009-0009-000000000009
# ╠═3a1b3c4d-0010-0010-0010-000000000010
# ╟─3a1b3c4d-0011-0011-0011-000000000011
# ╠═3a1b3c4d-0012-0012-0012-000000000012
# ╠═3a1b3c4d-0013-0013-0013-000000000013
# ╟─3a1b3c4d-0014-0014-0014-000000000014
# ╠═3a1b3c4d-0015-0015-0015-000000000015
# ╟─3a1b3c4d-0016-0016-0016-000000000016
# ╠═3a1b3c4d-0017-0017-0017-000000000017
# ╟─3a1b3c4d-0018-0018-0018-000000000018
# ╟─3a1b3c4d-0019-0019-0019-000000000019
# ╠═3a1b3c4d-0020-0020-0020-000000000020
# ╟─3a1b3c4d-0021-0021-0021-000000000021
# ╠═3a1b3c4d-0022-0022-0022-000000000022
# ╟─3a1b3c4d-0023-0023-0023-000000000023
# ╠═3a1b3c4d-0024-0024-0024-000000000024
# ╟─3a1b3c4d-0025-0025-0025-000000000025
# ╠═3a1b3c4d-0026-0026-0026-000000000026
# ╠═3a1b3c4d-0027-0027-0027-000000000027
# ╟─3a1b3c4d-0028-0028-0028-000000000028
# ╠═3a1b3c4d-0029-0029-0029-000000000029
# ╠═3a1b3c4d-0030-0030-0030-000000000030
# ╟─3a1b3c4d-0031-0031-0031-000000000031
# ╟─3a1b3c4d-0032-0032-0032-000000000032
# ╠═3a1b3c4d-0033-0033-0033-000000000033
# ╟─3a1b3c4d-0034-0034-0034-000000000034
# ╟─3a1b3c4d-0035-0035-0035-000000000035
