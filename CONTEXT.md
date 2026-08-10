# Context — Glossary

Ubiquitous language for this repository. Glossary only — no implementation
detail, no decisions (those live in `docs/adr/`).

## Skill

A folder with a `SKILL.md` at its root (YAML frontmatter: `name`, `description`)
providing reusable instructions/capabilities to an AI agent. The cross-agent
unit — read by Claude Code, Cursor, and other agents from the same `SKILL.md`
format. A skill is *content*, not a program to run.

## Plugin

A distributable bundle that carries one or more skills (and optionally
subagents, hooks, MCP servers, rules) plus a manifest. The unit a **marketplace**
installs. Claude plugins are manifested by `.claude-plugin/plugin.json`; Cursor
plugins by `.cursor-plugin/plugin.json`. Components (`skills/`, …) sit at the
plugin root; only the manifest lives in the `.*-plugin/` directory.

## Marketplace

A catalogue that lists plugins for one-command install. For Claude, a repo
becomes one by hosting `.claude-plugin/marketplace.json` at its root; consumers
run `/plugin marketplace add <repo>`. Cursor runs a curated, manually reviewed
marketplace that plugins are submitted to.

## Installer *(historical)*

The retired model: an idempotent `install-skill.sh` that provisioned a skill into
the user's global `~/.claude/` and appended pointers to their global config.
Superseded by the plugin/marketplace model — see `docs/adr/0001`. Distinct from a
**plugin**: an installer is a script you run; a plugin is content a host installs.

## House theme

The local visual contract applied to every generated draw.io diagram:
`adaptiveColors="auto"`, flat `plain-*` palette (no shadow/glass/gradient/sketch),
soft corners, orthogonal edges, generous spacing — tuned for readable output in
both light and dark preview. Now folded into the draw-io skill's `SKILL.md`
(previously a separate global file injected by the installer).
