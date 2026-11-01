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

Run this **whenever an implementation is finished** (agent or human), **before** declaring done, opening/merging a PR, or moving to the next task. Goal: the change matches the project's acceptable **quality and security** bar—not only "it compiles" or "tests are green."

This skill **anticipates** CI. Blocking truth lives in **GitHub Actions**. Local runs must match the same Gradle tasks/thresholds the CI uses. Do not claim CI passed without a real green run.

**Twin requirement:** every project that uses this skill MUST have a **blocking** GitHub Actions job (or reusable workflow) that runs the **same** quality + security targets. Agent loop locally; CI enforces on every PR/push. If the workflow is missing, creating or updating it is part of adopting this skill—not optional polish.

## Who runs it

**The same agent that implemented the feature/fix** owns the local loop. It does **not** hand off to a reviewer and stop.

CI runs the same checks on `pull_request` and `push` to protected branches (and on `workflow_dispatch` when useful). Merge is blocked while the job is red.

## Loop until targets are met (required behavior — local)

Treat the gate checklist as a **contract**. After the first run:

```text
LOOP:
  1. Run all blocking gates for this repo (quality + security core + applicable suggested).
  2. If every blocking target is ✅ (and CI-pending items are listed, not faked):
       emit the report with Verdict PASS or PASS WITH CI-PENDING → EXIT loop → work may be declared done.
  3. If any blocking target is ❌:
       a. Fix the failures that are in scope of this change (code, tests, config the change introduced).
       b. Re-run at least the failed gates (full suite when cheap or when fixes may have side effects).
       c. Go to 1.
  4. Stop looping only when:
       - all blocking targets are green, OR
       - remaining reds are proven pre-existing debt outside the diff / need a policy or infra change the agent cannot do alone.
     In the second case: Verdict FAIL, list exact blockers and what the human must decide—do **not** declare the implementation done.
```

Rules for the loop:

- **No "ship and hope"** — one red blocking gate ⇒ keep fixing or escalate; never mark done.
- **Cap runaway loops** — after a reasonable number of iterations (e.g. 3–5 full cycles) with the same failures recurring, stop, report the stuck gates and what was tried; ask the user. Do not infinite-loop burning tokens on the same error.
- **Do not weaken targets** to exit the loop (no threshold edits, blanket suppressions, or deleting tests to go green).
- **CI-pending** (Sonar cloud secrets, org-level scanners) does not replace local greens; locals must be green first, then note what still waits on CI.

## When to use

- Right after implementing or generating production code
- After a refactor that touches domain/application layers
- Before asking the user to review a PR
- After fixing review comments that changed code
- After adding or bumping dependencies
- When adopting this skill in a repo: ensure the GitHub Actions twin job exists and is required on the default branch

Skip only for pure docs/ADR-only edits with no code or dependency change (still run markdown/link checks if the repo has them).

## Stance

1. **Inventory first** — discover what the repo already wires (Gradle plugins, CI workflows, Dependabot/Renovate, constitution/ADR quality rules). Prefer existing tasks over inventing new ones.
2. **Same bar as CI** — thresholds come from the project (`build.gradle.kts`, `detekt.yml`, Sonar quality profile, ArchUnit/Konsist tests, `.github/dependabot.yml`, workflow YAML), not from vibes.
3. **Fix or escalate** — if a gate fails and the fix is in scope of the change, fix it and re-run. If the gate is broken by pre-existing debt outside the change, report it; do not silently widen scope.
4. **Diff-aware when possible** — prefer PR-diff / changed-module scope when the project supports it.
5. **Security is blocking** — critical-data exposure, committed secrets, and known vulnerable dependency versions introduced by the change are **FAIL**, not notes.
6. **Report in a fixed shape** (see below). Fail closed: any blocking gate red ⇒ work is not done.

## Core gates — quality (always attempt)

| Gate | Intent | Typical local signal |
| --- | --- | --- |
| **Cyclomatic / CRAP** | Keep functions simple; CRAP combines complexity + coverage | CRAP task, Detekt complexity, or Kover/JaCoCo + complexity; ub-mode-style CRAP &lt; 10 when configured |
| **Clean Code** | Naming, size, nesting, dead code, magic numbers | Detekt, ktlint/spotless; constitution |
| **Architecture** | Layer/package rules, dependency direction | **Konsist** and/or **ArchUnit** tests |
| **Static analysis (Detekt)** | Smells, complexity, coroutines, style | `./gradlew detekt` |
| **Sonar** | Portfolio gate (bugs, smells, coverage, duplications, security hotspots) | `sonar` in CI with secrets; local may be **CI-pending** |

