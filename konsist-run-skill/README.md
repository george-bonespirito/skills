# konsist-run-skill

A **run-skill** for [Konsist](https://github.com/LemonAppDev/konsist) — the Kotlin static-analysis library for architecture and consistency tests.

Bundles the `run-konsist` skill: a container-first driver that lets an agent (or you) build, run, and **drive** the Konsist API from a clean machine, plus the battle-scars of building Konsist from source.

## What's inside

```
skills/run-konsist/
  SKILL.md          man page — prerequisites, agent path, contributor build, gotchas
  smoke.sh          driver: runs the consumer project in Docker (JDK 21), persistent Gradle cache
  smoke/            self-contained consumer — konsist (Maven Central) + JUnit 5, jvmToolchain(21)
    src/main/.../domain/usecase/OrderUseCase.kt   Kotlin source for Konsist to scope
    src/test/kotlin/SmokeKonsistTest.kt           scopeFromProject().classes()…assertTrue { }
```

## Quick start

```bash
docker pull eclipse-temurin:21-jdk
skills/run-konsist/smoke.sh
```

Runs a real Konsist assertion over Kotlin source in a container (~1m15s cold, ~45s warm). No host JDK/Gradle required.

## Why a driver, not just docs

Konsist has no GUI or server — "running" it means calling its API. The driver is a consumer project that imports Konsist from Maven Central and asserts an architecture rule, which is exactly how the library is used. It runs on JDK 21 alone: the published artifact is Java-8 bytecode, sidestepping the JDK-8 toolchain the from-source build requires (see `SKILL.md` → Gotchas).

## Requirements

- Docker daemon running
- Network access from the container (Maven Central)

## License

MIT — see [LICENSE](LICENSE).
