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

# ╔═╡ 4a1b3c4d-0001-0001-0001-000000000001
md"""
# Epistemic Logic in Clinical Settings

This notebook parallels [Chapter 15 of Boxes and Diamonds](https://bd.openlogicproject.org) but applies **epistemic logic** to healthcare scenarios -- clinical knowledge, information asymmetry, and patient safety.

**Key insight**: Healthcare involves multiple agents with different knowledge -- the attending physician, the consulting specialist, the nurse, the patient, the EHR system. Epistemic logic formalizes "who knows what" and "what is common knowledge." When these knowledge states diverge, patient safety is at risk.

### Why This Matters

The Joint Commission identifies **communication failures** as the leading root cause of sentinel events. Handoff errors, unread chart notes, and siloed information are epistemic problems: they arise when one agent lacks knowledge that another agent has. Formalizing clinical knowledge with epistemic logic lets us reason precisely about:

- What each member of the care team knows
- What information is lost during handoffs
- When a public announcement (safety briefing, chart review) resolves a knowledge gap
- Whether a critical fact is truly **common knowledge** across the team
"""

# ╔═╡ 4a1b3c4d-0002-0002-0002-000000000002
begin
	using Pkg
	Pkg.activate(joinpath(@__DIR__, ".."))
	using Gamen
	using PlutoUI
end

# ╔═╡ 4a1b3c4d-0003-0003-0003-000000000003
md"""
## Agents and Knowledge in Clinical Settings

In B&D Chapter 15, the knowledge operator K_a A reads "agent a knows A." In a clinical setting, agents are members of the care team, and the propositions are clinical facts.

| Epistemic Formula | Clinical Reading |
|:-----------------|:-----------------|
| K\_physician(diagnosis) | "The physician knows the diagnosis" |
| K\_nurse(allergy) | "The nurse knows the patient's allergy" |
| K\_patient(treatment\_plan) | "The patient knows the treatment plan" |
| K\_ehr(lab\_result) | "The EHR system has the lab result" |
| E\_{care\_team}(code\_status) | "Everyone on the care team knows the code status" (group knowledge) |
| C\_{care\_team}(code\_status) | "The code status is common knowledge" (everyone knows, everyone knows everyone knows, ...) |

The distinction between **group knowledge** and **common knowledge** is clinically critical. During a cardiac arrest, it is not enough that every nurse individually knows the code status -- the team must know that *everyone* knows, so they can coordinate without re-confirming.
"""

# ╔═╡ 4a1b3c4d-0004-0004-0004-000000000004
md"""
## Building an Epistemic Clinical Model

### Scenario: Penicillin Allergy Documentation

A patient has a **penicillin allergy** documented in the EHR. The attending physician has reviewed the chart. The nurse has not yet checked the allergy section.

**Worlds:**
- **w1**: Actual world -- patient has the allergy, it is documented in the chart
- **w2**: World consistent with the nurse's uncertainty -- allergy status unknown
- **w3**: World where no allergy exists (also consistent with the nurse's information)

**Agents:**
- `:physician` -- has reviewed the chart, knows the allergy status
- `:nurse` -- has not checked the chart, cannot distinguish w1 from w2 or w3
"""

# ╔═╡ 4a1b3c4d-0005-0005-0005-000000000005
begin
	# Define propositions
	allergy = Atom(:allergy)
	documented = Atom(:documented)
	penicillin_ordered = Atom(:penicillin_ordered)

	# Build the epistemic frame (Definition 15.4, B&D)
	allergy_frame = EpistemicFrame(
		[:w1, :w2, :w3],
		[:physician => [:w1 => :w1],
		 :nurse     => [:w1 => :w1, :w1 => :w2, :w1 => :w3]]
	)

	# Build the model with valuation
	allergy_model = EpistemicModel(allergy_frame, [
		:allergy    => [:w1, :w2],    # allergy present in w1, w2
		:documented => [:w1],          # documented only in w1 (actual world)
	])

	println("Worlds: ", sort(collect(allergy_frame.worlds)))
	println("Agents: ", sort(collect(agents(allergy_frame))))
	println("Physician sees from w1: ", sort(collect(accessible(allergy_frame, :physician, :w1))))
	println("Nurse sees from w1:     ", sort(collect(accessible(allergy_frame, :nurse, :w1))))
