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

**Twin requirement:** every project that uses this skill MUST have a **blocking** GitHub Actions job (or reusable workflow) that runs the **same** quality + security targets. Agent loop locally; CI enforces on every PR/push. A missing or drifted twin is always a **Blocker** in the report and makes the verdict **FAIL** (see *Agent duty when the twin is missing or drifts*).

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
       emit the report with the verdict from "Verdict rules" → EXIT local loop.
       The final full iteration runs on a CLEAN tree: `git status --porcelain` is empty and every
       change is committed (scans over `origin/<default-branch>..HEAD` do not see uncommitted changes).
       PASS ⇒ done. PASS WITH CI-PENDING ⇒ NOT done yet: observe the twin; if it goes red, reopen the loop.
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
     (e.g. `git worktree add ../base $(git merge-base HEAD origin/<default-branch>) && cd ../base && ./gradlew <task>`).
     Attach the command and its output to the report.
     In the cap or debt case: Verdict FAIL, list exact blockers and what the human must decide—do **not** declare the implementation done.
```

Rules for the loop:

- **No "ship and hope"** — one red blocking gate ⇒ keep fixing or escalate; never mark done.
- **Cap runaway loops** — a failure **signature** is `<gate> + <first error line>`, normalized (strip line/column numbers, timestamps, durations, temp paths) so the same error is recognized across iterations.
  - An **iteration** is one pass through step 1, full or partial; every iteration counts toward the cap.
  - The same signature in **3 consecutive iterations** ends the loop.
  - **6 total iterations** end the loop regardless of signatures (this catches A,B,A,B oscillation).
  - These are **defaults**. A project may override them in its config (e.g. `.check-after-implementation.yml` with `loop.maxSameSignature` / `loop.maxIterations`, or an equivalent section in the constitution/ADR); the project value wins and is quoted in the report.
  - Either cap ⇒ **Verdict FAIL**, with the attempts per signature and the blockers listed; the agent escalates to the user. No infinite loops burning tokens on the same error.
- **Do not weaken targets** to exit the loop. Weakening includes: threshold edits; a new baseline entry (Detekt/Android Lint); new `.gitleaksignore` entries; Dependency-Check suppressions; `@Suppress` / `@SuppressWarnings`; `@Disabled` / `@Ignore`; deleting tests; excluding a module or path from a gate; changing `failBuildOnCVSS`; `// NOSONAR`; `eslint-disable` comments; `@ts-ignore` / `@ts-expect-error`; npm/pnpm audit exceptions; Detekt `ignoreFailures` or a raised `maxIssues`; `continue-on-error` or removing a step in the twin; setting `SONAR_REQUIRED: 'false'`; a loop-cap override above 2× the default; editing a protected path (see *Protected gate config*—never allowed for the agent, even with an ADR it writes). The others are is allowed **only with explicit user approval**, recorded in the report's **Follow-ups**.
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
6. **Report in a fixed shape** (see below). Fail closed: any blocking gate red, unconfigured (`⏭️`), config-gapped (`⚠️`), or without evidence ⇒ FAIL, work is not done—unless absence is accepted by an ADR waiver cited in the report.
7. **Gate set = union** — thresholds come from project config; the gate set is the **union** of this skill's core gates and the twin's jobs. A core gate missing from CI is **drift**: run it locally anyway and report it. Changing policy requires an ADR.

## Core gates — quality (always attempt)

| Gate | Intent | Typical local signal |
| --- | --- | --- |
| **Cyclomatic / CRAP** | Keep functions simple; CRAP combines complexity + coverage | Project's CRAP task, Detekt complexity, or Kover/JaCoCo + complexity; threshold from project config (example when none: CRAP &lt; 10) |
| **Clean Code** | Naming, size, nesting, dead code, magic numbers | Detekt, ktlint/spotless; constitution |
| **Architecture** | Layer/package rules, dependency direction | **Konsist** and/or **ArchUnit** tests |
| **Static analysis (Detekt)** | Smells, complexity, coroutines, style | `./gradlew detekt` |
| **Failure regression** | Every fixed failure becomes a deterministic regression check, so it cannot silently return | Applies when the change fixes a bug or an agent failure; see *Failure regression* below |
| **Sonar** | Portfolio gate (bugs, smells, coverage, duplications, security hotspots) | `./gradlew sonar -Dsonar.qualitygate.wait=true` in CI with secrets; counts only when the quality gate is **awaited**—an upload without wait is `⚠️` (FAIL). Local may be **CI-pending** |

