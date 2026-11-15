# second-brain

Skill for AI agents to operate a **source-backed Markdown second brain**: every
answer traced to a local file and, for outside claims, its URL; facts kept apart
from guesses; decisions logged with their reversals instead of overwritten. Plus
an idempotent **bootstrap** that scaffolds the skeleton into a new or existing repo.

Agent-agnostic: the rules live in `AGENTS.md`; `CLAUDE.md` just imports it, so
Claude Code, Cursor, Codex and others read the same rules.

## Credit

Based on meya. (@birmeya), *"A Build: I Wired Claude Code Into a Second Brain
That Proves Every Answer"*, X Article, 2026-11-04 —
<https://x.com/birmeya/article/2118001627235750374>. The Brain Rules, folder
skeleton, HOME index, decision-log fields, three tests, review skill steps and
failure table come from that article. Adaptations here: `AGENTS.md` as the
canonical rules file (the article keeps everything in `CLAUDE.md`), note/source
templates, and the bootstrap script.

## What's inside

```
skills/second-brain/
  SKILL.md                    how an agent answers, edits, captures and reviews
  scripts/bootstrap.sh        idempotent scaffold (never overwrites)
  templates/
    pointer.md                section appended to an existing repo's AGENTS.md/CLAUDE.md
    brain/
      AGENTS.md               Brain Rules (canonical)
      CLAUDE.md               @AGENTS.md + @HOME.md
      HOME.md                 short index: current focus, start here, next
      inbox.md                raw captures
      decisions.md            choice, reason, tradeoff, status, reopen-if; superseded never deleted
      notes/_template.md      summary, source pointer, open question
      sources/_template.md    URL, last checked, status, claims, recheck trigger
      projects/.gitkeep
      people/.gitkeep
      .claude/skills/weekly-review/SKILL.md   disable-model-invocation: true
```

## Install the skill

```text
/plugin marketplace add https://github.com/george-bonespirito/skills
/plugin install second-brain@torgge-skills
```

## Bootstrap a brain

No `curl | sh`: run the script from a local clone of this repo, from inside the
target repo.

```bash
git clone https://github.com/george-bonespirito/skills ~/src/skills
BOOT=~/src/skills/second-brain/skills/second-brain/scripts/bootstrap.sh
```

**Existing repo** (code repo that should carry a brain):

```bash
cd ~/src/my-service
bash "$BOOT" --dry-run     # preview
bash "$BOOT"               # creates ./second-brain/ at the repo root
```

The brain goes in `second-brain/` so it does not clash with the repo's own
root files or `docs/`. If the repo root already has `AGENTS.md` and/or
`CLAUDE.md`, a short pointer section is appended once (guarded by
`<!-- second-brain:pointer -->`) saying where the brain lives. Use
`--dir <path>` for another folder.

**New, dedicated brain repo**:

```bash
mkdir ~/second-brain && cd ~/second-brain && git init
bash "$BOOT" --root
```

Re-running is safe: every existing file is reported as `skipped`. With `--root`
in a repo whose `AGENTS.md`/`CLAUDE.md` already exist with other content, the
script leaves them untouched and warns you to merge the brain rules by hand.

Then fill `HOME.md`, capture into `inbox.md`, and run the three tests in
[SKILL.md](./skills/second-brain/SKILL.md#verify-the-setup). In Claude Code,
`/context` lists the loaded instructions and `/memory` shows memory settings.

## Failures and fixes

| Failure | Cause | Fix |
|---|---|---|
| Old advice keeps returning | No check date on the source | Recheck the original, update `Last checked`, mark stale entries superseded |
| Agent cannot explain a claim | Only a summary stored, no evidence link | Add the URL in `sources/` and reference that file from the note |
| Context bloats at launch | Too many files imported through the index | Keep `HOME.md` short; open detailed notes on demand |
| Two decisions contradict | Old choice never marked replaced | Set it to `superseded by D-NNN`, log the new reasoning below |
| A skill fires uninvoked | Automatic invocation left enabled | `disable-model-invocation: true` in the frontmatter (the bootstrap sets it on `weekly-review`) |
| Notes change without approval | Instructions alone cannot enforce | Add agent permissions or hooks (e.g. deny writes to the brain without approval) |
| Agent other than Claude ignores the rules | Rules only in `CLAUDE.md` | Keep rules in `AGENTS.md`; `CLAUDE.md` imports it (this plugin's layout) |

The last row is this plugin's addition; the first six are from the article.

## License

MIT — see [LICENSE](LICENSE).

## Changelog

### 0.1.0 — 2026-11-15

- First release: `second-brain` skill, `bootstrap.sh` (`--dir`, `--root`,
  `--dry-run`; idempotent, pointer append guarded by marker), templates and
  manual `weekly-review` skill.