end

# ╔═╡ 4a1b3c4d-0006-0006-0006-000000000006
md"""
### Reading the Model

The physician's accessibility relation from w1 is {w1} -- the physician can only "see" the actual world. This means the physician has complete information: any fact true at w1 is known by the physician.

The nurse's accessibility relation from w1 is {w1, w2, w3} -- the nurse cannot distinguish the actual world from two alternative worlds. The nurse's knowledge is limited to facts that hold across *all three* worlds.
"""

# ╔═╡ 4a1b3c4d-0007-0007-0007-000000000007
md"""
## Evaluating Knowledge (Definition 15.5)

Recall from B&D: M, w ⊩ K\_a B iff for all w' accessible by agent a from w, M, w' ⊩ B.

Let's check what each agent knows at w1:
"""

# ╔═╡ 4a1b3c4d-0008-0008-0008-000000000008
begin
	# Does the physician know about the allergy?
	physician_knows_allergy = satisfies(allergy_model, :w1, Knowledge(:physician, allergy))

	# Does the nurse know about the allergy?
	nurse_knows_allergy = satisfies(allergy_model, :w1, Knowledge(:nurse, allergy))

	# Does the physician know it's documented?
	physician_knows_documented = satisfies(allergy_model, :w1, Knowledge(:physician, documented))

	# Does the nurse know it's documented?
	nurse_knows_documented = satisfies(allergy_model, :w1, Knowledge(:nurse, documented))

	md"""
	| Query | Result | Explanation |
	|:------|:-------|:------------|
	| K\_physician(allergy) at w1 | **$(physician_knows_allergy)** | Physician sees only w1, allergy holds at w1 |
	| K\_nurse(allergy) at w1 | **$(nurse_knows_allergy)** | Nurse sees w1, w2, w3 -- allergy holds at w1 and w2 but NOT w3 |
	| K\_physician(documented) at w1 | **$(physician_knows_documented)** | Physician sees only w1, documented holds there |
	| K\_nurse(documented) at w1 | **$(nurse_knows_documented)** | Nurse sees w1, w2, w3 -- documented only at w1 |

	The nurse does **not** know the allergy status -- exactly because the nurse has not checked the chart and cannot rule out w3 (the world where there is no allergy). This is the epistemic formalization of an information gap.
	"""
end

# ╔═╡ 4a1b3c4d-0009-0009-0009-000000000009
md"""
### Higher-Order Knowledge

Does the physician know that the nurse does *not* know about the allergy? This matters for patient safety -- if the physician is aware of the gap, they can intervene.
"""

# ╔═╡ 4a1b3c4d-0010-0010-0010-000000000010
begin
	# K_physician(¬K_nurse(allergy)) -- physician knows the nurse doesn't know
	nurse_ignorance = Not(Knowledge(:nurse, allergy))
	physician_knows_gap = satisfies(allergy_model, :w1,
		Knowledge(:physician, nurse_ignorance))

	println("K[physician](¬K[nurse](allergy)) at w1: ", physician_knows_gap)
	println()
	println("The physician ", physician_knows_gap ? "is" : "is NOT",
		" aware that the nurse lacks allergy information.")
	println("This is a ", physician_knows_gap ? "recognized" : "hidden",
		" knowledge gap.")
end

