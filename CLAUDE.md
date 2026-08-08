# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

A personal **skills collection** that is also a **plugin marketplace** — the publishing source for skills used day-to-day with AI agents (Claude Code, Cursor, and others). Each top-level directory is one self-contained plugin bundling a skill. "Publishing" = committing it here and listing it in `.claude-plugin/marketplace.json`; consumers install via the marketplace.

Repo root is `/Users/gbonespirito/Development/skills` (the git root). `draw-io/` is the first plugin and the **reference implementation** — mirror its layout when adding new ones. See [`CONTEXT.md`](./CONTEXT.md) for the glossary and [`docs/adr/`](./docs/adr/) for decisions.

## Plugin directory convention

Each plugin lives in its own top-level directory and is installed by the host (Claude Code / Cursor), not by a shell script. The layout, established by `draw-io/`:

- **`skills/<skill>/SKILL.md`** — the skill itself (YAML frontmatter: `name`, `description`). One `skills/` dir, shared by both manifests.
- **`.claude-plugin/plugin.json`** — Claude manifest (`name` required).
- **`.cursor-plugin/plugin.json`** — Cursor manifest (`name` required).
- **`LICENSE`** + **`README.md`** at the plugin root. Cursor requires plugins be open source.

Components (`skills/`, agents, hooks) sit at the plugin **root**; only the manifest goes inside the `.*-plugin/` directory — misplacing components inside it makes them load silently invisible.

The repo root carries `.claude-plugin/marketplace.json` (`name`, `owner`, `plugins[]`), making the collection a Claude marketplace. There is no repo-wide build/lint/test — validation is per-plugin (`claude plugin validate`, then a manual `/plugin install` smoke test).

## Self-contained, not installer-fetched

Plugins are **declarative bundles the host installs** — they cannot run bash or edit the user's global `~/.claude/CLAUDE.md`. So skill content is **vendored in-repo**, never fetched at install time, and any local layer (e.g. draw-io's house theme) is **folded into `SKILL.md`**, not injected via a global-config pointer.

> Historical note: draw-io began as an `install-skill.sh` wrapper around an upstream fetch, governed by a two-layer "clobber upstream / guard local" invariant. That model is retired — with content vendored, there is no install-time fetch to guard. See `docs/adr/0001` for the rationale.

## Adding a new plugin

1. Create a top-level directory for the plugin.
2. Add `skills/<skill>/SKILL.md` (vendored content; fold any local layer in).
3. Add `.claude-plugin/plugin.json` + `.cursor-plugin/plugin.json`, `LICENSE` (open source), `README.md`.
4. Register it in `.claude-plugin/marketplace.json`.
5. Commit (see git conventions below) — that commit is the publish.

## Git

- Conventional Commits + emoji (see `~/.claude/rules/commits.md`). One plugin per PR; branch off `main` (`feature/<slug>`), never commit to `main` directly.
- MCP: `.claude/settings.local.json` enables the `graphify` MCP server for this repo.
