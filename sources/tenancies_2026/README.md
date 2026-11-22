# Current home tenancies, 2026

`scripts/build_tenancies_2026.rb` turns the 174 primary home venue bindings in `sources/geography_2026/bindings.json` into open-ended `home` tenancies in `yaml/tenancies/current_2026.yml`. It reads no network data.

## What a tenancy asserts

Like a current roster capture, these record current knowledge, not the date a team moved in. Each tenancy starts on the first home game observed at the team's primary venue in the captured season schedule (US Eastern date), with the event ID in `details`. MLB's season team feed lists venues without games, so an MLB tenancy starts on the 2026 MLB opener from `sources/season_dates/`. No tenancy has an end date.

Only the primary venue becomes a tenancy. Alternative venues in the geography capture, such as Citi Field for NYCFC and NHL outdoor games, are not tenancies. Earlier venues and moves need their own sourced batch; until then a team has no recorded stadium before its current tenancy starts.

## Regeneration

```sh
ruby scripts/build_tenancies_2026.rb
ruby scripts/build_tenancies_2026.rb --check
```