# ╔═╡ 4a1b3c4d-0011-0011-0011-000000000011
md"""
## Public Announcements and Clinical Handoffs (Definition 15.11)

B&D Chapter 15 introduces **Public Announcement Logic (PAL)**. The formula [B]C reads: "after B is truthfully announced, C holds."

In clinical settings, public announcements model:
- **Chart reviews**: a nurse reads the allergy section
- **Safety briefings**: the team lead announces critical information
- **Handoff reports**: outgoing clinician communicates patient status
- **Read-back protocols**: confirmation that information was received

The key operation is **model restriction**: after announcing B, the model is restricted to worlds where B holds. Worlds inconsistent with the announcement are eliminated.
"""

# ╔═╡ 4a1b3c4d-0012-0012-0012-000000000012
begin
	# Before announcement: does the nurse know the allergy?
	before = satisfies(allergy_model, :w1, Knowledge(:nurse, allergy))

	# After announcing the allergy: [allergy]K_nurse(allergy)
	announce_allergy = Announce(allergy, Knowledge(:nurse, allergy))
	after = satisfies(allergy_model, :w1, announce_allergy)

	md"""
	### Chart Check as Public Announcement

	We model the nurse checking the chart (and seeing the allergy) as a public announcement of `allergy`:

	- **Before**: K\_nurse(allergy) at w1 = **$(before)** (nurse cannot distinguish worlds)
	- **After**: [allergy]K\_nurse(allergy) at w1 = **$(after)** (announcement eliminates w3)

	The announcement of `allergy` restricts the model to worlds where `allergy` holds, eliminating w3. In the restricted model, the nurse can no longer "see" a world without the allergy.
	"""
end

# ╔═╡ 4a1b3c4d-0013-0013-0013-000000000013
begin
	# Show the restricted model explicitly
	restricted = restrict_model(allergy_model, allergy)

	println("=== Original model ===")
	println("Worlds: ", sort(collect(allergy_model.frame.worlds)))
	println("Nurse sees from w1: ", sort(collect(accessible(allergy_model.frame, :nurse, :w1))))
	println()
	println("=== After announcing allergy (M|allergy) ===")
	println("Worlds: ", sort(collect(restricted.frame.worlds)))
	println("Nurse sees from w1: ", sort(collect(accessible(restricted.frame, :nurse, :w1))))
	println()
	println("K[nurse](allergy) in M|allergy at w1: ",
		satisfies(restricted, :w1, Knowledge(:nurse, allergy)))
end

# ╔═╡ 4a1b3c4d-0014-0014-0014-000000000014
md"""
### Why This Matters for Safety

When the nurse checks the chart and learns the allergy, the restricted model eliminates worlds where the allergy does not exist. Now the nurse **knows** the allergy and can act on it -- verifying that penicillin is not ordered, flagging cross-reactive antibiotics, and communicating the allergy during handoff.

Without this "announcement" (chart check), the nurse might administer a penicillin-class antibiotic, causing an adverse drug event. The epistemic model makes the risk visible: an information gap (K\_nurse(allergy) = false) is a precondition for the error.
"""

# ╔═╡ 4a1b3c4d-0015-0015-0015-000000000015
md"""
## Group Knowledge and Common Knowledge (Definitions 15.3 and 15.6)

**Group knowledge** E\_{G} A: every agent in G knows A.

**Common knowledge** C\_{G} A: A holds at every world reachable via the transitive closure of the union of all agents' accessibility relations. Intuitively -- everyone knows A, everyone knows that everyone knows A, and so on ad infinitum.

### Clinical Scenario: Team Huddle

Consider a morning safety huddle where the allergy is discussed. Does this make the allergy common knowledge?
"""

