# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

Single-file installer that provisions the upstream draw.io skill (`jgraph/drawio-mcp`) into the **global** Claude Code context (`~/.claude/`), plus a local house-theme layer. There is no application code, build, or test suite — the deliverable is `install-skill.sh` itself.

## Run

```bash
chmod +x install-skill.sh && ./install-skill.sh
```

Idempotent — safe to re-run and to paste into a `bootstrap.sh`. Requires network (clones `REPO_URL` via `git`).

## Architecture — the two-layer split (the key design point)

The installer deliberately separates **upstream** from **local** so upstream updates never clobber local edits:

- **Upstream layer** (`~/.claude/skills/drawio/SKILL.md`): copied fresh from `jgraph/drawio-mcp` on every run. Always overwritten — never hand-edit here; edits are lost on re-run.
- **House-theme layer** (`~/.claude/drawio-house-theme.md`): local flat/`adaptiveColors` theme. Written **only if missing** — re-runs preserve your tweaks. This is where diagram styling lives.
- **Spine pointer** (`~/.claude/CLAUDE.md`): a one-line pointer to the house-theme is appended, guarded by `grep` so it's added at most once.

When editing `install-skill.sh`, preserve this invariant: upstream files are `cp` (clobber), local files are guarded (`[ -f ]` / `grep -q`).

## Phases in the script

- **Fase 0** — checks for draw.io Desktop (`drawio` on PATH). Optional: only needed to export `.drawio` → `.svg/.png/.pdf`. Missing → warns, continues (native `.drawio` generation still works). GUI host app, not containerizable.
- **Fase 1** — clone upstream, copy `skill-cli/drawio/SKILL.md`.
- **Fase 2** — write house-theme + spine pointer (guarded).
- **Fase 3** — prints manual validation steps (`/drawio` is interactive; no automated check).

## House-theme intent

Diagrams target human readability in both VS Code light and dark preview: `adaptiveColors="auto"`, flat `plain-*` palette (no shadow/glass/gradient/sketch), rounded corners, generous spacing. Version only the exported `.drawio.svg`; the intermediate `.drawio` is deleted after export.