## Core gates — security (always attempt)

| Gate | Intent | Typical local / CI signal |
| --- | --- | --- |
| **Dependency versions & CVEs** | No known-vulnerable or abandoned libs introduced/left unpinned by the change | **Dependabot** / Renovate; OWASP Dependency-Check / `dependencyCheckAnalyze`; Snyk/OSV; version catalogs + lockfiles |
| **Secret & credential leak** | No tokens, passwords, private keys, or connection strings in the diff | gitleaks / TruffleHog / `detect-secrets` on the diff |
| **Critical / sensitive data exposure** | PII, secrets, financial/health identifiers, tokens must not leak via logs, APIs, errors, or traces | Diff review + Detekt/Sonar security rules; sanitize errors; redact OTel attributes |
| **Safe defaults in new endpoints** | Authz, validation, injection, mass-assignment | Authz consistent with neighbors; Bean Validation; parameterized queries only |

### Critical-data checklist (manual + automated)

Apply to every changed handler, logger, serializer, and trace:

- [ ] Logs / metrics / spans do **not** include passwords, tokens, full card numbers, document IDs, or session cookies
- [ ] Exception messages and Problem Details bodies are safe for clients
- [ ] Persistence and cache keys do not store secrets in plaintext
- [ ] New public fields on APIs were intentional (no entity dumped as DTO)
- [ ] Test fixtures do not embed production-like secrets

If the project has a dedicated "sensitive data" / privacy ADR or Detekt rule set, that document wins.

### Dependabot / version policy

- Confirm `.github/dependabot.yml` (or Renovate) exists; new deps must be maintained and pinned as the repo requires
- On the PR: check open Dependabot alerts for modules you touched
- Prefer upgrading vulnerable transitives via BOM/platform rather than blind excludes
- Record skipped upgrades with reason (never silent)

If a listed tool is **not** in the repo, say so and run the closest substitute. Do not invent fake scores or fake CVE clears.

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
11. **TS/Nest/React** — ESLint security plugins, `tsc --noEmit`, npm/pnpm audit when those stacks change

## GitHub Actions twin (required)

The CI job is the **authoritative** twin of this skill. Name it clearly (e.g. `check-after-implementation` or `quality-and-security`) and make it a **required status check** on the default branch.

### What the workflow must do

1. Trigger on `pull_request` and `push` to protected branches (plus `workflow_dispatch` optional).
2. Run the **same** Gradle (or stack) tasks the agent runs locally—identical task names and configs.
3. Cover **quality core + security core**; add suggested gates the repo already supports.
4. Fail the job on any blocking gate red (`set -e` / Gradle non-zero / action `fail_ci`).
5. Upload reports as artifacts (Detekt, Kover/JaCoCo, PIT, Dependency-Check, gitleaks) for PR inspection.
6. Keep secrets (Sonar token, Snyk token) only in GitHub Secrets / Environments—never in the repo.
7. Prefer a **reusable workflow** (`.github/workflows/check-after-implementation.yml` calling a shared `workflow_call`) when multiple repos share the bar.

### Minimal skeleton (Kotlin/JVM Gradle — adapt to the repo)

```yaml
# .github/workflows/check-after-implementation.yml
name: check-after-implementation

on:
  pull_request:
  push:
    branches: [main, master]
  workflow_dispatch:

jobs:
  quality-and-security:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      pull-requests: read
      security-events: write   # if uploading CodeQL/SARIF
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - uses: actions/setup-java@v4
        with:
          distribution: temurin
          java-version: '21'
          cache: gradle

      - name: Grant gradlew
        run: chmod +x gradlew

      # Cheap → expensive (mirror local recipe)
      - name: Format / lint
        run: ./gradlew spotlessCheck ktlintCheck --no-daemon

      - name: Unit + integration + architecture
        run: ./gradlew test architectureTest --no-daemon

      - name: Detekt
        run: ./gradlew detekt --no-daemon

      - name: Coverage / CRAP
        run: ./gradlew koverVerify crapCheck --no-daemon
        # replace with the repo's real task names

      - name: Mutation (diff-scoped when configured)
        run: ./gradlew pitest --no-daemon

      - name: Dependency / CVE
        run: ./gradlew dependencyCheckAnalyze --no-daemon

      - name: Secret scan
        uses: gitleaks/gitleaks-action@v2
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}

      - name: Sonar (when secrets present)
        if: ${{ env.SONAR_TOKEN != '' }}
        env:
          SONAR_TOKEN: ${{ secrets.SONAR_TOKEN }}
        run: ./gradlew sonar --no-daemon

      - name: Upload reports
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: quality-security-reports
          path: |
            **/build/reports/
            **/build/reports/detekt/
            **/build/reports/kover/
            **/build/reports/pitest/
            **/build/reports/dependency-check/
```