# ╔═╡ 4a1b3c4d-0016-0016-0016-000000000016
begin
	# Model after the huddle: both physician and nurse have reviewed the chart
	# Now both agents see only w1 from w1
	huddle_frame = EpistemicFrame(
		[:w1, :w2, :w3],
		[:physician => [:w1 => :w1],
		 :nurse     => [:w1 => :w1]]
	)
	huddle_model = EpistemicModel(huddle_frame, [
		:allergy    => [:w1, :w2],
		:documented => [:w1],
	])

	team = [:physician, :nurse]

	gk = group_knows(huddle_model, :w1, team, allergy)
	ck = common_knowledge(huddle_model, :w1, team, allergy)

	md"""
	### After the Team Huddle

	Both agents now see only w1 from w1 (the huddle resolved all uncertainty):

	| Query | Result |
	|:------|:-------|
	| Group knowledge E\_{team}(allergy) | **$(gk)** |
	| Common knowledge C\_{team}(allergy) | **$(ck)** |

	Both hold. The allergy is not just individually known -- it is **common knowledge**. Each agent knows the allergy, each knows the other knows, and so on.
	"""
end

# ╔═╡ 4a1b3c4d-0017-0017-0017-000000000017
begin
	# Contrast: before the huddle (original model)
	gk_before = group_knows(allergy_model, :w1, team, allergy)
	ck_before = common_knowledge(allergy_model, :w1, team, allergy)

	md"""
	### Before the Huddle (Original Model)

	| Query | Result |
	|:------|:-------|
	| Group knowledge E\_{team}(allergy) | **$(gk_before)** |
	| Common knowledge C\_{team}(allergy) | **$(ck_before)** |

	Before the huddle, the allergy is **not** group knowledge (the nurse does not know) and therefore not common knowledge either. The huddle -- modeled as a public announcement -- converts individual knowledge into common knowledge.

	**Why common knowledge matters for safety**: During a code blue, the team must coordinate without pausing to confirm what each member knows. If the allergy is common knowledge, any team member can object to penicillin without first asking "does the nurse know?" Common knowledge is the epistemic foundation of coordinated action.
	"""
end

# ╔═╡ 4a1b3c4d-0018-0018-0018-000000000018
md"""
## Interactive: Who Has Checked the Chart?

Select which agents have reviewed the allergy documentation and see how knowledge states change:
"""

# ╔═╡ 4a1b3c4d-0019-0019-0019-000000000019
md"Physician has checked the chart: $(@bind phys_checked CheckBox(default=true))"

# ╔═╡ 4a1b3c4d-0020-0020-0020-000000000020
md"Nurse has checked the chart: $(@bind nurse_checked CheckBox(default=false))"

# ╔═╡ 4a1b3c4d-0021-0021-0021-000000000021
md"Patient has been informed: $(@bind patient_informed CheckBox(default=false))"

# ╔═╡ 4a1b3c4d-0022-0022-0022-000000000022
begin
	# Build relations based on who has checked
	phys_pairs = phys_checked ? [:w1 => :w1] : [:w1 => :w1, :w1 => :w2, :w1 => :w3]
	nurse_pairs = nurse_checked ? [:w1 => :w1] : [:w1 => :w1, :w1 => :w2, :w1 => :w3]
	patient_pairs = patient_informed ? [:w1 => :w1] : [:w1 => :w1, :w1 => :w2, :w1 => :w3]

	interactive_frame = EpistemicFrame(
		[:w1, :w2, :w3],
		[:physician => phys_pairs,
		 :nurse     => nurse_pairs,
		 :patient   => patient_pairs]
	)
	interactive_model = EpistemicModel(interactive_frame, [
		:allergy    => [:w1, :w2],
		:documented => [:w1],
	])

	i_team = [:physician, :nurse, :patient]

	i_phys  = satisfies(interactive_model, :w1, Knowledge(:physician, allergy))
	i_nurse = satisfies(interactive_model, :w1, Knowledge(:nurse, allergy))
	i_pat   = satisfies(interactive_model, :w1, Knowledge(:patient, allergy))
	i_gk    = group_knows(interactive_model, :w1, i_team, allergy)
	i_ck    = common_knowledge(interactive_model, :w1, i_team, allergy)

	md"""
	### Knowledge States at w1

	| Agent | Knows allergy? | Has checked chart? |
	|:------|:--------------|:-------------------|
	| Physician | **$(i_phys)** | $(phys_checked ? "Yes" : "No") |
	| Nurse | **$(i_nurse)** | $(nurse_checked ? "Yes" : "No") |
	| Patient | **$(i_pat)** | $(patient_informed ? "Yes" : "No") |

	| Group Query | Result |
	|:-----------|:-------|
	| Everyone knows (group knowledge) | **$(i_gk)** |
	| Common knowledge | **$(i_ck)** |

	Toggle the checkboxes above. Notice that:
	- **Group knowledge** requires *every* agent to have checked the chart
	- **Common knowledge** additionally requires the transitive closure condition -- all agents must have overlapping epistemic access
	- A single uninformed agent breaks both group and common knowledge
	"""
