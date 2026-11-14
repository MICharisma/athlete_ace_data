# Championship history and annual alignments

This batch records the NBA, NFL, NHL, and MLB championships awarded in 2016–2025. It includes 40 champions, 40 runners-up, and 1,232 annual team Campaigns. NBA and NHL seasons are labeled 2015_2016 through 2024_2025. NFL seasons are 2015 through 2024 because the Super Bowl follows the regular season. MLB seasons are 2016 through 2025.

Each championship is a Contest with two placed Contestants and a TitleAward. The entries enumerate the finalists, not the whole playoff field. No individual Games, scores, appearances, player rosters, or exact affiliation dates are generated. Only NFL awards have exact dates in this capture. Other awards retain their championship year and season without an invented day. TitleAward is the award record; this batch does not populate the older Season.champion field.

## Sources and capture meaning

Championship winners and runners-up were transcribed from these primary records on November 13, 2026:

- [NBA champions](https://www.nba.com/news/history-nba-champions), with original split-year season labels.
- [NHL 2026 Stanley Cup Final media guide](https://media.nhl.com/site/asset/public/ext/2025-26/2026StanleyCupFinal.pdf#page=43), page 43, “Stanley Cup Champions and Runners-Up.”
- [Pro Football Hall of Fame Super Bowl history](https://www.profootballhof.com/football-history/hall-of-famers-in-the-super-bowl), including the game dates.
- [MLB World Series history](https://www.mlb.com/postseason/history/world-series).

`championships.json` preserves the selected facts, source URLs, capture date, championship year, and separate season starting year. It includes exactly ten awards per league. A later award on a source page does not extend the selected window.

The four `*_alignments.json` captures enumerate every team in each selected season and its recorded conference and division. NBA, NFL, and ordinary NHL seasons use ESPN's season-specific standings hierarchy. Returned season years and distinct team counts are checked. Historical NFL names, Vegas and Seattle expansion, and the separate Arizona and Utah teams provide checks against accidentally receiving current standings.

The NHL's own dated standings supply the temporary 2020–21 divisions, observed May 20, 2021. That listing has no conferences. The NHL endpoint returned empty listings for the attempted 2015–16 off-season and in-season dates, so it was not used for the other historical seasons. ESPN's 2020–21 response did not expose the division hierarchy, so it was not used for that exception. MLB's season-specific team API supplies its annual classifications and names. Provider IDs or official NHL abbreviations are retained in the captures and reviewed bindings.

These are complete team classification lists for the selected seasons, not full player rosters or evidence of a classification's exact effective day. The records do not turn today's alignment into an unsupported claim about an earlier season.

## Inclusive year ranges

`alignment_ranges.yml` compresses the captures into 194 reviewed ranges. `from` and `through` are inclusive season starting years. For example, the Knicks' ten annual classifications use one entry:

```yaml
league: NBA
team: BKT-NBA-TEAM-NYK
from: 2015
through: 2024
conference: BKT-NBA-CONFERENCE-EASTERN_CONFERENCE
division: BKT-NBA-DIVISION-ATLANTIC_DIVISION
display_name: New York Knicks
abbreviation: NYK
```

The builder expands that entry into ten ordinary Campaign definitions. The range file is generator input outside `yaml/`, not a new manifest-envelope syntax. No shared reader or schema extension is required.

Ranges split when a conference, division, annual name, or abbreviation changes. NHL expansion and the temporary 2020–21 divisions remain explicit. Four season-specific, conference-free Division records represent that temporary alignment. Normal divisions resume in 2021–22. Arizona's Coyotes and Utah's team have distinct identities. NFL relocations and renames retain their continuing team identities, with names recorded on annual Campaigns. Cleveland's historical Indians name and the Athletics' annual name are preserved.

The builder rejects reversed ranges, overlapping team/season assignments, missing or substituted teams, and classifications that disagree with the captured season. It reuses existing catalog codes and existing declared Campaign attributes. Existing roster coverage and historical display facts are retained when another manifest already defines that Campaign. Source URLs on generated records identify the corresponding annual listing.

`display_name_corrections.json` retains reviewed exceptions to provider display names. ESPN returns Washington Commanders for 2019 through 2021. The club's [July 2020 announcement](https://www.commanders.com/news/redskins-announce-franchise-will-be-called-washington-football-team-pending-adop) and [February 2022 announcement](https://www.commanders.com/news/the-washington-football-team-is-now-the-washington-commanders) establish Redskins through 2019, Washington Football Team in 2020 and 2021, and Commanders from 2022. The raw listing is retained. Generated Campaign source metadata links the correction evidence, and range validation checks the reviewed name.

## Regenerate and validate

Run these commands from AthleteAce with its pinned Ruby:

```sh
mise exec -- ruby db/seeds/athlete_ace_data/scripts/capture_championship_alignments.rb --as-of YYYY-MM-DD
mise exec -- ruby db/seeds/athlete_ace_data/scripts/build_championship_history.rb --prepare-ranges
mise exec -- ruby db/seeds/athlete_ace_data/scripts/build_championship_history.rb
mise exec -- ruby db/seeds/athlete_ace_data/scripts/build_championship_history.rb --check
mise exec -- bundle exec rails seeds:validate
mise exec -- bundle exec rspec spec/services/seeds/championship_history_spec.rb
```

Use the actual capture date for `--as-of`. Capture makes network requests. Range preparation and generation are offline. `--prepare-ranges` replaces the reviewed ranges, so review its identity bindings and boundaries before generating manifests. To refresh only one provider, pass `--leagues NBA`, `NFL`, `NHL`, or `MLB`. Source or year-window changes require reviewing the capture script first.

`--check` exits nonzero when generated output is missing or differs. `seeds:validate` must report positive file and record counts. The focused spec must report a positive example count and zero failures. Run the structural validator documented in [CONTRIBUTING.md](../../CONTRIBUTING.md) against `yaml/championship_history` too.

## Import into an existing catalog

```sh
mise exec -- bundle exec rails seeds:championship_history
mise exec -- bundle exec rails seeds:championship_history
```

The task requires the core catalog's team, league, conference, and division identities. A fresh database first uses the ordinary `db:seed` import. The generated files are included in that import.

For an existing catalog, the dedicated task imports the batch anchors, fills missing Campaign conference/division fields, then imports the annual Campaigns and championships. It leaves current Team memberships alone. Recorded nonblank assignments are preserved; a disagreement raises and rolls back the task. This explicit fill step is separate from the ordinary importer's preserve-and-report behavior.

The first run reports created records and filled alignments. The same-capture replay must report `created: 0`, `alignments_filled: 0`, and `conflicts: 0`. A nonzero exit or nonzero replay count requires investigation.
