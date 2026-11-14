# Legacy AthleteAce JSON templates

These templates describe the legacy JSON seed layout, used only by the explicit legacy importer. For maintained YAML or JSON manifests, use the `micharisma-seeds/v1` envelope and follow the [contributor guide](../CONTRIBUTING.md). The standard Rails seed command imports that maintained library.

## Template Files

### Core Sports Data
- **`sports.json`** - Sport definitions (Baseball, Basketball, etc.)
- **`leagues.json`** - League information within a sport/country
- **`conferences.json`** - Conference and division structure
- **`teams.json`** - Team information including colors, logos, stadiums
- **`players.json`** - Individual player data and statistics
- **`memberships.json`** - Historical team-division relationships
- **`seasons.json`** - Season dates, format, and metadata
- **`positions.json`** - Sport-specific player positions

### Location Data
- **`countries.json`** - Country information with ISO codes
- **`states.json`** - States/provinces within countries  
- **`cities.json`** - Cities within states
- **`stadiums.json`** - Stadium/venue information

### Contest & Achievement Data
- **`contests.json`** - Competitions, tournaments, regular seasons
- **`quests.json`** - Achievements and quest definitions
- **`spectrums.json`** - Rating scales and measurement systems

### Historical Data
- **`expansions.json`** - Team expansion campaigns
- **`transitions.json`** - Team relocations, rebrands, name changes
- **`federations.json`** - International governing bodies

## Usage Guidelines

1. **Follow the schema** - Each template shows required and optional fields
2. **Use consistent naming** - Follow existing naming conventions in the data
3. **Include metadata** - Add descriptions, URLs, and logos where available
4. **Validate relationships** - Ensure team names match across files
5. **Use ISO standards** - Country codes, date formats, etc.

## File Locations

Place your JSON files in the appropriate directory structure:

```
db/seeds/athlete_ace_data/
├── sports/
│   └── [sport_name]/
│       └── [country]/
│           ├── leagues.json
│           └── [league_name]/
│               ├── conferences.json
│               ├── teams.json
│               ├── memberships.json
│               ├── seasons.json
│               ├── contests/
│               │   └── *.json
│               └── players/
│                   └── [team_name].json
├── locations/
│   ├── countries/
│   ├── states/
│   ├── cities/
│   └── stadiums/
├── quests/
├── ratings/
└── federations/
```

## Contributing

When adding new data:

1. Start with location data (country → state → city → stadium)
2. Add sport and league structure
3. Create teams and assign to divisions
4. Add players and historical data
5. Create contests and achievements

For questions or help, please refer to the main AthleteAce documentation.

## Seasons Champion Metadata

Season seed files can now indicate the champion without requiring full playoff data.

- Use `champion_name` or `champion_id` on a season entry to set `season.champion`.
- Use `championship_contest_name` or `championship_contest_id` to link the season to the deciding contest.
- If only a championship contest is provided and that contest has a champion, the season champion will be inferred from the contest on the post-contest sync pass.
