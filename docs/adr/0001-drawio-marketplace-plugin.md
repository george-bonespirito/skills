# ADR-0001: draw-io ships as a self-contained marketplace plugin

- **Status**: Accepted
- **Date**: 2026-08-08

## Context

`draw-io/` started as an **installer wrapper**: `install-skill.sh` cloned
`jgraph/drawio-mcp` at install time, copied their `SKILL.md` into the user's
global `~/.claude/skills/drawio/`, and bolted on a local house-theme file plus a
one-line pointer appended to `~/.claude/CLAUDE.md`. The collection's design
invariant was the **two-layer split**: upstream files re-fetched and clobbered
each run, local files written only-if-missing so upstream updates never
overwrote user edits.

The goal is now to publish draw-io to the **Claude Code** and **Cursor** plugin
marketplaces. Both consume a **declarative, self-contained plugin**
(`skills/<name>/SKILL.md` + a manifest); neither runs a bash installer, and
neither can append to the user's global `CLAUDE.md`. The installer model and the
marketplace model are structurally incompatible.

## Decision

Repackage draw-io as a self-contained, dual-manifest plugin, and turn the
collection repo into a Claude marketplace:

1. **Vendored + rewritten content.** The `SKILL.md` is authored in our own voice
   (the CLI pipeline is factual behavior of the `drawio` binary, not creative
   IP), with the house-theme folded directly into it. No verbatim upstream text,
   so no redistribution/attribution burden.
2. **MIT license.** The plugin is original work under MIT; satisfies Cursor's
   open-source requirement. draw.io itself stays a separate project under its own
   license, credited as a courtesy.
3. **Collection becomes a marketplace.** Repo root gains
   `.claude-plugin/marketplace.json`; `draw-io/` becomes a plugin with
   `.claude-plugin/plugin.json` (Claude) + `.cursor-plugin/plugin.json` (Cursor)
   over one shared `skills/drawio/` directory.
4. **Installer retired.** `draw-io/install-skill.sh` and the installer-scoped
   `draw-io/CLAUDE.md` are removed. The two-layer invariant becomes vestigial for
   draw-io: with content vendored and rewritten, there is no install-time
   upstream fetch to guard against.
5. **Export-SVG-first, draw.io Desktop as prerequisite.** The house-themed
   `.drawio.svg` stays the headline deliverable; the desktop CLI is a documented
   prerequisite (GUI host app, unbundlable), with graceful XML/URL degradation.

## Alternatives considered

- **Thin house-theme layer + hard dependency on the upstream skill.** Rejected:
  breaks the marketplace "self-contained" expectation; the skill would not work
  on its own after install.
- **Contribute the house-theme upstream to `jgraph/drawio-mcp`.** Rejected: cedes
  authorship and release control; ties our publishing cadence to their merges.
- **Copy upstream `SKILL.md` verbatim under Apache-2.0.** Rejected in favour of
  rewriting: avoids LICENSE/NOTICE/changelog bookkeeping and gives clean MIT
  authorship.
- **Keep the installer as a second global-install path.** Rejected: dual sources
  of truth for the skill content invite drift.

## Consequences

- The collection's documented "installer + two-layer invariant" identity no
  longer applies to draw-io; README and CLAUDE.md are updated to describe the
  marketplace model. Future skills follow the plugin layout, not the installer.
- Consumers install via `/plugin marketplace add <repo>` (Claude) or the Cursor
  Marketplace, not by running a shell script.
- **Open:** whether Claude's `/plugin marketplace add` accepts a Codeberg URL
  (vs requiring GitHub) is unverified. The manifest format is host-agnostic, so a
  mirror is a cheap fallback if needed.
- **Open:** Cursor documents a portable single `plugin.json` (schema-identified)
  as an alternative to the two manifest dirs; not yet evaluated for collapsing
  the dual manifest.
