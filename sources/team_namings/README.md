# Team namings

`scripts/build_team_namings.rb` derives each NBA, NFL, NHL and MLB team's dated `TeamNaming` records, and the shared `Nickname` records they use, from the per-season display names and abbreviations that Campaigns already record. It writes `yaml/team_namings/team_namings.yml`. Run it with `--check` to verify the committed file.

A run of consecutive seasons under one display name and abbreviation becomes one naming. It starts on the run's first season start date and ends the day before the next naming starts; the latest naming stays open. These bounds are season-level, not announcement or approval dates, and each naming records its first and last season in `details`.

The generator refuses to run while any of those seasons lacks a start date, or while a Campaign's display name is just its abbreviation. Unknown dates are never filled in.

A display name splits into territory and nickname when it ends in a current team mascot or a former nickname listed in `nicknames.yml`. Other names stay whole as the naming's `display_name`, with no nickname.