end

# ╔═╡ 4a1b3c4d-0023-0023-0023-000000000023
md"""
## Clinical Information Asymmetry Examples

Information asymmetry -- where one agent knows something that another does not -- is a pervasive source of clinical risk. Here are three common patterns:
"""

# ╔═╡ 4a1b3c4d-0024-0024-0024-000000000024
md"""
### Example 1: Specialist Knows Diagnosis, Primary Care Does Not

A cardiologist diagnoses atrial fibrillation during a consult. The diagnosis is in the specialist's note, but the primary care physician has not yet reviewed it.
"""

# ╔═╡ 4a1b3c4d-0025-0025-0025-000000000025
begin
	diagnosis = Atom(:afib_diagnosis)
	anticoag = Atom(:anticoagulation)

	# w1: patient has AFib (actual), w2: patient does not have AFib
	specialist_frame = EpistemicFrame(
		[:w1, :w2],
		[:specialist => [:w1 => :w1, :w2 => :w2],
		 :pcp        => [:w1 => :w1, :w1 => :w2, :w2 => :w2]]
	)
	specialist_model = EpistemicModel(specialist_frame, [
		:afib_diagnosis => [:w1],
	])

	spec_knows = satisfies(specialist_model, :w1, Knowledge(:specialist, diagnosis))
	pcp_knows = satisfies(specialist_model, :w1, Knowledge(:pcp, diagnosis))

	# After the specialist communicates (public announcement):
	announce_dx = Announce(diagnosis, Knowledge(:pcp, diagnosis))
	after_comm = satisfies(specialist_model, :w1, announce_dx)

	md"""
	- K\_specialist(afib\_diagnosis) at w1: **$(spec_knows)** -- specialist knows
	- K\_pcp(afib\_diagnosis) at w1: **$(pcp_knows)** -- PCP does not know
	- [afib\_diagnosis]K\_pcp(afib\_diagnosis) at w1: **$(after_comm)** -- after communication, PCP knows

	**Risk**: Without communication, the PCP may not prescribe anticoagulation, missing stroke prevention. The public announcement (a phone call, a shared note, a care coordination message) resolves the asymmetry.
	"""
end

# ╔═╡ 4a1b3c4d-0026-0026-0026-000000000026
md"""
### Example 2: Patient Knows Symptoms, Clinician Does Not

A patient experiences intermittent chest pain at home but has not reported it. The clinician's knowledge is limited to what is in the chart and what the patient has communicated.
"""

# ╔═╡ 4a1b3c4d-0027-0027-0027-000000000027
begin
	chest_pain = Atom(:chest_pain)

	# w1: patient has chest pain (actual), w2: no chest pain
	symptom_frame = EpistemicFrame(
		[:w1, :w2],
		[:patient   => [:w1 => :w1, :w2 => :w2],
		 :clinician => [:w1 => :w1, :w1 => :w2, :w2 => :w2]]
	)
	symptom_model = EpistemicModel(symptom_frame, [
		:chest_pain => [:w1],
	])

	pat_knows = satisfies(symptom_model, :w1, Knowledge(:patient, chest_pain))
	clin_knows = satisfies(symptom_model, :w1, Knowledge(:clinician, chest_pain))

	# After patient reports symptoms:
	after_report = satisfies(symptom_model, :w1,
		Announce(chest_pain, Knowledge(:clinician, chest_pain)))

	md"""
	- K\_patient(chest\_pain) at w1: **$(pat_knows)** -- patient knows their own symptoms
	- K\_clinician(chest\_pain) at w1: **$(clin_knows)** -- clinician does not know
	- After patient reports: **$(after_report)** -- clinician now knows

	**Risk**: Unreported symptoms delay diagnosis. The "announcement" here is the patient disclosing symptoms during the clinical encounter -- a structured review of systems serves as a systematic announcement protocol.
	"""
