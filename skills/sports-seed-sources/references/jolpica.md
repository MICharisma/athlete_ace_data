# Jolpica-F1

Jolpica-F1 (`https://api.jolpi.ca/ergast/f1/`) is the Ergast-compatible successor to the Ergast API, which shut down. Worked example: `sources/f1_2026/`, captured by `scripts/capture_f1_2026.rb`.

## Endpoints

All take `.json` and `?limit=100&offset=N`. 100 is the maximum page size. Check each response's `total`, and that `season` echoes the requested year.

| Path | Gives |
| --- | --- |
| `{year}` | Calendar: round, race name, date and time, circuit, and a `Sprint` block on sprint weekends |
| `{year}/circuits` | Circuit name, locality, country and coordinates |
| `{year}/constructors`, `{year}/drivers` | Season tables |
| `{year}/results`, `{year}/sprint` | One row per classified entrant per session, with car number, position, `positionText`, grid, laps, points and status |
| `{year}/driverstandings` | Running standings; useful as a completeness check |

## What the lists mean

- **The season driver table includes practice and reserve drivers.** 2026 lists 36 drivers, but only 25 have race or sprint results. Treat only drivers with results as race entrants.
- **The circuit table can keep a circuit whose race was dropped.** 2026 still listed Jeddah. Seed circuits from the calendar, and record the leftovers.
- **Results tables page by result row, not by race.** A page of 100 ends partway through a race. Count rows against `total`, and expect 22 rows per session on a 22-car grid.
- **`position` is always a number. `positionText` says R (retired), D (disqualified), W (withdrawn) or N (not classified).** Keep both.
- **Points can be fractional** (half points), so store them as numbers.
- **Event names don't imply the venue.** Round 16 of 2026 is the "Bahrain Grand Prix in Malaysia", held at Sepang. The venue comes from the circuit.
- **Localities are approximate** (Barcelona for Montmeló, Kuala Lumpur for Sepang, Budapest for Mogyoród, Spa for Stavelot, Miami for Miami Gardens). Keep the provider locality, as the geography policy says, and list the gaps for a sourced correction.

## Checks

- **Before capturing:** rounds run 1..N, and every calendar circuit is in the circuit table.
- **While capturing:** every result's driver and constructor is in the season tables, and every sprint result belongs to a round with a `Sprint` block.
- **After importing:** each driver's points summed from appearances match `driverstandings`.
- **Respect the rate limit.** The capture waits half a second between uncached requests.
