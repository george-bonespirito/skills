---
name: check-after-implementation
description: >-
  Use after finishing any code implementation to run quality and security gates
  (complexity, Clean Code, architecture, Detekt, Sonar, dependency/CVE versions,
  secrets and critical-data exposure) and report pass/fail before calling the
  work done. The implementing agent runs this in a fix-and-recheck loop until
  every blocking target is green. The same gate set must also run as a blocking
  GitHub Actions job/step.
---
# check-after-implementation

Run this **whenever an implementation is finished**, **before** declaring done, opening/merging a PR, or moving to the next task. A human may run it; in an agent session the owner is **the implementing agent** (see *Who runs it*). Goal: the change matches the project's acceptable **quality and security** bar—not only "it compiles" or "tests are green."

This skill **anticipates** CI. Blocking truth lives in **GitHub Actions**. Local runs must match the same Gradle tasks/thresholds the CI uses. Do not claim CI passed without a real green run.

**A local PASS never authorizes merge.** Merge depends only on the required status check (the CI twin) being green on the PR head commit.

**Twin requirement:** every project that uses this skill MUST have a **blocking** GitHub Actions job (or reusable workflow) that runs the **same** quality + security targets. Agent loop locally; CI enforces on every PR/push. A missing or drifted twin is always a **Blocker** in the report and caps the verdict at `PASS WITH CI-PENDING` (see *Agent duty when the twin is missing or drifts*).

## Who runs it

**The same agent that implemented the feature/fix** owns the local loop. It does **not** hand off to a reviewer and stop.

CI runs the same checks on `pull_request` and `push` to protected branches (and on `workflow_dispatch` when useful). Merge is blocked while the job is red.

**A red twin reopens the loop.** If the CI twin goes red on the PR (including after a local `PASS WITH CI-PENDING`), the loop reopens with the same owner, and the previous local PASS is no longer valid. Fix, re-run the full local suite, push, and observe the twin again.

## Loop until targets are met (required behavior — local)

Treat the gate checklist as a **contract**. After the first run:

```text
LOOP:
  1. Run all blocking gates for this repo (quality + security core + applicable suggested).
  2. If every blocking target is ✅ in a FULL iteration (and CI-pending items are listed, not faked):
       emit the report with the verdict from "Verdict rules" → EXIT loop.
  3. If any blocking target is ❌:
       a. Fix the failures that are in scope of this change (code, tests, config the change introduced).
       b. Re-run the failed gates to iterate quickly. Before any PASS verdict, run the COMPLETE
          blocking suite in a single final iteration; greens collected from partial re-runs do not count.
       c. Go to 1.
  4. Stop looping only when:
       - all blocking targets are green in a full final iteration, OR
       - the loop cap is hit (see Rules), OR
       - remaining reds are PROVEN pre-existing debt outside the diff / need a policy or infra change
         the agent cannot do alone.
     Proof of pre-existing debt: the same gate fails with the same signature at
     `git merge-base HEAD origin/<default-branch>`, checked out in a separate worktree
     (e.g. `git worktree add ../base $(git merge-base HEAD origin/main) && cd ../base && ./gradlew <task>`).
     Attach the command and its output to the report.
     In the cap or debt case: Verdict FAIL, list exact blockers and what the human must decide—do **not** declare the implementation done.
```

Rules for the loop:

- **No "ship and hope"** — one red blocking gate ⇒ keep fixing or escalate; never mark done.
- **Cap runaway loops** — a failure **signature** is `<gate> + <first error line>`.
  - The same signature in **3 consecutive iterations** ends the loop.
  - **6 total iterations** end the loop regardless of signatures (this catches A,B,A,B oscillation).
  - These are **defaults**. A project may override them in its config (e.g. `.check-after-implementation.yml` with `loop.maxSameSignature` / `loop.maxIterations`, or an equivalent section in the constitution/ADR); the project value wins and is quoted in the report.
  - Either cap ⇒ **Verdict FAIL**, with the attempts per signature and the blockers listed; the agent escalates to the user. No infinite loops burning tokens on the same error.