## Core gates — security (always attempt)

| Gate | Intent | Typical local / CI signal |
| --- | --- | --- |
| **Dependency versions & CVEs** | No known-vulnerable or abandoned libs introduced/left unpinned by the change | OWASP Dependency-Check `./gradlew dependencyCheckAnalyze` (verify config, see below); Dependabot alerts via `gh api`; Renovate; Snyk/OSV; version catalogs + lockfiles |
| **Secret & credential leak** | No tokens, passwords, private keys, or connection strings in the diff | `gitleaks git --log-opts="origin/<default>..HEAD"` / TruffleHog / `detect-secrets` on the diff |
| **Critical / sensitive data exposure** | PII, secrets, financial/health identifiers, tokens must not leak via logs, APIs, errors, or traces | Diff review with evidence (files + greps) + Detekt/Sonar security rules; sanitize errors; redact OTel attributes |
| **Safe defaults in new endpoints** | Authz, validation, injection, mass-assignment | Diff review with evidence; authz consistent with neighbors; Bean Validation; parameterized queries only |
| **Protected gate config** | The agent does not edit the files that define or enforce the gates | `git diff --name-only <base>...HEAD` matched against the protected set (see below) |

### Critical-data checklist (manual + automated)

Apply to every changed handler, logger, serializer, and trace. For each item record the **`file:line` ranges reviewed**, the **greps used**, and the **grep output (matched lines)**—the command alone is not evidence (e.g. `git diff origin/<default>...HEAD | grep -nE 'log\.(info|debug|warn|error)|logger\.'`, new `*Dto`/`*Response` classes in the diff, new `@RestController`/`@*Mapping`). An unchecked item without evidence is ❌.

- [ ] Logs / metrics / spans do **not** include passwords, tokens, full card numbers, document IDs, or session cookies — files:lines reviewed: …
- [ ] Exception messages and Problem Details bodies are safe for clients — files:lines reviewed: …
- [ ] Persistence and cache keys do not store secrets in plaintext — files:lines reviewed: …
- [ ] New public fields on APIs were intentional (no entity dumped as DTO) — files:lines reviewed: …
- [ ] Test fixtures do not embed production-like secrets — files:lines reviewed: …

If the project has a dedicated "sensitive data" / privacy ADR or Detekt rule set, that document wins.

### Protected gate config

The project may declare `.quality/protected-paths` (one glob per line, relative to the project root; `#` comments allowed). The default protected set applies even without that file: the files holding gate thresholds (e.g. `pit-thresholds.properties`), the build logic that loads them, `.github/CODEOWNERS`, and `.quality/protected-paths` itself.

- If the diff against the merge-base (`<base>...HEAD`, the same base used above) touches any protected path ⇒ ❌, **FAIL** (core, blocking).
- This gate **cannot be waived by the agent**, not even by an ADR the agent writes; only the human owner can. The agent does **not** loop on it: it stops and escalates to the human (Blockers lists the touched paths).
- Why: on private repos on the GitHub Free plan, branch protection and CODEOWNERS are not enforced; this gate is the compensating control. When CI is wired, the same rule becomes a twin job.
- Limitation: it protects against agents that follow this skill, not against agents that ignore it.

### Failure regression

Applies when the change **fixes a failure**: a bug, a failed acceptance criterion, or an agent that ignored a spec rule or constitution rule.

