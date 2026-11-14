# Lunar Night Shift

Open `index.html` in a browser. No installation, server, API key or network connection is needed to play. Easy is selected by default.

## Simplified Easy mode — 15 November 2026

- One persistent, randomly selected two-step mission.
- Three stars: survive, complete step one, complete step two.
- Four stages with two Earth-day shifts each.
- Three crew; grouped mission, base and protection cards.
- No fuel management, generator, cooling failures, bonus discovery or stage reserve-check failures.
- Each new stage supplies +4 battery and +2 food. Radiation, shielding and mission progress persist. Retrying restores the stage entry snapshot without adding supplies again.
- Stage 1 is quiet. Passive protection alone still cannot survive the whole mission.
- Short warnings and reports. Flare source links are absent from play reports; provenance is retained in the science page and data files.

Medium and Hard retain the longer seven-stage resource-management rules. The original colors, rounded panels, yellow buttons, meters and Moon-base illustration are retained.

## NASA data

The bundle was retrieved directly from NASA's public DONKI API: 218 flare records and 27 particle-event records. `data/provenance.json` contains exact request URLs, retrieval timestamp, counts and SHA-256 hashes; `data/flr.json` and `data/sep.json` retain the raw responses.

Refresh with `python tools/fetch_nasa.py` (network needed). Rebuild from the cached responses with `python tools/fetch_nasa.py --offline`. Records are clustered conservatively by shared flare associations or adjacent observations within 48 hours. These are training bundles, not a claim that each instrument observation is a distinct storm. Historical event timing is relocated after stage 1; source dates remain in the data. The snapshot is not live data.

Radiation points, resource budgets, crop timing, equipment faults and repair rates are game assumptions, not NASA dose measurements. This distinction is explained in Science Behind It rather than repeated during play.

## Validation

Run `node tests/run.cjs`. The saved `tests/results.json` reports 2,700 policy campaigns and 900 retry campaigns across 300 seeds per mode. The tested cautious policy earned 3/3 stars in all 300 Easy missions. Passive-only policies failed, including an early maximum-shield strategy. Checks cover seed scenarios, retries and top-up duplication, unavailable Easy systems, resource conservation and outcome metadata.

Full Easy and Medium browser playthroughs passed in Edge, including 1024px desktop and 390px mobile checks, no horizontal overflow, no JavaScript errors and no report links. Automated success does not substitute for child playtesting or prove optimal gameplay. The event pool contains three linked training clusters; broader verified data would improve replay variety.

The implementation specification describes the earlier agreed design. This README and SIMPLIFICATION.md supersede its Easy-mode rules.
