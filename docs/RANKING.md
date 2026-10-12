# How reports are ranked (priority score)

A transparent weighted sum from 0 to 100, implemented in `PriorityScore.swift`, weights in `Config.ranking`, unit-tested in `PriorityScoreTests.swift`, and shown to staff on the "How we rank" screen. Early-detection logic: a small, isolated patch near the creek that was reported recently by a confident scan of an aggressive species comes first.

| Factor | Max | How it is scored | Why |
|---|---|---|---|
| Patch size | 25 | Few plants 100%, patch 60%, large stand 20% | Small patches are cheap to remove now; large stands are a project |
| Isolation | 15 | 0 other open reports within 30 m: 100%; 1 to 2: 60%; 3+: 20% | An outpost away from the main infestation is the classic early-detection target |
| Near the creek | 20 | 100% within 15 m of the bundled waterway geometry, fading linearly to 0 at 150 m | Water moves seeds and fragments downstream (riparian corridors are the invasion highways) |
| Model confidence | 15 | Linear from 50% calibrated confidence (0 points) to 100% (full points); reports needing expert review are capped at 30% confidence | Spend staff time on the sure things first, but never hide the uncertain ones |
| Recent and unaddressed | 10 | 100% in the first 7 days, fading to 30% at 90 days | Fresh sightings are easier to find and treat |
| Aggressive spreader | 15 | Per-species weight 0 to 1 | From the Georgia Forestry Commission 2021 Dirty Dozen list (acres occupied, Forest Inventory and Analysis data): privet 1.00, stiltgrass 0.90, chinaberry 0.85, lespedeza 0.80, kudzu 0.75, Chinese tallow 0.70, olives 0.65, Japanese climbing fern 0.60, English ivy 0.55, wisteria 0.50, mimosa 0.45, Callery pear and trifoliate orange 0.40; other listed species 0.30 (Japanese honeysuckle 0.50 because the GFC note says honeysuckle was left off its list, not because it is harmless) |

Treated and dismissed reports score 0 and leave the list. Practice reports (outside the preserve boundary plus a 60 m buffer, or with no location) are never ranked. Scores are recomputed whenever a report is created, deleted or changes status, because isolation depends on the other reports.

The work order PDF shows the top 10 by this score with the three biggest factors for each ("why it ranked"). Treatment method is the staff's decision: the app never recommends herbicides, doses or removal by visitors.