1. **Classify the origin** — `code` (the implementation was wrong) or `harness` (the spec was ambiguous, a skill/prompt was weak, or a rule had no executable check).
2. **Reproducing check is required** — the diff must add a deterministic check that fails without the fix and passes with it:
   - `code` ⇒ a test that reproduces the failure; its detection power is proven by the mutation gate (PIT/Stryker) on the diff.
   - `harness` ⇒ the spec/skill/constitution adjustment **plus** an executable check for the rule (acceptance test, Konsist/ArchUnit rule, or static check), referenced by the rule id (`R-NNN`) when the spec uses ids.
   - Evidence: the check run against the pre-fix code (e.g. `git stash` of the fix, or the failing CI run) showing red, and the post-fix run showing green.
3. **LLM-as-a-judge is not a gate** — it is not deterministic; it may complement exploration but never satisfies this gate.
4. **Record it** — append one line to `.quality/falhas.md` (create it if absent): `date | rule id or area | cause | origin (code/harness) | link to the check`.
5. **Repeated failure** — if the same rule id or area already appears in `.quality/falhas.md`, report it in **Follow-ups** as a harness problem to fix, not only a code fix.

Missing reproducing check or missing record line ⇒ ❌, **FAIL** (core, blocking). The agent may loop on it like any other gate.

### Dependabot / version policy

- Confirm `.github/dependabot.yml` (or Renovate) exists; new deps must be maintained and pinned as the repo requires
- Dependabot alerts cover the **default branch**; dependencies **new in the PR** are checked by the `dependency-review` job (see skeleton).
- List open Dependabot alerts and filter by the manifests you touched:
  `gh api "repos/{owner}/{repo}/dependabot/alerts?state=open" --paginate -q '.[] | [.dependency.manifest_path, .dependency.package.name, .security_advisory.severity] | @tsv'`
