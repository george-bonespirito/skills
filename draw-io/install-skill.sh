#!/usr/bin/env bash
#
# install-drawio-skill.sh
# Instala a skill oficial draw.io (jgraph/drawio-mcp, fluxo Skill+CLI) no
# contexto GLOBAL do Claude Code, com house-theme confortavel p/ leitura humana.
#
# Idempotente: pode rodar quantas vezes quiser. Seguro p/ colar no bootstrap.sh.
#   - upstream SKILL.md: re-copiado (sempre pega a versao mais nova)
#   - house-theme + spine pointer: escritos so se faltarem (nao clobbera edits seus)
#
# Uso:  chmod +x install-drawio-skill.sh && ./install-drawio-skill.sh
#
set -euo pipefail

REPO_URL="https://github.com/jgraph/drawio-mcp"
SKILL_DIR="$HOME/.claude/skills/drawio"
THEME_FILE="$HOME/.claude/drawio-house-theme.md"
SPINE="$HOME/.claude/CLAUDE.md"

say() { printf '\033[1;36m>>> %s\033[0m\n' "$*"; }
warn() { printf '\033[1;33m[!] %s\033[0m\n' "$*"; }

# ---------------------------------------------------------------------------
# FASE 0 — draw.io Desktop (host). Necessario SO p/ export .drawio.svg/png/pdf.
# Sem ele, a skill ainda gera .drawio puro. E app GUI de host -> nao containeriza.
# ---------------------------------------------------------------------------
say "Fase 0: checando draw.io Desktop"
if command -v drawio >/dev/null 2>&1; then
  say "draw.io Desktop encontrado: $(drawio --version 2>/dev/null || echo '?')"
else
  warn "draw.io Desktop NAO encontrado — export p/ .drawio.svg vai falhar."
  warn "Instale a release do seu SO em: ${REPO_URL%/*}/drawio-desktop/releases"
  warn "  Debian/Ubuntu: sudo dpkg -i drawio-amd64-*.deb"
  warn "  Fedora/RHEL:   sudo rpm -i drawio-*.rpm"
  warn "Seguindo mesmo assim (skill funciona p/ .drawio nativo)."
fi

# ---------------------------------------------------------------------------
# FASE 1 — instalar a skill global (copia direta do SKILL.md upstream).
# ---------------------------------------------------------------------------
say "Fase 1: instalando skill em $SKILL_DIR"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
git clone --depth 1 "$REPO_URL" "$tmp" >/dev/null 2>&1
mkdir -p "$SKILL_DIR"
cp "$tmp/skill-cli/drawio/SKILL.md" "$SKILL_DIR/SKILL.md"
say "SKILL.md copiado."

# ---------------------------------------------------------------------------
# FASE 2 — camada de tema PROPRIA (upstream fica intocado; sem drift em updates).
# ---------------------------------------------------------------------------
say "Fase 2: house-theme + pointer no spine"

if [ -f "$THEME_FILE" ]; then
  say "house-theme ja existe — preservando seus ajustes ($THEME_FILE)"
else
  cat >"$THEME_FILE" <<'THEME'
# draw.io — house theme (leitura humana)

Ao gerar qualquer .drawio, aplicar:

- `adaptiveColors="auto"` no <mxGraphModel> — adapta cores p/ light/dark
  (essencial: o SVG fica confortavel tanto no preview claro quanto escuro do VS Code).
- Paleta **flat**: usar as classes `plain-*` (plain-blue, plain-green...) — mesmas
  cores pastel do draw.io, **sem** shadow nem glass. Menos ruido visual.
- Cantos suaves: `rounded=1;arcSize=6`.
- Tipografia legivel: `fontSize=13;fontFamily=Helvetica;` (titulos `fontStyle=1`).
- Edges: `edgeStyle=orthogonalEdgeStyle;rounded=1;strokeWidth=1.5;` (sem curvas).
- Fills desaturados; texto `#333333`, nunca preto puro em massa.
- Espacamento generoso: nos >= 120x60, gaps >= 40px.
- NAO usar: shadow=1, glass=1, gradientes, sketch (salvo pedido explicito).

Paleta base (fill / stroke):
  neutro  #F5F5F5 / #666666   |  azul  #DAE8FC / #6C8EBF
  verde   #D5E8D4 / #82B366   |  ambar #FFF2CC / #D6B656
  vermelho#F8CECC / #B85450   |  roxo  #E1D5E7 / #9673A6
THEME
  say "house-theme criado: $THEME_FILE"
fi

touch "$SPINE"
if grep -q 'drawio-house-theme' "$SPINE"; then
  say "pointer ja presente no spine — nada a fazer"
else
  printf '\n- Diagramas draw.io: aplicar ~/.claude/drawio-house-theme.md\n' >>"$SPINE"
  say "pointer adicionado ao spine ($SPINE)"
fi

# ---------------------------------------------------------------------------
# FASE 3 — validacao (manual; /drawio e interativo).
# ---------------------------------------------------------------------------
cat <<'DONE'

>>> Instalacao concluida. Validacao:

  cd /tmp && claude
  /drawio svg: C4 container — Order Service (Spring Boot), PostgreSQL, Kafka, Payment (NestJS)

Esperado: *.drawio.svg com tema flat + adaptiveColors. Referencie no markdown:

  ![C4 Container — Order Service](./diagrams/order-service.drawio.svg)

Abra o preview do VS Code em tema claro e escuro (deve ler bem nos dois) e
reabra o mesmo arquivo na extensao hediet.vscode-drawio (offline) p/ editar.

Notas:
  - Geracao pode tocar a rede (skill busca xml-reference.md do GitHub em runtime).
    O export via draw.io Desktop CLI e 100% offline.
  - Versione so o .drawio.svg (o .drawio intermediario e apagado apos export).
  - Mantenha Mermaid inline p/ C4/sequence de rotina; use draw.io p/ shapes ricos
    (AWS/Azure/K8s) ou edicao visual.
DONE
