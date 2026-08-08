# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

A personal **skills collection** — the publishing source for skills authored or used day-to-day with AI agents (Claude Code and others). Each top-level directory is one self-contained skill. "Publishing" a skill = committing it here; consumers install it from this repo.

Repo root is `/Users/gbonespirito/Development/skills` (the git root). `draw-io/` is the first skill and the **reference implementation** — mirror its conventions when adding new skills.

## Skill directory convention

Each skill lives in its own top-level directory and is installed into the **global** Claude Code context (`~/.claude/`), not per-project. The convention, established by `draw-io/`:

- **`install-skill.sh`** — idempotent bash installer, the skill's entry point. Safe to re-run and to paste into a `bootstrap.sh`. It provisions the skill into `~/.claude/` and prints manual validation steps.
- **`CLAUDE.md`** (per skill) — scoped guidance for that skill's directory. Documents the skill's own architecture, not the collection's.

There is no repo-wide build, lint, or test harness — skills are shell installers plus docs. Validation is per-skill and manual (each `install-skill.sh` prints its own check).

## The upstream/local two-layer invariant (installer design)

The core pattern every installer should preserve (see `draw-io/install-skill.sh`): keep **upstream** artifacts separate from **local** customizations so upstream updates never clobber user edits.

- Upstream files (fetched/cloned each run) → `cp` / overwrite. Never hand-edit; changes are lost on re-run.
- Local files (themes, config, spine pointers) → written **only if missing**, guarded by `[ -f ]` or `grep -q`. Re-runs preserve them.

When authoring or editing an installer, honor this split: clobber upstream, guard local.

## Adding a new skill

1. Create a top-level directory named for the skill.
2. Add an idempotent `install-skill.sh` following the two-layer invariant above.
3. Add a scoped `CLAUDE.md` if the skill has non-obvious architecture.
4. Commit (see git conventions below) — that commit is the publish.

## Git

- Conventional Commits + emoji (see `~/.claude/rules/commits.md`). One skill per PR; branch off `main` (`feature/<slug>`), never commit to `main` directly.
- MCP: `.claude/settings.local.json` enables the `graphify` MCP server for this repo.
