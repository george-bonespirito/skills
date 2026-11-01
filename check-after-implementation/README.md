# check-after-implementation

Skill for AI agents: after finishing any code implementation, run the project's **quality and security** gates in a **fix-and-recheck loop** until every blocking target is green — then emit a structured report. The same gate set must also exist as a **blocking GitHub Actions** job.

## What's inside

```
skills/check-after-implementation/
  SKILL.md   when/who/loop, quality + security core gates, CI twin skeleton, report shape
```

## Install

```text
/plugin marketplace add https://codeberg.org/torgge/skills
/plugin install check-after-implementation@torgge-skills
```

## Requirements

- A repo with discoverable quality tasks (Gradle Detekt/Konsist/ArchUnit/PIT/Kover, etc.) and/or CI workflow to mirror
- Agent that can run local build tools and open/update PRs when asked to wire CI

## License

MIT — see [LICENSE](LICENSE).