**Adapt, don't paste blindly:** delete steps whose tasks do not exist; rename tasks to match `build.gradle.kts`; add Trivy/Hadolint when Docker is in play; wire CodeQL as a parallel job if the org uses it.

### Branch protection

Require the job name as a status check before merge. Dependabot security updates stay enabled alongside this job—they are complementary, not a substitute.

### Agent duty when the twin is missing or drifts

If CI lacks the job, or local tasks ≠ workflow tasks:

1. Report the gap in the Quality & Security Report.
2. Propose (or, when the user asked to wire CI, open a PR for) the workflow aligned to current Gradle tasks.
3. Do not claim "CI covered" until the twin is green on the PR.

## Execution recipe (agent)

```text
1. Detect stack & module(s) touched.
2. Read CI workflow(s) + Gradle quality/security tasks + dependabot/renovate + detekt/sonar/konsist.
3. Assert a check-after-implementation (or equivalent) job exists; note drift.
4. Build checklist: quality core + security core + applicable suggested.
5. Enter the fix-and-recheck LOOP until all blocking local targets are met or escalate.
6. Emit the Quality & Security Report; list CI twin status.
```

Order inside each local iteration (cheap → expensive):
format/lint → unit/integration → architecture → detekt (+ security) → secret scan → dependency/CVE → critical-data review → coverage/CRAP → mutation (diff).

## Quality & Security Report (required output)

Emit **once**, when the loop exits:

```markdown
## Quality report — check-after-implementation

**Change:** <one line>
**Modules:** <list>
**Loop iterations:** <n>
**CI twin:** present & aligned | missing | drifted (<detail>)
**Verdict:** PASS | FAIL | PASS WITH CI-PENDING

### Quality
| Gate | Command | Result | Notes |
| --- | --- | --- | --- |
| … | `./gradlew …` | ✅/❌/⏭️ | … |

### Security
| Gate | Command / check | Result | Notes |
| --- | --- | --- | --- |
| Dependabot / CVE / versions | … | ✅/❌/⏭️ | … |
| Secrets on diff | … | ✅/❌/⏭️ | … |
| Critical-data exposure | diff review (+ rules) | ✅/❌/⏭️ | … |
| Endpoint safe defaults | … | ✅/❌/⏭️ | … |

**Blockers:** …
**Debt outside diff:** …
**CI still required:** Sonar / Dependabot / full workflow run / …
**Follow-ups:** …
```

`⏭️` = not configured. `PASS WITH CI-PENDING` = locals green, mandatory cloud gate / full Actions run not yet observed.

## Anti-patterns

- Declaring done after tests without Detekt/architecture/mutation/security when those are project gates
- Running the checklist once, reporting reds, and stopping without fixing in-scope failures
- Local gates that do not match the GitHub Actions job (or no twin job at all)
- Adding a dependency without checking CVEs / Dependabot
- Logging "temporarily" with full request bodies that include PII or tokens
- Returning JPA/Hibernate entities (or rich domain dumps) directly on REST
- Weakening thresholds or suppressions to exit the loop without user-visible justification
- Treating Sonar or Dependabot as optional when CI blocks on them
- Conflicting with ub-mode/CI policy in prose — CI wins; ADR to change policy

## Relationship to other skills

- Complements implementer/TDD skills: they produce code; **this** skill closes the quality **and** security loop **until targets are green**, with CI as the hard gate.
- Aligns with ub-mode: skill anticipates; **GitHub Actions blocks**.
- Point to project config and workflow YAML instead of duplicating long rule lists.
