---
name: new-plugin
description: Scaffold a new dual-manifest plugin (Claude + Cursor) in this marketplace repo and register it in both marketplace manifests. Use when adding a new plugin/skill to publish.
disable-model-invocation: true
---

# new-plugin

Scaffold a new plugin in this collection following the `draw-io` reference layout, then register it in **both** marketplace manifests. `claude plugin init` is NOT used — it scaffolds a different layout under `~/.claude/skills/`.

Ask the user for: **plugin name** (kebab-case, starts/ends alphanumeric), **skill name** (usually same), and a **one-line description**.

## Steps

### 1. Directory + skill

Create `<plugin>/skills/<skill>/SKILL.md` (components live at the plugin **root**, never inside `.*-plugin/`):

```markdown
---
name: <skill>
description: <trigger-rich description — when should the agent use this?>
license: MIT
metadata:
  version: 0.1.0
---

# <skill>

<skill body>
```

### 2. Claude manifest — `<plugin>/.claude-plugin/plugin.json`

```json
{
  "name": "<plugin>",
  "description": "<one-line>",
  "version": "0.1.0",
  "author": { "name": "George Bonespirito", "email": "george@bonespirito.com" },
  "homepage": "https://codeberg.org/torgge/skills",
  "repository": "https://codeberg.org/torgge/skills",
  "license": "MIT",
  "keywords": ["<...>"]
}
```

### 3. Cursor manifest — `<plugin>/.cursor-plugin/plugin.json`

Same shape, omit `email`/`homepage`/`repository` (Cursor reads them from the marketplace/submission):

```json
{
  "name": "<plugin>",
  "description": "<one-line>",
  "version": "0.1.0",
  "author": { "name": "George Bonespirito" },
  "license": "MIT",
  "keywords": ["<...>"]
}
```

### 4. LICENSE + README at the plugin root

`<plugin>/LICENSE` (MIT — Cursor requires open source) and `<plugin>/README.md`. Copy the MIT text from `draw-io/LICENSE`.

### 5. Register in BOTH marketplace manifests

Append the same entry to `plugins[]` in `.claude-plugin/marketplace.json` **and** `.cursor-plugin/marketplace.json`:

```json
{ "name": "<plugin>", "source": "./<plugin>", "description": "<one-line>" }
```

### 6. Validate

```bash
jq -e . <plugin>/.claude-plugin/plugin.json <plugin>/.cursor-plugin/plugin.json .claude-plugin/marketplace.json .cursor-plugin/marketplace.json
claude plugin validate <plugin>
claude plugin validate .
```

All must pass. The `validate-manifest` hook also fires on each manifest edit.

### 7. Commit + PR

Branch `feature/<plugin>` off `main`, Conventional Commit (`✨ feat(<plugin>): …`). Push to `origin` (Codeberg) — the `auto-pr-codeberg` hook opens the PR. That commit is the publish.
