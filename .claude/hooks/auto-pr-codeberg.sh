#!/usr/bin/env bash
# PostToolUse (Bash, if git push*) — abre PR no Codeberg após push de uma
# branch feature/*, se ainda não existir. Token lido do keychain (git credential).
# Realiza a regra "push sempre abre PR". Idempotente: pula se PR já aberto.
set -uo pipefail

REPO="torgge/skills"
API="https://codeberg.org/api/v1/repos/${REPO}/pulls"

input=$(cat)
cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // empty')
printf '%s' "$cmd" | grep -qE 'git[[:space:]]+push' || exit 0
printf '%s' "$cmd" | grep -qE '\borigin\b' || exit 0   # só mirror canônico (Codeberg)

branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
case "$branch" in
  feature/*|fix/*|chore/*|docs/*|refactor/*|test/*) ;;
  *) exit 0 ;;
esac

TOKEN=$(printf 'protocol=https\nhost=codeberg.org\n\n' | git credential fill 2>/dev/null | sed -n 's/^password=//p')
[ -n "$TOKEN" ] || { echo '{"systemMessage":"auto-PR: sem token Codeberg no keychain — pulei"}'; exit 0; }

existing=$(curl -s -H "Authorization: token $TOKEN" "${API}?state=open" \
  | jq -r --arg b "$branch" '.[] | select(.head.ref==$b) | .number' 2>/dev/null | head -1)
[ -n "$existing" ] && exit 0

title=$(git log -1 --pretty=%s 2>/dev/null)
body="Auto-opened by PostToolUse hook after push of \`${branch}\`."
resp=$(curl -s -w $'\n%{http_code}' -X POST \
  -H "Authorization: token $TOKEN" -H "Content-Type: application/json" \
  -d "$(jq -cn --arg t "$title" --arg h "$branch" --arg b "$body" \
        '{title:$t, head:$h, base:"main", body:$b}')" \
  "$API")
code=$(printf '%s' "$resp" | tail -1)
url=$(printf '%s' "$resp" | sed '$d' | jq -r '.html_url // empty' 2>/dev/null)

if [ "$code" = "201" ] && [ -n "$url" ]; then
  jq -cn --arg u "$url" '{systemMessage:("✅ auto-PR aberto: " + $u)}'
else
  jq -cn --arg c "$code" '{systemMessage:("⚠️ auto-PR falhou (HTTP " + $c + ")")}'
fi
exit 0
