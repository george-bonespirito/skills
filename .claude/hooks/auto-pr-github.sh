#!/usr/bin/env bash
# PostToolUse (Bash, if git push*) — abre PR no GitHub após push de uma
# branch feature/*, se ainda não existir. Usa o `gh` autenticado.
# Realiza a regra "push sempre abre PR". Idempotente: pula se PR já aberto.
# (Até 2026-11-20 abria no Codeberg; o repo migrou para o GitHub.)
set -uo pipefail

REPO="george-bonespirito/skills"

input=$(cat)
cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // empty')
printf '%s' "$cmd" | grep -qE 'git[[:space:]]+push' || exit 0
printf '%s' "$cmd" | grep -qE '\borigin\b' || exit 0

branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
case "$branch" in
  feature/*|fix/*|chore/*|docs/*|refactor/*|test/*) ;;
  *) exit 0 ;;
esac

command -v gh >/dev/null 2>&1 || { echo '{"systemMessage":"auto-PR: gh não instalado — pulei"}'; exit 0; }

existing=$(gh pr list -R "$REPO" --head "$branch" --state open --json number --jq '.[0].number' 2>/dev/null)
[ -n "$existing" ] && exit 0

title=$(git log -1 --pretty=%s 2>/dev/null)
body="Auto-opened by PostToolUse hook after push of \`${branch}\`."
if url=$(gh pr create -R "$REPO" --base main --head "$branch" --title "$title" --body "$body" 2>&1); then
  jq -cn --arg u "$url" '{systemMessage:("✅ auto-PR aberto: " + $u)}'
else
  jq -cn --arg e "$url" '{systemMessage:("⚠️ auto-PR falhou: " + $e)}'
fi
exit 0
