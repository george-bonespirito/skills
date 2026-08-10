# Publicar `draw-io` no Marketplace Público do Cursor Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Tornar o plugin `draw-io` deste repo instalável pelo marketplace público do Cursor, com GitHub como mirror público e Codeberg permanecendo canônico.

**Architecture:** O repo é uma coleção multi-plugin. Hoje só tem o manifest de marketplace do Claude (`.claude-plugin/marketplace.json`). O Cursor exige um `.cursor-plugin/marketplace.json` paralelo na raiz e ownership via GitHub. Adicionamos o manifest Cursor, criamos um repo GitHub espelho da conta `torgge`, configuramos push-mirror mantendo `origin` no Codeberg, e submetemos no publish do Cursor. Os per-plugin manifests do `draw-io` já existem e estão válidos — não mudam.

**Tech Stack:** Git, `gh` CLI (conta GitHub `torgge`, scope `repo`), `jq` para validar JSON, manifests Cursor (`plugin.json` / `marketplace.json`).

## Global Constraints

- Plugin `name` — lowercase kebab-case, começa/termina com alfanumérico. `draw-io` já conforme. Não alterar.
- Cursor marketplace exige **repo Git público** com **ownership pela conta GitHub que submete** (`torgge`).
- Codeberg (`https://codeberg.org/torgge/skills`) permanece **canônico** — `origin` NÃO muda. GitHub é mirror.
- Paths nos manifests: **relativos apenas** (sem `..` nem absolutos).
- Cursor exige plugins **open source** — `draw-io/LICENSE` (MIT) já presente.
- **Sem validador Cursor local oficial garantido** — validação = JSON parseável (`jq`) + checklist dos docs. Não reportar "validado" além disso.
- Não editar os per-plugin manifests do `draw-io` (`.cursor-plugin/plugin.json` / `.claude-plugin/plugin.json`) — já válidos.
- Branch de trabalho: `feature/cursor-marketplace-publish` (branch off `main`, nunca commit direto em `main`).

---

### Task 1: Manifest de marketplace Cursor na raiz

Espelha o `.claude-plugin/marketplace.json` existente para o schema Cursor. Sem esse arquivo na raiz, o Cursor não enxerga a coleção como marketplace.

**Files:**
- Create: `.cursor-plugin/marketplace.json`
- Reference (não modificar): `.claude-plugin/marketplace.json`, `draw-io/.cursor-plugin/plugin.json`

**Interfaces:**
- Consumes: nada (primeira task).
- Produces: `.cursor-plugin/marketplace.json` com `name: "torgge-skills"`, `owner.name`, `plugins[]` contendo a entry `draw-io` com `source: "./draw-io"`. Task 3 faz o push desse arquivo; Task 4 aponta o publish do Cursor para o repo que o contém.

- [ ] **Step 1: Criar o branch de trabalho**

```bash
git switch -c feature/cursor-marketplace-publish
```

- [ ] **Step 2: Escrever `.cursor-plugin/marketplace.json`**

Schema Cursor multi-plugin: `name`, `owner` (`name` obrigatório, `email` opcional), `plugins[]` (máx 500). Espelha o conteúdo do manifest Claude. Não incluir campos fora do schema.

```json
{
  "name": "torgge-skills",
  "description": "Personal collection of AI-agent skills as installable plugins for Claude Code and Cursor.",
  "owner": {
    "name": "George Bonespirito",
    "email": "george@bonespirito.com"
  },
  "plugins": [
    {
      "name": "draw-io",
      "source": "./draw-io",
      "description": "Generate editable draw.io diagrams and export them as house-themed SVG (embedded XML, readable in light/dark). Mermaid or XML authoring, ELK auto-layout, browser-URL output."
    }
  ]
}
```

- [ ] **Step 3: Validar que o JSON parseia e tem os campos exigidos**

Run:
```bash
jq -e '.name and .owner.name and (.plugins | type == "array") and (.plugins[0].name == "draw-io") and (.plugins[0].source == "./draw-io")' .cursor-plugin/marketplace.json
```
Expected: imprime `true`, exit 0. Se `false`/erro de parse → corrigir o arquivo antes de seguir.

- [ ] **Step 4: Confirmar que o `source` aponta um diretório existente com manifest Cursor**

Run:
```bash
test -f "$(jq -r '.plugins[0].source' .cursor-plugin/marketplace.json)/.cursor-plugin/plugin.json" && echo OK
```
Expected: `OK`. Garante que `./draw-io/.cursor-plugin/plugin.json` existe (path relativo resolve).

- [ ] **Step 5: Commit**

```bash
git add .cursor-plugin/marketplace.json
git commit -m "✨ feat(marketplace): add Cursor marketplace manifest at repo root"
```

---

### Task 2: Repo GitHub espelho (ownership `torgge`)

Cria o repo público na conta GitHub que fará o submit, sem mexer no `origin` Codeberg. Adiciona um remote `github` dedicado ao mirror.

**Files:**
- Modify (config git, não arquivo versionado): remotes do repo local — adicionar remote `github`.

**Interfaces:**
- Consumes: nada da Task 1 (independente; só o push da Task 3 precisa do commit da Task 1).
- Produces: repo GitHub público `torgge/skills` e remote local `github` apontando para ele. Task 3 faz `git push github`.

- [ ] **Step 1: Confirmar a conta GitHub ativa é `torgge`**

Run:
```bash
gh api user --jq '.login'
```
Expected: `torgge`. Se vier outra conta → `gh auth switch --user torgge` antes de seguir (há duas contas autenticadas: `torgge` e `G-A-A-B`).

- [ ] **Step 2: Criar o repo GitHub público**