- **Do not weaken targets** to exit the loop. Weakening includes: threshold edits; a new baseline entry (Detekt/Android Lint); new `.gitleaksignore` entries; Dependency-Check suppressions; `@Suppress` / `@SuppressWarnings`; `@Disabled` / `@Ignore`; deleting tests; excluding a module or path from a gate; changing `failBuildOnCVSS`. Any of these is allowed **only with explicit user approval**, recorded in the report's **Follow-ups**.
- **CI-pending** (Sonar cloud secrets, org-level scanners) does not replace local greens; locals must be green first, then note what still waits on CI.

## When to use

- Right after implementing or generating production code
- After a refactor that touches domain/application layers
- Before asking the user to review a PR
- After fixing review comments that changed code
- After adding or bumping dependencies
- When adopting this skill in a repo: ensure the GitHub Actions twin job exists and is required on the default branch
- When the CI twin goes red on a PR you own (the loop reopens)

Skip only for pure docs/ADR-only edits with no code or dependency change (still run markdown/link checks if the repo has them).

## Stance

1. **Inventory first** — discover what the repo already wires (Gradle plugins, CI workflows, Dependabot/Renovate, constitution/ADR quality rules). Prefer existing tasks over inventing new ones; every task you run or put in YAML must exist in `./gradlew tasks --all`.
2. **Same bar as CI** — thresholds come from the project (`build.gradle.kts`, `detekt.yml`, Sonar quality profile, ArchUnit/Konsist tests, `.github/dependabot.yml`, workflow YAML), not from vibes. Numbers in this skill (e.g. CRAP < 10) are **examples** used only when the project defines nothing.
3. **Fix or escalate** — if a gate fails and the fix is in scope of the change, fix it and re-run. If the gate is broken by pre-existing debt outside the change, prove it (merge-base check) and report it; do not silently widen scope.
4. **Diff-aware when possible** — prefer PR-diff / changed-module scope when the project supports it.
5. **Security is blocking** — critical-data exposure, committed secrets, and known vulnerable dependency versions introduced by the change are **FAIL**, not notes.
6. **Report in a fixed shape** (see below). Fail closed: any blocking gate red, unconfigured, or without evidence ⇒ work is not done.

## Core gates — quality (always attempt)

| Gate | Intent | Typical local signal |
| --- | --- | --- |
| **Cyclomatic / CRAP** | Keep functions simple; CRAP combines complexity + coverage | Project's CRAP task, Detekt complexity, or Kover/JaCoCo + complexity; threshold from project config (example when none: CRAP &lt; 10) |
| **Clean Code** | Naming, size, nesting, dead code, magic numbers | Detekt, ktlint/spotless; constitution |
| **Architecture** | Layer/package rules, dependency direction | **Konsist** and/or **ArchUnit** tests |
| **Static analysis (Detekt)** | Smells, complexity, coroutines, style | `./gradlew detekt` |
| **Sonar** | Portfolio gate (bugs, smells, coverage, duplications, security hotspots) | `sonar` in CI with secrets; local may be **CI-pending** |

## Core gates — security (always attempt)

| Gate | Intent | Typical local / CI signal |
| --- | --- | --- |
| **Dependency versions & CVEs** | No known-vulnerable or abandoned libs introduced/left unpinned by the change | OWASP Dependency-Check `./gradlew dependencyCheckAnalyze` (verify config, see below); Dependabot alerts via `gh api`; Renovate; Snyk/OSV; version catalogs + lockfiles |
| **Secret & credential leak** | No tokens, passwords, private keys, or connection strings in the diff | `gitleaks git --log-opts="origin/<default>..HEAD"` / TruffleHog / `detect-secrets` on the diff |
| **Critical / sensitive data exposure** | PII, secrets, financial/health identifiers, tokens must not leak via logs, APIs, errors, or traces | Diff review with evidence (files + greps) + Detekt/Sonar security rules; sanitize errors; redact OTel attributes |
| **Safe defaults in new endpoints** | Authz, validation, injection, mass-assignment | Diff review with evidence; authz consistent with neighbors; Bean Validation; parameterized queries only |

