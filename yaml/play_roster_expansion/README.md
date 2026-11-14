# Fuller Play pools

These supplemental definitions select the full NBA and NHL player lists from
`sources/coverage_2025.json`, captured October 5, 2026. They replace the two-player
sampling limit for Play without redefining existing catalog records. Run the normal
AthleteAce `rails db:seed` entry point to load them; replay must create zero records.

NBA lists are captured roster snapshots. NHL lists represent regular-season
appearances, including players who departed during the season. These records do not
assert current teams, contract dates or exact membership bounds. Seasonal games
exclude recorded multi-team players when an answer would be ambiguous.

Each Activation explicitly references its existing Campaign. Player definitions
reuse established catalog identities where available. The two different NHL players
named Elias Pettersson retain separate identities qualified by their captured
provider IDs (`8480012` and `8483678`). Identical names alone are not a merge key.

The original sample manifests and source capture remain separate. Campaign details
on the original sample still describe that original selection; Play derives its
available-player counts from all recorded memberships, including this supplement.
