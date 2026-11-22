# Season dates, captured 22 November 2026

`season_dates.json` records the first and last regular-season game dates for the 62 NBA, NFL, NHL and MLB seasons in the library: NBA 2000-01 to 2026-27, NFL 2015 to 2026, NHL 2015-16 to 2026-27 and MLB 2016 to 2026. `scripts/build_season_dates.rb` adds them to the Season definitions in `yaml/catalog/` as `start_date` and `end_date`. The team namings generator (`scripts/build_team_namings.rb`) dates each naming from these start dates.

## Source and meaning

- A date is a US Eastern scoreboard day, as ESPN's `scoreboard?dates=YYYYMMDD` parameter reads it, on which at least one **completed** regular-season game (season type 2) is listed. The capture keeps each first and last day's URL and game IDs.
- ESPN's core API season-type window (`/seasons/{year}/types/2`) only starts the search. Its start is usually the day before the first game, so the window itself is not recorded as a season date. The search continues past the window while completed regular-season games appear within 21 days.
- Seasons in progress on the capture date (NBA 2026-27, NHL 2026-27 and NFL 2026) have no end date.
- NBA and NHL seasons are requested by ending year, NFL and MLB by calendar year. Every response's season year is checked.

## Reviewed cases

- ESPN keeps postponed and cancelled games in the season, so only completed games count. Without that rule the NHL 2019-20 season appeared to end on 4 April 2020; play stopped on 11 March.
- MLB's 2025 Tokyo Series (18 and 19 March) falls before ESPN's season window, which starts on 27 March. The look-back finds it.
- The capture matches the 2011-12 NBA lockout opener (25 December 2011), the 2020-21 NBA and NHL starts (22 December 2020 and 13 January 2021) and the 14 August 2020 end of the NBA's bubble regular season.

## Regeneration

```sh
ruby scripts/capture_season_dates.rb --as-of YYYY-MM-DD [--refresh]
ruby scripts/build_season_dates.rb
ruby scripts/build_season_dates.rb --check
```

The application fills missing dates on existing seasons before the library import compares values, and reports any recorded date that differs.
