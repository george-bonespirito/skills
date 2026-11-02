# check-after-implementation

Skill for AI agents: after finishing any code implementation, run the project's **quality and security** gates in a **fix-and-recheck loop** until every blocking target is green — then emit a structured report. The same gate set must also exist as a **blocking GitHub Actions** job.

## What's inside

```
skills/check-after-implementation/
  SKILL.md   when/who/loop, quality + security core gates, CI twin skeleton, report shape
```

## Install

```text
/plugin marketplace add https://github.com/torgge/skills
/plugin install check-after-implementation@torgge-skills
```

## Requirements

- A repo with discoverable quality tasks (Gradle Detekt/Konsist/ArchUnit/PIT/Kover, etc.) and/or CI workflow to mirror
- Agent that can run local build tools and open/update PRs when asked to wire CI

## License

MIT — see [LICENSE](LICENSE).

## Changelog

### 0.2.0 — 2026-11-01

Applied review patches P0–P2:

- Fail-closed verdicts: new *Verdict rules*; a core gate in `⏭️` caps the verdict at PASS WITH CI-PENDING; ✅ without evidence counts as ❌; new `⚠️ non-blocking` state.
- Loop: a full final iteration is required before PASS; failure signature = gate + first error line; caps of 3 same-signature / 6 total iterations (defaults, overridable by project config); proof of pre-existing debt via a merge-base worktree.
- Explicit list of weakening actions (baselines, `.gitleaksignore`, suppressions, `@Disabled`, module excludes, `failBuildOnCVSS`), allowed only with recorded user approval.
- Dependency-Check `failBuildOnCVSS` ≤ 7 + NVD API key check; Dependabot alerts via `gh api`.
- Evidence column in the report; file:line + greps for manual critical-data/endpoint review.
- A red CI twin reopens the loop; a missing/drifted twin is always a Blocker; a local PASS never authorizes merge.
- CI skeleton: actions pinned by SHA, Gradle wrapper validation, job-level `SONAR_TOKEN` (required Sonar fails when the secret is missing), placeholders instead of invented tasks, `security-events: write` only on SARIF jobs, `GITLEAKS_LICENSE` note, parallel TypeScript job.
- TS/Node core gates block; step zero `./gradlew tasks --all`; CRAP < 10 clarified as an example only.