end

# ╔═╡ 4a1b3c4d-0028-0028-0028-000000000028
md"""
### Example 3: EHR Has Data, Clinician Has Not Reviewed It

A critical lab result (e.g., elevated troponin) is filed in the EHR. The result is "known" to the system but the on-call physician has not opened the chart.
"""

# ╔═╡ 4a1b3c4d-0029-0029-0029-000000000029
begin
	troponin = Atom(:elevated_troponin)

	# w1: elevated troponin (actual), w2: normal troponin
	ehr_frame = EpistemicFrame(
		[:w1, :w2],
		[:ehr      => [:w1 => :w1, :w2 => :w2],
		 :oncall   => [:w1 => :w1, :w1 => :w2, :w2 => :w2]]
	)
	ehr_model = EpistemicModel(ehr_frame, [
		:elevated_troponin => [:w1],
	])

	ehr_knows = satisfies(ehr_model, :w1, Knowledge(:ehr, troponin))
	oncall_knows = satisfies(ehr_model, :w1, Knowledge(:oncall, troponin))

	# After the alert fires (announcement):
	after_alert = satisfies(ehr_model, :w1,
		Announce(troponin, Knowledge(:oncall, troponin)))

	md"""
	- K\_ehr(elevated\_troponin) at w1: **$(ehr_knows)** -- the system has the result
	- K\_oncall(elevated\_troponin) at w1: **$(oncall_knows)** -- the physician does not know
	- After alert fires: **$(after_alert)** -- physician now knows

	**Risk**: Critical results sitting unacknowledged in the EHR are a leading cause of diagnostic delay. The "public announcement" is the alert notification -- but only if the physician actually reads it. This is why result acknowledgment systems exist: they ensure the announcement is received, not just sent.
	"""
end

# ╔═╡ 4a1b3c4d-0030-0030-0030-000000000030
md"""
## Handoff Safety: Announcements as Protocol

Clinical handoffs (shift change, transfer between units) are sequences of public announcements. A structured handoff protocol like **I-PASS** (Illness severity, Patient summary, Action list, Situation awareness, Synthesis by receiver) can be modeled as a series of announcements that systematically close knowledge gaps.
"""

# ╔═╡ 4a1b3c4d-0031-0031-0031-000000000031
begin
	# A handoff scenario with multiple facts
	# Three facts the incoming nurse needs to know
	med_change = Atom(:med_change)
	fall_risk = Atom(:fall_risk)
	npo_status = Atom(:npo_status)

	# Before handoff: outgoing nurse knows everything, incoming nurse knows nothing
	handoff_frame = EpistemicFrame(
		[:w1, :w2, :w3, :w4],
		[:outgoing => [:w1 => :w1],
		 :incoming => [:w1 => :w1, :w1 => :w2, :w1 => :w3, :w1 => :w4]]
	)
	handoff_model = EpistemicModel(handoff_frame, [
		:med_change => [:w1],
		:fall_risk  => [:w1, :w2],
		:npo_status => [:w1, :w3],
	])

	# Check what the incoming nurse knows before handoff
	knows_med = satisfies(handoff_model, :w1, Knowledge(:incoming, med_change))
	knows_fall = satisfies(handoff_model, :w1, Knowledge(:incoming, fall_risk))
	knows_npo = satisfies(handoff_model, :w1, Knowledge(:incoming, npo_status))

	# After announcing med_change, does incoming know it?
	after_med_announce = satisfies(handoff_model, :w1,
		Announce(med_change, Knowledge(:incoming, med_change)))

	# Successive restriction: announce med_change, then check fall_risk knowledge
	restricted_after_med = restrict_model(handoff_model, med_change)
	knows_fall_after_med = satisfies(restricted_after_med, :w1,
		Knowledge(:incoming, fall_risk))

	md"""
	### Before Handoff

	| Fact | Incoming nurse knows? |
	|:-----|:---------------------|
	| Medication change | **$(knows_med)** |
	| Fall risk | **$(knows_fall)** |
	| NPO status | **$(knows_npo)** |

	### After Announcing Medication Change

	- K\_incoming(med\_change): **$(after_med_announce)** -- now known
	- K\_incoming(fall\_risk) in M|med\_change: **$(knows_fall_after_med)** -- announcing one fact can sharpen knowledge of others (by eliminating inconsistent worlds)

	Each announcement in the handoff protocol restricts the model further, progressively closing the incoming nurse's knowledge gaps. A complete handoff is one where, after all announcements, every critical fact is common knowledge between the outgoing and incoming team.
	"""