### Critical-data checklist (manual + automated)

Apply to every changed handler, logger, serializer, and trace. For each item record the **`file:line` ranges reviewed** and the **greps used** (e.g. `git diff origin/<default>...HEAD | grep -nE 'log\.(info|debug|warn|error)|logger\.'`, new `*Dto`/`*Response` classes in the diff, new `@RestController`/`@*Mapping`). An unchecked item without evidence is ❌.

- [ ] Logs / metrics / spans do **not** include passwords, tokens, full card numbers, document IDs, or session cookies — files:lines reviewed: …
- [ ] Exception messages and Problem Details bodies are safe for clients — files:lines reviewed: …
- [ ] Persistence and cache keys do not store secrets in plaintext — files:lines reviewed: …
- [ ] New public fields on APIs were intentional (no entity dumped as DTO) — files:lines reviewed: …
- [ ] Test fixtures do not embed production-like secrets — files:lines reviewed: …

If the project has a dedicated "sensitive data" / privacy ADR or Detekt rule set, that document wins.

### Dependabot / version policy

- Confirm `.github/dependabot.yml` (or Renovate) exists; new deps must be maintained and pinned as the repo requires
- On the PR: list open Dependabot alerts and filter by the manifests you touched:
  `gh api "repos/{owner}/{repo}/dependabot/alerts?state=open" --paginate -q '.[] | [.dependency.manifest_path, .dependency.package.name, .security_advisory.severity] | @tsv'`
