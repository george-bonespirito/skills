#!/usr/bin/env bash
# Drives the Konsist library end-to-end: runs a consumer project that imports
# konsist from Maven Central and asserts an architecture rule over Kotlin source.
# Container-first (JDK 21). No Konsist-from-source build needed — the published
# artifact runs on JDK 21, sidestepping the repo's Java-8 compile toolchain.
#
# Usage:  .claude/skills/run-konsist/smoke.sh
# Env:    GRADLE_CACHE  host dir for ~/.gradle (default: <skill>/.gradle-cache)
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
SMOKE="$DIR/smoke"
GRADLE_CACHE="${GRADLE_CACHE:-$DIR/.gradle-cache}"
mkdir -p "$GRADLE_CACHE"

exec docker run --rm \
  -v "$SMOKE":/work -w /work \
  -v "$GRADLE_CACHE":/root/.gradle \
  eclipse-temurin:21-jdk \
  ./gradlew --no-daemon --console=plain test "$@"
