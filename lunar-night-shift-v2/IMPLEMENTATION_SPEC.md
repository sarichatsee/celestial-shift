# Lunar Night Shift: agreed redesign

Status: design interview complete; consolidated specification awaiting final implementation confirmation. Supersedes the four-level prototype and earlier stage-rating proposals. No redesigned game has yet been implemented.

## Mission and time

Medium and Hard have seven stages of four Earth-day shifts each: 28 shifts, 14 daylight followed by 14 darkness. Sunset occurs halfway through stage 4. Label this a simplified lunar cycle, not a precise lunar solar day.

Easy has four stages of two shifts each, with daylight followed by darkness and a shorter training expedition. Each shift remains one Earth day: Easy is an explicitly abbreviated eight-day scenario, not a full lunar cycle. Start its daylight clock four days before simulated sunset. No mode has flare events in stage 1. All shifts accumulate background game risk.

At the beginning, select a deployment objective from authored templates, disclose its dependent tasks and all available achievement stars. Objectives persist across stages. Stage progression changes the environment; it does not replace unfinished objectives or restrict tasks to a stage theme.

## Success and achievements

Baseline success is survival through the final shift within mission limits. An unfinished deployment objective gives partial achievement, not automatic mission failure. Display safe return, objective status and stars earned out of available stars separately.

Research completes task objectives; energy cannot directly purchase stars. Award each disclosed achievement once. Exact star totals depend on the mission and should not be compared as a universal raw leaderboard across modes.

Example objective: collect samples outdoors, then analyse them indoors. If collection is unfinished when outdoor work becomes prohibited, its achievement becomes unavailable. Already collected samples remain available for analysis. Lost bonus opportunities must not block baseline survival.

## Crew and task cards

Three interchangeable crew tokens are available each shift. Essential life support runs automatically but consumes resources. Show task prerequisites, crew and energy costs, location, progress, remaining duration, deadline and reward. Players reassign crew each shift; previous assignments must never silently continue when prohibited.

Tasks may require one or two crew. Progress persists across shifts and stages. Interrupted work retains progress. Supported repairs offer a slower indoor robot-control method. Reference workload: 12 work units, direct work 3 units per staffed shift, remote work 2. Thus four direct shifts or six remote shifts finish it; two direct plus three remote also finish it. Exact task staffing and energy costs are tuning parameters, not NASA measurements.

Use authored mission templates with valid dependency graphs, not unconstrained random tasks. Higher difficulty increases dependencies, competing demands and resource pressure. Introduce cards progressively so children do not face every system simultaneously.

## Protection and radiation

Start with basic passive habitat shielding and a usable shelter. Additional passive shielding requires outdoor construction and persists. It does not require electricity to retain its material protection. Newly completed shielding protects from the next shift.

Sheltering is an operational choice: recall outside crew before resolving that shift, spend energy and one crew assignment, pause both direct and remote repairs, and allow remaining crew to do designated shelter-compatible indoor tasks. Essential life support continues. The repair console is outside the shelter compartment in this fictional habitat.

Radiation risk is a cumulative game score, not mSv, a measured human dose or a medical prediction:

- Add 0.5 background risk per Earth-day shift, including sheltered shifts.
- At risk >=40, prohibit outdoor assignments for the remainder of the attempt. Indoor work remains possible, including supported remote repairs outside shelter mode.
- At risk >=100, end the mission attempt with Mission Control evacuation.
- Higher exposure narrows opportunities; do not describe it as loss of physical mobility or invent illness symptoms.
- Active sheltering greatly reduces storm risk; passive shielding reduces it partially. Every supported scenario must defeat passive-only play even with the strongest attainable upgrade.

For deterministic shift resolution: validate assignments and costs before mutating; enforce existing restrictions; apply shelter recall; resolve resource use, current exposure and failure; award work only if still permitted. If risk crosses 40 during resolution, stop that shift's outdoor work conservatively and preserve earlier progress. Show this possible interruption before committing. Shield construction completed this shift cannot protect against the same shift's exposure. Do not let research rewards override evacuation.

Exact storm-risk values must be tuned separately for the shorter Easy scenario and longer missions. All constants must be labelled game assumptions. Do not add fake observed events simply to achieve a desired failure rate.

## Historical events and warnings

Select real archived flare/event bundles and relocate them into allowed training slots after stage 1. Keep associated records together, preserve original identity/date/source and recorded outcome, and label relocated timing as a training adaptation. Do not present it as a live forecast or exact historical replay. A missing association is not proof of no real-world hazard.

The supplied extract lacks raw SEP identities and notification chronology; rebuilding provenance is required before claiming deduplicated physical particle events or authentic advance-warning times. Existing records may support clearly labelled training hits, not measured lunar crew exposure.

Warning panels show the current Earth-control training alert, possible risk costs, assignments sheltering would interrupt, available and unavailable tasks with reasons, and approaching deadlines. Never expose unresolved outcomes or invent forecast percentages. A warning alone does not prohibit outdoor work; shelter selection or the cumulative restriction does.

Randomness is seeded and constrained: valid mission dependencies, feasible timing and protection opportunities, no flare in stage 1, active-shelter survival possible, passive-only failure enforced. Retry preserves the seed and event sequence. Display original event dates separately from game dates. Equipment failures and mission deadlines are authored scenarios, not DONKI observations.

## Difficulty and recovery

Easy: shorter scenario, generous reserves, guided first shelter action, clear teaching of passive-only failure. Medium: full mission with meaningful competing tasks. Hard: same timeline and three crew, tighter reserves and deadlines; do not initially remove a crew member.

Failure restarts the CURRENT stage with its exact entry snapshot: resources, risk, upgrades, objective progress, achievements and events. Do not erase exposure accumulated before stage entry, reroll hazards, or silently make retries easier. Avoid irrevocable entry traps: test conservative future-exposure and resource bounds at stage transitions. Optional achievement loss is allowed; inevitable baseline failure after a supposedly successful stage is a design defect requiring rebalancing, not hidden radiation forgiveness.

## Required acceptance checks

1. Across all supported mission/event combinations, passive-only play cannot finish; a cautious active-shelter policy can survive.
2. Test both unupgraded and maximally upgraded passive protection. Distinguish warnings from resolved training hits.
3. Selective play can outperform blanket sheltering in achievements on suitable scenarios; do not demand this for every scenario or punish justified caution.
4. Risk boundary tests at below 40, exactly 40, below 100 and exactly 100; background accumulation included.
5. Outdoor collection/construction and direct repair blocked at restriction; acquired samples and remote repairs still usable appropriately.
6. Direct/remote mixed repair progress, interrupted work and shelter-compatible assignments behave consistently; no double-booked crew or duplicated achievement.
7. Invalid plans change nothing; retry exactly restores stage entry and future event order; new missions can vary.
8. No future-outcome leakage in warnings, deadlines, descriptions or task availability.
9. No flare in stage 1; sunlight transition and resource conservation correct; task dependencies remain feasible.
10. Test stage-entry recoverability using resource/risk boundary cases and adversarial policies, not only successful benchmark scripts.
11. Verify file:// browser operation, touch layout, legible task cards and visible explanations of blocked work. Human playtests must check whether children understand the trade-off; automated wins do not establish engagement.

Implementation may choose UI layout, exact task catalogue, tuning constants and test machinery within these rules. Report any material conflict with the agreed rules instead of silently changing them.
