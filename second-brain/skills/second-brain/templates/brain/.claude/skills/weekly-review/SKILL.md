---
name: weekly-review
description: Audit this second brain on demand for missing sources, unchecked dates, possibly outdated claims, conflicting decisions and unfinished actions. Run only when the user types the command.
disable-model-invocation: true
---

# weekly-review

Manual invocation only. Not a scheduler. Read-only.

1. Read `HOME.md`, `inbox.md` and `decisions.md`.
2. Walk every file in `notes/` and `sources/` (skip `_template.md`). Flag notes
   without a source file, sources without a URL, and missing or old
   `Last checked` dates.
3. Flag claims that might be outdated, without declaring them false.
4. Find conflicting `active` decisions and unfinished actions (HOME `Next`,
   open questions, stale inbox items).
5. Return a prioritised checklist with exact file paths.
6. Make no edits and claim no live-URL verification without the user's approval.
