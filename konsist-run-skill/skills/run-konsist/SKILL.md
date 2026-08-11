---
name: run-konsist
description: Build, run, and drive the Konsist Kotlin static-analysis library. Use when asked to run konsist, smoke-test konsist, verify a konsist change, exercise the Konsist API, or build/test the konsist repo from source.
---

# run-konsist

Konsist is a **Kotlin static-analysis library** (JVM, Gradle) — you write JUnit/Kotest tests that scope Kotlin declarations and assert architecture/consistency rules. It has no GUI or server: "running" it means **driving its API from a consumer test**.

The driver is [`smoke.sh`](smoke.sh) — a self-contained consumer project under `smoke/` that pulls Konsist from Maven Central and asserts a real rule over Kotlin source, in a JDK-21 Docker container. It needs no Konsist checkout (the published artifact is Java-8 bytecode that runs on JDK 21), so it drives the library exactly as consumers do — the layer most changes touch (`com.lemonappdev.konsist.api`).

**Commands below assume you are in this skill directory** (`konsist-run-skill/skills/run-konsist/`). `smoke.sh` is cwd-independent (it resolves its own path), so the repo-relative form `konsist-run-skill/skills/run-konsist/smoke.sh` works too.

## Prerequisites

- Docker daemon running.
- Pull the JDK image once:
  ```bash
  docker pull eclipse-temurin:21-jdk
  ```
No host JDK/Gradle needed — the driver runs everything in the container via the bundled Gradle wrapper (8.11.1).

## Run — agent path (the driver)

```bash
./smoke.sh
```

Runs the `smoke/` consumer project (`gradle test`) in `eclipse-temurin:21-jdk`. Expected output:

```
SmokeKonsistTest > konsist scopes the project and finds Kotlin files() PASSED
SmokeKonsistTest > UseCase classes reside in a domain package() PASSED
BUILD SUCCESSFUL
```

Timing (measured): **~1m15s cold** (downloads Gradle dist + Konsist + JUnit), **~45s warm**. The Gradle cache persists in `.gradle-cache/` next to the driver (override with `GRADLE_CACHE=/path`).

### What the driver exercises

`smoke/src/test/kotlin/SmokeKonsistTest.kt` calls the real Konsist API:

```kotlin
Konsist.scopeFromProject()
    .classes()
    .withNameEndingWith("UseCase")
    .assertTrue { it.resideInPackage("..domain..") }
```

against `smoke/src/main/kotlin/com/example/domain/usecase/OrderUseCase.kt`. To point the smoke at a **local** build of the library, publish it (`./gradlew publishToMavenLocal` in a konsist checkout), add `mavenLocal()` to `smoke/build.gradle.kts` repositories, and bump the dep to the locally-published version.

### Prove it actually enforces (negative check)

Konsist detects violations, not just green paths. Verified:

```bash
# add a *UseCase class OUTSIDE ..domain.. then run smoke.sh
mkdir -p smoke/src/main/kotlin/com/example/other
printf 'package com.example.other\nclass RogueUseCase\n' \
  > smoke/src/main/kotlin/com/example/other/RogueUseCase.kt
./smoke.sh   # FAILS
rm -rf smoke/src/main/kotlin/com/example/other
```

Result: `UseCase classes reside in a domain package() FAILED` — `com.lemonappdev.konsist.core.exception.KoAssertionFailedException at SmokeKonsistTest.kt:24`.

## Build Konsist from source — contributor path

For changes to the library internals. This runs inside a **konsist checkout**, not this plugin:

```bash
git clone --depth 1 https://github.com/LemonAppDev/konsist.git
cd konsist
```

The repo is a single Gradle module `:lib` (wrapper 8.11.1). CI (`.github/workflows/check.yml`) runs, in order:

```bash
./gradlew lib:assemble
./gradlew :lib:test
./gradlew lib:apiTest
./gradlew lib:integrationTest
./gradlew lib:konsistTest       # Konsist checking its own source
./gradlew detektCheck spotlessCheck
./gradlew publishToMavenLocal
```

**Gotcha — this needs a JDK 8 toolchain, not just JDK 21.** `lib` compiles to a Java 8 target via Gradle toolchains. In a JDK-21-only container `lib:assemble` fails at `:lib:compileJava`:

```
Cannot find a Java installation on your machine matching this tasks requirements:
{languageVersion=8, vendor=any vendor} for LINUX on aarch64.
No locally installed toolchains match and toolchain download repositories have not been configured.
```

Fix: make a JDK 8 install discoverable to Gradle — provide one and pass
`-Dorg.gradle.java.installations.paths=/opt/jdk8`, or wire up the foojay
resolver for auto-download. CI runs on Corretto with JDK 8 present on the
runner. The **consumer smoke above needs none of this** — which is why it's
the primary driver.

## Gotchas

- **`| tail` hides Gradle's exit code.** `./gradlew … | tail -30` reports `tail`'s status (0), masking a failed build. Check for `BUILD SUCCESSFUL`/`BUILD FAILED` in the text, or drop the pipe.
- **First `lib` build is ~21 min** cold — almost all of it downloading the Kotlin toolchain + deps into the Gradle cache. Mount a persistent `-v <cache>:/root/.gradle` so reruns skip it.
- **`org.gradle.daemon=true` in konsist's `gradle.properties`** — always pass `--no-daemon` in an ephemeral container, or Gradle forks a single-use daemon and warns.
- **Samples pin `konsist:0.17.2`; the repo builds `0.17.3`** (`gradle.properties: konsist.version`). This smoke uses `0.17.3` from Maven Central.

## Troubleshooting

| Symptom | Fix |
|---|---|
| `docker ps` hangs forever | Docker Desktop up but daemon not ready (or wrong context). Wait for startup / `docker context use desktop-linux`. |
| `Cannot find a Java installation … languageVersion=8` | Contributor build only — provide a JDK 8 toolchain (see above). Consumer smoke is unaffected. |
| Smoke can't resolve `com.lemonappdev:konsist` | No network from the container, or version not on Maven Central. Check the dep in `smoke/build.gradle.kts`. |