Run:
```bash
gh repo create torgge/skills --public \
  --description "Personal collection of AI-agent skills as installable plugins for Claude Code and Cursor." \
  --homepage "https://codeberg.org/torgge/skills"
```
Expected: cria o repo e imprime a URL `https://github.com/torgge/skills`. Se responder que o repo já existe → pular a criação e seguir para o Step 3 (reaproveita o existente).

- [ ] **Step 3: Adicionar o remote `github` (mantendo `origin` no Codeberg)**

Run:
```bash
git remote add github https://github.com/torgge/skills.git
git remote -v
```
Expected: `origin` continua `codeberg.org/torgge/skills`; novo `github` aponta `github.com/torgge/skills`. Se `github` já existir → `git remote set-url github https://github.com/torgge/skills.git`.

- [ ] **Step 4: Documentar o mirror no CLAUDE.md do repo**

O CLAUDE.md atual não menciona GitHub. Registrar a convenção do mirror (não derivável do código) — surgical, uma linha na seção Git.

Localizar em `CLAUDE.md` a linha que começa com `- Conventional Commits + emoji` na seção `## Git` e inserir logo abaixo:

```markdown
- **Mirror GitHub:** `origin` = Codeberg (canônico). Remote `github` = `github.com/torgge/skills`, mirror público só para o marketplace do Cursor (o publish autentica via ownership GitHub). Publicar = `git push github <branch>` após o push canônico.
```

- [ ] **Step 5: Commit da doc**

```bash
git add CLAUDE.md
git commit -m "📚 docs: document GitHub mirror for Cursor marketplace"
```

---

### Task 3: Push do conteúdo para o mirror e verificação pública

Publica a branch no Codeberg (canônico) e no GitHub (mirror), depois confirma que o `.cursor-plugin/marketplace.json` está acessível no GitHub — pré-condição do submit.

**Files:** nenhum arquivo novo — operação de push/verificação.

**Interfaces:**
- Consumes: commits das Tasks 1 e 2; remote `github` da Task 2.
- Produces: `main` do GitHub com `.cursor-plugin/marketplace.json` e `draw-io/` presentes. Task 4 submete essa URL.

- [ ] **Step 1: Merge da feature em `main` local (squash) após revisão**

> Só executar depois que as Tasks 1–2 estiverem revisadas. Segue a convenção do repo: squash-merge, um feature por PR. Se o fluxo for via PR no Codeberg, abrir o PR aqui e aguardar aprovação (ver memory `pr-create-await-approval`) em vez de mergear local.

```bash
git switch main
git merge --squash feature/cursor-marketplace-publish
git commit -m "✨ feat(marketplace): publish draw-io to Cursor marketplace"
```

- [ ] **Step 2: Push canônico para o Codeberg**

```bash
git push origin main
```
Expected: `main` atualizado no Codeberg. (Pode exigir o token via keychain — ver memory `codeberg-token-keychain`.)

- [ ] **Step 3: Push do mirror para o GitHub**

```bash
git push github main
```
Expected: `main` criado/atualizado em `github.com/torgge/skills`.

- [ ] **Step 4: Verificar que o manifest Cursor está público no GitHub**

Run:
```bash
gh api repos/torgge/skills/contents/.cursor-plugin/marketplace.json --jq '.name'
```
Expected: `marketplace.json`. Confirma que o arquivo existe na branch default pública. Se `404` → o push não incluiu o arquivo; revisar Tasks 1/3.

- [ ] **Step 5: Verificar que o plugin `draw-io` está público no GitHub**

Run:
```bash
gh api repos/torgge/skills/contents/draw-io/.cursor-plugin/plugin.json --jq '.name'
```
Expected: `plugin.json`. Confirma que o `source: "./draw-io"` resolve no repo público.

---

### Task 4: Submissão no publish do Cursor (ação manual do usuário)

O submit final é uma ação de browser no `cursor.com/marketplace/publish` — **não automatizável por CLI**. Esta task é o runbook e o checklist de pré-submissão.

**Files:** nenhum.

**Interfaces:**
- Consumes: repo GitHub público verificado (Task 3).
- Produces: submissão enviada para review da equipe Cursor. Não há passo posterior no repo.

- [ ] **Step 1: Rodar o checklist de pré-submissão dos docs**

Verificar, sem afirmar além do medido:
- `name` do plugin é único, lowercase, kebab-case → `draw-io` ✓ (confirmar em `draw-io/.cursor-plugin/plugin.json`).
- Componentes têm frontmatter YAML válido → `draw-io/skills/drawio/SKILL.md` tem `name` + `description`.
- Só paths relativos nos manifests (sem `..`/absolutos).
- `draw-io/README.md` documenta uso.
- `draw-io/LICENSE` presente (open source).
- Repo público no GitHub, conteúdo espelhado (Tasks 1–3 já verificaram).

Run (frontmatter do skill):
```bash
head -5 draw-io/skills/drawio/SKILL.md
```
Expected: bloco `---` com `name:` e `description:`.

- [ ] **Step 2: Submeter no Cursor**

> Ação manual — abrir no browser. No prompt do Claude Code, o usuário pode rodar:
> `! open https://cursor.com/marketplace/publish`

1. Login com a conta **GitHub `torgge`** (dona do repo).
2. Informar o repositório `github.com/torgge/skills`.
3. Enviar para review da equipe Cursor.

- [ ] **Step 3: Registrar o estado pós-submissão**

Após enviar, o marketplace público fica pendente de review da equipe Cursor (fora do controle do repo). Anotar a data de submissão; sem passo de código posterior. Instalação local/manual já funciona a partir do GitHub independentemente do review.

---
