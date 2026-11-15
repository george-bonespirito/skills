#!/usr/bin/env bash
# Scaffold a source-backed second brain into a new or existing repo.
# Idempotent: creates only what is missing, never overwrites a file.
# Usage: bootstrap.sh [--dir <path>] [--root] [--dry-run]
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
TEMPLATES=$(cd "$SCRIPT_DIR/../templates" && pwd)
MARKER='<!-- second-brain:pointer -->'

DRY_RUN=0
ROOT_MODE=0
TARGET=""
CREATED=0
SKIPPED=0

usage() {
  cat <<'USAGE'
Usage: bootstrap.sh [--dir <path>] [--root] [--dry-run]

  (default)    scaffold into <repo-root>/second-brain
  --dir PATH   scaffold into PATH (relative to the current directory)
  --root       scaffold at the repo root (dedicated brain repo)
  --dry-run    print what would be created, change nothing

Existing files are never overwritten. In an existing repo, a pointer section is
appended once to the root AGENTS.md / CLAUDE.md if they exist.
USAGE
}

die() { printf 'error: %s\n' "$1" >&2; exit 1; }

parse_args() {
  while [ $# -gt 0 ]; do
    case "$1" in
      --dir) [ $# -ge 2 ] || die "--dir needs a path"; TARGET="$2"; shift 2 ;;
      --root) ROOT_MODE=1; shift ;;
      --dry-run) DRY_RUN=1; shift ;;
      -h|--help) usage; exit 0 ;;
      *) usage >&2; die "unknown option: $1" ;;
    esac
  done
}

repo_root() { git rev-parse --show-toplevel 2>/dev/null || pwd; }

absolute() {
  case "$1" in
    /*) printf '%s\n' "${1%/}" ;;
    *) printf '%s\n' "$PWD/${1#./}" ;;
  esac
}

resolve_target() {
  local root="$1"
  if [ -n "$TARGET" ]; then absolute "$TARGET"; return; fi
  if [ "$ROOT_MODE" -eq 1 ]; then printf '%s\n' "$root"; return; fi
  printf '%s\n' "$root/second-brain"
}

created() {
  CREATED=$((CREATED + 1))
  if [ "$DRY_RUN" -eq 1 ]; then printf '  would create  %s\n' "$1"; return 0; fi
  printf '  created  %s\n' "$1"
}
skipped() { SKIPPED=$((SKIPPED + 1)); printf '  skipped  %s (exists)\n' "$1"; }

copy_if_missing() {
  local src="$1" dest="$2"
  if [ -e "$dest" ]; then skipped "$dest"; return 0; fi
  created "$dest"
  [ "$DRY_RUN" -eq 1 ] && return 0
  mkdir -p "$(dirname "$dest")"
  cp "$src" "$dest"
}

scaffold() {
  local target="$1" src rel
  while IFS= read -r src; do
    rel="${src#"$TEMPLATES/brain/"}"
    copy_if_missing "$src" "$target/$rel"
  done < <(find "$TEMPLATES/brain" -type f | LC_ALL=C sort)
}

append_pointer() {
  local file="$1" brain_rel="$2"
  [ -f "$file" ] || return 0
  if grep -qF "$MARKER" "$file"; then
    SKIPPED=$((SKIPPED + 1)); printf '  skipped  %s (pointer present)\n' "$file"; return 0
  fi
  created "$file (pointer appended)"
  [ "$DRY_RUN" -eq 1 ] && return 0
  sed "s|{{BRAIN_DIR}}|$brain_rel|g" "$TEMPLATES/pointer.md" >> "$file"
}

link_from_root() {
  local root="$1" target="$2" rel
  [ "$target" = "$root" ] && return 0
  case "$target" in
    "$root"/*) rel="${target#"$root"/}" ;;
    *) rel="$target" ;;
  esac
  append_pointer "$root/AGENTS.md" "$rel"
  append_pointer "$root/CLAUDE.md" "$rel"
}

warn_if_foreign() {
  local file="$1" expected="$2"
  [ -f "$file" ] || return 0
  grep -qF "$expected" "$file" && return 0
  printf 'warning: %s already existed without "%s"; brain rules not wired.\n' "$file" "$expected" >&2
  printf '         Merge %s/brain/%s into it by hand.\n' "$TEMPLATES" "$(basename "$file")" >&2
}

warn_root_collision() {
  local root="$1" target="$2"
  [ "$target" = "$root" ] || return 0
  warn_if_foreign "$root/AGENTS.md" '# Brain Rules'
  warn_if_foreign "$root/CLAUDE.md" '@AGENTS.md'
}

main() {
  parse_args "$@"
  local root target
  root=$(repo_root)
  target=$(resolve_target "$root")
  case "$target" in */.git|*/.git/*) die "refusing to write inside .git" ;; esac
  [ "$DRY_RUN" -eq 1 ] && printf 'dry run: nothing will be written\n'
  printf 'second brain: %s\n' "$target"
  scaffold "$target"
  link_from_root "$root" "$target"
  warn_root_collision "$root" "$target"
  printf 'done: %d created, %d skipped\n' "$CREATED" "$SKIPPED"
}

main "$@"