- **Dependency-Check config:** verify `failBuildOnCVSS` ≤ 7 (or the project's policy value) and that an NVD API key is configured (`nvd.apiKey` / `NVD_API_KEY` secret). The default `failBuildOnCVSS = 11` never fails, and without an API key the NVD download is slow and flaky. If either is missing, the gate result is `⚠️ non-blocking` (listed in Blockers as a config gap), **not** ✅.
- Prefer upgrading vulnerable transitives via BOM/platform rather than blind excludes
- Record skipped upgrades with reason (never silent)

If a listed tool is **not** in the repo, say so and run a substitute only if it covers the **same intent** (e.g. OSV-Scanner for Dependency-Check, TruffleHog for gitleaks) and record which one. If no substitute exists, the gate is `⏭️` (see Verdict rules: a core gate in `⏭️` is not green). Do not invent fake scores or fake CVE clears.

## Core gates — TypeScript / Node (when the diff touches TS/JS: Nest, React, etc.)

When the diff touches TypeScript/JavaScript, these are **core** (blocking), not suggested:

| Gate | Typical command |
| --- | --- |
| Type check | `npx tsc --noEmit` |
| Lint + security rules | `npx eslint .` with a security plugin (e.g. `eslint-plugin-security`) |
| Tests | the repo's `npm test` / `pnpm test` |
| Dependency CVEs | `npm audit --audit-level=high` (or `pnpm audit --audit-level high`) |

The CI twin gets a parallel job using `actions/setup-node` that runs the same commands (see skeleton).

## Suggested gates (when the project supports them)

1. **Mutation testing (PIT / Stryker)** — prefer **diff-scoped**; SDD middle ground: mutation everywhere; test-first for domain
2. **Coverage with teeth (Kover / JaCoCo)** — pair with CRAP; regression on changed module
3. **Formatting (Spotless, ktlintFormat)**
4. **Duplication** — report-only if ub-mode policy says so
5. **API / contract** — OpenAPI diff, Pact, Spring Cloud Contract
6. **Container / IaC** — Hadolint, Trivy, Checkov when containers/IaC change
7. **SAST extras** — Semgrep / CodeQL
8. **Observability conventions** — OTel naming; no sensitive attributes
9. **ADR / constitution** automated checks
10. **Build** — `./gradlew assemble` + tests for touched modules

## GitHub Actions twin (required)

The CI job is the **authoritative** twin of this skill. Name it clearly (e.g. `check-after-implementation` or `quality-and-security`) and make it a **required status check** on the default branch.

### What the workflow must do

1. Trigger on `pull_request` and `push` to protected branches (plus `workflow_dispatch` optional).
2. Run the **same** Gradle (or stack) tasks the agent runs locally—identical task names and configs. Every task must exist in `./gradlew tasks --all`.
3. Cover **quality core + security core**; add suggested gates the repo already supports.
4. Fail the job on any blocking gate red (`set -e` / Gradle non-zero / action `fail_ci`). If Sonar is required in the repo, a missing `SONAR_TOKEN` must **fail** the job, never skip.
5. Upload reports as artifacts (Detekt, Kover/JaCoCo, PIT, Dependency-Check, gitleaks) for PR inspection.
6. Keep secrets (Sonar token, Snyk token, NVD API key, gitleaks license) only in GitHub Secrets / Environments—never in the repo.
7. Pin third-party actions by **commit SHA** (with the version tag as a comment); validate the Gradle wrapper before running it.
8. Grant `security-events: write` **only** to the job that uploads SARIF (CodeQL etc.); everything else stays `contents: read`.
9. Prefer a **reusable workflow** (`.github/workflows/check-after-implementation.yml` calling a shared `workflow_call`) when multiple repos share the bar.

### Minimal skeleton (Kotlin/JVM Gradle — adapt to the repo)

`<…>` values are **placeholders**: replace each with the real task from `./gradlew tasks --all`, or delete the step. SHAs were resolved from the actions' latest releases when this skill was written; refresh them with Dependabot (`package-ecosystem: github-actions`).

```yaml
# .github/workflows/check-after-implementation.yml
name: check-after-implementation

on:
  pull_request:
  push:
    branches: [main, master]
  workflow_dispatch:

permissions:
  contents: read

jobs:
  quality-and-security:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      pull-requests: read
    env:
      # Job-level so step `if:` conditions can see it.
      SONAR_TOKEN: ${{ secrets.SONAR_TOKEN }}
      NVD_API_KEY: ${{ secrets.NVD_API_KEY }}
      SONAR_REQUIRED: 'true'   # set 'false' only if the repo does not require Sonar
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
        with:
          fetch-depth: 0

      - uses: gradle/actions/wrapper-validation@8da46b539cd8fe6ab27ca75128919a18d757604c # v6.4.1

      - uses: actions/setup-java@b843ebf9b913146b38da2eaa7aeddf76074ae1ad # v6.1.0
        with:
          distribution: temurin
          java-version: '21'

      - uses: gradle/actions/setup-gradle@8da46b539cd8fe6ab27ca75128919a18d757604c # v6.4.1

      - name: Grant gradlew (wrapper validated above)
        run: chmod +x gradlew

      # Cheap → expensive (mirror local recipe)
      - name: Format / lint
        run: ./gradlew <format-check-task> --no-daemon   # e.g. spotlessCheck or ktlintCheck

      - name: Unit + integration + architecture
        run: ./gradlew test <arch-test-task> --no-daemon

      - name: Detekt
        run: ./gradlew detekt --no-daemon

      - name: Coverage / CRAP
        run: ./gradlew <coverage-verify-task> <crap-task> --no-daemon   # e.g. koverVerify

      - name: Mutation (diff-scoped when configured)
        run: ./gradlew pitest --no-daemon

      - name: Dependency / CVE (failBuildOnCVSS <= 7, NVD key required)
        run: ./gradlew dependencyCheckAnalyze --no-daemon

      - name: Secret scan
        uses: gitleaks/gitleaks-action@e0c47f4f8be36e29cdc102c57e68cb5cbf0e8d1e # v3.0.0
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
          # Required for repos owned by an organization (free key from gitleaks.io).
          GITLEAKS_LICENSE: ${{ secrets.GITLEAKS_LICENSE }}

      - name: Sonar
        if: env.SONAR_TOKEN != ''
        run: ./gradlew sonar --no-daemon

      - name: Fail if Sonar is required but secret is missing
        if: env.SONAR_TOKEN == '' && env.SONAR_REQUIRED == 'true'
        run: |
          echo "::error::SONAR_TOKEN missing but Sonar is a required gate"
          exit 1

      - name: Upload reports
        if: always()
        uses: actions/upload-artifact@cf430e030ddbb5b0abf93d22962f4752f3646cd9 # v7.0.2
        with:
          name: quality-security-reports
          path: |
            **/build/reports/

  typescript:
    # Keep only when the repo has TS/JS; mirrors "Core gates — TypeScript / Node".
    runs-on: ubuntu-latest
    permissions:
      contents: read
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
      - uses: actions/setup-node@949feb2413d6458794dcd2491c4babbbce0c15c1 # v7.1.0
        with:
          node-version: '22'
          cache: npm
      - run: npm ci
      - run: npx tsc --noEmit
      - run: npx eslint .
      - run: npm test
      - run: npm audit --audit-level=high

  # sast:
  #   Only a job that uploads SARIF (CodeQL, Semgrep, Trivy) gets security-events: write.
  #   permissions:
  #     contents: read
  #     security-events: write
```

**Adapt, don't paste blindly:** replace every `<placeholder>` with a task that exists in `./gradlew tasks --all`, or delete the step; add Trivy/Hadolint when Docker is in play; wire CodeQL as a parallel SARIF job if the org uses it.

### Branch protection

Require the job name as a status check before merge. Dependabot security updates stay enabled alongside this job—they are complementary, not a substitute.

### Agent duty when the twin is missing or drifts

If CI lacks the job, or local tasks ≠ workflow tasks:

1. Report the gap in the Quality & Security Report.
2. A missing or drifted twin is **always listed in Blockers** and caps the verdict at `PASS WITH CI-PENDING`. The agent writes the proposed workflow YAML (aligned to current `./gradlew tasks --all`) into the report; it opens a PR for it **only if the user asked** to wire CI.
3. Do not claim "CI covered" until the twin is green on the PR.

## Execution recipe (agent)

```text
0. Run `./gradlew tasks --all` (and `package.json` scripts for TS) and record the real task names;
   never run or write a task that is not in that list.
1. Detect stack & module(s) touched.
2. Read CI workflow(s) + Gradle quality/security tasks + dependabot/renovate + detekt/sonar/konsist
   + project loop-cap overrides.
3. Assert a check-after-implementation (or equivalent) job exists; note drift.
4. Build checklist: quality core + security core (+ TS core if the diff touches TS) + applicable suggested.
5. Enter the fix-and-recheck LOOP until all blocking local targets are met in a full final iteration, or the cap/escalation hits.
6. Emit the Quality & Security Report; list CI twin status and run URL when observed.
```

Order inside each local iteration (cheap → expensive):
format/lint → unit/integration → architecture → detekt (+ security) → secret scan → dependency/CVE → critical-data review → coverage/CRAP → mutation (diff).

## Quality & Security Report (required output)

Emit **once**, when the loop exits:

```markdown
## Quality report — check-after-implementation

**Change:** <one line>
**Modules:** <list>
**Loop iterations:** <n> (cap: <same-signature>/<total>, source: default | project config)
**CI twin:** present & aligned (run: <URL> on <head SHA>) | missing | drifted (<detail>)
**Verdict:** PASS | FAIL | PASS WITH CI-PENDING

### Quality
| Gate | Command | Result | Evidence | Notes |
| --- | --- | --- | --- | --- |
| … | `./gradlew …` | ✅/❌/⚠️/⏭️ | exit 0, `build/reports/…` | … |

### Security
| Gate | Command / check | Result | Evidence | Notes |
| --- | --- | --- | --- | --- |
| Dependabot / CVE / versions | `dependencyCheckAnalyze`, `gh api …/dependabot/alerts` | ✅/❌/⚠️/⏭️ | exit code, report path, failBuildOnCVSS value | … |
| Secrets on diff | `gitleaks …` | ✅/❌/⏭️ | exit code, report path | … |
| Critical-data exposure | diff review (+ rules) | ✅/❌/⏭️ | files:lines reviewed, greps used | … |
| Endpoint safe defaults | diff review | ✅/❌/⏭️ | files:lines reviewed, greps used | … |

**Blockers:** … (include: tool missing, twin missing/drifted, config gaps)
**Debt outside diff:** … (merge-base command + output)
**Loop attempts:** <signature> × <n> …
**CI still required:** Sonar / Dependabot / full workflow run / …
**Follow-ups:** … (include any user-approved weakening, with the approval)
```

- **Evidence is mandatory.** Automated gates: exit code and report path. Manual gates: `file:line` ranges reviewed and greps used. A ✅ without evidence counts as ❌.
- `⏭️` = not configured. A **core** gate in `⏭️` is **not green**: the verdict is at most `PASS WITH CI-PENDING`, and the gate is listed in Blockers as "tool missing". A **suggested** gate in `⏭️` does not affect the verdict.
- `⚠️ non-blocking` = gate ran but its configuration cannot fail (e.g. `failBuildOnCVSS` > policy, missing NVD key); listed in Blockers as a config gap; never counts as ✅.

### Verdict rules

- **PASS** — every blocking gate ✅ (with evidence) in the final **full** iteration, **and** the CI twin is present, aligned, and green on the head SHA, with the run URL cited.
- **PASS WITH CI-PENDING** — every local blocking gate ✅, but at least one of: twin missing or drifted, twin run not yet observed, a cloud-only gate (e.g. Sonar) pending, or a core gate `⏭️`/`⚠️`.
- **FAIL** — any blocking gate ❌, the loop cap was hit, or blocking debt outside the diff remains.

No verdict authorizes merge by itself; the required status check does.

## Anti-patterns

- Declaring done after tests without Detekt/architecture/mutation/security when those are project gates
- Running the checklist once, reporting reds, and stopping without fixing in-scope failures
- Claiming PASS from partial re-runs instead of a full final iteration
- Local gates that do not match the GitHub Actions job (or no twin job at all)
- Adding a dependency without checking CVEs / Dependabot
- Logging "temporarily" with full request bodies that include PII or tokens
- Returning JPA/Hibernate entities (or rich domain dumps) directly on REST
- Weakening thresholds, adding baselines/ignores/suppressions, or disabling tests to exit the loop (allowed only with explicit user approval recorded in Follow-ups)
- Writing invented Gradle tasks into CI YAML instead of checking `./gradlew tasks --all`
- Treating Sonar or Dependabot as optional when CI blocks on them
- Treating a local PASS as merge authorization
- Policy conflicts: thresholds come from project config; the gate set is the **union** of this skill's core gates and the twin's jobs. A core gate missing from CI is **drift**: run it locally anyway and report it. Changing policy requires an ADR.

## Relationship to other skills

- Complements implementer/TDD skills: they produce code; **this** skill closes the quality **and** security loop **until targets are green**, with CI as the hard gate.
- Aligns with ub-mode: skill anticipates; **GitHub Actions blocks**. A local PASS never authorizes merge; the required check does.
- Point to project config and workflow YAML instead of duplicating long rule lists.