end

# ╔═╡ 4a1b3c4d-0032-0032-0032-000000000032
md"""
## Epistemic Conditions and Patient Safety

B&D Table 15.1 lists epistemic axiom schemas and their frame conditions. Each has a clinical interpretation:

| Axiom | Frame Condition | Clinical Meaning |
|:------|:---------------|:-----------------|
| **Veridicality (T)**: K\_a A -> A | Reflexive R\_a | If an agent "knows" something, it is actually true. Rules out false beliefs masquerading as knowledge. |
| **Positive Introspection (4)**: K\_a A -> K\_a K\_a A | Transitive R\_a | If you know a fact, you know that you know it. Agents are aware of their own knowledge. |
| **Negative Introspection (5)**: not K\_a A -> K\_a (not K\_a A) | Euclidean R\_a | If you do not know a fact, you know that you do not know it. Agents are aware of their own ignorance. |

**S5 (full knowledge)** requires all three -- the agent's accessibility relation is an equivalence relation. This is the standard system for epistemic logic (EPISTEMIC\_S5 in Gamen.jl).

**Clinical implication of veridicality**: Veridicality (T axiom) ensures that "knowledge" is *factive* -- if the physician "knows" the diagnosis, the diagnosis is actually correct. This distinguishes knowledge from mere belief. A physician who confidently believes an incorrect diagnosis does not *know* it in the epistemic logic sense.
"""

# ╔═╡ 4a1b3c4d-0033-0033-0033-000000000033
begin
	# Demonstrate veridicality with a reflexive model
	# S5 frame: equivalence relations for each agent
	s5_frame = EpistemicFrame(
		[:w1, :w2],
		[:physician => [:w1 => :w1, :w1 => :w2, :w2 => :w1, :w2 => :w2]]
	)
	s5_model = EpistemicModel(s5_frame, [:allergy => [:w1, :w2]])

	# Veridicality: K[physician](allergy) → allergy
	veridicality = Implies(Knowledge(:physician, allergy), allergy)
	v_w1 = satisfies(s5_model, :w1, veridicality)
	v_w2 = satisfies(s5_model, :w2, veridicality)

	println("Veridicality (K[physician](allergy) -> allergy):")
	println("  at w1: ", v_w1)
	println("  at w2: ", v_w2)
	println()
	println("With reflexive relations, knowledge is factive:")
	println("anything the physician 'knows' is actually true.")
end