- **Dependency-Check config:** verify `failBuildOnCVSS` ≤ 7 (or the project's policy value) and that an NVD API key is configured (`nvd.apiKey` / `NVD_API_KEY` secret). The default `failBuildOnCVSS = 11` never fails, and without an API key the NVD download is slow and flaky. The build must wire the key explicitly: `dependencyCheck { nvd { apiKey = System.getenv("NVD_API_KEY") } }` (do not rely on the plugin reading the environment). If either is missing, the gate result is `⚠️` (config gap, listed in Blockers) ⇒ FAIL for this core gate.
- Prefer upgrading vulnerable transitives via BOM/platform rather than blind excludes
- Record skipped upgrades with reason (never silent)

If a listed tool is **not** in the repo, say so and run a substitute only if it covers the **same intent** (e.g. OSV-Scanner for Dependency-Check, TruffleHog for gitleaks) and record which one. If no substitute exists, the gate is `⏭️` (see Verdict rules: a core gate in `⏭️` is FAIL unless waived by ADR). Do not invent fake scores or fake CVE clears.

## Core gates — TypeScript / Node (when the diff touches TS/JS: Nest, React, etc.)

When the diff touches TypeScript/JavaScript, these are **core** (blocking), not suggested:

| Gate | Typical command |
| --- | --- |
| Type check | `npx tsc --noEmit` |
| Lint + security rules | `npx eslint .` with a security plugin (e.g. `eslint-plugin-security`) |
| Tests | `<pm> test` |
| Dependency CVEs | `npm audit --audit-level=high` / `pnpm audit --audit-level high` |

`<pm>` = the package manager implied by the lockfile (`package-lock.json` ⇒ npm, `pnpm-lock.yaml` ⇒ pnpm). Use it for install, scripts, audit, and the `setup-node` cache; never mix.

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
8. Every gate this skill marks `⚠️` by configuration must also **fail in the twin**: e.g. a step that fails when `NVD_API_KEY` is empty; `failBuildOnCVSS` passed as `-PfailBuildOnCVSS=7` and read by the build; no Detekt `ignoreFailures`; a minimal Kover verify rule; Sonar with `-Dsonar.qualitygate.wait=true`. The build must wire `nvd { apiKey = System.getenv("NVD_API_KEY") }` explicitly.
9. Grant `security-events: write` **only** to the job that uploads SARIF (CodeQL etc.); everything else stays `contents: read`.
10. Prefer a **reusable workflow** (`.github/workflows/check-after-implementation.yml` calling a shared `workflow_call`) when multiple repos share the bar.

### Minimal skeleton (Kotlin/JVM Gradle — adapt to the repo)

`<…>` values are **placeholders**: replace each with the real task from `./gradlew tasks --all`, or delete the step. SHAs were resolved from the actions' latest releases when this skill was written; refresh them with Dependabot (`package-ecosystem: github-actions`).

**Secrets on bot and fork PRs:** Dependabot PRs read only **Dependabot secrets**—register `SONAR_TOKEN` and `NVD_API_KEY` there too. Fork PRs receive no secrets: the job fails by design, and merge requires a maintainer re-run (or a trusted-branch rerun). `setup-gradle` uses `cache-provider: basic` (the default enhanced provider is proprietary and needs its terms accepted).

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
    timeout-minutes: 60
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
          persist-credentials: false

      - uses: gradle/actions/wrapper-validation@8da46b539cd8fe6ab27ca75128919a18d757604c # v6.4.1

      - uses: actions/setup-java@b843ebf9b913146b38da2eaa7aeddf76074ae1ad # v6.1.0
        with:
          distribution: temurin
          java-version: '21'

      - uses: gradle/actions/setup-gradle@8da46b539cd8fe6ab27ca75128919a18d757604c # v6.4.1
        with:
          cache-provider: basic

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
        run: ./gradlew <mutation-task> --no-daemon   # e.g. pitest

      - name: Fail if NVD API key is missing
        if: env.NVD_API_KEY == ''
        run: |
          echo "::error::NVD_API_KEY missing; Dependency-Check would be a config gap"
          exit 1

      - name: Dependency / CVE (build reads -PfailBuildOnCVSS and NVD_API_KEY)
        run: ./gradlew dependencyCheckAnalyze -PfailBuildOnCVSS=7 --no-daemon

      - name: Secret scan
        uses: gitleaks/gitleaks-action@e0c47f4f8be36e29cdc102c57e68cb5cbf0e8d1e # v3.0.0
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
          # Required for repos owned by an organization (free key from gitleaks.io).
          GITLEAKS_LICENSE: ${{ secrets.GITLEAKS_LICENSE }}
          # Comments need pull-requests: write; keep them off (alternative: grant
          # pull-requests: write only on a separate gitleaks job).
          GITLEAKS_ENABLE_COMMENTS: 'false'

      - name: Sonar
        if: env.SONAR_TOKEN != ''
        run: ./gradlew sonar -Dsonar.qualitygate.wait=true --no-daemon

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
    timeout-minutes: 60
    permissions:
      contents: read
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
        with:
          persist-credentials: false
      # Use the package manager implied by the lockfile; this example assumes npm
      # (for pnpm: add pnpm/action-setup, cache: pnpm, pnpm install --frozen-lockfile, pnpm audit).
      - uses: actions/setup-node@949feb2413d6458794dcd2491c4babbbce0c15c1 # v7.1.0
        with:
          node-version: '22'
          cache: npm
      - run: npm ci
      - run: npx tsc --noEmit
      - run: npx eslint .
      - run: npm test
      - run: npm audit --audit-level=high

  dependency-review:
    # Checks dependencies newly introduced by the PR (Dependabot alerts cover the default branch).
    if: github.event_name == 'pull_request'
    runs-on: ubuntu-latest
    timeout-minutes: 60
    permissions:
      contents: read
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
        with:
          persist-credentials: false
      - uses: actions/dependency-review-action@a1d282b36b6f3519aa1f3fc636f609c47dddb294 # v5.0.0
        with:
          fail-on-severity: high

  # sast:
  #   Only a job that uploads SARIF (CodeQL, Semgrep, Trivy) gets security-events: write.
  #   permissions:
  #     contents: read
  #     security-events: write
```

**Adapt, don't paste blindly:** replace every `<placeholder>` with a task that exists in `./gradlew tasks --all`, or delete the step; add Trivy/Hadolint when Docker is in play; wire CodeQL as a parallel SARIF job if the org uses it.

### Branch protection

Require **every** job of the workflow as a required status check before merge (`quality-and-security`, `typescript` when present, `dependency-review`), not just one job name. Dependabot security updates stay enabled alongside this job—they are complementary, not a substitute.

### Agent duty when the twin is missing or drifts

If CI lacks the job, or local tasks ≠ workflow tasks:

1. Report the gap in the Quality & Security Report.
2. A missing or drifted twin is **always listed in Blockers** and makes the verdict **FAIL** until the twin exists and is aligned. The agent writes the proposed workflow YAML (aligned to current `./gradlew tasks --all`) into the report; it opens a PR for it **only if the user asked** to wire CI.
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
| Failure regression | reproducing check pre/post fix | ✅/❌/n.a. | origin, red run before fix, green after, `.quality/falhas.md` line | n.a. when the change fixes no failure |

### Security
| Gate | Command / check | Result | Evidence | Notes |
| --- | --- | --- | --- | --- |
| Dependabot / CVE / versions | `dependencyCheckAnalyze`, `gh api …/dependabot/alerts` | ✅/❌/⚠️/⏭️ | exit code, report path, failBuildOnCVSS value | … |
| Secrets on diff | `gitleaks …` | ✅/❌/⏭️ | exit code, report path | … |
| Critical-data exposure | diff review (+ rules) | ✅/❌/⏭️ | files:lines reviewed, greps + matched lines | … |
| Endpoint safe defaults | diff review | ✅/❌/⏭️ | files:lines reviewed, greps + matched lines | … |

**Blockers:** … (include: tool missing, twin missing/drifted, config gaps)
**Debt outside diff:** … (merge-base command + output)
**Loop attempts:** <signature> × <n> …
**CI still required:** Sonar / Dependabot / full workflow run / …
**Follow-ups:** … (include any user-approved weakening, with the approval)
```

- **Evidence is mandatory.** Automated gates: exit code and report path. Manual gates: `file:line` ranges reviewed and greps used. A ✅ without evidence counts as ❌.
- `⏭️` = not configured. A **core** gate in `⏭️` ⇒ **FAIL**; the gap is listed in Blockers as "tool missing" and the human decides: install the tool, or accept its absence via an ADR (waiver cited in the report, gate then shown as `⏭️ waived: ADR-…`). A **suggested** gate in `⏭️` does not affect the verdict.
- `⚠️` = gate ran but its configuration cannot fail (e.g. `failBuildOnCVSS` > policy, missing NVD key, Sonar without quality-gate wait). A **core** gate in `⚠️` ⇒ **FAIL** (config gap in Blockers), same waiver path as `⏭️`; never counts as ✅.

### Verdict rules

- **PASS** — every blocking gate ✅ (with evidence) in the final **full** iteration, **and** the CI twin is present, aligned, and green on the head SHA, with the run URL cited.
- **PASS WITH CI-PENDING** — every local blocking gate ✅ (or ADR-waived), and the only open items are **waiting on CI**: the twin run not yet observed, or a cloud-only gate (e.g. Sonar) pending.
- **FAIL** — any blocking gate ❌; any core gate `⏭️`/`⚠️` without an ADR waiver; twin missing or drifted; the loop cap was hit; a protected path was touched (human owner only, no agent waiver); or blocking debt outside the diff remains.

**Done definition:** PASS and PASS WITH CI-PENDING both end the **local** loop, but the work is **done only with PASS**. PASS WITH CI-PENDING obliges the agent to observe the twin run and, if it goes red, reopen the loop (see *Who runs it*).

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
- Treating a local PASS as merge authorization, or PASS WITH CI-PENDING as done
- Policy conflicts resolved by prose instead of config/ADR (see Stance §7)

## Relationship to other skills

- Complements implementer/TDD skills: they produce code; **this** skill closes the quality **and** security loop **until targets are green**, with CI as the hard gate.
- Aligns with ub-mode: skill anticipates; **GitHub Actions blocks**. A local PASS never authorizes merge; the required check does.
- Point to project config and workflow YAML instead of duplicating long rule lists.
