# 2026 source captures

These normalized JSON captures preserve provider IDs, source URLs, observation dates, and the complete selected source listings. `report.json` records generated coverage, number conflicts, and identity bindings. They regenerate the importable manifests under `yaml/coverage_2026/` without network access.

| Dataset | Source | Meaning |
| --- | --- | --- |
| NBA 2026/27 | ESPN season team and roster feeds | Complete source-listed season roster snapshot |
| NFL 2026 | ESPN season team and roster feeds | Complete source listing, including reserve categories where supplied |
| MLB 2026 | MLB Stats API `fullSeason` roster | Season inventory, including departed players; not a current active roster |
| NHL 2026/27 | NHL season roster and club schedule feeds | Season roster snapshot and complete regular-season schedule |
| MLS 2026 | ESPN season team and roster feeds | Complete source-listed season roster snapshot |
| EPL 2026/27 | ESPN season team and roster feeds | Club roster snapshot, not a certified senior or U21 registration list |
| Champions League 2026/27 | ESPN competition team and roster feeds | Listed league-phase clubs and club rosters, not UEFA List A or List B certification |
| NBA 2023/24 through 2025/26 | Basketball Reference season per-game tables | Regular-season and playoff appearance unions, preserving trade-side memberships; excludes members who never appeared |

The NHL capture checks 32 team schedules, 84 regular-season games per team, 1,344 unique game IDs, and two agreeing copies of each game. It excludes preseason and playoffs. Scheduled games have no fabricated scores, rosters, or appearances.

Historical season labels alone do not prove historical data. ESPN's site roster endpoint returned an empty old-season list, while its old-season core team-athlete collection returned current athletes. Those historical endpoints were rejected. Basketball Reference's separate regular-season and playoff tables provided the historical participant facts. NBA Stats reset or timed out during this capture.

The capture preserves single-name soccer players without inventing surnames. Existing official NHL player IDs preserve the two Elias Pettersson identities. ESPN soccer IDs reuse clubs and players across competitions. Abbreviations do not identify a club globally: Bayern Munich and Manchester United can both appear as `MUN`.

The visual pilot uses ESPN logo feeds, the [Blues brand page](https://www.nhl.com/blues/team/brand), an [Arsenal kit launch gallery](https://www.arsenal.com/news/gallery-2627-adidas-home-kit-launches-in-the-armoury-afAJd0y8JygH), and an [NBA Store Association Edition reference](https://store.nba.com/new-york-knicks/unisex-new-york-knicks-jalen-brunson-nike-white-swingman-jersey-association-edition/t-25470720+p-469981676139465+z-9-3762950839). Individual representation records retain the exact asset URL or the local generator name. The NBA Store product page and LockerVision API were unavailable for direct capture, so the Knicks garment depictions are schematic. Logos and images remain their owners' works; these manifests record their sources without asserting a redistribution license.

Local images and self-contained schematic GLBs are ignored under `media/`. Downloaded reference photographs are distinct from authored illustrative SVG and 3D representations. The pilot does not claim accurate geometry, materials, or textures. Each representation has one canonical local path, content type, byte size, and SHA-256. Missing historical introduction dates stay unknown. Concurrent logos are intentional.

See [the application import and refresh guide](../../../../../docs/seed-library-2026.md) for commands and replay behavior.
