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

# Athletes batch (2026-11-22)

Hand-curated claims about eleven athletes who are already Players in the catalog. Manifest: `yaml/figure_connections/athletes_2026_11.yaml`. New identities live in `yaml/catalog/businesses.yml`, `yaml/catalog/practices.yml` and `yaml/catalog/topics.yml`. The Figures are the implicit `FIGURE-` + Player code Figures (as with Curry in the pilot); LeBron James's Figure is the existing one in `yaml/catalog/figures/J.yml`.

Pages were read on 2026-11-22 in a browser, with the same rules as the pilot: the page's URL, title, publisher, byline and publication date as the page states them, an excerpt of under 15 words checked against the page text, and claims that import as pending.

## What each claim asserts

| Person | Claims | Sources |
| --- | --- | --- |
| Kevin Durant | Founded Thirty Five Ventures (co-founded with Rich Kleiman, date unknown); owns a 5% stake in the Philadelphia Union from 2020-06-15 | Philadelphia Union release, 2020-06-15 |
| Patrick Mahomes | Owns part of the Kansas City Royals from 2020-07-28; a direct quote on deepening his roots in the community | ESPN News Services, 2020-07-28 |
| LeBron James | Owns a Fenway Sports Group partnership stake from 2021-03; owned 2% of Liverpool (undated); a direct quote on his goal of owning an NBA franchise | ESPN, Jeff Passan, 2021-03-16 |
| Shohei Ohtani | Sponsored by New Balance from 2023, reported current as of 2026-11-20; a direct quote on trust in the partnership | AP via ESPN, 2026-11-20 |
| Stephen Curry | Founded Unanimous Media (co-founded, date unknown); a paraphrase about uplifting people | AP via CBS Detroit, 2019-06-27 |
| Sidney Crosby | Promotes Tim Hortons (dates and compensation unknown) | Tim Hortons releases, 2016-09-07 and 2023-01-04 |
| Nathan MacKinnon | Promotes Tim Hortons (2016 campaign only) | Tim Hortons release, 2016-09-07 |
| Kevin Love | Participates in talk therapy from 2017-11, with his own interpretation; a direct quote that everyone is going through something we can't see | Love's essay, The Players' Tribune, 2018-03-06 |
| DeMar DeRozan | A direct quote on depression ("we're all human"); a self-stated value of treating everyone the same, with respect | ESPN, 2018-02-26, quoting the Toronto Star |
| Jaylen Brown | Participates in weighted underwater training from 2022, connected in his own words to anxiety management and breathwork; a direct quote on not panicking, linked to that practice | NBC Sports Boston, 2024-09-24; Boston.com, 2026-04-09 |
| Erling Haaland | Participates in two sleep protocols (blue-light-blocking glasses before bed; mouth taping), both connected to Sleep; direct quotes on sleep and on small daily habits | ITV News Granada, 2023-08-31 |

This batch fills three of the pilot's gaps: it has `founded` (Durant, Curry) and `owns` (Durant, Mahomes, James) claims, more than one Protocol, and one Protocol that an athlete connects to two different Practices in his own words (Brown).

## Decisions for the reviewing admin

- **Sports clubs as Businesses.** `FigureBusinessRelationship` can only target a Business, so the Philadelphia Union, the Kansas City Royals and Liverpool are recorded as `BUSINESS-` ownership entities, separate from their Team records. Their descriptions say so. If clubs should instead get a dedicated claim type, drop those three claims and Businesses before publishing.
- **Mouth taping.** Haaland's claim records what he does, not advice. ITV warns that taping the mouth during sleep can be dangerous; the claim's context repeats that warning. Consider whether the card should be published.
- **Sponsor statements.** Ohtani's and Mahomes's quotes come from statements issued with a business announcement, like James's Calm quote in the pilot.
- **Relayed quotes.** DeRozan's quotes come from ESPN quoting the Toronto Star, and Brown's anxiety quotes from Boston.com quoting an ESPN profile. Neither original was read; each Attestation says so.

## Rejected or narrowed claims

- **Kevin Love recommending therapy.** He writes that he isn't telling everyone to see a therapist, so the claim is `participates_in`, not `recommends`.
- **Jaylen Brown recommending underwater training.** Only a teammate's account says Brown advised him to try it, so no recommendation is recorded.
- **Liverpool stake dates.** ESPN reports a reported $6.5 million investment in FSG's purchase but no date, and doesn't say what happened to the direct stake after James joined FSG. The claim has no dates and its state is unknown.
- **Durant's option on another 5% of the Union, and whether he still holds the stake.** Not established; the claim has a start date only.
- **Crosby's start date.** His 2016 words ("again this year") show an earlier campaign, but no source read gives a date.
- **Unanimous Media's founding date and co-founders.** AP calls it newly formed in 2019 but names neither.
- **Haaland's start dates and the podcast date.** ITV reports the interview on 2023-08-31 without dating either.
- **Unavailable sources:** The Hollywood Reporter and Variety (Unanimous Media) returned paywall 402 responses; SLAM (Jaylen Brown) showed a bot check; NESN's 2021 Jaylen Brown meditation story and the Tim Hortons corporate release (id 5939) returned 404. None were used.

## Coverage gaps that remain

- **A morning walk interpreted differently by two people.** Still no citable source.
- **`invests_in` and `documented_unpaid`.** No claim in either batch.
- **Original interviews.** The Toronto Star interview and the ESPN Jaylen Brown profile would be stronger primary sources for the relayed quotes.

Validate the batch the same way as the pilot (see "Regenerating and checking" above).
