# Figure connections pilot (AA-218)

Hand-curated claims about six people, for the first public version of Figure connections. Manifest: `yaml/figure_connections/pilot_2026_11.yaml`. New identities live in `yaml/catalog/figures/{B,J,M}.yml`, `yaml/catalog/businesses.yml`, `yaml/catalog/practices.yml` and `yaml/catalog/topics.yml`.

Pages were read on 2026-11-14. Each Attestation records the page's URL, title, publisher, byline and publication date as the page states them, plus a short excerpt of under 15 words. Excerpts were checked against the page text, not search-engine summaries. Claims import as pending; an admin publishes them from Admin → Figure claims after review.

## What each claim asserts

| Person | Role in the catalog | Claims | Sources |
| --- | --- | --- | --- |
| Steve Kerr | Player, broadcaster, coach (existing Figure and appointments) | Paraphrase of his four core values; a direct quote on leadership; a paraphrase crediting Phil Jackson with introducing him to mindfulness | Harvard Law School, "Steve Kerr holds court at Harvard Law", 2022-04-13 |
| George Mumford | Figure only | Teaches mindfulness and meditation (no protocol: the sources describe no routine); a direct quote on practice quality | WGBH, 2015-07-07; Mindful interview, 2011-04-15 |
| Phil Jackson | Figure only | Teaches silent group sitting with breath awareness, connected to meditation; undated | Selling Power, "The Lane Well Traveled" (no date on the page) |
| LeBron James | Existing Player | Promotes Calm from 2019-12-10, compensation unknown; a direct quote from the announcement | Calm press release via GlobeNewswire, 2019-12-10 |
| Stephen Curry | Existing Player | Sponsored by Under Armour, 2013 to 2025-11, historical, compensation unknown | ABC7/ESPN, 2025-11-14; Under Armour release, 2025-11-13 |
| Charles Barkley | Figure only | Promotes Weight Watchers from 2011-12, documented paid, end unknown | Philadelphia Magazine, 2011-12-13; Larry Brown Sports, 2012-01-06 |

Kerr's core values are recorded as a paraphrase because both readable sources list them in the author's narration, not in Kerr's quoted words. Kerr's leadership quote is his own words as the article quotes them. James's quote is the first two sentences of his statement in Calm's release; the rest of the sentence is omitted, not altered.

## Rejected or narrowed claims

- **Kerr in his own words on the four values.** Greater Good (2017-06-14) and Harvard Law describe them in narration. The PositiveCoach audio wasn't reviewed. Recorded as a paraphrase instead.
- **Phil Jackson leading Lakers meditation.** The Mindful interview doesn't say Jackson directed it. The Sports Illustrated Vault profile (1996-05-27) returned 404. Only the Bulls-era description from Selling Power is used.
- **Mumford's method or session length.** Neither source describes one, so his claim has no Protocol.
- **Curry owning Curry Brand.** Reported by CNBC (via search results), but neither the Under Armour release nor ABC7 states ownership. Not recorded.
- **Payment terms for Calm and Under Armour.** Not disclosed, so compensation is unknown.
- **LeBron James's Calm content as meditation.** The release describes "inspirational wisdom sessions", not meditation, so no practice claim is recorded.
- **insidersport.com** returned 403 and wasn't used.

## Coverage gaps against AA-218

- **A morning walk interpreted as prayer and gratitude by one person and differently by another.** No real, citable source was found. It is covered by fictional Factory Bot scenarios in the application's specs only.
- **Different meditation protocols.** Only Jackson's claim names a Protocol; Mumford's is general-only.
- **Broadcasting appointments for Barkley.** Not recorded; Kerr's TNT appointment is the pilot's broadcasting role.
- **Founded, owns and invests_in predicates.** No claim in this pilot; the business claims use promotes and sponsored_by.

## Regenerating and checking

The manifest is hand-authored; there is no generator. Validate with:

```sh
.venv/bin/python tools/validate_seeds.py yaml/figure_connections yaml/catalog
```

From the application root:

```sh
mise exec -- bin/rails seeds:validate
mise exec -- bin/rails db:seed
```

A second `db:seed` must create nothing and report no conflicts.