# ╔═╡ 4a1b3c4d-0034-0034-0034-000000000034
md"""
## Summary: B&D Epistemic Concepts in Clinical Practice

| B&D Concept | Gamen.jl | Clinical Interpretation |
|:-----------|:---------|:-----------------------|
| Knowledge K\_a A | `Knowledge(agent, formula)` | Agent a knows clinical fact A |
| Multi-agent frame | `EpistemicFrame(worlds, relations)` | Care team with individual knowledge states |
| Multi-agent model | `EpistemicModel(frame, valuation)` | Clinical scenario with facts and agents |
| Accessibility R\_a | `accessible(frame, agent, world)` | Worlds consistent with agent a's information |
| Agent set | `agents(frame)` | Members of the care team |
| Public announcement [B]C | `Announce(B, C)` | "After communicating B, does C hold?" |
| Model restriction M\|B | `restrict_model(model, formula)` | Updated knowledge state after communication |
| Group knowledge E\_G A | `group_knows(model, w, agents, formula)` | Everyone on the team knows A |
| Common knowledge C\_G A | `common_knowledge(model, w, agents, formula)` | A is known, known to be known, etc. |
| Veridicality (T axiom) | Reflexive R\_a | Knowledge is factive -- "knowing" implies truth |
| S5 system | `EPISTEMIC_S5` | Full knowledge with introspection |

### Key Takeaways

1. **Information gaps are epistemic gaps**: When a nurse does not know an allergy, this is K\_nurse(allergy) = false -- a formal, checkable condition.
2. **Communication is public announcement**: Chart checks, handoffs, and safety briefings are model restriction operations that eliminate uncertainty.
3. **Common knowledge enables coordination**: For a team to act in concert (e.g., during a code), critical facts must be common knowledge, not merely individually known.
4. **Asymmetry is the default**: In multi-agent clinical settings, different agents start with different information. Safety protocols exist to drive the system toward common knowledge.
"""

# ╔═╡ Cell order:
# ╟─4a1b3c4d-0001-0001-0001-000000000001
# ╠═4a1b3c4d-0002-0002-0002-000000000002
# ╟─4a1b3c4d-0003-0003-0003-000000000003
# ╟─4a1b3c4d-0004-0004-0004-000000000004
# ╠═4a1b3c4d-0005-0005-0005-000000000005
# ╟─4a1b3c4d-0006-0006-0006-000000000006
# ╟─4a1b3c4d-0007-0007-0007-000000000007
# ╠═4a1b3c4d-0008-0008-0008-000000000008
# ╟─4a1b3c4d-0009-0009-0009-000000000009
# ╠═4a1b3c4d-0010-0010-0010-000000000010
# ╟─4a1b3c4d-0011-0011-0011-000000000011
# ╠═4a1b3c4d-0012-0012-0012-000000000012
# ╠═4a1b3c4d-0013-0013-0013-000000000013
# ╟─4a1b3c4d-0014-0014-0014-000000000014
# ╟─4a1b3c4d-0015-0015-0015-000000000015
# ╠═4a1b3c4d-0016-0016-0016-000000000016
# ╠═4a1b3c4d-0017-0017-0017-000000000017
# ╟─4a1b3c4d-0018-0018-0018-000000000018
# ╠═4a1b3c4d-0019-0019-0019-000000000019
# ╠═4a1b3c4d-0020-0020-0020-000000000020
# ╠═4a1b3c4d-0021-0021-0021-000000000021
# ╠═4a1b3c4d-0022-0022-0022-000000000022
# ╟─4a1b3c4d-0023-0023-0023-000000000023
# ╟─4a1b3c4d-0024-0024-0024-000000000024
# ╠═4a1b3c4d-0025-0025-0025-000000000025
# ╟─4a1b3c4d-0026-0026-0026-000000000026
# ╠═4a1b3c4d-0027-0027-0027-000000000027
# ╟─4a1b3c4d-0028-0028-0028-000000000028
# ╠═4a1b3c4d-0029-0029-0029-000000000029
# ╟─4a1b3c4d-0030-0030-0030-000000000030
# ╠═4a1b3c4d-0031-0031-0031-000000000031
# ╟─4a1b3c4d-0032-0032-0032-000000000032
# ╠═4a1b3c4d-0033-0033-0033-000000000033
# ╟─4a1b3c4d-0034-0034-0034-000000000034
