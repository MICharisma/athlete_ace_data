# Curation skills

Agent skills for gathering sports facts from the web and curating them into seed manifests. Each directory holds a `SKILL.md` with `name` and `description` frontmatter, plus optional `references/` files loaded only when needed. Humans can read them as a curation handbook too.

Start with **`seed-curation`**: it describes the capture → build → validate → import → replay loop and routes to the others.

| Skill | Covers |
| --- | --- |
| `seed-curation` | Entry point and end-to-end loop |
| `source-evidence` | Whether a source supports a claim; list meanings; provenance |
| `sports-seed-sources` | Provider endpoints and checks (`references/` per provider) |
| `seed-identity` | Codes, aliases, Figures, provider-ID bindings, collisions |
| `manifest-authoring` | `micharisma-seeds/v1` envelope rules and validation |
| `geography-and-venues` | Stadiums, localities, venue registry |
| `historical-claims` | Activations, stints, rosters, transactions, numbers, games |
| `team-visuals` | Logos, uniforms, asset files, palettes |

## Discovery

AthleteAce symlinks each skill directory into its `.claude/skills/`, so Claude Code sessions in the application checkout find them automatically. The application's `AGENTS.md` points other agents here. When you add a skill, add its symlink in the application:

```sh
ln -s ../../db/seeds/athlete_ace_data/skills/<name> .claude/skills/<name>
```

## Writing and maintaining skills

- **Method here, history in sources.** Skills describe how to do the next batch. A batch's `sources/<batch>/README.md` records what that capture did; skills link to it as a worked example instead of copying it.
- **Descriptions trigger on the job.** Say what task the skill is for and what it is not for, in one or two sentences.
- **Keep `SKILL.md` short.** Move provider- or topic-specific detail into `references/` so agents load only what they need.
- **Record mistakes.** Every skill ends with "Mistakes we've made". When a batch hits a new trap, add one line there in the same change as the fix.
- **Stay true to the code.** When importer behavior, a model rule, or a script option changes, update the skill that describes it. Skills refer to application docs for the full contract rather than duplicating it.
