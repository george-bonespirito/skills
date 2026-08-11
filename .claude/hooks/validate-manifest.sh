#!/usr/bin/env bash
# PostToolUse (Edit|Write) — valida manifests de plugin/marketplace tocados.
# jq sempre; `claude plugin validate` só nos manifests Claude (.claude-plugin).
# Não bloqueia a edição (PostToolUse já rodou) — avisa via systemMessage.
set -uo pipefail

input=$(cat)
f=$(printf '%s' "$input" | jq -r '.tool_input.file_path // empty')
[ -n "$f" ] && [ -f "$f" ] || exit 0

kind=""
case "$f" in
  */.claude-plugin/plugin.json|*/.claude-plugin/marketplace.json) kind="claude" ;;
  */.cursor-plugin/plugin.json|*/.cursor-plugin/marketplace.json) kind="cursor" ;;
  *) exit 0 ;;
esac

err=""
if ! jq -e . "$f" >/dev/null 2>&1; then
  err="JSON inválido em $f"
elif [ "$kind" = "claude" ] && command -v claude >/dev/null 2>&1; then
  # plugin root (ou repo root p/ marketplace) = dirname(dirname(manifest))
  dir=$(dirname "$(dirname "$f")")
  out=$(claude plugin validate "$dir" 2>&1) || err="claude plugin validate falhou ($dir): $(printf '%s' "$out" | tail -3 | tr '\n' ' ')"
fi

[ -z "$err" ] && exit 0
jq -cn --arg m "⚠️ manifest inválido — $err" \
  '{systemMessage:$m, hookSpecificOutput:{hookEventName:"PostToolUse", additionalContext:$m}}'
exit 0
