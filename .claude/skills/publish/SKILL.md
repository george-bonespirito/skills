---
name: publish
description: Publish a plugin from this repo — conformance check, commit, push to Codeberg (auto-PR), and after merge, mirror to GitHub and run the Cursor marketplace submit runbook. Use when a plugin is ready to publish or re-publish.
disable-model-invocation: true
---

# publish

End-to-end publish flow for this dual marketplace. `origin` = Codeberg (canonical), `github` = public mirror for Cursor's publish gate. Committing a plugin here + listing it is the publish; the Cursor marketplace submit is a separate one-time step per publisher.

Ask which plugin is being published. Then:

## 1. Conformance check

Dispatch the `plugin-conformance-reviewer` subagent on the plugin. If it reports blocking failures, stop and surface them — do not publish a non-conforming plugin.

Also confirm manifests parse:
```bash
jq -e . <plugin>/.claude-plugin/plugin.json <plugin>/.cursor-plugin/plugin.json \
        .claude-plugin/marketplace.json .cursor-plugin/marketplace.json
claude plugin validate <plugin> && claude plugin validate .
```

## 2. Branch + commit

Branch `feature/<plugin>` (or `fix/`) off `main` — never commit to `main` directly. Conventional Commit with emoji (`✨ feat(<plugin>): …`). That commit is the publish.

## 3. Push → auto-PR

```bash
git push -u origin feature/<plugin>
```
The `auto-pr-codeberg` hook opens the PR. **Then STOP and wait for the user to approve/merge** — never merge yourself (see the pr-create-await-approval convention). Do not proceed to step 4 until the user confirms the merge.

## 4. After merge — sync + mirror

Verify the merge actually landed, then mirror to GitHub:
```bash
git fetch origin --prune
git switch main && git pull origin main --ff-only
git push github main
```
Confirm `github main` SHA == local `main`. If `git push github` fails with "Could not resolve host", the local DNS is blocking `github.com` (a focus/hosts blocker) — ask the user to run it via `!` or fix DNS.

## 5. Cursor marketplace submit (manual, one-time)

Only the repo owner submits, authenticating via GitHub ownership. This is a browser step — you cannot do it. Provide the runbook:

- Open `https://cursor.com/marketplace/publish`, log in with the GitHub account that owns `torgge/skills`.
- **GitHub repository:** `https://github.com/torgge/skills`
- **Logotype URL** (optional, 1:1 SVG/PNG): if the plugin has `assets/logo.svg`, serve via jsDelivr for the correct `image/svg+xml` MIME: `https://cdn.jsdelivr.net/gh/torgge/skills@main/<plugin>/assets/logo.svg` — NOT `raw.githubusercontent.com` (serves `text/plain`).
- **Website URL:** `https://codeberg.org/torgge/skills`
- Submit → pending Cursor team review.

## Notes

- Local/manual install works from GitHub immediately, independent of the public-marketplace review.
- Re-publishing an existing plugin: bump `version` in both `plugin.json` files (SemVer) and tag with `claude plugin tag <plugin>` before the PR.
